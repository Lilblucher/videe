enum MediaType { video, audio }

class MediaItem {
  final String id;
  final String title;
  final String filePath;
  final String? thumbnailPath;
  final String? author;
  final String source;
  final Duration? duration;
  final int fileSize;
  final MediaType type;
  final DateTime downloadedAt;
  final String? originalUrl;
  bool isFavorite;

  MediaItem({
    required this.id,
    required this.title,
    required this.filePath,
    this.thumbnailPath,
    this.author,
    required this.source,
    this.duration,
    required this.fileSize,
    required this.type,
    required this.downloadedAt,
    this.originalUrl,
    this.isFavorite = false,
  });

  String get fileSizeLabel {
    final mb = fileSize / (1024 * 1024);
    if (mb > 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get durationLabel {
    if (duration == null) return '';
    final h = duration!.inHours;
    final m = duration!.inMinutes.remainder(60);
    final s = duration!.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'thumbnailPath': thumbnailPath,
        'author': author,
        'source': source,
        'durationMs': duration?.inMilliseconds,
        'fileSize': fileSize,
        'type': type.name,
        'downloadedAt': downloadedAt.toIso8601String(),
        'originalUrl': originalUrl,
        'isFavorite': isFavorite,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'],
        title: json['title'],
        filePath: json['filePath'],
        thumbnailPath: json['thumbnailPath'],
        author: json['author'],
        source: json['source'] ?? 'unknown',
        duration: json['durationMs'] != null
            ? Duration(milliseconds: json['durationMs'])
            : null,
        fileSize: json['fileSize'] ?? 0,
        type: MediaType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => MediaType.video,
        ),
        downloadedAt: DateTime.parse(json['downloadedAt']),
        originalUrl: json['originalUrl'],
        isFavorite: json['isFavorite'] ?? false,
      );
}
