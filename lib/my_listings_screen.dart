import 'package:flutter/material.dart';

import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6FBF6);

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final Map<String, Future<List<_ListingItem>>> _futures = {};

  @override
  void initState() {
    super.initState();
    for (final status in _tabs.keys) {
      _futures[status] = _loadListings(status);
    }
  }

  static const _tabs = {
    'listed': 'Listed',
    'active': 'Active',
    'closed': 'Closed',
  };

  Future<List<_ListingItem>> _loadListings(String status) async {
    final items = await ApiService.instance.myListings(status: status);
    return items
        .map(
          (item) =>
              _ListingItem.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  void _refresh([String? status]) {
    setState(() {
      if (status == null) {
        for (final key in _tabs.keys) {
          _futures[key] = _loadListings(key);
        }
      } else {
        _futures[status] = _loadListings(status);
      }
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteListing(_ListingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text('This removes "${item.title}" from your listings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(() async {
      await ApiService.instance.deleteMyListing(item.id);
    });
  }

  Future<void> _editListing(_ListingItem item) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _EditListingSheet(item: item),
    );
    if (updated == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          title: const Text(
            'Items listed',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          bottom: TabBar(
            indicatorColor: _primaryColor,
            labelColor: _ink,
            unselectedLabelColor: _muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900),
            tabs: _tabs.values.map((label) => Tab(text: label)).toList(),
          ),
        ),
        body: TabBarView(
          children: _tabs.keys.map((status) => _tabBody(status)).toList(),
        ),
      ),
    );
  }

  Widget _tabBody(String status) {
    return FutureBuilder<List<_ListingItem>>(
      future: _futures[status],
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryColor),
          );
        }
        if (snapshot.hasError) {
          return _emptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load listings',
            subtitle: snapshot.error.toString(),
            action: () => _refresh(status),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _emptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No ${_tabs[status]!.toLowerCase()} items',
            subtitle: 'Your items will appear here when available.',
            action: () => _refresh(status),
          );
        }
        return RefreshIndicator(
          color: _primaryColor,
          onRefresh: () async {
            _refresh(status);
            await _futures[status];
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _listingCard(items[index]),
          ),
        );
      },
    );
  }

  Widget _listingCard(_ListingItem item) {
    final isSold = item.status == 'sold';
    final isPendingReview = item.status == 'paused';
    final isActive = item.status == 'active';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDE9)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 84,
                  height: 84,
                  color: _surface,
                  child: item.imageUrl == null
                      ? const Icon(Icons.image_outlined, color: _muted)
                      : Image.network(item.imageUrl!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (item.isBoosted) _tag('Boosted', _primaryColor),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'NGN ${item.price}',
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _tag(
                          _statusLabel(item.status),
                          _statusColor(item.status),
                        ),
                        if (item.category != null) _tag(item.category!, _muted),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.rocket_launch_outlined,
                  label: 'Boost',
                  onTap: item.isBoosted || !isActive
                      ? null
                      : () => _runAction(() async {
                          await ApiService.instance.boostMyListing(item.id);
                        }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: () => _editListing(item),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: isSold
                      ? Icons.play_circle_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  label: isSold ? 'Reopen' : 'Close',
                  onTap: isPendingReview
                      ? null
                      : () => _runAction(() async {
                          if (isSold) {
                            await ApiService.instance.reopenMyListing(item.id);
                          } else {
                            await ApiService.instance.closeMyListing(item.id);
                          }
                        }),
                ),
              ),
              const SizedBox(width: 8),
              _iconAction(
                icon: Icons.delete_outline_rounded,
                color: Colors.red,
                onTap: () => _deleteListing(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: onTap == null ? _muted : _ink,
        side: BorderSide(color: Colors.grey.shade200),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 40,
      width: 42,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: Colors.grey.shade200),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Icon(icon, size: 19),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _muted, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: action,
              style: FilledButton.styleFrom(backgroundColor: _primaryColor),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'active' => Colors.green,
      'sold' => Colors.orange,
      'paused' => const Color(0xFFE46E1C),
      'rejected' => Colors.red,
      _ => _muted,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'sold' => 'Closed',
      'paused' => 'Pending review',
      _ => status[0].toUpperCase() + status.substring(1),
    };
  }
}

class _EditListingSheet extends StatefulWidget {
  const _EditListingSheet({required this.item});

  final _ListingItem item;

  @override
  State<_EditListingSheet> createState() => _EditListingSheetState();
}

class _EditListingSheetState extends State<_EditListingSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _locationController;
  late String _condition;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
    _priceController = TextEditingController(text: widget.item.rawPrice);
    _locationController = TextEditingController(text: widget.item.location);
    _condition = widget.item.condition;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ApiService.instance.updateMyListing(widget.item.id, {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'condition': _condition,
        'location': _locationController.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit listing',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _field(_titleController, 'Title'),
              const SizedBox(height: 12),
              _field(_descriptionController, 'Description', minLines: 3),
              const SizedBox(height: 12),
              _field(
                _priceController,
                'Price',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _field(_locationController, 'Location'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _condition,
                decoration: _decoration('Condition'),
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('New')),
                  DropdownMenuItem(value: 'like_new', child: Text('Like New')),
                  DropdownMenuItem(value: 'used', child: Text('Used')),
                  DropdownMenuItem(
                    value: 'refurbished',
                    child: Text('Refurbished'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _condition = value ?? 'used'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isSaving ? 'Saving...' : 'Save changes',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int minLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : 5,
      keyboardType: keyboardType,
      decoration: _decoration(label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return '$label is required';
        if (label == 'Price' && double.tryParse(value.trim()) == null) {
          return 'Enter a valid price';
        }
        return null;
      },
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
    );
  }
}

class _ListingItem {
  const _ListingItem({
    required this.id,
    required this.title,
    required this.description,
    required this.rawPrice,
    required this.status,
    required this.condition,
    required this.location,
    this.category,
    this.imageUrl,
    this.promotedUntil,
  });

  final String id;
  final String title;
  final String description;
  final String rawPrice;
  final String status;
  final String condition;
  final String location;
  final String? category;
  final String? imageUrl;
  final DateTime? promotedUntil;

  String get price => double.tryParse(rawPrice)?.toStringAsFixed(0) ?? rawPrice;

  bool get isBoosted {
    final until = promotedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  factory _ListingItem.fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    final firstImage = images is List && images.isNotEmpty
        ? (images.first as Map).cast<String, dynamic>()
        : null;
    final category = (json['category'] as Map?)?.cast<String, dynamic>();
    return _ListingItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled listing',
      description: json['description']?.toString() ?? '',
      rawPrice: json['price']?.toString() ?? '0',
      status: json['status']?.toString() ?? 'draft',
      condition: json['condition']?.toString() ?? 'used',
      location: json['location']?.toString() ?? '',
      category: category?['name']?.toString(),
      imageUrl: firstImage?['url']?.toString(),
      promotedUntil: DateTime.tryParse(json['promotedUntil']?.toString() ?? ''),
    );
  }
}
