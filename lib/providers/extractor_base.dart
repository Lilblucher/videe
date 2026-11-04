import '../models/video_info.dart';

abstract class VideoExtractor {
  String get name;
  List<String> get supportedDomains;

  bool canHandle(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return supportedDomains.any(
        (d) => host == d || host.endsWith('.$d'));
  }

  Future<VideoInfo?> extract(String url);
}
