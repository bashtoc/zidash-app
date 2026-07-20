import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_required_dialog.dart';
import 'product_detail_screen.dart';
import 'services/api_service.dart';

class CategoryListingsScreen extends StatefulWidget {
  const CategoryListingsScreen({
    super.key,
    required this.categoryName,
    required this.categoryIcon,
  });

  final String categoryName;
  final String categoryIcon;

  @override
  State<CategoryListingsScreen> createState() => _CategoryListingsScreenState();
}

class _CategoryListingsScreenState extends State<CategoryListingsScreen> {
  late Future<List<dynamic>> _listingsFuture;
  final Set<String> _preferredProductIds = {};

  static const primaryColor = Color(0xFF66C665);

  @override
  void initState() {
    super.initState();
    _listingsFuture = ApiService.instance.listings(
      category: widget.categoryName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF7FBF7),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Image.asset(
                            widget.categoryIcon,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.category,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.categoryName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A2B3C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // Listings Grid
              SliverToBoxAdapter(
                child: FutureBuilder<List<dynamic>>(
                  future: _listingsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _buildEmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: 'Could not load listings',
                        subtitle: 'Check your connection and try again.',
                        onRetry: () {
                          setState(() {
                            _listingsFuture = ApiService.instance.listings(
                              category: widget.categoryName,
                            );
                          });
                        },
                      );
                    }
                    final listings = snapshot.data ?? [];
                    if (listings.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No listings yet',
                        subtitle:
                            'Be the first to list something in ${widget.categoryName}!',
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: listings.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.65,
                            ),
                        itemBuilder: (context, index) {
                          return _buildListingCard(
                            context,
                            index: index,
                            listing: listings[index] as Map<String, dynamic>,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onRetry,
  }) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBF7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryColor, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2B3C),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListingCard(
    BuildContext context, {
    int index = 0,
    required Map<String, dynamic> listing,
  }) {
    final fallbackImages = [
      'assets/images/phone.png',
      'assets/images/watch.png',
      'assets/images/headphones.png',
      'assets/images/shoes.png',
    ];
    final fallbackTitles = [
      'iPhone 15 Pro Max',
      'Apple Watch Series 9',
      'Sony A7 III',
      'Nike Air Max 270',
    ];
    final fallbackPrices = ['₦1,280,000', '₦450,000', '₦320,000', '₦120,000'];

    final listingImages = listing['images'] as List<dynamic>?;
    final imageUrl = listingImages != null && listingImages.isNotEmpty
        ? (listingImages.first as Map<String, dynamic>)['url']?.toString()
        : null;
    final imgPath = fallbackImages[index % fallbackImages.length];
    final title =
        listing['title']?.toString() ??
        fallbackTitles[index % fallbackTitles.length];
    final price = listing['price'] == null
        ? fallbackPrices[index % fallbackPrices.length]
        : _formatPrice(listing['price']);
    final seller = listing['seller'] as Map<String, dynamic>?;
    final sellerName = _sellerDisplayName(seller, fallback: 'Zidash Seller');
    final location = listing['location']?.toString() ?? 'Lagos, NG';
    final listingId = listing['id']?.toString();
    final isPreferred =
        listingId != null && _preferredProductIds.contains(listingId);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              listingId: listing['id']?.toString() ?? '',
              initialListing: listing,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: imageUrl == null
                      ? Image.asset(
                          imgPath,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          imageUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                imgPath,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                        ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => _togglePreferred(listing),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPreferred
                            ? Icons.favorite_rounded
                            : Icons.favorite_border,
                        color: isPreferred ? Colors.red : Colors.black54,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 10,
                        backgroundImage: NetworkImage(
                          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=100',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sellerName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.verified, color: Colors.blue, size: 12),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(dynamic value) {
    final amount = num.tryParse(value?.toString() ?? '');
    if (amount == null) return 'Price on request';
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    return '₦$formatted';
  }

  Future<void> _togglePreferred(Map<String, dynamic> listing) async {
    final allowed = await requireAuthenticated(
      context,
      title: 'Sign up to save products',
      message:
          'Create an account to save preferred products and find them later.',
    );
    if (!allowed || !mounted) return;
    final id = listing['id']?.toString();
    if (id == null || id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product is not available to save.')),
      );
      return;
    }
    try {
      final result = await ApiService.instance.togglePreferredProduct(id);
      if (!mounted) return;
      final saved = result['saved'] == true;
      setState(() {
        if (saved) {
          _preferredProductIds.add(id);
        } else {
          _preferredProductIds.remove(id);
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
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
