import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'data/climbing_models.dart';
import 'data/route_model.dart';
import 'data/route_database.dart';
import 'route_detail_screen.dart';

// Sort options available in the library.
enum _SortOption { nameAsc, nameDesc, dateNewest, dateOldest }

extension _SortOptionLabel on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.nameAsc:
        return 'Name (A → Z)';
      case _SortOption.nameDesc:
        return 'Name (Z → A)';
      case _SortOption.dateNewest:
        return 'Date (newest first)';
      case _SortOption.dateOldest:
        return 'Date (oldest first)';
    }
  }

  IconData get icon {
    switch (this) {
      case _SortOption.nameAsc:
        return Icons.sort_by_alpha;
      case _SortOption.nameDesc:
        return Icons.sort_by_alpha;
      case _SortOption.dateNewest:
        return Icons.calendar_today;
      case _SortOption.dateOldest:
        return Icons.calendar_today;
    }
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<SavedRoute> _routes = [];
  bool _isLoading = true;
  _SortOption _sortOption = _SortOption.dateNewest;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final routes = await RouteDatabase.instance.getAllRoutes();
    if (mounted) {
      setState(() {
        _routes = routes;
        _isLoading = false;
      });
    }
  }

  /// Returns a sorted copy of [_routes] according to the current [_sortOption].
  List<SavedRoute> get _sortedRoutes {
    final list = List<SavedRoute>.from(_routes);
    switch (_sortOption) {
      case _SortOption.nameAsc:
        list.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortOption.nameDesc:
        list.sort((a, b) =>
            b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case _SortOption.dateNewest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _SortOption.dateOldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }
    return list;
  }

  Future<void> _deleteRoute(String id) async {
    await RouteDatabase.instance.deleteRoute(id);
    await _loadRoutes();
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Sort routes by',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ..._SortOption.values.map((option) {
                final selected = option == _sortOption;
                return ListTile(
                  leading: Icon(option.icon,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  title: Text(option.label),
                  trailing: selected
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() => _sortOption = option);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Show the sort button in the app bar only when there are routes.
      appBar: _routes.isEmpty
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort routes',
                  onPressed: _showSortSheet,
                ),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? _buildEmptyState(context)
              : _buildRouteList(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.collections_bookmark_outlined,
              size: 100, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text('No routes saved yet',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Create your first climbing route!',
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildRouteList(BuildContext context) {
    final sorted = _sortedRoutes;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final route = sorted[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RouteDetailScreen(
                    route: route,
                    onDeleted: () => _deleteRoute(route.id),
                  ),
                ),
              );
              // Refresh in case anything changed (edits, sharing, etc.).
              _loadRoutes();
            },
            onLongPress: () =>
                _confirmDelete(context, route.id, route.name),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: route.annotatedImagePath != null && !kIsWeb
                          ? Image.file(File(route.annotatedImagePath!),
                              fit: BoxFit.cover)
                          : route.imagePath.isNotEmpty && !kIsWeb
                              ? Image.file(
                                  File(route.imagePath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 40),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child:
                                      const Icon(Icons.image, size: 40)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Route info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(route.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Chip(
                              label: Text(route.difficulty,
                                  style: const TextStyle(fontSize: 12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 8),
                            Text('${route.selectedHolds.length} holds',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(_formatDate(route.createdAt),
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRoute(id);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}