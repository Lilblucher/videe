import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_info.dart';
import 'extractor_base.dart';

class InstagramExtractor extends VideoExtractor {
  @override
  String get name => 'Instagram';

  @override
  List<String> get supportedDomains =>
      ['instagram.com', 'www.instagram.com', 'ddinstagram.com'];

  @override
  Future<VideoInfo?> extract(String url) async {
    try {
      final cleanUrl = url.replaceFirst(RegExp(r'\?.*$'), '');
      final embedUrl = '$cleanUrl?__a=1&__d=dis';
      final response = await http.get(
        Uri.parse(embedUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return await _extractFromPage(url);
      }

      try {
        final data = jsonDecode(response.body);
        final media = data['graphql']?['shortcode_media'] ??
            data['items']?[0];
        if (media == null) return await _extractFromPage(url);

        final videoUrl = media['video_url'] as String?;
        if (videoUrl == null) return null;

        return VideoInfo(
          id: url.hashCode.toString(),
          title: (media['edge_media_to_caption']?['edges']?[0]?['node']?['text'] as String?)
                  ?.substring(0, 100) ??
              'Instagram Video',
          url: url,
          thumbnailUrl: media['display_url'] ?? media['image_versions2']?['candidates']?[0]?['url'],
          author: media['owner']?['username'],
          source: 'instagram',
          streams: [
            VideoStream(
              url: videoUrl,
              quality: 'Original',
              format: 'mp4',
            ),
          ],
        );
      } catch (_) {
        return await _extractFromPage(url);
      }
    } catch (e) {
      return null;
    }
  }

  Future<VideoInfo?> _extractFromPage(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      final body = response.body;
      final videoMatch =
          RegExp(r'"video_url":"(https?://[^"]+)"').firstMatch(body);
      if (videoMatch == null) return null;

      final videoUrl = videoMatch.group(1)!.replaceAll(r'&', '&');
      final titleMatch = RegExp(r'"text":"([^"]{1,100})"').firstMatch(body);
      final thumbMatch =
          RegExp(r'"display_url":"(https?://[^"]+)"').firstMatch(body);

      return VideoInfo(
        id: url.hashCode.toString(),
        title: titleMatch?.group(1) ?? 'Instagram Video',
        url: url,
        thumbnailUrl: thumbMatch?.group(1)?.replaceAll(r'&', '&'),
        source: 'instagram',
        streams: [
          VideoStream(url: videoUrl, quality: 'Original', format: 'mp4'),
        ],
      );
    } catch (e) {
      return null;
    }
  }
}

class TikTokExtractor extends VideoExtractor {
  @override
  String get name => 'TikTok';

  @override
  List<String> get supportedDomains =>
      ['tiktok.com', 'www.tiktok.com', 'vm.tiktok.com', 'vt.tiktok.com'];

  @override
  Future<VideoInfo?> extract(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 15));

      final body = response.body;

      final videoMatch = RegExp(r'"playAddr":"(https?://[^"]+)"').firstMatch(body) ??
          RegExp(r'"downloadAddr":"(https?://[^"]+)"').firstMatch(body);
      if (videoMatch == null) return null;

      final videoUrl = videoMatch.group(1)!
          .replaceAll(r'/', '/')
          .replaceAll(r'&', '&');

      final titleMatch =
          RegExp(r'"desc":"([^"]{1,200})"').firstMatch(body);
      final thumbMatch =
          RegExp(r'"cover":"(https?://[^"]+)"').firstMatch(body) ??
              RegExp(r'"originCover":"(https?://[^"]+)"').firstMatch(body);
      final authorMatch =
          RegExp(r'"uniqueId":"([^"]+)"').firstMatch(body);

      return VideoInfo(
        id: url.hashCode.toString(),
        title: titleMatch?.group(1) ?? 'TikTok Video',
        url: url,
        thumbnailUrl: thumbMatch?.group(1)?.replaceAll(r'/', '/'),
        author: authorMatch?.group(1),
        source: 'tiktok',
        streams: [
          VideoStream(url: videoUrl, quality: 'Original', format: 'mp4'),
        ],
      );
    } catch (e) {
      return null;
    }
  }
}

class TwitterExtractor extends VideoExtractor {
  @override
  String get name => 'Twitter/X';

  @override
  List<String> get supportedDomains =>
      ['twitter.com', 'x.com', 'mobile.twitter.com'];

  @override
  Future<VideoInfo?> extract(String url) async {
    try {
      final fxUrl = url
          .replaceFirst('twitter.com', 'fxtwitter.com')
          .replaceFirst('x.com', 'fixupx.com');

      final response = await http.get(
        Uri.parse(fxUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; Discordbot/2.0)',
        },
      ).timeout(const Duration(seconds: 15));

      final body = response.body;

      final videoMatch = RegExp(
              r'<meta[^>]+property="og:video(?::secure_url)?"[^>]+content="(https?://[^"]+)"')
          .firstMatch(body);
      if (videoMatch == null) return null;

      final videoUrl = videoMatch.group(1)!;
      final titleMatch = RegExp(
              r'<meta[^>]+property="og:description"[^>]+content="([^"]*)"')
          .firstMatch(body);
      final thumbMatch = RegExp(
              r'<meta[^>]+property="og:image"[^>]+content="(https?://[^"]+)"')
          .firstMatch(body);

      return VideoInfo(
        id: url.hashCode.toString(),
        title: titleMatch?.group(1) ?? 'Twitter Video',
        url: url,
        thumbnailUrl: thumbMatch?.group(1),
        source: 'twitter',
        streams: [
          VideoStream(url: videoUrl, quality: 'Original', format: 'mp4'),
        ],
      );
    } catch (e) {
      return null;
    }
  }
}

class FacebookExtractor extends VideoExtractor {
  @override
  String get name => 'Facebook';

  @override
  List<String> get supportedDomains =>
      ['facebook.com', 'www.facebook.com', 'fb.watch', 'm.facebook.com', 'web.facebook.com'];

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

      final body = response.body;

      final hdMatch = RegExp(r'"hd_src":"(https?://[^"]+)"').firstMatch(body) ??
          RegExp(r'"hd_src_no_ratelimit":"(https?://[^"]+)"').firstMatch(body);
      final sdMatch = RegExp(r'"sd_src":"(https?://[^"]+)"').firstMatch(body) ??
          RegExp(r'"sd_src_no_ratelimit":"(https?://[^"]+)"').firstMatch(body);

      final streams = <VideoStream>[];
      if (hdMatch != null) {
        streams.add(VideoStream(
          url: hdMatch.group(1)!.replaceAll(r'\/', '/'),
          quality: 'HD',
          format: 'mp4',
        ));
      }
      if (sdMatch != null) {
        streams.add(VideoStream(
          url: sdMatch.group(1)!.replaceAll(r'\/', '/'),
          quality: 'SD',
          format: 'mp4',
        ));
      }

      if (streams.isEmpty) return null;

      final titleMatch =
          RegExp(r'<meta[^>]+property="og:title"[^>]+content="([^"]*)"')
              .firstMatch(body);
      final thumbMatch =
          RegExp(r'<meta[^>]+property="og:image"[^>]+content="(https?://[^"]+)"')
              .firstMatch(body);

      return VideoInfo(
        id: url.hashCode.toString(),
        title: titleMatch?.group(1) ?? 'Facebook Video',
        url: url,
        thumbnailUrl: thumbMatch?.group(1),
        source: 'facebook',
        streams: streams,
      );
    } catch (e) {
      return null;
    }
  }
}
