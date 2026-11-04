import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../models/video_info.dart';
import '../../services/extraction_service.dart';
import '../../services/media_sniffer.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/download_sheet.dart';

class BrowserScreen extends StatefulWidget {
  final String? initialUrl;
  final StorageService storage;

  const BrowserScreen({super.key, this.initialUrl, required this.storage});

  @override
  State<BrowserScreen> createState() => BrowserScreenState();
}

class BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? _webController;
  final _urlController = TextEditingController();
  final _extractionService = ExtractionService();
  final _mediaSniffer = MediaSniffer();
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = '';
  double _progress = 0;
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    final startUrl = widget.initialUrl ?? 'https://www.google.com';
    _currentUrl = startUrl;
    _urlController.text = startUrl;
    _mediaSniffer.addListener(_onMediaChanged);
  }

  void _onMediaChanged() {
    if (mounted) setState(() {});
  }

  void loadUrl(String url) {
    if (!url.startsWith('http')) url = 'https://$url';
    _urlController.text = url;
    _currentUrl = url;
    _mediaSniffer.clearForPage(url);
    _webController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _mediaSniffer.removeListener(_onMediaChanged);
    _mediaSniffer.dispose();
    super.dispose();
  }

  void _navigate() {
    var url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (!url.contains('.') || url.contains(' ')) {
      url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
    } else if (!url.startsWith('http')) {
      url = 'https://$url';
    }

    _mediaSniffer.clearForPage(url);
    _webController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> _runJsVideoDetection() async {
    if (_webController == null) return;
    try {
      final result = await _webController!.evaluateJavascript(
        source: MediaSniffer.videoDetectionJs,
      );
      if (result != null && result != 'null' && result != '[]') {
        final String jsonStr = result is String ? result : result.toString();
        final List<dynamic> videos = jsonDecode(jsonStr);
        _mediaSniffer.addFromJsDetection(
          videos.cast<Map<String, dynamic>>(),
          _currentUrl,
        );
      }
    } catch (_) {}
  }

  Future<void> _downloadFromUrl() async {
    if (_currentUrl.isEmpty) return;

    setState(() => _extracting = true);
    try {
      final video = await _extractionService.extractVideo(_currentUrl);
      if (video != null && mounted) {
        DownloadSheet.show(context, video);
      } else if (_mediaSniffer.hasMedia && mounted) {
        _showSniffedMedia();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No downloadable video found on this page'),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  String _pageTitle = '';

  Future<void> _showSniffedMedia() async {
    final media = _mediaSniffer.detectedMedia;
    if (media.isEmpty) return;

    final title = await _webController?.getTitle();
    _pageTitle = (title != null && title.isNotEmpty) ? title : Uri.tryParse(_currentUrl)?.host ?? _currentUrl;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => _SniffedMediaSheet(
        media: media,
        pageUrl: _currentUrl,
        pageTitle: _pageTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildToolbar(),
            if (_progress > 0 && _progress < 1)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 2,
              ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      userAgent: 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      useOnLoadResource: true,
                      useShouldInterceptRequest: false,
                    ),
                    onWebViewCreated: (controller) {
                      _webController = controller;
                    },
                    onLoadStart: (controller, url) {
                      final urlStr = url?.toString() ?? '';
                      setState(() {
                        _currentUrl = urlStr;
                        _urlController.text = urlStr;
                        _isLoading = true;
                        _progress = 0.1;
                      });
                      _mediaSniffer.clearForPage(urlStr);
                    },
                    onLoadStop: (controller, url) async {
                      final urlStr = url?.toString() ?? _currentUrl;
                      setState(() {
                        _currentUrl = urlStr;
                        _isLoading = false;
                        _progress = 1.0;
                      });
                      _canGoBack = await controller.canGoBack();
                      _canGoForward = await controller.canGoForward();
                      setState(() {});

                      final title = await controller.getTitle() ?? urlStr;
                      widget.storage.addHistoryEntry(urlStr, title);

                      await _runJsVideoDetection();
                    },
                    onProgressChanged: (controller, progress) {
                      setState(() => _progress = progress / 100);
                    },
                    onLoadResource: (controller, resource) {
                      final url = resource.url?.toString() ?? '';
                      if (url.isNotEmpty) {
                        _mediaSniffer.onResourceLoaded(url, _currentUrl);
                      }
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      final url = navigationAction.request.url?.toString() ?? '';
                      if (_mediaSniffer.isMediaUrl(url) &&
                          !url.contains('youtube.com') &&
                          !url.contains('googlevideo.com')) {
                        _mediaSniffer.onResourceLoaded(url, _currentUrl);
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                  ),
                  if (_mediaSniffer.hasMedia)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: _buildMediaFab(),
                    ),
                ],
              ),
            ),
            if (_extractionService.isVideoUrl(_currentUrl) || _mediaSniffer.hasMedia)
              _buildDownloadBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaFab() {
    return FloatingActionButton.extended(
      onPressed: _showSniffedMedia,
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.videocam, color: Colors.white),
      label: Text(
        '${_mediaSniffer.count} video${_mediaSniffer.count == 1 ? '' : 's'}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: AppColors.surface,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded,
                size: 18,
                color: _canGoBack ? AppColors.textPrimary : AppColors.textMuted),
            onPressed: _canGoBack ? () => _webController?.goBack() : null,
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios_rounded,
                size: 18,
                color: _canGoForward ? AppColors.textPrimary : AppColors.textMuted),
            onPressed: _canGoForward ? () => _webController?.goForward() : null,
          ),
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(
                    _currentUrl.startsWith('https') ? Icons.lock : Icons.language,
                    size: 14,
                    color: _currentUrl.startsWith('https')
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        hintText: 'Search or enter URL',
                        border: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onSubmitted: (_) => _navigate(),
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  else if (_urlController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _urlController.clear(),
                      child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _webController?.reload(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            color: AppColors.surface,
            onSelected: (value) {
              switch (value) {
                case 'bookmark':
                  widget.storage.addBookmark(_currentUrl, _urlController.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bookmark added')),
                  );
                case 'bookmarks':
                  _showBookmarks();
                case 'history':
                  _showHistory();
                case 'download':
                  _downloadFromUrl();
                case 'detect':
                  _runJsVideoDetection();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Download video'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'detect',
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18, color: AppColors.secondary),
                    SizedBox(width: 8),
                    Text('Scan for videos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'bookmark',
                child: Row(
                  children: [
                    Icon(Icons.bookmark_add, size: 18),
                    SizedBox(width: 8),
                    Text('Add bookmark'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'bookmarks',
                child: Row(
                  children: [
                    Icon(Icons.bookmarks, size: 18),
                    SizedBox(width: 8),
                    Text('Bookmarks'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18),
                    SizedBox(width: 8),
                    Text('History'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.videocam, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _mediaSniffer.hasMedia
                  ? '${_mediaSniffer.count} video${_mediaSniffer.count == 1 ? '' : 's'} detected'
                  : 'Video detected on this page',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_extracting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )
          else
            ElevatedButton.icon(
              onPressed: _downloadFromUrl,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  void _showBookmarks() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final bookmarks = widget.storage.getBookmarks();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Bookmarks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            if (bookmarks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No bookmarks yet',
                    style: TextStyle(color: AppColors.textMuted)),
              )
            else
              ...bookmarks.take(20).map((bm) => ListTile(
                    leading: const Icon(Icons.bookmark, color: AppColors.primary),
                    title: Text(bm['title'] ?? bm['url'],
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(bm['url'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      loadUrl(bm['url']!);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        widget.storage.removeBookmark(bm['url']!);
                        Navigator.pop(context);
                        _showBookmarks();
                      },
                    ),
                  )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) {
        final history = widget.storage.getBrowserHistory();
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('History',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        widget.storage.clearHistory();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear all',
                          style: TextStyle(color: AppColors.accent)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: history.length,
                  itemBuilder: (_, i) {
                    final entry = history[i];
                    return ListTile(
                      leading: const Icon(Icons.history,
                          color: AppColors.textMuted, size: 20),
                      title: Text(entry['title'] ?? '',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(entry['url'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      dense: true,
                      onTap: () {
                        Navigator.pop(context);
                        loadUrl(entry['url']!);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SniffedMediaSheet extends StatelessWidget {
  final List<DetectedMedia> media;
  final String pageUrl;
  final String pageTitle;

  const _SniffedMediaSheet({
    required this.media,
    required this.pageUrl,
    required this.pageTitle,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.videocam, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detected Media',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      Text(
                        '${media.length} file${media.length == 1 ? '' : 's'} found on this page',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: media.length,
              itemBuilder: (_, i) {
                final m = media[i];
                return _SniffedMediaTile(media: m, pageTitle: pageTitle);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SniffedMediaTile extends StatelessWidget {
  final DetectedMedia media;
  final String pageTitle;

  const _SniffedMediaTile({required this.media, required this.pageTitle});

  @override
  Widget build(BuildContext context) {
    final isAudio = media.isAudioOnly;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          isAudio ? Icons.audiotrack : Icons.play_circle_filled,
          color: isAudio ? AppColors.warning : AppColors.primary,
        ),
        title: Text(
          media.title ?? pageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                media.qualityGuess,
                style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                media.format.toUpperCase(),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ),
            if (media.contentLength != null) ...[
              const SizedBox(width: 6),
              Text(
                _formatSize(media.contentLength!),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.download_rounded, color: AppColors.primary),
          onPressed: () {
            Navigator.pop(context);
            _startDirectDownload(context);
          },
        ),
      ),
    );
  }

  void _startDirectDownload(BuildContext context) {
    final video = _mediaToVideoInfo();
    DownloadSheet.show(context, video);
  }

  VideoInfo _mediaToVideoInfo() {
    return VideoInfo(
      id: media.url.hashCode.toString(),
      title: media.title ?? pageTitle,
      url: media.sourceUrl,
      source: Uri.tryParse(media.sourceUrl)?.host ?? 'web',
      streams: [
        VideoStream(
          url: media.url,
          quality: media.qualityGuess,
          format: media.format,
          fileSize: media.contentLength,
          isAudioOnly: media.isAudioOnly,
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb > 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    if (mb > 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
