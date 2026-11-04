import '../models/video_info.dart';
import '../providers/extractor_base.dart';
import '../providers/youtube_extractor.dart';
import '../providers/social_extractor.dart';
import '../providers/generic_extractor.dart';

class ExtractionService {
  final List<VideoExtractor> _extractors = [
    YouTubeExtractor(),
    InstagramExtractor(),
    TikTokExtractor(),
    TwitterExtractor(),
    FacebookExtractor(),
    GenericExtractor(),
  ];

  Future<VideoInfo?> extractVideo(String url) async {
    url = _normalizeUrl(url);

    for (final extractor in _extractors) {
      if (extractor.canHandle(url)) {
        final result = await extractor.extract(url);
        if (result != null && result.streams.isNotEmpty) {
          return result;
        }
      }
    }
    return null;
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
