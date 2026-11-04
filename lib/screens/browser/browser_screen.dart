import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/extraction_service.dart';
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
  late WebViewController _webController;
  final _urlController = TextEditingController();
  final _extractionService = ExtractionService();
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _videoDetected = false;
  String _currentUrl = '';
  double _progress = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final startUrl = widget.initialUrl ?? 'https://www.google.com';
    _currentUrl = startUrl;
    _urlController.text = startUrl;
    _initWebView(startUrl);
  }

  void _initWebView(String url) {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _currentUrl = url;
              _urlController.text = url;
              _isLoading = true;
              _progress = 0.1;
            });
            _checkForVideo(url);
          },
          onPageFinished: (url) async {
            setState(() {
              _currentUrl = url;
              _isLoading = false;
              _progress = 1.0;
            });
            _canGoBack = await _webController.canGoBack();
            _canGoForward = await _webController.canGoForward();
            setState(() {});

            final title = await _webController.getTitle() ?? url;
            widget.storage.addHistoryEntry(url, title);
            _checkForVideo(url);
          },
          onProgress: (progress) {
            setState(() => _progress = progress / 100);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() => _initialized = true);
  }

  void loadUrl(String url) {
    if (!url.startsWith('http')) url = 'https://$url';
    _urlController.text = url;
    _currentUrl = url;
    _webController.loadRequest(Uri.parse(url));
  }

  @override
  void dispose() {
    _urlController.dispose();
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

    _webController.loadRequest(Uri.parse(url));
  }

  void _checkForVideo(String url) {
    final detected = _extractionService.isVideoUrl(url);
    if (detected != _videoDetected) {
      setState(() => _videoDetected = detected);
    }
  }

  Future<void> _downloadVideo() async {
    if (_currentUrl.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final video = await _extractionService.extractVideo(_currentUrl);
      if (video != null && mounted) {
        DownloadSheet.show(context, video);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No downloadable video found on this page'),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              child: _initialized
                  ? WebViewWidget(controller: _webController)
                  : const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)),
            ),
            if (_videoDetected) _buildDownloadBar(),
          ],
        ),
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
                color:
                    _canGoBack ? AppColors.textPrimary : AppColors.textMuted),
            onPressed: _canGoBack ? () => _webController.goBack() : null,
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios_rounded,
                size: 18,
                color: _canGoForward
                    ? AppColors.textPrimary
                    : AppColors.textMuted),
            onPressed:
                _canGoForward ? () => _webController.goForward() : null,
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
                    _currentUrl.startsWith('https')
                        ? Icons.lock
                        : Icons.language,
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  else if (_urlController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _urlController.clear(),
                      child: const Icon(Icons.close,
                          size: 16, color: AppColors.textMuted),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _webController.reload(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            color: AppColors.surface,
            onSelected: (value) {
              switch (value) {
                case 'bookmark':
                  widget.storage
                      .addBookmark(_currentUrl, _urlController.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bookmark added')),
                  );
                case 'bookmarks':
                  _showBookmarks();
                case 'history':
                  _showHistory();
                case 'download':
                  _downloadVideo();
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
          const Expanded(
            child: Text(
              'Video detected on this page',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _downloadVideo,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            if (bookmarks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No bookmarks yet',
                    style: TextStyle(color: AppColors.textMuted)),
              )
            else
              ...bookmarks.take(20).map((bm) => ListTile(
                    leading:
                        const Icon(Icons.bookmark, color: AppColors.primary),
                    title: Text(bm['title'] ?? bm['url'],
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(bm['url'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
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
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
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
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
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
