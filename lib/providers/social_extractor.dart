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
    return await _tryDdInstagram(url) ??
        await _tryEmbedPage(url) ??
        await _tryPageScrape(url);
  }

  Future<VideoInfo?> _tryDdInstagram(String url) async {
    try {
      final ddUrl = url
          .replaceFirst('instagram.com', 'ddinstagram.com')
          .replaceFirst('www.ddinstagram.com', 'ddinstagram.com');
      final response = await http.get(
        Uri.parse(ddUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; Discordbot/2.0)',
          'Accept': 'text/html',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final body = response.body;

      final videoMatch = RegExp(
        r'<meta\s+property="og:video(?::secure_url)?"\s+content="(https?://[^"]+)"',
      ).firstMatch(body);
      if (videoMatch == null) return null;

      final videoUrl = videoMatch.group(1)!;
      final titleMatch = RegExp(
        r'<meta\s+property="og:description"\s+content="([^"]*)"',
      ).firstMatch(body);
      final thumbMatch = RegExp(
        r'<meta\s+property="og:image"\s+content="(https?://[^"]+)"',
      ).firstMatch(body);

      return VideoInfo(
        id: url.hashCode.toString(),
        title: _decodeHtml(titleMatch?.group(1) ?? 'Instagram Video'),
        url: url,
        thumbnailUrl: thumbMatch?.group(1),
        source: 'instagram',
        streams: [
          VideoStream(url: videoUrl, quality: 'Original', format: 'mp4'),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<VideoInfo?> _tryEmbedPage(String url) async {
    try {
      final shortcode = _extractShortcode(url);
      if (shortcode == null) return null;

      final embedUrl = 'https://www.instagram.com/p/$shortcode/embed/';
      final response = await http.get(
        Uri.parse(embedUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final body = response.body;

      final videoMatch = RegExp(r'"video_url"\s*:\s*"(https?://[^"]+)"').firstMatch(body);
      if (videoMatch == null) return null;

      final videoUrl = videoMatch.group(1)!.replaceAll(r'&', '&').replaceAll(r'\/', '/');
      final thumbMatch = RegExp(r'"display_url"\s*:\s*"(https?://[^"]+)"').firstMatch(body);
      final captionMatch = RegExp(r'"caption"\s*:\s*\{[^}]*"text"\s*:\s*"([^"]{1,200})"').firstMatch(body);

      return VideoInfo(
        id: url.hashCode.toString(),
        title: captionMatch?.group(1) ?? 'Instagram Video',
        url: url,
        thumbnailUrl: thumbMatch?.group(1)?.replaceAll(r'&', '&'),
        source: 'instagram',
        streams: [
          VideoStream(url: videoUrl, quality: 'Original', format: 'mp4'),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<VideoInfo?> _tryPageScrape(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 15));

      final body = response.body;

      final patterns = [
        RegExp(r'"video_url"\s*:\s*"(https?://[^"]+)"'),
        RegExp(r'"video_versions"\s*:\s*\[.*?"url"\s*:\s*"(https?://[^"]+)"'),
        RegExp(r'content="(https?://[^"]+\.mp4[^"]*)"'),
      ];

      for (final p in patterns) {
        final match = p.firstMatch(body);
        if (match != null) {
          final videoUrl = match.group(1)!.replaceAll(r'&', '&').replaceAll(r'\/', '/');
          return VideoInfo(
            id: url.hashCode.toString(),
            title: 'Instagram Video',
            url: url,
            source: 'instagram',
            streams: [
              VideoStream(url: videoUrl, quality: 'Original', format: 'mp4'),
            ],
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _extractShortcode(String url) {
    final match = RegExp(r'instagram\.com/(?:p|reel|tv)/([A-Za-z0-9_-]+)').firstMatch(url);
    return match?.group(1);
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
    return await _tryOembed(url) ??
        await _tryDirectScrape(url);
  }

  Future<VideoInfo?> _tryOembed(String url) async {
    try {
      final oembedUrl = 'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(url)}';
      final response = await http.get(
        Uri.parse(oembedUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final title = data['title'] as String? ?? 'TikTok Video';
      final thumbUrl = data['thumbnail_url'] as String?;
      final author = data['author_name'] as String?;

      final videoUrl = await _getVideoFromPage(url);
      if (videoUrl == null) return null;

      return VideoInfo(
        id: url.hashCode.toString(),
        title: title,
        url: url,
        thumbnailUrl: thumbUrl,
        author: author,
        source: 'tiktok',
        streams: [
          VideoStream(url: videoUrl, quality: 'Original', format: 'mp4'),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getVideoFromPage(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      final body = response.body;

      final patterns = [
        RegExp(r'"playAddr"\s*:\s*"(https?://[^"]+)"'),
        RegExp(r'"downloadAddr"\s*:\s*"(https?://[^"]+)"'),
        RegExp(r'"playAddr"\s*:\s*\[\s*"(https?://[^"]+)"'),
        RegExp(r'<meta\s+property="og:video(?::secure_url)?"\s+content="(https?://[^"]+)"'),
        RegExp(r'"urls"\s*:\s*\[\s*"(https?://[^"]+)"'),
      ];

      for (final p in patterns) {
        final match = p.firstMatch(body);
        if (match != null) {
          return match
              .group(1)!
              .replaceAll(r'/', '/')
              .replaceAll(r'&', '&')
              .replaceAll(r'\/', '/');
        }
      }

      final scriptMatch = RegExp(
        r'<script\s+id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>',
        dotAll: true,
      ).firstMatch(body);
      if (scriptMatch != null) {
        try {
          final data = jsonDecode(scriptMatch.group(1)!);
          final videoData = data['__DEFAULT_SCOPE__']?['webapp.video-detail']?['itemInfo']?['itemStruct'];
          final playAddr = videoData?['video']?['playAddr'] as String?;
          if (playAddr != null) return playAddr;
          final bitrateAddr = videoData?['video']?['bitrateInfo']?[0]?['PlayAddr']?['UrlList']?[0] as String?;
          if (bitrateAddr != null) return bitrateAddr;
        } catch (_) {}
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<VideoInfo?> _tryDirectScrape(String url) async {
    try {
      final videoUrl = await _getVideoFromPage(url);
      if (videoUrl == null) return null;

      return VideoInfo(
        id: url.hashCode.toString(),
        title: 'TikTok Video',
        url: url,
        source: 'tiktok',
        streams: [
          VideoStream(url: videoUrl, quality: 'Original', format: 'mp4'),
        ],
      );
    } catch (_) {
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
    return await _tryFxTwitter(url) ??
        await _tryVxTwitter(url) ??
        await _tryDirectScrape(url);
  }

  Future<VideoInfo?> _tryFxTwitter(String url) async {
    try {
      final fxUrl = url
          .replaceFirst('twitter.com', 'fxtwitter.com')
          .replaceFirst('x.com', 'fixupx.com');

      final response = await http.get(
        Uri.parse(fxUrl),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; Discordbot/2.0)'},
      ).timeout(const Duration(seconds: 15));

      final body = response.body;

      final videoMatch = RegExp(
        r'<meta\s+property="og:video(?::secure_url)?"\s+content="(https?://[^"]+)"',
      ).firstMatch(body);
      if (videoMatch == null) return null;

      final videoUrl = videoMatch.group(1)!;
      final titleMatch = RegExp(
        r'<meta\s+property="og:description"\s+content="([^"]*)"',
      ).firstMatch(body);
      final thumbMatch = RegExp(
        r'<meta\s+property="og:image"\s+content="(https?://[^"]+)"',
      ).firstMatch(body);

      return VideoInfo(
        id: url.hashCode.toString(),
        title: _decodeHtml(titleMatch?.group(1) ?? 'Twitter Video'),
        url: url,
        thumbnailUrl: thumbMatch?.group(1),
        source: 'twitter',
        streams: [
          VideoStream(url: videoUrl, quality: 'Original', format: 'mp4'),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<VideoInfo?> _tryVxTwitter(String url) async {
    try {
      final apiUrl = url
          .replaceFirst('twitter.com', 'api.vxtwitter.com')
          .replaceFirst('x.com', 'api.vxtwitter.com');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);

      final mediaList = data['media_extended'] as List?;
      if (mediaList == null || mediaList.isEmpty) return null;

      final streams = <VideoStream>[];
      for (final media in mediaList) {
        if (media['type'] != 'video') continue;
        final mediaUrl = media['url'] as String?;
        if (mediaUrl == null) continue;
        streams.add(VideoStream(
          url: mediaUrl,
          quality: '${media['size']?['width'] ?? ''}x${media['size']?['height'] ?? ''}'.replaceAll('x', '') .isEmpty
              ? 'Original'
              : '${media['size']?['height'] ?? ''}p',
          format: 'mp4',
        ));
      }

      if (streams.isEmpty) return null;

      return VideoInfo(
        id: url.hashCode.toString(),
        title: (data['text'] as String?)?.substring(0, (data['text'] as String).length.clamp(0, 120)) ?? 'Twitter Video',
        url: url,
        thumbnailUrl: data['media_extended']?[0]?['thumbnail_url'] as String?,
        author: data['user_name'] as String?,
        source: 'twitter',
        streams: streams,
      );
    } catch (_) {
      return null;
    }
  }

  Future<VideoInfo?> _tryDirectScrape(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      final body = response.body;
      final videoMatch = RegExp(
        r'<meta\s+property="og:video(?::secure_url)?"\s+content="(https?://[^"]+)"',
      ).firstMatch(body);
      if (videoMatch == null) return null;

      return VideoInfo(
        id: url.hashCode.toString(),
        title: 'Twitter Video',
        url: url,
        source: 'twitter',
        streams: [
          VideoStream(url: videoMatch.group(1)!, quality: 'Original', format: 'mp4'),
        ],
      );
    } catch (_) {
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
    return await _tryMobileVersion(url) ??
        await _tryDesktopScrape(url);
  }

  Future<VideoInfo?> _tryMobileVersion(String url) async {
    try {
      final mobileUrl = url
          .replaceFirst('www.facebook.com', 'm.facebook.com')
          .replaceFirst('web.facebook.com', 'm.facebook.com');

      final response = await http.get(
        Uri.parse(mobileUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
          'Accept': 'text/html',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      final body = response.body;
      final streams = <VideoStream>[];

      final hdPatterns = [
        RegExp(r'"hd_src"\s*:\s*"(https?://[^"]+)"'),
        RegExp(r'"hd_src_no_ratelimit"\s*:\s*"(https?://[^"]+)"'),
        RegExp(r'hd_src\s*:\s*"(https?://[^"]+)"'),
        RegExp(r'"browser_native_hd_url"\s*:\s*"(https?://[^"]+)"'),
      ];
      final sdPatterns = [
        RegExp(r'"sd_src"\s*:\s*"(https?://[^"]+)"'),
        RegExp(r'"sd_src_no_ratelimit"\s*:\s*"(https?://[^"]+)"'),
        RegExp(r'sd_src\s*:\s*"(https?://[^"]+)"'),
        RegExp(r'"browser_native_sd_url"\s*:\s*"(https?://[^"]+)"'),
      ];

      for (final p in hdPatterns) {
        final match = p.firstMatch(body);
        if (match != null) {
          streams.add(VideoStream(
            url: _cleanFbUrl(match.group(1)!),
            quality: 'HD',
            format: 'mp4',
          ));
          break;
        }
      }

      for (final p in sdPatterns) {
        final match = p.firstMatch(body);
        if (match != null) {
          streams.add(VideoStream(
            url: _cleanFbUrl(match.group(1)!),
            quality: 'SD',
            format: 'mp4',
          ));
          break;
        }
      }

      final ogVideo = RegExp(
        r'<meta\s+property="og:video(?::secure_url)?"\s+content="(https?://[^"]+)"',
      ).firstMatch(body);
      if (ogVideo != null && streams.isEmpty) {
        streams.add(VideoStream(
          url: ogVideo.group(1)!,
          quality: 'Auto',
          format: 'mp4',
        ));
      }

      if (streams.isEmpty) return null;

      final titleMatch = RegExp(
        r'<meta\s+property="og:title"\s+content="([^"]*)"',
      ).firstMatch(body);
      final thumbMatch = RegExp(
        r'<meta\s+property="og:image"\s+content="(https?://[^"]+)"',
      ).firstMatch(body);

      return VideoInfo(
        id: url.hashCode.toString(),
        title: _decodeHtml(titleMatch?.group(1) ?? 'Facebook Video'),
        url: url,
        thumbnailUrl: thumbMatch?.group(1),
        source: 'facebook',
        streams: streams,
      );
    } catch (_) {
      return null;
    }
  }

  Future<VideoInfo?> _tryDesktopScrape(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      final body = response.body;
      final playableMatch = RegExp(r'"playable_url(?:_quality_hd)?"\s*:\s*"(https?://[^"]+)"').firstMatch(body);
      if (playableMatch == null) return null;

      return VideoInfo(
        id: url.hashCode.toString(),
        title: 'Facebook Video',
        url: url,
        source: 'facebook',
        streams: [
          VideoStream(
            url: _cleanFbUrl(playableMatch.group(1)!),
            quality: 'Auto',
            format: 'mp4',
          ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  String _cleanFbUrl(String url) {
    return url
        .replaceAll(r'\/', '/')
        .replaceAll(r'%', '%')
        .replaceAll(r'&', '&');
  }
}

class RedditExtractor extends VideoExtractor {
  @override
  String get name => 'Reddit';

  @override
  List<String> get supportedDomains =>
      ['reddit.com', 'www.reddit.com', 'old.reddit.com', 'v.redd.it'];

  @override
  Future<VideoInfo?> extract(String url) async {
    try {
      var jsonUrl = url;
      if (!jsonUrl.endsWith('.json')) {
        jsonUrl = jsonUrl.replaceAll(RegExp(r'\?.*$'), '');
        if (!jsonUrl.endsWith('/')) jsonUrl += '/';
        jsonUrl += '.json';
      }

      final response = await http.get(
        Uri.parse(jsonUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; Videe/1.0)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);

      final post = data is List
          ? data[0]?['data']?['children']?[0]?['data']
          : data['data']?['children']?[0]?['data'];
      if (post == null) return null;

      final title = post['title'] as String? ?? 'Reddit Video';
      final thumbnail = post['thumbnail'] as String?;
      final streams = <VideoStream>[];

      final redditVideo = post['secure_media']?['reddit_video'] ??
          post['media']?['reddit_video'];
      if (redditVideo != null) {
        final fallbackUrl = redditVideo['fallback_url'] as String?;
        final dashUrl = redditVideo['dash_url'] as String?;
        final hlsUrl = redditVideo['hls_url'] as String?;
        final height = redditVideo['height'] as int?;

        if (fallbackUrl != null) {
          streams.add(VideoStream(
            url: fallbackUrl,
            quality: height != null ? '${height}p' : 'Original',
            format: 'mp4',
          ));

          if (height != null) {
            for (final q in [720, 480, 360, 240]) {
              if (q < height) {
                final lowerUrl = fallbackUrl.replaceFirst(
                  RegExp(r'DASH_\d+'),
                  'DASH_$q',
                );
                streams.add(VideoStream(
                  url: lowerUrl,
                  quality: '${q}p',
                  format: 'mp4',
                ));
              }
            }
          }
        }

        if (hlsUrl != null) {
          streams.add(VideoStream(url: hlsUrl, quality: 'Auto (HLS)', format: 'hls'));
        }
        if (dashUrl != null) {
          streams.add(VideoStream(url: dashUrl, quality: 'Auto (DASH)', format: 'dash'));
        }

        final audioUrl = fallbackUrl?.replaceFirst(RegExp(r'DASH_\d+\.mp4'), 'DASH_audio.mp4');
        if (audioUrl != null) {
          streams.add(VideoStream(
            url: audioUrl,
            quality: 'Audio',
            format: 'mp4',
            isAudioOnly: true,
          ));
        }
      }

      if (streams.isEmpty) {
        final videoUrl = post['url'] as String?;
        if (videoUrl != null && (videoUrl.contains('.mp4') || videoUrl.contains('.gifv'))) {
          streams.add(VideoStream(
            url: videoUrl.replaceFirst('.gifv', '.mp4'),
            quality: 'Original',
            format: 'mp4',
          ));
        }
      }

      if (streams.isEmpty) return null;

      return VideoInfo(
        id: url.hashCode.toString(),
        title: title,
        url: url,
        thumbnailUrl: thumbnail != null && thumbnail.startsWith('http') ? thumbnail : null,
        author: post['author'] as String?,
        source: 'reddit',
        streams: streams,
      );
    } catch (_) {
      return null;
    }
  }
}

class VimeoExtractor extends VideoExtractor {
  @override
  String get name => 'Vimeo';

  @override
  List<String> get supportedDomains =>
      ['vimeo.com', 'www.vimeo.com', 'player.vimeo.com'];

  @override
  Future<VideoInfo?> extract(String url) async {
    return await _tryOembed(url) ??
        await _tryConfigApi(url);
  }

  Future<VideoInfo?> _tryOembed(String url) async {
    try {
      final oembedUrl = 'https://vimeo.com/api/oembed.json?url=${Uri.encodeComponent(url)}';
      final response = await http.get(
        Uri.parse(oembedUrl),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);

      final videoId = _extractVideoId(url);
      if (videoId == null) return null;

      return await _tryConfigApi(url, videoId: videoId, title: data['title'] as String?,
          author: data['author_name'] as String?, thumbUrl: data['thumbnail_url'] as String?);
    } catch (_) {
      return null;
    }
  }

  Future<VideoInfo?> _tryConfigApi(String url, {String? videoId, String? title, String? author, String? thumbUrl}) async {
    try {
      videoId ??= _extractVideoId(url);
      if (videoId == null) return null;

      final configUrl = 'https://player.vimeo.com/video/$videoId/config';
      final response = await http.get(
        Uri.parse(configUrl),
        headers: {
          'Referer': url,
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);

      final streams = <VideoStream>[];
      final progressive = data['request']?['files']?['progressive'] as List?;
      if (progressive != null) {
        for (final file in progressive) {
          streams.add(VideoStream(
            url: file['url'] as String,
            quality: file['quality'] as String? ?? 'Auto',
            format: 'mp4',
            fileSize: file['size'] as int?,
          ));
        }
      }

      final hlsUrl = data['request']?['files']?['hls']?['cdns']?.values?.first?['url'] as String?;
      if (hlsUrl != null) {
        streams.add(VideoStream(url: hlsUrl, quality: 'Auto (HLS)', format: 'hls'));
      }

      if (streams.isEmpty) return null;

      streams.sort((a, b) => (b.fileSize ?? 0).compareTo(a.fileSize ?? 0));

      return VideoInfo(
        id: videoId,
        title: title ?? data['video']?['title'] as String? ?? 'Vimeo Video',
        url: url,
        thumbnailUrl: thumbUrl ?? data['video']?['thumbs']?['640'] as String?,
        author: author ?? data['video']?['owner']?['name'] as String?,
        duration: data['video']?['duration'] != null
            ? Duration(seconds: data['video']['duration'] as int)
            : null,
        source: 'vimeo',
        streams: streams,
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractVideoId(String url) {
    final match = RegExp(r'vimeo\.com/(?:video/)?(\d+)').firstMatch(url);
    return match?.group(1);
  }
}

class DailymotionExtractor extends VideoExtractor {
  @override
  String get name => 'Dailymotion';

  @override
  List<String> get supportedDomains =>
      ['dailymotion.com', 'www.dailymotion.com', 'dai.ly'];

  @override
  Future<VideoInfo?> extract(String url) async {
    try {
      final videoId = _extractVideoId(url);
      if (videoId == null) return null;

      final oembedUrl = 'https://www.dailymotion.com/services/oembed?url=${Uri.encodeComponent(url)}&format=json';
      final oembedResponse = await http.get(Uri.parse(oembedUrl)).timeout(const Duration(seconds: 10));
      String? title;
      String? author;
      String? thumbUrl;

      if (oembedResponse.statusCode == 200) {
        final data = jsonDecode(oembedResponse.body);
        title = data['title'] as String?;
        author = data['author_name'] as String?;
        thumbUrl = data['thumbnail_url'] as String?;
      }

      final embedUrl = 'https://www.dailymotion.com/player/metadata/video/$videoId';
      final response = await http.get(
        Uri.parse(embedUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);

      final streams = <VideoStream>[];
      final qualities = data['qualities'] as Map<String, dynamic>?;
      if (qualities != null) {
        for (final entry in qualities.entries) {
          final quality = entry.key;
          final sources = entry.value as List?;
          if (sources == null) continue;
          for (final source in sources) {
            final sourceUrl = source['url'] as String?;
            final type = source['type'] as String?;
            if (sourceUrl == null) continue;
            if (type == 'application/x-mpegURL') {
              streams.add(VideoStream(url: sourceUrl, quality: '$quality (HLS)', format: 'hls'));
            } else {
              streams.add(VideoStream(url: sourceUrl, quality: quality, format: 'mp4'));
            }
          }
        }
      }

      if (streams.isEmpty) return null;

      return VideoInfo(
        id: videoId,
        title: title ?? data['title'] as String? ?? 'Dailymotion Video',
        url: url,
        thumbnailUrl: thumbUrl ?? data['poster_url'] as String?,
        author: author ?? data['owner']?['screenname'] as String?,
        duration: data['duration'] != null
            ? Duration(seconds: (data['duration'] as num).toInt())
            : null,
        source: 'dailymotion',
        streams: streams,
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractVideoId(String url) {
    final match = RegExp(r'(?:dailymotion\.com/video/|dai\.ly/)([a-zA-Z0-9]+)').firstMatch(url);
    return match?.group(1);
  }
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
