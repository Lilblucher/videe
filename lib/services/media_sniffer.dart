import 'dart:async';
import 'package:flutter/foundation.dart';

class DetectedMedia {
  final String url;
  final String? title;
  final String? mimeType;
  final int? contentLength;
  final String sourceUrl;
  final DateTime detectedAt;

  DetectedMedia({
    required this.url,
    this.title,
    this.mimeType,
    this.contentLength,
    required this.sourceUrl,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  String get format {
    if (url.contains('.mp4') || mimeType?.contains('mp4') == true) return 'mp4';
    if (url.contains('.webm') || mimeType?.contains('webm') == true) return 'webm';
    if (url.contains('.m3u8') || mimeType?.contains('mpegurl') == true) return 'hls';
    if (url.contains('.ts') || mimeType?.contains('mp2t') == true) return 'ts';
    if (url.contains('.flv') || mimeType?.contains('flv') == true) return 'flv';
    if (url.contains('.mp3') || mimeType?.contains('mpeg') == true) return 'mp3';
    if (url.contains('.m4a') || mimeType?.contains('m4a') == true) return 'm4a';
    return 'mp4';
  }

  String get qualityGuess {
    final u = url.toLowerCase();
    if (u.contains('1080') || u.contains('hd1080')) return '1080p';
    if (u.contains('720') || u.contains('hd720')) return '720p';
    if (u.contains('480')) return '480p';
    if (u.contains('360')) return '360p';
    if (u.contains('240')) return '240p';
    if (u.contains('hd') || u.contains('high')) return 'HD';
    if (u.contains('sd') || u.contains('low')) return 'SD';
    return 'Auto';
  }

  bool get isAudioOnly {
    final m = mimeType?.toLowerCase() ?? '';
    return m.contains('audio') ||
        url.contains('.mp3') ||
        url.contains('.m4a') ||
        url.contains('.aac') ||
        url.contains('.ogg');
  }
}

class MediaSniffer extends ChangeNotifier {
  final List<DetectedMedia> _detectedMedia = [];
  final Set<String> _seenUrls = {};

  List<DetectedMedia> get detectedMedia => List.unmodifiable(_detectedMedia);
  int get count => _detectedMedia.length;
  bool get hasMedia => _detectedMedia.isNotEmpty;

  static final _mediaExtensions = RegExp(
    r'\.(mp4|webm|m3u8|ts|flv|mkv|avi|mov|wmv|mp3|m4a|aac|ogg|wav)(\?|$|#)',
    caseSensitive: false,
  );

  static final _mediaContentTypes = RegExp(
    r'(video/|audio/|application/x-mpegurl|application/vnd\.apple\.mpegurl|application/dash\+xml)',
    caseSensitive: false,
  );

  static final _excludePatterns = [
    RegExp(r'analytics', caseSensitive: false),
    RegExp(r'tracking', caseSensitive: false),
    RegExp(r'beacon', caseSensitive: false),
    RegExp(r'pixel', caseSensitive: false),
    RegExp(r'\.gif(\?|$)', caseSensitive: false),
    RegExp(r'\.js(\?|$)', caseSensitive: false),
    RegExp(r'\.css(\?|$)', caseSensitive: false),
    RegExp(r'favicon', caseSensitive: false),
    RegExp(r'googleads', caseSensitive: false),
    RegExp(r'doubleclick', caseSensitive: false),
    RegExp(r'ad[sv]ert', caseSensitive: false),
    RegExp(r'googlesyndication', caseSensitive: false),
    RegExp(r'facebook\.com/tr', caseSensitive: false),
  ];

  static final _googlevideoPat = RegExp(
    r'googlevideo\.com/videoplayback',
    caseSensitive: false,
  );

  bool isMediaUrl(String url) {
    if (_excludePatterns.any((p) => p.hasMatch(url))) return false;
    if (_googlevideoPat.hasMatch(url)) return true;
    return _mediaExtensions.hasMatch(url);
  }

  bool isMediaContentType(String? contentType) {
    if (contentType == null) return false;
    return _mediaContentTypes.hasMatch(contentType);
  }

  void onResourceLoaded(String url, String pageUrl, {String? contentType, int? contentLength}) {
    if (_seenUrls.contains(url)) return;
    if (!isMediaUrl(url) && !isMediaContentType(contentType)) return;

    _seenUrls.add(url);
    _detectedMedia.add(DetectedMedia(
      url: url,
      mimeType: contentType,
      contentLength: contentLength,
      sourceUrl: pageUrl,
    ));
    notifyListeners();
  }

  void addFromJsDetection(List<Map<String, dynamic>> videos, String pageUrl) {
    for (final v in videos) {
      final url = v['src'] as String? ?? '';
      if (url.isEmpty || _seenUrls.contains(url)) continue;
      _seenUrls.add(url);
      _detectedMedia.add(DetectedMedia(
        url: url,
        title: v['title'] as String?,
        mimeType: v['type'] as String?,
        sourceUrl: pageUrl,
      ));
    }
    if (videos.isNotEmpty) notifyListeners();
  }

  void clearForPage(String pageUrl) {
    _detectedMedia.clear();
    _seenUrls.clear();
    notifyListeners();
  }

  void clear() {
    _detectedMedia.clear();
    _seenUrls.clear();
    notifyListeners();
  }

  static const videoDetectionJs = '''
(function() {
  var results = [];
  var seen = {};

  // Find all <video> elements
  var videos = document.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    var v = videos[i];
    if (v.src && !seen[v.src]) {
      seen[v.src] = true;
      results.push({src: v.src, type: v.type || '', title: document.title});
    }
    if (v.currentSrc && !seen[v.currentSrc]) {
      seen[v.currentSrc] = true;
      results.push({src: v.currentSrc, type: '', title: document.title});
    }
  }

  // Find all <source> elements inside <video>
  var sources = document.querySelectorAll('video source');
  for (var i = 0; i < sources.length; i++) {
    var s = sources[i];
    if (s.src && !seen[s.src]) {
      seen[s.src] = true;
      results.push({src: s.src, type: s.type || '', title: document.title});
    }
  }

  // Find <meta property="og:video">
  var ogVideo = document.querySelector('meta[property="og:video"], meta[property="og:video:url"], meta[property="og:video:secure_url"]');
  if (ogVideo) {
    var content = ogVideo.getAttribute('content');
    if (content && !seen[content]) {
      seen[content] = true;
      results.push({src: content, type: 'video/mp4', title: document.title});
    }
  }

  // Find JSON-LD VideoObject
  var scripts = document.querySelectorAll('script[type="application/ld+json"]');
  for (var i = 0; i < scripts.length; i++) {
    try {
      var data = JSON.parse(scripts[i].textContent);
      var items = Array.isArray(data) ? data : [data];
      for (var j = 0; j < items.length; j++) {
        var item = items[j];
        if (item['@type'] === 'VideoObject' && item.contentUrl && !seen[item.contentUrl]) {
          seen[item.contentUrl] = true;
          results.push({src: item.contentUrl, type: 'video/mp4', title: item.name || document.title});
        }
      }
    } catch(e) {}
  }

  // Find embed/iframe video sources
  var iframes = document.querySelectorAll('iframe[src*="video"], iframe[src*="embed"], iframe[src*="player"]');
  for (var i = 0; i < iframes.length; i++) {
    var src = iframes[i].src;
    if (src && !seen[src]) {
      seen[src] = true;
      results.push({src: src, type: 'embed', title: document.title});
    }
  }

  // Find video URLs in data attributes
  var allElements = document.querySelectorAll('[data-video-url], [data-src*=".mp4"], [data-src*=".m3u8"], [data-video*=".mp4"]');
  for (var i = 0; i < allElements.length; i++) {
    var el = allElements[i];
    var url = el.getAttribute('data-video-url') || el.getAttribute('data-src') || el.getAttribute('data-video');
    if (url && !seen[url]) {
      seen[url] = true;
      results.push({src: url, type: '', title: document.title});
    }
  }

  return JSON.stringify(results);
})();
''';
}
