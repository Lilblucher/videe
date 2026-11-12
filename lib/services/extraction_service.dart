import '../models/video_info.dart';
import '../providers/extractor_base.dart';
import '../providers/youtube_extractor.dart';
import '../providers/social_extractor.dart';
import '../providers/relay_extractor.dart';
import '../providers/generic_extractor.dart';

class ExtractionService {
  final List<VideoExtractor> _extractors = [
    YouTubeExtractor(),
    // Relay (dl_service) goes first for TikTok/Instagram: it's the
    // server-side yt-dlp extraction that survives CDN blocking, the
    // client-side scrapers below are the fallback when the relay is
    // unreachable or returns nothing.
    RelayExtractor(),
    InstagramExtractor(),
    TikTokExtractor(),
    TwitterExtractor(),
    FacebookExtractor(),
    RedditExtractor(),
    VimeoExtractor(),
    DailymotionExtractor(),
    GenericExtractor(),
  ];

  Future<VideoInfo?> extractVideo(String url) async {
    url = _normalizeUrl(url);

    for (final extractor in _extractors) {
      if (extractor.canHandle(url)) {
        final result = await extractor.extract(url);
        if (result != null && result.streams.isNotEmpty) {
          final direct = _directlyDownloadable(result);
          if (direct != null) return direct;
        }
      }
    }
    return null;
  }

  // HLS (.m3u8) and DASH streams are segmented manifests, not single files -
  // a plain GET download only saves the playlist text, not playable video.
  // The download pipeline has no HLS muxer, so only progressive/direct
  // streams can be offered.
  VideoInfo? _directlyDownloadable(VideoInfo video) {
    final direct = video.streams
        .where((s) => s.format != 'hls' && s.format != 'dash')
        .toList();
    if (direct.isEmpty) return null;
    return VideoInfo(
      id: video.id,
      title: video.title,
      url: video.url,
      thumbnailUrl: video.thumbnailUrl,
      author: video.author,
      duration: video.duration,
      source: video.source,
      streams: direct,
      description: video.description,
      uploadDate: video.uploadDate,
      viewCount: video.viewCount,
    );
  }

  String getSourceName(String url) {
    for (final ext in _extractors) {
      if (ext.canHandle(url) && ext is! GenericExtractor) {
        return ext.name;
      }
    }
    return Uri.tryParse(url)?.host ?? 'Unknown';
  }

  bool isVideoUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final videoPatterns = [
      RegExp(r'youtube\.com/watch'),
      RegExp(r'youtu\.be/'),
      RegExp(r'youtube\.com/shorts/'),
      RegExp(r'instagram\.com/(?:p|reel|tv)/'),
      RegExp(r'tiktok\.com/.*video'),
      RegExp(r'tiktok\.com/@[^/]+/video'),
      RegExp(r'(?:twitter|x)\.com/.+/status/'),
      RegExp(r'facebook\.com/.+/videos/'),
      RegExp(r'fb\.watch/'),
      RegExp(r'vimeo\.com/\d+'),
      RegExp(r'dailymotion\.com/video/'),
      RegExp(r'reddit\.com/.+/comments/'),
    ];

    return videoPatterns.any((p) => p.hasMatch(url));
  }

  String _normalizeUrl(String url) {
    url = url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }
}
