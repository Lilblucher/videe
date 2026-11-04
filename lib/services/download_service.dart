import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/download_item.dart';
import '../models/media_item.dart';
import '../models/video_info.dart';
import 'storage_service.dart';

class DownloadService extends ChangeNotifier {
  final StorageService _storage;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10),
    sendTimeout: const Duration(seconds: 30),
  ));
  final Map<String, CancelToken> _cancelTokens = {};
  List<DownloadItem> _downloads = [];
  static const _maxConcurrent = 3;

  DownloadService(this._storage) {
    _downloads = _storage.getDownloads();
    for (final d in _downloads) {
      if (d.status == DownloadStatus.downloading) {
        d.status = DownloadStatus.failed;
        d.errorMessage = 'Interrupted';
        _storage.saveDownload(d);
      }
    }
  }

  List<DownloadItem> get downloads => List.unmodifiable(_downloads);
  List<DownloadItem> get activeDownloads =>
      _downloads.where((d) => d.isActive).toList();
  List<DownloadItem> get completedDownloads =>
      _downloads.where((d) => d.status == DownloadStatus.completed).toList();

  Future<String> get _downloadDir async {
    final dir = await getExternalStorageDirectory();
    final downloadDir = Directory(p.join(dir!.path, 'Videe'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  Future<DownloadItem> startDownload(VideoInfo video, VideoStream stream) async {
    final dir = await _downloadDir;
    final ext = stream.isAudioOnly ? 'mp3' : stream.format;
    final sanitized = video.title
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final truncated = sanitized.substring(0, sanitized.length.clamp(0, 80));
    final fileName = '${truncated}_${stream.quality}.$ext';
    final savePath = p.join(dir, fileName);

    final item = DownloadItem(
      id: const Uuid().v4(),
      videoId: video.id,
      title: video.title,
      url: video.url,
      streamUrl: stream.url,
      quality: stream.quality,
      format: stream.format,
      thumbnailUrl: video.thumbnailUrl,
      author: video.author,
      source: video.source,
      savePath: savePath,
      totalBytes: stream.fileSize,
      createdAt: DateTime.now(),
    );

    _downloads.insert(0, item);
    await _storage.saveDownload(item);
    notifyListeners();

    _processQueue();
    return item;
  }

  void _processQueue() {
    final downloading =
        _downloads.where((d) => d.status == DownloadStatus.downloading).length;
    if (downloading >= _maxConcurrent) return;

    final queued =
        _downloads.where((d) => d.status == DownloadStatus.queued).toList();
    for (var i = 0; i < queued.length && (downloading + i) < _maxConcurrent; i++) {
      _executeDownload(queued[i]);
    }
  }

  Future<void> _executeDownload(DownloadItem item) async {
    item.status = DownloadStatus.downloading;
    await _storage.saveDownload(item);
    notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;

    try {
      final response = await _dio.download(
        item.streamUrl,
        item.savePath,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
            'Accept': '*/*',
          },
          followRedirects: true,
          maxRedirects: 5,
        ),
        onReceiveProgress: (received, total) {
          item.downloadedBytes = received;
          if (total > 0 && item.totalBytes == null) {
            item = _updateItemField(item, totalBytes: total);
          }
          notifyListeners();
        },
      );

      final file = File(item.savePath);
      final fileSize = await file.exists() ? await file.length() : 0;
      final contentType = response.headers.value('content-type') ?? '';

      if (fileSize < 1024 || contentType.contains('text/html')) {
        item.status = DownloadStatus.failed;
        item.errorMessage = 'Invalid video file (size: $fileSize, type: $contentType)';
        await _storage.saveDownload(item);
        try { await file.delete(); } catch (_) {}
        notifyListeners();
        _processQueue();
        return;
      }

      item.status = DownloadStatus.completed;
      item.completedAt = DateTime.now();
      await _storage.saveDownload(item);

      await _addToMediaLibrary(item);
      notifyListeners();
      _processQueue();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return;
      }
      item.status = DownloadStatus.failed;
      item.errorMessage = e.message ?? 'Download failed';
      await _storage.saveDownload(item);
      notifyListeners();
      _processQueue();
    } catch (e) {
      item.status = DownloadStatus.failed;
      item.errorMessage = e.toString();
      await _storage.saveDownload(item);
      notifyListeners();
      _processQueue();
    } finally {
      _cancelTokens.remove(item.id);
    }
  }

  DownloadItem _updateItemField(DownloadItem item, {int? totalBytes}) {
    final idx = _downloads.indexWhere((d) => d.id == item.id);
    if (idx >= 0) {
      final existing = _downloads[idx];
      if (totalBytes != null) {
        final updated = DownloadItem(
          id: existing.id,
          videoId: existing.videoId,
          title: existing.title,
          url: existing.url,
          streamUrl: existing.streamUrl,
          quality: existing.quality,
          format: existing.format,
          thumbnailUrl: existing.thumbnailUrl,
          author: existing.author,
          source: existing.source,
          savePath: existing.savePath,
          totalBytes: totalBytes,
          downloadedBytes: existing.downloadedBytes,
          status: existing.status,
          createdAt: existing.createdAt,
        );
        _downloads[idx] = updated;
        return updated;
      }
    }
    return item;
  }

  Future<void> _addToMediaLibrary(DownloadItem item) async {
    final file = File(item.savePath);
    if (!await file.exists()) return;

    final stat = await file.stat();
    final mediaItem = MediaItem(
      id: item.id,
      title: item.title,
      filePath: item.savePath,
      thumbnailPath: item.thumbnailUrl,
      author: item.author,
      source: item.source,
      fileSize: stat.size,
      type: item.format == 'mp3' || item.format == 'webm' && item.quality.contains('kbps')
          ? MediaType.audio
          : MediaType.video,
      downloadedAt: DateTime.now(),
      originalUrl: item.url,
    );

    await _storage.saveMediaItem(mediaItem);
  }

  Future<void> pauseDownload(String id) async {
    final item = _downloads.firstWhere((d) => d.id == id);
    _cancelTokens[id]?.cancel();
    _cancelTokens.remove(id);
    item.status = DownloadStatus.paused;
    await _storage.saveDownload(item);
    notifyListeners();
    _processQueue();
  }

  Future<void> resumeDownload(String id) async {
    final item = _downloads.firstWhere((d) => d.id == id);
    item.status = DownloadStatus.queued;
    item.downloadedBytes = 0;
    item.errorMessage = null;
    await _storage.saveDownload(item);
    notifyListeners();
    _processQueue();
  }

  Future<void> cancelDownload(String id) async {
    _cancelTokens[id]?.cancel();
    _cancelTokens.remove(id);
    final item = _downloads.firstWhere((d) => d.id == id);
    item.status = DownloadStatus.cancelled;
    await _storage.saveDownload(item);

    final file = File(item.savePath);
    if (await file.exists()) await file.delete();

    notifyListeners();
    _processQueue();
  }

  Future<void> retryDownload(String id) async {
    await resumeDownload(id);
  }

  Future<void> removeDownload(String id) async {
    _cancelTokens[id]?.cancel();
    _cancelTokens.remove(id);
    _downloads.removeWhere((d) => d.id == id);
    await _storage.deleteDownload(id);
    notifyListeners();
  }

  Future<void> clearCompleted() async {
    final completed = _downloads
        .where((d) => d.status == DownloadStatus.completed)
        .toList();
    for (final item in completed) {
      _downloads.remove(item);
      await _storage.deleteDownload(item.id);
    }
    notifyListeners();
  }
}
