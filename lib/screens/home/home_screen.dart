import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/extraction_service.dart';
import '../../services/download_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/download_sheet.dart';

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

  final _quickSites = [
    _SiteShortcut('YouTube', 'https://m.youtube.com', Icons.play_circle, Color(0xFFFF0000)),
    _SiteShortcut('Instagram', 'https://www.instagram.com', Icons.camera_alt, Color(0xFFE4405F)),
    _SiteShortcut('TikTok', 'https://www.tiktok.com', Icons.music_note, Color(0xFF000000)),
    _SiteShortcut('Twitter', 'https://x.com', Icons.alternate_email, Color(0xFF1DA1F2)),
    _SiteShortcut('Facebook', 'https://m.facebook.com', Icons.facebook, Color(0xFF1877F2)),
    _SiteShortcut('Reddit', 'https://www.reddit.com', Icons.reddit, Color(0xFFFF4500)),
    _SiteShortcut('Vimeo', 'https://vimeo.com', Icons.video_library, Color(0xFF1AB7EA)),
    _SiteShortcut('Dailymotion', 'https://www.dailymotion.com', Icons.ondemand_video, Color(0xFF0066DC)),
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

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildUrlInput()),
            SliverToBoxAdapter(child: _buildQuickSites()),
            SliverToBoxAdapter(child: _buildActiveDownloads()),
            SliverToBoxAdapter(child: _buildStats()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Videe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Download anything. No ads.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.link, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'Paste video URL here...',
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (_) => _extractAndDownload(),
                  ),
                ),
                if (_isExtracting)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded,
                        color: AppColors.primary),
                    onPressed: _extractAndDownload,
                  ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickSites() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            'BROWSE SITES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _quickSites.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final site = _quickSites[i];
              return GestureDetector(
                onTap: () => widget.onBrowse(site.url),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: site.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(site.icon, color: site.color, size: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        site.name,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'ACTIVE DOWNLOADS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => widget.onNavigate(2),
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...active.take(3).map((item) => Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.downloading,
                          color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: item.progress,
                              backgroundColor: AppColors.surfaceLight,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.primary),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.progressLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _buildStats() {
    return Consumer<DownloadService>(
      builder: (_, service, __) {
        final completed = service.completedDownloads.length;
        final active = service.activeDownloads.length;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              _StatCard(
                icon: Icons.check_circle,
                label: 'Completed',
                value: '$completed',
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.downloading,
                label: 'Active',
                value: '$active',
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.block,
                label: 'Ads',
                value: '0',
                color: AppColors.accent,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteShortcut {
  final String name;
  final String url;
  final IconData icon;
  final Color color;

  const _SiteShortcut(this.name, this.url, this.icon, this.color);
}
