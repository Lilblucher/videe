import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/media_item.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../library/player_screen.dart';

class LibraryScreen extends StatefulWidget {
  final StorageService storage;

  const LibraryScreen({super.key, required this.storage});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _filter = 'all';
  String _searchQuery = '';
  bool _gridView = true;

  List<MediaItem> get _filteredItems {
    var items = widget.storage.getMediaItems();

    if (_filter == 'video') {
      items = items.where((i) => i.type == MediaType.video).toList();
    } else if (_filter == 'audio') {
      items = items.where((i) => i.type == MediaType.audio).toList();
    } else if (_filter == 'favorites') {
      items = items.where((i) => i.isFavorite).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((i) =>
              i.title.toLowerCase().contains(q) ||
              (i.author?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearch(),
            _buildFilters(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          const Text(
            'Library',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _gridView ? Icons.view_list : Icons.grid_view,
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search library...',
          prefixIcon:
              const Icon(Icons.search, color: AppColors.textMuted, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      ('all', 'All'),
      ('video', 'Videos'),
      ('audio', 'Audio'),
      ('favorites', 'Favorites'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f.$2, style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f.$1),
              selectedColor: AppColors.primary.withValues(alpha: 0.3),
              backgroundColor: AppColors.surfaceLight,
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    final items = _filteredItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined,
                size: 64,
                color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No media yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Downloaded videos will appear here',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_gridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _MediaGridItem(
          item: items[i],
          onTap: () => _openPlayer(items[i]),
          onToggleFavorite: () => _toggleFavorite(items[i]),
          onDelete: () => _deleteItem(items[i]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (_, i) => _MediaListItem(
        item: items[i],
        onTap: () => _openPlayer(items[i]),
        onToggleFavorite: () => _toggleFavorite(items[i]),
        onDelete: () => _deleteItem(items[i]),
      ),
    );
  }

  void _openPlayer(MediaItem item) {
    if (!File(item.filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(item: item)),
    );
  }

  void _toggleFavorite(MediaItem item) {
    setState(() {
      item.isFavorite = !item.isFavorite;
      widget.storage.saveMediaItem(item);
    });
  }

  void _deleteItem(MediaItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete media?'),
        content: Text('Delete "${item.title}" from library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final file = File(item.filePath);
              if (file.existsSync()) file.deleteSync();
              widget.storage.deleteMediaItem(item.id);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _MediaGridItem extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  const _MediaGridItem({
    required this.item,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.thumbnailPath != null)
                      CachedNetworkImage(
                        imageUrl: item.thumbnailPath!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    else
                      _placeholder(),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.durationLabel.isEmpty
                              ? item.fileSizeLabel
                              : item.durationLabel,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.type == MediaType.audio
                              ? Icons.audiotrack
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          item.source,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textMuted),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onToggleFavorite,
                          child: Icon(
                            item.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: item.isFavorite
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: Icon(
        item.type == MediaType.audio ? Icons.audiotrack : Icons.video_library,
        size: 32,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _MediaListItem extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  const _MediaListItem({
    required this.item,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 64,
            height: 40,
            child: item.thumbnailPath != null
                ? CachedNetworkImage(
                    imageUrl: item.thumbnailPath!,
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
        title: Text(item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${item.source} - ${item.fileSizeLabel}',
          style:
              const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onToggleFavorite,
              child: Icon(
                item.isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: item.isFavorite ? AppColors.accent : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
