class VideoStream {
  final String url;
  final String quality;
  final String format;
  final int? fileSize;
  final bool isAudioOnly;
  final bool isVideoOnly;
  final String? codec;

  VideoStream({
    required this.url,
    required this.quality,
    required this.format,
    this.fileSize,
    this.isAudioOnly = false,
    this.isVideoOnly = false,
    this.codec,
  });

  String get label {
    if (isAudioOnly) return '$quality (Audio)';
    if (isVideoOnly) return '$quality (Video only)';
    return '$quality ($format)';
  }

  String get sizeLabel {
    if (fileSize == null) return '';
    final mb = fileSize! / (1024 * 1024);
    if (mb > 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'quality': quality,
        'format': format,
        'fileSize': fileSize,
        'isAudioOnly': isAudioOnly,
        'isVideoOnly': isVideoOnly,
        'codec': codec,
      };

  factory VideoStream.fromJson(Map<String, dynamic> json) => VideoStream(
        url: json['url'] ?? '',
        quality: json['quality'] ?? '',
        format: json['format'] ?? '',
        fileSize: json['fileSize'],
        isAudioOnly: json['isAudioOnly'] ?? false,
        isVideoOnly: json['isVideoOnly'] ?? false,
        codec: json['codec'],
      );
}

class VideoInfo {
  final String id;
  final String title;
  final String url;
  final String? thumbnailUrl;
  final String? author;
  final Duration? duration;
  final String source;
  final List<VideoStream> streams;
  final String? description;
  final DateTime? uploadDate;
  final int? viewCount;

  VideoInfo({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnailUrl,
    this.author,
    this.duration,
    required this.source,
    required this.streams,
    this.description,
    this.uploadDate,
    this.viewCount,
  });

  String get durationLabel {
    if (duration == null) return '';
    final h = duration!.inHours;
    final m = duration!.inMinutes.remainder(60);
    final s = duration!.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        'author': author,
        'durationMs': duration?.inMilliseconds,
        'source': source,
        'streams': streams.map((s) => s.toJson()).toList(),
        'description': description,
        'uploadDate': uploadDate?.toIso8601String(),
        'viewCount': viewCount,
      };

  factory VideoInfo.fromJson(Map<String, dynamic> json) => VideoInfo(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        url: json['url'] ?? '',
        thumbnailUrl: json['thumbnailUrl'],
        author: json['author'],
        duration: json['durationMs'] != null
            ? Duration(milliseconds: json['durationMs'])
            : null,
        source: json['source'] ?? 'unknown',
        streams: (json['streams'] as List? ?? [])
            .map((s) => VideoStream.fromJson(s))
            .toList(),
        description: json['description'],
        uploadDate: json['uploadDate'] != null
            ? DateTime.tryParse(json['uploadDate'])
            : null,
        viewCount: json['viewCount'],
      );
}
