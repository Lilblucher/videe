enum DownloadStatus { queued, downloading, paused, completed, failed, cancelled }

class DownloadItem {
  final String id;
  final String videoId;
  final String title;
  final String url;
  final String streamUrl;
  final String quality;
  final String format;
  final String? thumbnailUrl;
  final String? author;
  final String source;
  final String savePath;
  final int? totalBytes;
  int downloadedBytes;
  DownloadStatus status;
  String? errorMessage;
  final DateTime createdAt;
  DateTime? completedAt;

  DownloadItem({
    required this.id,
    required this.videoId,
    required this.title,
    required this.url,
    required this.streamUrl,
    required this.quality,
    required this.format,
    this.thumbnailUrl,
    this.author,
    required this.source,
    required this.savePath,
    this.totalBytes,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.queued,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  double get progress {
    if (totalBytes == null || totalBytes == 0) return 0;
    return downloadedBytes / totalBytes!;
  }

  String get progressLabel {
    final pct = (progress * 100).toStringAsFixed(1);
    return '$pct%';
  }

  String get sizeLabel {
    String fmt(int bytes) {
      final mb = bytes / (1024 * 1024);
      if (mb > 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
      return '${mb.toStringAsFixed(1)} MB';
    }
    if (totalBytes != null) {
      return '${fmt(downloadedBytes)} / ${fmt(totalBytes!)}';
    }
    return fmt(downloadedBytes);
  }

  bool get isActive =>
      status == DownloadStatus.downloading || status == DownloadStatus.queued;

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoId': videoId,
        'title': title,
        'url': url,
        'streamUrl': streamUrl,
        'quality': quality,
        'format': format,
        'thumbnailUrl': thumbnailUrl,
        'author': author,
        'source': source,
        'savePath': savePath,
        'totalBytes': totalBytes,
        'downloadedBytes': downloadedBytes,
        'status': status.name,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
        id: json['id'],
        videoId: json['videoId'],
        title: json['title'],
        url: json['url'],
        streamUrl: json['streamUrl'],
        quality: json['quality'],
        format: json['format'],
        thumbnailUrl: json['thumbnailUrl'],
        author: json['author'],
        source: json['source'],
        savePath: json['savePath'],
        totalBytes: json['totalBytes'],
        downloadedBytes: json['downloadedBytes'] ?? 0,
        status: DownloadStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => DownloadStatus.failed,
        ),
        errorMessage: json['errorMessage'],
        createdAt: DateTime.parse(json['createdAt']),
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse(json['completedAt'])
            : null,
      );
}
