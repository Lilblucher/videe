import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'extraction_service.dart';

class ClipboardMonitor extends ChangeNotifier {
  final ExtractionService _extractionService = ExtractionService();
  Timer? _timer;
  String? _lastClipboard;
  String? _detectedUrl;
  bool _enabled = true;

  String? get detectedUrl => _detectedUrl;
  bool get hasUrl => _detectedUrl != null;
  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    if (!value) {
      _timer?.cancel();
      _timer = null;
      _detectedUrl = null;
    }
    notifyListeners();
  }

  void start() {
    if (!_enabled) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dismiss() {
    _detectedUrl = null;
    notifyListeners();
  }

  Future<void> _check() async {
    if (!_enabled) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty || text == _lastClipboard) return;
      _lastClipboard = text;

      if (_isVideoUrl(text)) {
        _detectedUrl = text;
        notifyListeners();
      }
    } catch (_) {}
  }

  bool _isVideoUrl(String text) {
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      return false;
    }
    return _extractionService.isVideoUrl(text);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
