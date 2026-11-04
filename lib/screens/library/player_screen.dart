import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import '../../models/media_item.dart';
import '../../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem item;

  const PlayerScreen({super.key, required this.item});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _videoController =
          VideoPlayerController.file(File(widget.item.filePath));
      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          bufferedColor: AppColors.primary.withValues(alpha: 0.3),
          backgroundColor: AppColors.surfaceLight,
        ),
      );

      setState(() => _initialized = true);
    } catch (e) {
      setState(() => _error = 'Failed to load video: $e');
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.item.title,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => Share.shareXFiles(
              [XFile(widget.item.filePath)],
              text: widget.item.title,
            ),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : !_initialized
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Chewie(controller: _chewieController!),
                      ),
                    ),
                    _buildInfoBar(),
                  ],
                ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.item.author != null) ...[
                const Icon(Icons.person, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(widget.item.author!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 16),
              ],
              const Icon(Icons.source, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(widget.item.source,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Text(widget.item.fileSizeLabel,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
