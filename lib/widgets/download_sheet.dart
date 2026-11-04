import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/video_info.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';

class DownloadSheet extends StatelessWidget {
  final VideoInfo video;
  final DownloadService downloadService;

  const DownloadSheet({super.key, required this.video, required this.downloadService});

  static void show(BuildContext context, VideoInfo video) {
    final ds = context.read<DownloadService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => DownloadSheet(video: video, downloadService: ds),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
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
                if (video.thumbnailUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl!,
                      width: 80,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (video.author != null)
                        Text(
                          video.author!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.download, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Select Quality',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${video.streams.length} options',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: video.streams.length,
              itemBuilder: (context, index) {
                final stream = video.streams[index];
                return _StreamTile(video: video, stream: stream, downloadService: downloadService);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamTile extends StatelessWidget {
  final VideoInfo video;
  final VideoStream stream;
  final DownloadService downloadService;

  const _StreamTile({required this.video, required this.stream, required this.downloadService});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    if (stream.isAudioOnly) {
      icon = Icons.audiotrack;
      iconColor = AppColors.warning;
    } else if (stream.isVideoOnly) {
      icon = Icons.videocam;
      iconColor = AppColors.secondary;
    } else {
      icon = Icons.play_circle_filled;
      iconColor = AppColors.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          stream.label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Row(
          children: [
            if (stream.sizeLabel.isNotEmpty)
              Text(
                stream.sizeLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            if (stream.codec != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  stream.codec!,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.download_rounded, color: AppColors.primary),
          onPressed: () {
            downloadService.startDownload(video, stream);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloading: ${video.title}'),
                backgroundColor: AppColors.surface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
      ),
    );
  }
}
