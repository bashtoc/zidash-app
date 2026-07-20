import 'package:flutter/material.dart';

import 'product_detail_screen.dart';
import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6F7F6);
const _fallbackImage = 'assets/images/phone.png';

class PreferredProductsScreen extends StatefulWidget {
  const PreferredProductsScreen({super.key});

  @override
  State<PreferredProductsScreen> createState() =>
      _PreferredProductsScreenState();
}

class _PreferredProductsScreenState extends State<PreferredProductsScreen> {
  late Future<List<dynamic>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = ApiService.instance.preferredProducts();
  }

  void _refresh() {
    setState(() {
      _productsFuture = ApiService.instance.preferredProducts();
    });
  }

  Future<void> _removePreferred(Map<String, dynamic> listing) async {
    final id = listing['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await ApiService.instance.togglePreferredProduct(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from preferred products.')),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: _surface,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          'Preferred Products',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: () async {
          _refresh();
          await _productsFuture;
        },
        child: FutureBuilder<List<dynamic>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: _primaryColor),
              );
            }
            if (snapshot.hasError) {
              return _state(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load preferred products',
                message: snapshot.error.toString(),
                action: _refresh,
              );
            }
            final products = (snapshot.data ?? [])
                .whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList();
            if (products.isEmpty) {
              return _state(
                icon: Icons.favorite_border_rounded,
                title: 'No preferred products yet',
                message: 'Tap the heart on a product to save it here.',
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) => _productCard(products[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _state({
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? action,
  }) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 110),
        Icon(icon, color: _muted, size: 46),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
        ),
        if (action != null) ...[
          const SizedBox(height: 18),
          Center(
            child: FilledButton(
              onPressed: action,
              style: FilledButton.styleFrom(backgroundColor: _primaryColor),
              child: const Text('Retry'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _productCard(Map<String, dynamic> listing) {
    final image = _imageUrl(listing);
    final title = listing['title']?.toString() ?? 'Untitled product';
    final seller = (listing['seller'] as Map?)?.cast<String, dynamic>();
    final sellerName = _sellerDisplayName(seller, fallback: 'Zidash seller');
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              listingId: listing['id']?.toString() ?? '',
              initialListing: listing,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image == null
                      ? Image.asset(_fallbackImage, fit: BoxFit.cover)
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(_fallbackImage, fit: BoxFit.cover),
                        ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removePreferred(listing),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: _primaryColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _priceLabel(listing['price']),
                    style: const TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _imageUrl(Map<String, dynamic> listing) {
    final images = listing['images'];
    if (images is! List || images.isEmpty) return null;
    final first = images.first;
    if (first is Map) return first['url']?.toString();
    return first?.toString();
  }

  String _priceLabel(dynamic value) {
    final amount = num.tryParse(value?.toString() ?? '');
    if (amount == null) return 'Price on request';
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    return '₦$formatted';
  }
}

String _sellerDisplayName(
  Map<String, dynamic>? seller, {
  required String fallback,
}) {
  final user = (seller?['user'] as Map?)?.cast<String, dynamic>();
  final firstName = user?['firstName']?.toString().trim() ?? '';
  final lastName = user?['lastName']?.toString().trim() ?? '';
  final accountName = '$firstName $lastName'.trim();
  if (accountName.isNotEmpty) return accountName;

  final displayName = seller?['displayName']?.toString().trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;

  return fallback;
}
