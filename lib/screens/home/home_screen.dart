import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/extraction_service.dart';
import '../../services/download_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/download_sheet.dart';
import '../../widgets/hex_mark.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final Function(String) onBrowse;

  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onBrowse,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  final _extractionService = ExtractionService();
  bool _isExtracting = false;
  String? _error;

  static const _quickSites = [
    _SiteShortcut('YouTube', 'https://m.youtube.com'),
    _SiteShortcut('Instagram', 'https://www.instagram.com'),
    _SiteShortcut('TikTok', 'https://www.tiktok.com'),
    _SiteShortcut('Twitter', 'https://x.com'),
    _SiteShortcut('Facebook', 'https://m.facebook.com'),
    _SiteShortcut('Reddit', 'https://www.reddit.com'),
    _SiteShortcut('Vimeo', 'https://vimeo.com'),
    _SiteShortcut('Dailymotion', 'https://www.dailymotion.com'),
  ];

  Future<void> _extractAndDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isExtracting = true;
      _error = null;
    });

    try {
      final video = await _extractionService.extractVideo(url);
      if (video != null && mounted) {
        DownloadSheet.show(context, video);
        _urlController.clear();
      } else if (mounted) {
        setState(() => _error = 'No video found at this URL');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to extract video');
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  void _clear() {
    setState(() {
      _urlController.clear();
      _error = null;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildUrlInput()),
            SliverToBoxAdapter(child: _buildQuickSites()),
            SliverToBoxAdapter(child: _buildActiveDownloads()),
            SliverToBoxAdapter(child: _buildRecent()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: HexMark(size: 30),
      ),
    );
  }

  Widget _buildUrlInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: AppText.sans(
                size: 40,
                weight: FontWeight.w700,
                color: AppColors.text,
                letterSpacing: -0.035 * 40,
                height: 1.02,
              ),
              children: [
                const TextSpan(text: 'Paste a link.\n'),
                TextSpan(
                  text: 'Keep the file.',
                  style: AppText.sans(
                    size: 40,
                    weight: FontWeight.w700,
                    color: AppColors.textDim,
                    letterSpacing: -0.035 * 40,
                    height: 1.02,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _urlController,
                  style: AppText.mono(size: 13, color: AppColors.textMuted),
                  cursorColor: AppColors.accent,
                  decoration: InputDecoration(
                    hintText: 'https://video.example/watch?v=…',
                    hintStyle: AppText.mono(size: 13, color: AppColors.textFaint),
                  ),
                  onSubmitted: (_) => _extractAndDownload(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _isExtracting ? null : _extractAndDownload,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                          ),
                          child: _isExtracting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onAccent,
                                  ),
                                )
                              : Text(
                                  'Analyze link',
                                  style: AppText.sans(size: 15, weight: FontWeight.w700, color: AppColors.onAccent),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clear,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadius.control),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Clear',
                          style: AppText.sans(size: 14, weight: FontWeight.w500, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: AppText.mono(size: 11.5, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickSites() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 10),
          child: Text(
            'BROWSE SITES',
            style: AppText.mono(size: 11, weight: FontWeight.w500, letterSpacing: 1, color: AppColors.textFaint),
          ),
        ),
        SizedBox(
          height: 72,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _quickSites.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final site = _quickSites[i];
              return GestureDetector(
                onTap: () => widget.onBrowse(site.url),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    site.name,
                    style: AppText.sans(size: 13, weight: FontWeight.w500, color: AppColors.textMuted),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveDownloads() {
    return Consumer<DownloadService>(
      builder: (_, service, __) {
        final active = service.activeDownloads;
        if (active.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
              child: Row(
                children: [
                  Text(
                    'ACTIVE DOWNLOADS',
                    style: AppText.mono(size: 11, weight: FontWeight.w500, letterSpacing: 1, color: AppColors.textFaint),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => widget.onNavigate(2),
                    child: Text(
                      'See all',
                      style: AppText.sans(size: 12, weight: FontWeight.w600, color: AppColors.accentText),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: active.take(3).map((item) => Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.downloading, color: AppColors.accentText, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.sans(size: 13, weight: FontWeight.w500, color: AppColors.text),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(1),
                                  child: LinearProgressIndicator(
                                    value: item.progress,
                                    minHeight: 2,
                                    backgroundColor: AppColors.hairline,
                                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.progressLabel,
                            style: AppText.mono(size: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecent() {
    return Consumer<DownloadService>(
      builder: (_, service, __) {
        final recent = service.downloads.take(5).toList();
        if (recent.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Text(
                'RECENT',
                style: AppText.mono(size: 11, weight: FontWeight.w500, letterSpacing: 1, color: AppColors.textFaint),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: recent.map((item) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.hairline)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.sans(size: 14, weight: FontWeight.w500, color: AppColors.textTitle),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${item.format.toUpperCase()} ${item.sizeLabel}',
                            style: AppText.mono(size: 11.5, color: AppColors.textDim),
                          ),
                        ],
                      ),
                    )).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SiteShortcut {
  final String name;
  final String url;

  const _SiteShortcut(this.name, this.url);
}
