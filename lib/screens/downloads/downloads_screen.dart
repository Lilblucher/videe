import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/download_item.dart';
import '../../services/download_service.dart';
import '../../theme/app_theme.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<DownloadService>(
          builder: (_, service, __) {
            final downloads = service.downloads;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context, service)),
                if (downloads.isEmpty)
                  const SliverFillRemaining(child: _EmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: downloads.length,
                      itemBuilder: (_, i) =>
                          _DownloadTile(item: downloads[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DownloadService service) {
    final active = service.activeDownloads.length;
    final completed = service.completedDownloads.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Downloads',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (completed > 0)
                TextButton(
                  onPressed: () => service.clearCompleted(),
                  child: const Text('Clear completed',
                      style: TextStyle(color: AppColors.accent, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Chip(
                icon: Icons.downloading,
                label: '$active active',
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _Chip(
                icon: Icons.check_circle,
                label: '$completed done',
                color: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_for_offline_outlined,
              size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'No downloads yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste a URL or browse to start downloading',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadItem item;

  const _DownloadTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final service = context.read<DownloadService>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 40,
                child: item.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surfaceLight,
                          child: const Icon(Icons.video_library,
                              size: 20, color: AppColors.textMuted),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceLight,
                        child: const Icon(Icons.video_library,
                            size: 20, color: AppColors.textMuted),
                      ),
              ),
            ),
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
                  Row(
                    children: [
                      _statusIcon(),
                      const SizedBox(width: 4),
                      Text(
                        _statusText(),
                        style: TextStyle(
                          fontSize: 11,
                          color: _statusColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.status == DownloadStatus.downloading) ...[
                        const SizedBox(width: 8),
                        Text(
                          item.sizeLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.status == DownloadStatus.downloading) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: item.progress,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _actionButton(service),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon() {
    switch (item.status) {
      case DownloadStatus.queued:
        return const Icon(Icons.hourglass_top,
            size: 12, color: AppColors.warning);
      case DownloadStatus.downloading:
        return const Icon(Icons.downloading,
            size: 12, color: AppColors.primary);
      case DownloadStatus.paused:
        return const Icon(Icons.pause_circle,
            size: 12, color: AppColors.warning);
      case DownloadStatus.completed:
        return const Icon(Icons.check_circle,
            size: 12, color: AppColors.success);
      case DownloadStatus.failed:
        return const Icon(Icons.error, size: 12, color: AppColors.error);
      case DownloadStatus.cancelled:
        return const Icon(Icons.cancel, size: 12, color: AppColors.textMuted);
    }
  }

  String _statusText() {
    switch (item.status) {
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.downloading:
        return item.progressLabel;
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return item.errorMessage ?? 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusColor() {
    switch (item.status) {
      case DownloadStatus.queued:
      case DownloadStatus.paused:
        return AppColors.warning;
      case DownloadStatus.downloading:
        return AppColors.primary;
      case DownloadStatus.completed:
        return AppColors.success;
      case DownloadStatus.failed:
        return AppColors.error;
      case DownloadStatus.cancelled:
        return AppColors.textMuted;
    }
  }

  Widget _actionButton(DownloadService service) {
    switch (item.status) {
      case DownloadStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.pause, color: AppColors.warning, size: 20),
          onPressed: () => service.pauseDownload(item.id),
        );
      case DownloadStatus.paused:
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.play_arrow,
              color: AppColors.primary, size: 20),
          onPressed: () => service.resumeDownload(item.id),
        );
      case DownloadStatus.queued:
        return IconButton(
          icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
          onPressed: () => service.cancelDownload(item.id),
        );
      case DownloadStatus.completed:
      case DownloadStatus.cancelled:
        return IconButton(
          icon: const Icon(Icons.delete_outline,
              color: AppColors.textMuted, size: 20),
          onPressed: () => service.removeDownload(item.id),
        );
    }
  }
}
