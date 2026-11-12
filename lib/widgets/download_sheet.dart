import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/video_info.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import '../widgets/underline_tabs.dart';

/// Format picker. Per the v2 design spec this is a full page, not a sheet:
/// thumb + title, underline tabs splitting streams into Video/Audio, a
/// ledger of format rows (tap to select), and a single accent CTA at the
/// bottom that downloads the selected stream.
class DownloadSheet extends StatelessWidget {
  final VideoInfo video;
  final DownloadService downloadService;

  const DownloadSheet({super.key, required this.video, required this.downloadService});

  static void show(BuildContext context, VideoInfo video) {
    final ds = context.read<DownloadService>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DownloadSheet(video: video, downloadService: ds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FormatScreen(video: video, downloadService: downloadService);
  }
}

class _FormatScreen extends StatefulWidget {
  final VideoInfo video;
  final DownloadService downloadService;

  const _FormatScreen({required this.video, required this.downloadService});

  @override
  State<_FormatScreen> createState() => _FormatScreenState();
}

class _FormatScreenState extends State<_FormatScreen> {
  int _tab = 0;
  int? _selected;

  List<VideoStream> get _videoStreams =>
      widget.video.streams.where((s) => !s.isAudioOnly).toList();
  List<VideoStream> get _audioStreams =>
      widget.video.streams.where((s) => s.isAudioOnly).toList();

  List<VideoStream> get _currentStreams =>
      _tab == 0 ? _videoStreams : _audioStreams;

  @override
  void initState() {
    super.initState();
    if (_videoStreams.isEmpty && _audioStreams.isNotEmpty) _tab = 1;
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final streams = _currentStreams;
    final selectedStream =
        (_selected != null && _selected! < streams.length) ? streams[_selected!] : null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_new, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text('Back', style: AppText.sans(size: 13, weight: FontWeight.w500, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 176,
                      width: double.infinity,
                      child: video.thumbnailUrl != null
                          ? CachedNetworkImage(
                              imageUrl: video.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(color: AppColors.surface),
                            )
                          : Container(color: AppColors.surface),
                    ),
                    if (video.durationLabel.isNotEmpty)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            video.durationLabel,
                            style: AppText.mono(size: 11, weight: FontWeight.w500, color: AppColors.textTitle),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(size: 20, weight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.02, height: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                video.source,
                style: AppText.mono(size: 11.5, color: AppColors.textDim),
              ),
              const SizedBox(height: 22),
              if (_audioStreams.isNotEmpty && _videoStreams.isNotEmpty)
                UnderlineTabs(
                  labels: const ['Video', 'Audio'],
                  activeIndex: _tab,
                  onChanged: (i) => setState(() {
                    _tab = i;
                    _selected = null;
                  }),
                ),
              Expanded(
                child: streams.isEmpty
                    ? Center(
                        child: Text(
                          'No streams in this category',
                          style: AppText.mono(size: 12, color: AppColors.textDim),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: streams.length,
                        itemBuilder: (context, i) {
                          final s = streams[i];
                          final selected = i == _selected;
                          return GestureDetector(
                            onTap: () => setState(() => _selected = i),
                            child: Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              margin: const EdgeInsets.only(bottom: 0),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.accent : Colors.transparent,
                                border: const Border(bottom: BorderSide(color: AppColors.hairline)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 62,
                                    child: Text(
                                      s.quality,
                                      style: AppText.sans(
                                        size: 15,
                                        weight: FontWeight.w700,
                                        color: selected ? AppColors.onAccent : AppColors.textTitle,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      s.isAudioOnly
                                          ? s.format.toUpperCase()
                                          : '${s.format.toUpperCase()}${s.codec != null ? ' · ${s.codec}' : ''}',
                                      style: AppText.mono(
                                        size: 11.5,
                                        color: selected ? AppColors.onAccent : AppColors.textDim,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    s.sizeLabel.isNotEmpty ? s.sizeLabel : '—',
                                    style: AppText.mono(
                                      size: 12,
                                      weight: FontWeight.w500,
                                      color: selected ? AppColors.onAccent : AppColors.textTitle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Text(
                'Saves to /Downloads/Videe',
                style: AppText.mono(size: 11.5, color: AppColors.textDim),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: GestureDetector(
                  onTap: selectedStream == null
                      ? null
                      : () {
                          widget.downloadService.startDownload(video, selectedStream);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Downloading: ${video.title}',
                                style: AppText.sans(size: 13, color: AppColors.text),
                              ),
                              backgroundColor: AppColors.surface,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.control),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          );
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: selectedStream == null ? AppColors.surface : AppColors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      selectedStream == null
                          ? 'Select a quality'
                          : 'Download${selectedStream.sizeLabel.isNotEmpty ? ' ${selectedStream.sizeLabel}' : ''}',
                      style: AppText.sans(
                        size: 16,
                        weight: FontWeight.w700,
                        color: selectedStream == null ? AppColors.textDim : AppColors.onAccent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
