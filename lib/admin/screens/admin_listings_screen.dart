import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------
const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6FBF6);
const _adminAccent = Color(0xFFDC2626);

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------
class _AdminListing {
  final String id;
  final String title;
  final String price;
  final String status;
  final String category;
  final String sellerName;
  final String location;
  final String? imageUrl;
  final DateTime? createdAt;

  const _AdminListing({
    required this.id,
    required this.title,
    required this.price,
    required this.status,
    required this.category,
    required this.sellerName,
    required this.location,
    this.imageUrl,
    this.createdAt,
  });

  factory _AdminListing.fromJson(Map<String, dynamic> json) {
    // Price formatting
    String formattedPrice = '';
    final rawPrice = json['price'];
    if (rawPrice != null) {
      final double? parsed = rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse('$rawPrice');
      if (parsed != null) {
        final formatter = NumberFormat('#,##0', 'en_US');
        formattedPrice = '₦${formatter.format(parsed)}';
      }
    }

    // Category
    String category = '';
    final categoryField = json['category'];
    if (categoryField is Map) {
      category = (categoryField['name'] ?? '').toString();
    }
    if (category.isEmpty) {
      category = (json['categoryName'] ?? '').toString();
    }

    // Seller
    final sellerField = json['seller'];
    String sellerName = 'Unknown Seller';
    if (sellerField is Map) {
      final dn = sellerField['displayName'];
      if (dn != null && dn.toString().isNotEmpty) {
        sellerName = dn.toString();
      }
    }

    // Image URL
    String? imageUrl;
    final imagesList = json['images'];
    if (imagesList is List && imagesList.isNotEmpty) {
      final first = imagesList.first;
      if (first is Map) {
        final url = first['url'];
        if (url != null && url.toString().isNotEmpty) {
          imageUrl = url.toString();
        }
      }
    }

    // Created at
    final DateTime? createdAt = DateTime.tryParse(
      (json['createdAt'] ?? '').toString(),
    );

    return _AdminListing(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled').toString(),
      price: formattedPrice,
      status: (json['status'] ?? 'active').toString(),
      category: category,
      sellerName: sellerName,
      location: (json['location'] ?? '').toString(),
      imageUrl: imageUrl,
      createdAt: createdAt,
    );
  }

  bool get isPaused => status == 'paused';
  bool get isActive => status == 'active';

  Color get statusColor {
    switch (status) {
      case 'active':
        return _primaryColor;
      case 'paused':
        return Colors.orange;
      case 'flagged':
        return _adminAccent;
      default:
        return _muted;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'paused':
        return 'Pending review';
      case 'flagged':
        return 'Flagged';
      case 'draft':
        return 'Draft';
      default:
        return status;
    }
  }

  _AdminListing copyWith({String? status}) {
    return _AdminListing(
      id: id,
      title: title,
      price: price,
      status: status ?? this.status,
      category: category,
      sellerName: sellerName,
      location: location,
      imageUrl: imageUrl,
      createdAt: createdAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Screen widget
// ---------------------------------------------------------------------------
class AdminListingsScreen extends StatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends State<AdminListingsScreen> {
  final _searchController = TextEditingController();

  List<_AdminListing> _listings = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  String _searchQuery = '';
  String? _statusFilter; // null = all

  Timer? _debounce;

  // Filter tab configuration
  static const _filterLabels = ['All', 'Active', 'Pending', 'Rejected'];
  static const List<String?> _filterValues = [
    null,
    'active',
    'paused',
    'rejected',
  ];

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Data loading
  // -------------------------------------------------------------------------
  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }

    if (!_hasMore && !reset) return;
    if (_isLoadingMore) return;

    if (!reset) {
      setState(() => _isLoadingMore = true);
    }

    try {
      final response = await ApiService.instance.adminListings(
        page: _currentPage,
        status: _statusFilter,
        query: _searchQuery.isEmpty ? null : _searchQuery,
      );

      final rawItems =
          (response['data'] ?? response['listings'] ?? response['items'] ?? [])
              as List;
      final parsed = rawItems
          .map((e) => _AdminListing.fromJson(e as Map<String, dynamic>))
          .toList();

      final totalPages =
          (response['totalPages'] ?? response['pages'] ?? 1) as int;

      if (!mounted) return;
      setState(() {
        if (reset) {
          _listings = parsed;
        } else {
          _listings = [..._listings, ...parsed];
        }
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = _currentPage < totalPages;
        _currentPage++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = reset;
        _errorMessage = e.toString();
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore && !_isLoading) {
        _load();
      }
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchQuery = value.trim();
      _load(reset: true);
    });
  }

  void _setFilter(String? status) {
    if (_statusFilter == status) return;
    setState(() => _statusFilter = status);
    _load(reset: true);
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------
  Future<void> _pauseListing(_AdminListing item) async {
    final activating = !item.isActive;
    final action = activating ? 'Start' : 'Pause';
    final confirmed = await _showConfirmDialog(
      title: '$action Listing',
      content: activating
          ? 'Start "${item.title}" and make it visible on the marketplace?'
          : 'Pause "${item.title}" and hide it from the marketplace?',
      confirmLabel: action,
      confirmColor: activating ? _primaryColor : Colors.orange,
    );
    if (!confirmed || !mounted) return;

    try {
      await ApiService.instance.adminSetListingPaused(
        item.id,
        paused: item.isActive,
      );
      final newStatus = item.isActive ? 'paused' : 'active';
      if (!mounted) return;
      setState(() {
        final idx = _listings.indexWhere((l) => l.id == item.id);
        if (idx != -1) {
          _listings[idx] = _listings[idx].copyWith(status: newStatus);
        }
      });
      _showSnackBar(
        'Listing ${activating ? 'started' : 'paused'} successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to update listing: $e', isError: true);
    }
  }

  Future<void> _deleteListing(_AdminListing item) async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete Listing',
      content:
          'This will permanently delete "${item.title}". This action cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: _adminAccent,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ApiService.instance.adminDeleteListing(item.id);
      if (!mounted) return;
      setState(() => _listings.removeWhere((l) => l.id == item.id));
      _showSnackBar('Listing deleted.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to delete listing: $e', isError: true);
    }
  }

  void _openDetail(_AdminListing item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DetailSheet(
        item: item,
        onPause: () {
          Navigator.of(ctx).pop();
          _pauseListing(item);
        },
        onDelete: () {
          Navigator.of(ctx).pop();
          _deleteListing(item);
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(fontSize: 14, color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _adminAccent : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchAndFilter(),
          Flexible(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: _onSearch,
            style: const TextStyle(fontSize: 14, color: _ink),
            decoration: InputDecoration(
              hintText: 'Search listings…',
              hintStyle: const TextStyle(fontSize: 14, color: _muted),
              prefixIcon: const Icon(Icons.search, color: _muted, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: _muted, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_filterLabels.length, (i) {
                final label = _filterLabels[i];
                final value = _filterValues[i];
                final isSelected = _statusFilter == value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : _muted,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: _primaryColor,
                    backgroundColor: _surface,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                    onSelected: (_) => _setFilter(value),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _adminAccent, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Failed to load listings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _primaryColor),
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, color: _muted, size: 56),
            const SizedBox(height: 12),
            const Text(
              'No listings found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your search or filters.',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _listings.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _listings.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: _primaryColor),
              ),
            );
          }
          return _ListingTile(
            item: _listings[index],
            onTap: () => _openDetail(_listings[index]),
            onPause: () => _pauseListing(_listings[index]),
            onDelete: () => _deleteListing(_listings[index]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Listing tile
// ---------------------------------------------------------------------------
class _ListingTile extends StatelessWidget {
  final _AdminListing item;
  final VoidCallback onTap;
  final VoidCallback onPause;
  final VoidCallback onDelete;

  const _ListingTile({
    required this.item,
    required this.onTap,
    required this.onPause,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: item.imageUrl != null
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: _surface,
                          child: const Icon(
                            Icons.image_outlined,
                            color: _muted,
                            size: 28,
                          ),
                        ),
                      )
                    : Container(
                        color: _surface,
                        child: const Icon(
                          Icons.image_outlined,
                          color: _muted,
                          size: 28,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.price,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.sellerName} · ${item.location}',
                    style: const TextStyle(fontSize: 11, color: _muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status + actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusPill(item: item),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: item.isActive ? 'Pause' : 'Start',
                        icon: Icon(
                          item.isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          size: 20,
                          color: item.isActive ? Colors.orange : _primaryColor,
                        ),
                        onPressed: onPause,
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Delete',
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: _adminAccent,
                        ),
                        onPressed: onDelete,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status pill
// ---------------------------------------------------------------------------
class _StatusPill extends StatelessWidget {
  final _AdminListing item;

  const _StatusPill({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: item.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        item.statusLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: item.statusColor,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable generic pill
// ---------------------------------------------------------------------------
Widget _pill(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
    ),
  );
}

// ---------------------------------------------------------------------------
// Detail bottom sheet
// ---------------------------------------------------------------------------
class _DetailSheet extends StatelessWidget {
  final _AdminListing item;
  final VoidCallback onPause;
  final VoidCallback onDelete;

  const _DetailSheet({
    required this.item,
    required this.onPause,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = item.createdAt != null
        ? DateFormat('MMM d, yyyy').format(item.createdAt!)
        : null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Image
            if (item.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    width: double.infinity,
                    color: _surface,
                    child: const Icon(
                      Icons.image_outlined,
                      color: _muted,
                      size: 48,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Title
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),

            // Price
            Text(
              item.price,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 8),

            // Tags row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatusPill(item: item),
                if (item.category.isNotEmpty) _pill(item.category, _muted),
                if (item.location.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _muted.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: _muted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          item.location,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Seller
            Text(
              'Seller: ${item.sellerName}',
              style: const TextStyle(fontSize: 13, color: _muted),
            ),

            // Listed date
            if (dateStr != null) ...[
              const SizedBox(height: 2),
              Text(
                'Listed: $dateStr',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: item.isActive
                          ? Colors.orange
                          : _primaryColor,
                      side: BorderSide(
                        color: item.isActive ? Colors.orange : _primaryColor,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onPause,
                    icon: Icon(
                      item.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 18,
                    ),
                    label: Text(
                      item.isActive ? 'Pause' : 'Start',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _adminAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
