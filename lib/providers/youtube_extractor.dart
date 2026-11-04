import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../models/video_info.dart';
import 'extractor_base.dart';

class YouTubeExtractor extends VideoExtractor {
  final _client = yt.YoutubeExplode();

  @override
  String get name => 'YouTube';

  @override
  List<String> get supportedDomains => [
        'youtube.com',
        'www.youtube.com',
        'm.youtube.com',
        'youtu.be',
        'youtube-nocookie.com',
      ];

  @override
  Future<VideoInfo?> extract(String url) async {
    try {
      final videoId = yt.VideoId.parseVideoId(url);
      if (videoId == null) return null;

      final video = await _client.videos.get(videoId);
      final manifest = await _client.videos.streamsClient.getManifest(videoId);

      final streams = <VideoStream>[];

      for (final s in manifest.muxed) {
        streams.add(VideoStream(
          url: s.url.toString(),
          quality: s.qualityLabel,
          format: s.container.name,
          fileSize: s.size.totalBytes,
          codec: s.videoCodec,
        ));
      }

      for (final s in manifest.videoOnly) {
        streams.add(VideoStream(
          url: s.url.toString(),
          quality: s.qualityLabel,
          format: s.container.name,
          fileSize: s.size.totalBytes,
          isVideoOnly: true,
          codec: s.videoCodec,
        ));
      }

      for (final s in manifest.audioOnly) {
        final bitrate = '${(s.bitrate.bitsPerSecond / 1000).round()}kbps';
        streams.add(VideoStream(
          url: s.url.toString(),
          quality: bitrate,
          format: s.container.name,
          fileSize: s.size.totalBytes,
          isAudioOnly: true,
          codec: s.audioCodec,
        ));
      }

      streams.sort((a, b) {
        if (a.isAudioOnly != b.isAudioOnly) return a.isAudioOnly ? 1 : -1;
        if (a.isVideoOnly != b.isVideoOnly) return a.isVideoOnly ? 1 : -1;
        return (b.fileSize ?? 0).compareTo(a.fileSize ?? 0);
      });

      return VideoInfo(
        id: videoId,
        title: video.title,
        url: url,
        thumbnailUrl: video.thumbnails.highResUrl,
        author: video.author,
        duration: video.duration,
        source: 'youtube',
        streams: streams,
        description: video.description,
        uploadDate: video.uploadDate,
        viewCount: video.engagement.viewCount,
      );
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
