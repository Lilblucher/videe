import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/download_item.dart';
import '../models/media_item.dart';

class StorageService {
  static const _downloadsBox = 'downloads';
  static const _mediaBox = 'media';
  static const _settingsBox = 'settings';
  static const _historyBox = 'browser_history';
  static const _bookmarksBox = 'bookmarks';

  late Box _downloads;
  late Box _media;
  late Box _settings;
  late Box _history;
  late Box _bookmarks;

  Future<void> init() async {
    await Hive.initFlutter();
    _downloads = await Hive.openBox(_downloadsBox);
    _media = await Hive.openBox(_mediaBox);
    _settings = await Hive.openBox(_settingsBox);
    _history = await Hive.openBox(_historyBox);
    _bookmarks = await Hive.openBox(_bookmarksBox);
  }

  // Downloads
  List<DownloadItem> getDownloads() {
    return _downloads.values
        .map((v) => DownloadItem.fromJson(Map<String, dynamic>.from(jsonDecode(v))))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveDownload(DownloadItem item) async {
    await _downloads.put(item.id, jsonEncode(item.toJson()));
  }

  Future<void> deleteDownload(String id) async {
    await _downloads.delete(id);
  }

  // Media library
  List<MediaItem> getMediaItems() {
    return _media.values
        .map((v) => MediaItem.fromJson(Map<String, dynamic>.from(jsonDecode(v))))
        .toList()
      ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
  }

  Future<void> saveMediaItem(MediaItem item) async {
    await _media.put(item.id, jsonEncode(item.toJson()));
  }

  Future<void> deleteMediaItem(String id) async {
    await _media.delete(id);
  }

  MediaItem? getMediaItem(String id) {
    final raw = _media.get(id);
    if (raw == null) return null;
    return MediaItem.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  // Settings
  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settings.get(key, defaultValue: defaultValue) as T?;
  }

  Future<void> setSetting(String key, dynamic value) async {
    await _settings.put(key, value);
  }

  // Browser history
  List<Map<String, dynamic>> getBrowserHistory() {
    return _history.values
        .map((v) => Map<String, dynamic>.from(jsonDecode(v)))
        .toList()
      ..sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
  }

  Future<void> addHistoryEntry(String url, String title) async {
    final entry = {
      'url': url,
      'title': title,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _history.put(url.hashCode.toString(), jsonEncode(entry));
  }

  Future<void> clearHistory() async {
    await _history.clear();
  }

  // Bookmarks
  List<Map<String, dynamic>> getBookmarks() {
    return _bookmarks.values
        .map((v) => Map<String, dynamic>.from(jsonDecode(v)))
        .toList();
  }

  Future<void> addBookmark(String url, String title, {String? favicon}) async {
    final bm = {
      'url': url,
      'title': title,
      'favicon': favicon,
      'addedAt': DateTime.now().toIso8601String(),
    };
    await _bookmarks.put(url.hashCode.toString(), jsonEncode(bm));
  }

  Future<void> removeBookmark(String url) async {
    await _bookmarks.delete(url.hashCode.toString());
  }

  bool isBookmarked(String url) {
    return _bookmarks.containsKey(url.hashCode.toString());
  }
}
