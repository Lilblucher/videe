import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/download_item.dart';
import '../../services/download_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hex_progress_ring.dart';
import '../../widgets/underline_tabs.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Consumer<DownloadService>(
          builder: (_, service, __) {
            final active = service.downloads
                .where((d) => d.status == DownloadStatus.downloading || d.status == DownloadStatus.paused)
                .toList();
            final queued = service.downloads.where((d) => d.status == DownloadStatus.queued).toList();
            final done = service.downloads
                .where((d) =>
                    d.status == DownloadStatus.completed ||
                    d.status == DownloadStatus.failed ||
                    d.status == DownloadStatus.cancelled)
                .toList();

            final lists = [active, queued, done];
            final current = lists[_tab];
            final hero = active.isNotEmpty ? active.first : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hero != null) _buildHero(hero),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, hero != null ? 24 : 20, 20, 0),
                  child: UnderlineTabs(
                    labels: [
                      'Active ${active.length}',
                      'Queued ${queued.length}',
                      'Done',
                    ],
                    activeIndex: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
                Expanded(
                  child: current.isEmpty
                      ? _EmptyState(tab: _tab)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          itemCount: current.length,
                          itemBuilder: (_, i) => _DownloadRow(
                            index: i + 1,
                            item: current[i],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(DownloadItem item) {
    final speedLine = item.status == DownloadStatus.paused
        ? 'Paused'
        : item.sizeLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          HexProgressRing(
            progress: item.progress,
            size: 104,
            glow: item.status != DownloadStatus.paused,
            progressColor: item.status == DownloadStatus.paused ? AppColors.textDim : AppColors.accent,
            center: Text(
              item.progressLabel,
              style: AppText.mono(size: 24, weight: FontWeight.w500, color: AppColors.text, letterSpacing: -0.04 * 24),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(size: 17, weight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.01, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  speedLine,
                  style: AppText.mono(size: 12, color: AppColors.accentText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int tab;

  const _EmptyState({required this.tab});

  @override
  Widget build(BuildContext context) {
    final label = switch (tab) {
      0 => 'No active downloads',
      1 => 'Nothing queued',
      _ => 'No downloads yet',
    };
    return Center(
      child: Text(
        label,
        style: AppText.mono(size: 12, color: AppColors.textDim),
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  final int index;
  final DownloadItem item;

  const _DownloadRow({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    final service = context.read<DownloadService>();
    final isPaused = item.status == DownloadStatus.paused;
    final barColor = isPaused ? const Color(0xFF3A3E45) : AppColors.accent;
    final pctColor = item.status == DownloadStatus.failed ? AppColors.error : AppColors.accentText;

    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                index.toString().padLeft(2, '0'),
                style: AppText.mono(size: 11, color: AppColors.textFaint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(size: 14, weight: FontWeight.w500, color: AppColors.textTitle),
                ),
              ),
              Text(
                _percentLabel(),
                style: AppText.mono(size: 12, weight: FontWeight.w500, color: pctColor),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 21, top: 6, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _metaLabel(),
                    style: AppText.mono(size: 11, color: AppColors.textDim),
                  ),
                ),
                GestureDetector(
                  onTap: () => _onAction(service),
                  child: Text(
                    _actionLabel(),
                    style: AppText.mono(size: 11, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          if (item.status == DownloadStatus.downloading || item.status == DownloadStatus.paused)
            Padding(
              padding: const EdgeInsets.only(left: 21, bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 2,
                  backgroundColor: AppColors.hairline,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _percentLabel() {
    switch (item.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.paused:
        return item.progressLabel;
      case DownloadStatus.queued:
        return '—';
      case DownloadStatus.completed:
        return item.sizeLabel.isNotEmpty ? item.sizeLabel : 'Done';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _metaLabel() {
    switch (item.status) {
      case DownloadStatus.downloading:
        return item.sizeLabel;
      case DownloadStatus.paused:
        return 'Paused · ${item.sizeLabel}';
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.completed:
        return 'Done · ${item.sizeLabel}';
      case DownloadStatus.failed:
        return item.errorMessage ?? 'Download failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _actionLabel() {
    switch (item.status) {
      case DownloadStatus.downloading:
        return 'Pause';
      case DownloadStatus.paused:
      case DownloadStatus.failed:
        return 'Resume';
      case DownloadStatus.queued:
        return 'Cancel';
      case DownloadStatus.completed:
      case DownloadStatus.cancelled:
        return 'Remove';
    }
  }

  void _onAction(DownloadService service) {
    switch (item.status) {
      case DownloadStatus.downloading:
        service.pauseDownload(item.id);
      case DownloadStatus.paused:
      case DownloadStatus.failed:
        service.resumeDownload(item.id);
      case DownloadStatus.queued:
        service.cancelDownload(item.id);
      case DownloadStatus.completed:
      case DownloadStatus.cancelled:
        service.removeDownload(item.id);
    }
  }
}
