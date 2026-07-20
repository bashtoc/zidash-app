import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_required_dialog.dart';
import 'chat_screen.dart';
import 'seller_profile_screen.dart';
import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6F7F6);

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.listingId,
    this.initialListing,
  });

  final String listingId;
  final Map<String, dynamic>? initialListing;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<Map<String, dynamic>> _listingFuture;
  Future<List<dynamic>>? _similarFuture;
  int _imageIndex = 0;
  bool _isPreferred = false;

  @override
  void initState() {
    super.initState();
    _listingFuture = _loadListing();
  }

  Future<Map<String, dynamic>> _loadListing() async {
    final listing = widget.listingId.isEmpty
        ? widget.initialListing ?? <String, dynamic>{}
        : await ApiService.instance.listing(widget.listingId);
    final categoryId = _categoryId(listing);
    if (categoryId != null) {
      setState(() {
        _similarFuture = ApiService.instance.listings(categoryId: categoryId);
      });
    }
    return listing;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _listingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              widget.initialListing == null) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }
          if (snapshot.hasError) {
            return _errorState(snapshot.error.toString());
          }
          final listing = snapshot.data ?? widget.initialListing ?? {};
          return _content(listing);
        },
      ),
      bottomNavigationBar: FutureBuilder<Map<String, dynamic>>(
        future: _listingFuture,
        builder: (context, snapshot) {
          final listing = snapshot.data ?? widget.initialListing ?? {};
          return _contactBar(listing);
        },
      ),
    );
  }

  Widget _contactBar(Map<String, dynamic> listing) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: _contactButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message',
              filled: true,
              onTap: _openChat,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _contactButton(
              iconWidget: const _WhatsAppIcon(size: 19),
              label: 'WhatsApp',
              onTap: () => _openWhatsApp(listing),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _contactButton(
              icon: Icons.call_outlined,
              label: 'Call',
              onTap: () => _callSeller(listing),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactButton({
    IconData? icon,
    Widget? iconWidget,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    assert(icon != null || iconWidget != null);
    final buttonIcon = iconWidget ?? Icon(icon, size: 18);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );
    if (filled) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: buttonIcon,
        label: FittedBox(child: Text(label)),
        style: FilledButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: buttonIcon,
      label: FittedBox(child: Text(label)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        minimumSize: const Size.fromHeight(54),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _content(Map<String, dynamic> listing) {
    final images = _imageUrls(listing);
    final title = listing['title']?.toString() ?? 'Untitled listing';
    final price = _priceLabel(listing['price']);
    final description = listing['description']?.toString() ?? '';
    final condition = _conditionLabel(listing['condition']?.toString());
    final location = listing['location']?.toString() ?? 'Lagos, NG';
    final category = (listing['category'] as Map?)?.cast<String, dynamic>();
    final categoryName = category?['name']?.toString();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 420,
          pinned: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.85),
              ),
              icon: const Icon(Icons.arrow_back_ios_new, color: _ink, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                ),
                icon: const Icon(Icons.share_outlined, color: _ink, size: 20),
                onPressed: () => _shareListing(listing),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 8,
                right: 12,
                left: 4,
              ),
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                ),
                icon: Icon(
                  _isPreferred ? Icons.favorite_rounded : Icons.favorite_border,
                  color: _isPreferred ? Colors.red : _ink,
                  size: 20,
                ),
                onPressed: () => _togglePreferred(listing),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(background: _imageGallery(images)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _primaryColor,
                      ),
                    ),
                    _pill(condition, _primaryColor),
                    if (categoryName != null) _pill(categoryName, _muted),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${listing['viewsCount'] ?? 0} views',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: _ink,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                _sellerCard(listing),
                const SizedBox(height: 32),
                const Text(
                  'Similar Listings',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _similarListings(listing['id']?.toString()),
                const SizedBox(height: 32),
                _safetySection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _safetySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F7F1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SafetyBadge(
                icon: Icons.verified_user_outlined,
                color: Color(0xFF0DAA4D),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your safety is important to us',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Zidash is a community marketplace. We connect buyers and sellers, but we do not handle payments or deliveries. Please trade safely.',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'SAFETY TIPS',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 14),
        _SafetyTipTile(
          icon: Icons.manage_search_rounded,
          iconColor: _primaryColor,
          accentColor: const Color(0xFFFF9F2A),
          title: 'Do your due diligence',
          body:
              'Confirm item details, check seller ratings and reviews, and use secure payment methods. Avoid sharing sensitive personal information.',
        ),
        _SafetyTipTile(
          icon: Icons.handshake_outlined,
          iconColor: const Color(0xFF0DAA4D),
          accentColor: const Color(0xFFFF9F2A),
          title: 'Meet safely',
          body:
              'Always meet in safe, public locations. Bring a friend or family member when possible.',
        ),
        _SafetyTipTile(
          icon: Icons.campaign_outlined,
          iconColor: const Color(0xFFFF8A00),
          accentColor: const Color(0xFFFF8A00),
          title: 'Report scams',
          body:
              'Report suspicious users, fake listings or any unusual activity immediately.',
        ),
        _SafetyTipTile(
          icon: Icons.shield_outlined,
          iconColor: const Color(0xFF0DAA4D),
          accentColor: const Color(0xFFFFB12F),
          title: 'Zidash is not liable',
          body:
              'Zidash does not mediate transactions or assume liability for any loss, damage or disputes. Stay vigilant and protect yourself.',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4ED),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF6D1A),
                size: 38,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important Notice',
                      style: TextStyle(
                        color: Color(0xFFFF6D1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Unreliable or reported users may be deactivated immediately without warning.',
                      style: TextStyle(
                        color: _ink,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Stay safe. Trade wisely.',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: const [
            _PracticeTile(
              icon: Icons.forum_rounded,
              color: _primaryColor,
              label: 'Communicate clearly within the app',
            ),
            _PracticeTile(
              icon: Icons.payments_outlined,
              color: Color(0xFF0DAA4D),
              label: 'Inspect items before making any payment',
            ),
            _PracticeTile(
              icon: Icons.location_on_rounded,
              color: _primaryColor,
              label: 'Choose busy, well-lit public places',
            ),
            _PracticeTile(
              icon: Icons.assignment_turned_in_outlined,
              color: Color(0xFF9AA39A),
              label: 'Keep records of your conversations',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F8F3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const _SafetyBadge(
                icon: Icons.support_agent_rounded,
                color: Color(0xFF0DAA4D),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Need help?',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Our support team is here for you.',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _contactSupport,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0DAA4D),
                        side: const BorderSide(color: Color(0xFF0DAA4D)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      child: const Text('Contact Support'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF008C2E),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: const Text('Got it, I understand'),
          ),
        ),
      ],
    );
  }

  Widget _imageGallery(List<String> images) {
    final effectiveImages = images.isEmpty ? <String>[assetsFallback] : images;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: effectiveImages.length,
          onPageChanged: (index) => setState(() => _imageIndex = index),
          itemBuilder: (context, index) {
            final image = effectiveImages[index];
            final isNetwork = image.startsWith('http');
            return isNetwork
                ? Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Image.asset(assetsFallback, fit: BoxFit.cover),
                  )
                : Image.asset(image, fit: BoxFit.cover);
          },
        ),
        Positioned(
          bottom: 18,
          right: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_imageIndex + 1}/${effectiveImages.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sellerCard(Map<String, dynamic> listing) {
    final seller = (listing['seller'] as Map?)?.cast<String, dynamic>();
    final sellerId = seller?['id']?.toString();
    final name = _sellerDisplayName(seller, fallback: 'Zidash Seller');
    final trustScore = seller?['trustScore']?.toString() ?? '60';

    return GestureDetector(
      onTap: () {
        if (sellerId == null || sellerId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seller profile is not available.')),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SellerProfileScreen(sellerId: sellerId, initialSeller: seller),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: _surface,
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.verified, color: Colors.blue, size: 18),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Trust Score $trustScore',
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_ios, size: 15, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _similarListings(String? currentId) {
    final future = _similarFuture;
    if (future == null) {
      return const Text(
        'No similar listings yet.',
        style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
      );
    }
    return SizedBox(
      height: 210,
      child: FutureBuilder<List<dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }
          final listings = (snapshot.data ?? [])
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .where((item) => item['id']?.toString() != currentId)
              .take(8)
              .toList();
          if (listings.isEmpty) {
            return const Text(
              'No similar listings yet.',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
            );
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: listings.length,
            itemBuilder: (context, index) => _similarCard(listings[index]),
          );
        },
      ),
    );
  }

  Widget _similarCard(Map<String, dynamic> listing) {
    final images = _imageUrls(listing);
    final title = listing['title']?.toString() ?? 'Untitled listing';
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              listingId: listing['id']?.toString() ?? '',
              initialListing: listing,
            ),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: images.isEmpty
                  ? Image.asset(
                      assetsFallback,
                      height: 108,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      images.first,
                      height: 108,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        assetsFallback,
                        height: 108,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
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
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _priceLabel(listing['price']),
                    style: const TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w900,
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

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Future<void> _openChat() async {
    final allowed = await requireAuthenticated(
      context,
      title: 'Sign up to message sellers',
      message:
          'Create an account to contact sellers and keep your conversations saved.',
    );
    if (!allowed || !mounted) return;
    try {
      final conversation = await ApiService.instance.startConversation(
        listingId: widget.listingId,
      );
      if (!mounted) return;
      final seller = (conversation['seller'] as Map?)?.cast<String, dynamic>();
      final listing = (conversation['listing'] as Map?)
          ?.cast<String, dynamic>();
      final title = _userName(seller) ?? 'Zidash seller';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversation['id']?.toString(),
            title: title,
            avatarUrl: seller?['avatarUrl']?.toString(),
            listing: listing ?? widget.initialListing,
            sellerId: seller?['id']?.toString(),
            listingId: widget.listingId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String? _userName(Map<String, dynamic>? user) {
    if (user == null) return null;
    final first = user['firstName']?.toString() ?? '';
    final last = user['lastName']?.toString() ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? null : name;
  }

  Future<void> _openWhatsApp(Map<String, dynamic> listing) async {
    final allowed = await requireAuthenticated(
      context,
      title: 'Sign up to contact sellers',
      message: 'Create an account to contact sellers safely from Zidash.',
    );
    if (!allowed) return;
    final phone = _sellerPhone(listing);
    final digits = phone?.replaceAll(RegExp(r'\D'), '');
    if (digits == null || digits.isEmpty) {
      _showContactUnavailable('WhatsApp number is not available.');
      return;
    }
    final title = listing['title']?.toString() ?? 'your listing';
    final message = 'Hi, I am interested in $title on Zidash.';
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
    await _launchContactUri(uri, 'Could not open WhatsApp.');
  }

  Future<void> _callSeller(Map<String, dynamic> listing) async {
    final allowed = await requireAuthenticated(
      context,
      title: 'Sign up to call sellers',
      message: 'Create an account to contact sellers safely from Zidash.',
    );
    if (!allowed) return;
    final phone = _sellerPhone(listing);
    if (phone == null || phone.trim().isEmpty) {
      _showContactUnavailable('Seller phone number is not available.');
      return;
    }
    await _launchContactUri(
      Uri(scheme: 'tel', path: phone.trim()),
      'Could not start a phone call.',
    );
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@zidash.com',
      queryParameters: {'subject': 'Zidash marketplace safety support'},
    );
    await _launchContactUri(uri, 'Could not open email support.');
  }

  Future<void> _togglePreferred(Map<String, dynamic> listing) async {
    final allowed = await requireAuthenticated(
      context,
      title: 'Sign up to save products',
      message:
          'Create an account to save preferred products and find them later.',
    );
    if (!allowed) return;
    final id = listing['id']?.toString();
    if (!_isBackendListingId(id)) {
      debugPrint(
        '[preferred-products][product-detail] invalid listing id=$id listing=$listing',
      );
      _showContactUnavailable('Product is not available to save.');
      return;
    }
    final listingId = id!;
    try {
      debugPrint(
        '[preferred-products][product-detail] toggling listingId=$listingId',
      );
      final result = await ApiService.instance.togglePreferredProduct(
        listingId,
      );
      if (!mounted) return;
      final saved = result['saved'] == true;
      debugPrint(
        '[preferred-products][product-detail] toggled listingId=$listingId saved=$saved',
      );
      setState(() => _isPreferred = saved);
    } catch (error) {
      debugPrint(
        '[preferred-products][product-detail] failed listingId=$listingId error=$error',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  bool _isBackendListingId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  Future<void> _launchContactUri(Uri uri, String fallbackMessage) async {
    final didLaunch = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!didLaunch) _showContactUnavailable(fallbackMessage);
  }

  void _showContactUnavailable(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _shareListing(Map<String, dynamic> listing) {
    final title = listing['title']?.toString() ?? 'Check out this listing';
    final price = _priceLabel(listing['price']);
    final condition = _conditionLabel(listing['condition']?.toString());
    final location = listing['location']?.toString();
    final description = listing['description']?.toString();
    final buffer = StringBuffer();
    buffer.writeln('🛒 $title');
    buffer.writeln('💰 $price  •  $condition');
    if (location != null && location.isNotEmpty) {
      buffer.writeln('📍 $location');
    }
    if (description != null && description.isNotEmpty) {
      buffer.writeln();
      buffer.write(description);
    }
    buffer.writeln();
    buffer.write('— Shared via Zidash');

    SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  String? _sellerPhone(Map<String, dynamic> listing) {
    final seller = (listing['seller'] as Map?)?.cast<String, dynamic>();
    final user = (seller?['user'] as Map?)?.cast<String, dynamic>();
    return user?['phone']?.toString() ??
        seller?['phone']?.toString() ??
        listing['sellerPhone']?.toString();
  }

  List<String> _imageUrls(Map<String, dynamic> listing) {
    final images = listing['images'];
    if (images is! List) return [];
    return images
        .whereType<Map>()
        .map((item) => item['url']?.toString())
        .whereType<String>()
        .toList();
  }

  String? _categoryId(Map<String, dynamic> listing) {
    final category = (listing['category'] as Map?)?.cast<String, dynamic>();
    return category?['id']?.toString() ?? listing['categoryId']?.toString();
  }

  String _priceLabel(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '');
    if (amount == null) return '₦0';
    return '₦${amount.toStringAsFixed(0)}';
  }

  String _conditionLabel(String? value) {
    return switch (value) {
      'new' => 'New',
      'like_new' => 'Like New',
      'refurbished' => 'Refurbished',
      _ => 'Used',
    };
  }

  String _initials(String name) {
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'ZS' : initials;
  }
}

class _SafetyBadge extends StatelessWidget {
  const _SafetyBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAF6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 34),
    );
  }
}

class _SafetyTipTile extends StatelessWidget {
  const _SafetyTipTile({
    required this.icon,
    required this.iconColor,
    required this.accentColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final Color accentColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(width: 66, height: 66),
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFF7FAF6),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(icon, color: iconColor, size: 34),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    height: 1.42,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right_rounded, color: _ink, size: 24),
        ],
      ),
    );
  }
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 42),
          const SizedBox(height: 14),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppIcon extends StatelessWidget {
  const _WhatsAppIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WhatsAppIconPainter()),
    );
  }
}

class _WhatsAppIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale, scale);

    const green = Color(0xFF25D366);
    final bubblePaint = Paint()
      ..color = green
      ..style = PaintingStyle.fill;
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bubble = Path()
      ..addOval(const Rect.fromLTWH(2.2, 2.2, 19.6, 19.6))
      ..moveTo(6.3, 18.1)
      ..lineTo(4.7, 22.1)
      ..lineTo(8.9, 20.8)
      ..close();
    canvas.drawPath(bubble, bubblePaint);

    final phone = Path()
      ..moveTo(8.2, 7.8)
      ..cubicTo(8.1, 11.8, 11.5, 15.7, 16.0, 16.2)
      ..cubicTo(16.8, 16.3, 17.7, 15.2, 17.8, 14.6)
      ..cubicTo(17.9, 14.2, 16.2, 13.4, 15.6, 13.2)
      ..cubicTo(15.1, 13.1, 14.6, 13.9, 14.1, 14.1)
      ..cubicTo(12.8, 13.6, 10.6, 11.5, 10.1, 10.1)
      ..cubicTo(10.3, 9.5, 11.0, 9.1, 10.9, 8.5)
      ..cubicTo(10.8, 7.9, 10.0, 6.4, 9.5, 6.3)
      ..cubicTo(8.8, 6.2, 8.3, 7.0, 8.2, 7.8);
    canvas.drawPath(phone, whitePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const assetsFallback = 'assets/images/phone.png';

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
