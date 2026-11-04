import 'package:http/http.dart' as http;
import '../models/video_info.dart';
import 'extractor_base.dart';

class GenericExtractor extends VideoExtractor {
  @override
  String get name => 'Generic';

  @override
  List<String> get supportedDomains => [];

  @override
  bool canHandle(String url) => true;

  @override
  Future<VideoInfo?> extract(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final body = response.body;
      final streams = <VideoStream>[];

      final videoUrls = _extractVideoUrls(body);
      for (final vUrl in videoUrls) {
        streams.add(VideoStream(
          url: vUrl,
          quality: 'Auto',
          format: _guessFormat(vUrl),
        ));
      }

      if (streams.isEmpty) return null;

      final title = _extractTitle(body) ?? Uri.parse(url).host;
      final thumbnail = _extractThumbnail(body);

      return VideoInfo(
        id: url.hashCode.toString(),
        title: title,
        url: url,
        thumbnailUrl: thumbnail,
        source: Uri.parse(url).host,
        streams: streams,
      );
    } catch (e) {
      return null;
    }
  }

  List<String> _extractVideoUrls(String html) {
    final urls = <String>{};

    final patterns = [
      RegExp(r'"(https?://[^"]+\.(?:mp4|webm|m3u8|flv|ts|mkv|mov)[^"]*)"'),
      RegExp(r"'(https?://[^']+\.(?:mp4|webm|m3u8|flv|ts|mkv|mov)[^']*)'"),
      RegExp(r'src="(https?://[^"]+\.(?:mp4|webm|m3u8|flv|ts|mkv|mov)[^"]*)"'),
      RegExp(r'"contentUrl"\s*:\s*"(https?://[^"]+)"'),
      RegExp(r'"url"\s*:\s*"(https?://[^"]+\.(?:mp4|webm|m3u8)[^"]*)"'),
      RegExp(r'<source[^>]+src="(https?://[^"]+)"'),
      RegExp(r'file\s*:\s*"(https?://[^"]+\.(?:mp4|webm|m3u8)[^"]*)"'),
      RegExp(r'"video_url"\s*:\s*"(https?://[^"]+)"'),
      RegExp(r'"playback_url"\s*:\s*"(https?://[^"]+)"'),
      RegExp(r'"stream_url"\s*:\s*"(https?://[^"]+)"'),
      RegExp(r'"hls_url"\s*:\s*"(https?://[^"]+\.m3u8[^"]*)"'),
      RegExp(r'"dash_url"\s*:\s*"(https?://[^"]+\.mpd[^"]*)"'),
      RegExp(r'<meta[^>]+property="og:video(?::secure_url)?"[^>]+content="(https?://[^"]+)"'),
      RegExp(r'googlevideo\.com/videoplayback[^"\'>\s]+', caseSensitive: false),
    ];

    final excludePatterns = [
      RegExp(r'analytics', caseSensitive: false),
      RegExp(r'tracking', caseSensitive: false),
      RegExp(r'beacon', caseSensitive: false),
      RegExp(r'pixel', caseSensitive: false),
      RegExp(r'googleads', caseSensitive: false),
      RegExp(r'doubleclick', caseSensitive: false),
    ];

    for (final p in patterns) {
      for (final m in p.allMatches(html)) {
        final u = m.group(1) ?? m.group(0);
        if (u != null && !excludePatterns.any((ep) => ep.hasMatch(u))) {
          urls.add(u.replaceAll(r'\/', '/').replaceAll(r'&amp;', '&'));
        }
      }
    }

    return urls.toList();
  }

  String? _extractTitle(String html) {
    final ogTitle = RegExp(r'<meta[^>]+property="og:title"[^>]+content="([^"]*)"')
        .firstMatch(html)
        ?.group(1);
    if (ogTitle != null && ogTitle.isNotEmpty) return _decodeHtml(ogTitle);

    final title = RegExp(r'<title[^>]*>([^<]+)</title>')
        .firstMatch(html)
        ?.group(1);
    if (title != null && title.isNotEmpty) return _decodeHtml(title);

    return null;
  }

  String? _extractThumbnail(String html) {
    final ogImage = RegExp(r'<meta[^>]+property="og:image"[^>]+content="([^"]*)"')
        .firstMatch(html)
        ?.group(1);
    if (ogImage != null && ogImage.isNotEmpty) return ogImage;

    final twitterImage =
        RegExp(r'<meta[^>]+name="twitter:image"[^>]+content="([^"]*)"')
            .firstMatch(html)
            ?.group(1);
    return twitterImage;
  }

  String _guessFormat(String url) {
    if (url.contains('.mp4')) return 'mp4';
    if (url.contains('.webm')) return 'webm';
    if (url.contains('.m3u8')) return 'hls';
    return 'mp4';
  }

  String _decodeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'");
  }
}
