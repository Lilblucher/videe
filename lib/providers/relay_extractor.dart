import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/relay_config.dart';
import '../models/video_info.dart';
import 'extractor_base.dart';

/// Extracts via `dl_service` (a standalone yt-dlp-backed relay — see
/// coreripper/CLAUDE.md's `dl_service/` section) instead of scraping the
/// platform page directly. This is the ssstik.io/fastdl.app architecture:
/// the relay server does the real extraction, and the stream URLs handed
/// back point at the relay's own `/download` route, never at the
/// platform's CDN — so there is no signed-URL/Referer/IP check for that CDN
/// to reject on-device.
///
/// Placed ahead of [TikTokExtractor]/[InstagramExtractor] in
/// [ExtractionService]'s list; if the relay is unreachable or returns
/// nothing, [ExtractionService.extractVideo] falls through to those
/// client-side scrapers automatically — this class returning null is a
/// deliberate fallback trigger, not an error swallowed.
class RelayExtractor extends VideoExtractor {
  @override
  String get name => 'Relay';

  @override
  List<String> get supportedDomains => [
        'tiktok.com',
        'vm.tiktok.com',
        'vt.tiktok.com',
        'instagram.com',
        'instagr.am',
      ];

  @override
  Future<VideoInfo?> extract(String url) async {
    try {
      final response = await http
          .post(
            Uri.parse('$relayBaseUrl/probe'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final options = data['options'] as List?;
      if (options == null || options.isEmpty) return null;

      final source = Uri.tryParse(url)?.host.contains('tiktok') == true
          ? 'tiktok'
          : 'instagram';

      final streams = <VideoStream>[];
      for (final raw in options) {
        final opt = raw as Map<String, dynamic>;
        final isAudio = opt['audioMp3'] == true;
        final sizeMb = (opt['sizeMb'] as num?)?.toDouble();
        final downloadUrl = Uri.parse('$relayBaseUrl/download').replace(
          queryParameters: {
            'url': url,
            'option': jsonEncode({
              'kind': opt['kind'],
              'fspec': opt['fspec'],
              'audioMp3': isAudio,
            }),
          },
        );

        streams.add(VideoStream(
          url: downloadUrl.toString(),
          quality: isAudio ? 'MP3' : (opt['bucket'] as String? ?? opt['label'] as String? ?? 'Auto'),
          format: isAudio ? 'mp3' : 'mp4',
          fileSize: sizeMb != null ? (sizeMb * 1024 * 1024).round() : null,
          isAudioOnly: isAudio,
        ));
      }

      if (streams.isEmpty) return null;

      return VideoInfo(
        id: url.hashCode.toString(),
        title: (data['title'] as String?) ?? '${source == 'tiktok' ? 'TikTok' : 'Instagram'} Video',
        url: url,
        duration: data['duration'] != null
            ? Duration(seconds: (data['duration'] as num).toInt())
            : null,
        source: source,
        streams: streams,
      );
    } catch (_) {
      return null;
    }
  }
}
