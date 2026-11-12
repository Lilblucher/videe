import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/media_item.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/underline_tabs.dart';
import '../library/player_screen.dart';

class LibraryScreen extends StatefulWidget {
  final StorageService storage;

  const LibraryScreen({super.key, required this.storage});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _tab = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _tabLabels = ['All', 'Video', 'Audio'];

  List<MediaItem> get _filteredItems {
    var items = widget.storage.getMediaItems();

    if (_tab == 1) {
      items = items.where((i) => i.type == MediaType.video).toList();
    } else if (_tab == 2) {
      items = items.where((i) => i.type == MediaType.audio).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((i) =>
              i.title.toLowerCase().contains(q) ||
              (i.author?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return items..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.storage.getMediaItems();
    final totalBytes = items.fold<int>(0, (sum, i) => sum + i.fileSize);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Library',
                style: AppText.sans(size: 28, weight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.03 * 28),
              ),
              const SizedBox(height: 4),
              Text(
                '${items.length} files · ${_sizeLabel(totalBytes)}',
                style: AppText.mono(size: 12, color: AppColors.textDim),
              ),
              const SizedBox(height: 20),
              Container(
                height: 40,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: AppText.sans(size: 14, color: AppColors.text),
                        decoration: InputDecoration(
                          hintText: 'Search files',
                          hintStyle: AppText.sans(size: 14, color: AppColors.textFaint),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close, size: 16, color: AppColors.textDim),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              UnderlineTabs(
                labels: _tabLabels,
                activeIndex: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final items = _filteredItems;

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No media yet',
          style: AppText.mono(size: 12, color: AppColors.textDim),
        ),
      );
    }

    final groups = _groupByDay(items);

    return ListView(
      padding: const EdgeInsets.only(top: 18, bottom: 20),
      children: [
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              group.key,
              style: AppText.mono(size: 11, weight: FontWeight.w500, letterSpacing: 1, color: AppColors.textFaint),
            ),
          ),
          for (final item in group.value)
            _MediaRow(
              item: item,
              onTap: () => _openPlayer(item),
              onDelete: () => _deleteItem(item),
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Map<String, List<MediaItem>> _groupByDay(List<MediaItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final groups = <String, List<MediaItem>>{};

    for (final item in items) {
      final d = item.downloadedAt;
      final day = DateTime(d.year, d.month, d.day);
      final String label;
      if (day == today) {
        label = 'TODAY';
      } else if (day == yesterday) {
        label = 'YESTERDAY';
      } else {
        label = '${d.month}/${d.day}/${d.year}';
      }
      groups.putIfAbsent(label, () => []).add(item);
    }
    return groups;
  }

  String _sizeLabel(int bytes) {
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(1)} GB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  void _openPlayer(MediaItem item) {
    if (!File(item.filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File not found', style: AppText.sans(size: 13, color: AppColors.text)),
          backgroundColor: AppColors.surface,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(item: item)),
    );
  }

  void _deleteItem(MediaItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Delete media?', style: AppText.sans(size: 16, weight: FontWeight.w700, color: AppColors.text)),
        content: Text(
          'Delete "${item.title}" from library?',
          style: AppText.sans(size: 13, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppText.sans(size: 14, color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final file = File(item.filePath);
              if (file.existsSync()) file.deleteSync();
              widget.storage.deleteMediaItem(item.id);
              Navigator.pop(context);
              setState(() {});
            },
            child: Text('Delete', style: AppText.sans(size: 14, color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MediaRow({required this.item, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: SizedBox(
                width: 48,
                height: 48,
                child: item.thumbnailPath != null
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailPath!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
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
                    style: AppText.sans(size: 14, weight: FontWeight.w500, color: AppColors.textTitle),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.fileSizeLabel}${item.durationLabel.isNotEmpty ? ' · ${item.durationLabel}' : ''}',
                    style: AppText.mono(size: 11.5, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
            Text(
              item.type == MediaType.audio ? 'MP3' : 'MP4',
              style: AppText.mono(size: 11, weight: FontWeight.w500, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surface,
      child: Icon(
        item.type == MediaType.audio ? Icons.audiotrack : Icons.video_library,
        size: 20,
        color: AppColors.textDim,
      ),
    );
  }
}
