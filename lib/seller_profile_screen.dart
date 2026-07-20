import 'package:flutter/material.dart';

import 'auth_required_dialog.dart';
import 'chat_screen.dart';
import 'product_detail_screen.dart';
import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6F7F6);
const _fallbackImage = 'assets/images/onboarding_business.png';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({
    super.key,
    required this.sellerId,
    this.initialSeller,
  });

  final String sellerId;
  final Map<String, dynamic>? initialSeller;

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  late Future<_SellerProfileData> _sellerFuture;
  late Future<List<dynamic>> _listingsFuture;
  bool? _isFollowing;
  bool? _isOwnStore;
  int? _followersCount;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _sellerFuture = _loadSeller();
    _listingsFuture = ApiService.instance.sellerListings(widget.sellerId);
  }

  Future<_SellerProfileData> _loadSeller() async {
    final response = await ApiService.instance.sellerProfile(widget.sellerId);
    var seller = _SellerProfileData.fromJson(response);

    await ApiService.instance.loadSession();
    final isAnonymous = await ApiService.instance.isAnonymousSession();
    if (!isAnonymous && ApiService.instance.isAuthenticated) {
      try {
        final status = await ApiService.instance.sellerFollowStatus(seller.id);
        seller = seller.copyWith(
          isFollowing: status['isFollowing'] == true,
          isOwnStore: status['isOwnStore'] == true,
          followersCount: _SellerProfileData._intValue(
            status['followersCount'],
          ),
        );
        _isFollowing = seller.isFollowing;
        _isOwnStore = seller.isOwnStore;
        _followersCount = seller.followersCount;
      } on ApiException catch (error) {
        if (!error.isUnauthorized) rethrow;
      }
    }
    return seller;
  }

  void _refresh() {
    setState(() {
      _isFollowing = null;
      _isOwnStore = null;
      _followersCount = null;
      _sellerFuture = _loadSeller();
      _listingsFuture = ApiService.instance.sellerListings(widget.sellerId);
    });
  }

  int _visibleFollowersCount(_SellerProfileData seller) {
    return _followersCount ?? seller.followersCount;
  }

  bool _visibleIsFollowing(_SellerProfileData seller) {
    return _isFollowing ?? seller.isFollowing;
  }

  bool _visibleIsOwnStore(_SellerProfileData seller) {
    return _isOwnStore ?? seller.isOwnStore;
  }

  Future<void> _toggleFollow(_SellerProfileData seller) async {
    final allowed = await requireAuthenticated(
      context,
      title: 'Sign up to follow stores',
      message:
          'Create an account to follow stores and keep up with new listings.',
    );
    if (!allowed || !mounted || _visibleIsOwnStore(seller)) return;

    setState(() => _isFollowLoading = true);
    try {
      final result = await ApiService.instance.toggleSellerFollow(seller.id);
      if (!mounted) return;
      final isFollowing = result['isFollowing'] == true;
      final followersCount = _SellerProfileData._intValue(
        result['followersCount'],
      );
      final isOwnStore = result['isOwnStore'] == true;
      final updatedSeller = seller.copyWith(
        isFollowing: isFollowing,
        isOwnStore: isOwnStore,
        followersCount: followersCount,
      );
      setState(() {
        _isFollowing = isFollowing;
        _isOwnStore = isOwnStore;
        _followersCount = followersCount;
        _sellerFuture = Future.value(updatedSeller);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: FutureBuilder<_SellerProfileData>(
        future: _sellerFuture,
        builder: (context, snapshot) {
          final seller =
              snapshot.data ??
              (widget.initialSeller == null
                  ? null
                  : _SellerProfileData.fromJson(widget.initialSeller!));
          if (snapshot.connectionState != ConnectionState.done &&
              seller == null) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }
          if (snapshot.hasError && seller == null) {
            return _errorState(snapshot.error.toString());
          }
          return RefreshIndicator(
            color: _primaryColor,
            onRefresh: () async {
              _refresh();
              await Future.wait([_sellerFuture, _listingsFuture]);
            },
            child: _content(seller!),
          );
        },
      ),
    );
  }

  Widget _errorState(String message) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront_outlined, size: 48, color: _muted),
            const SizedBox(height: 14),
            const Text(
              'Seller profile unavailable',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _refresh,
              style: FilledButton.styleFrom(backgroundColor: _primaryColor),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(_SellerProfileData seller) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _storeHeader(seller)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                _sellerStats(seller),
                const SizedBox(height: 18),
                _aboutCard(seller),
                const SizedBox(height: 22),
                _listingsHeader(),
              ],
            ),
          ),
        ),
        _sellerListings(),
        const SliverToBoxAdapter(child: SizedBox(height: 36)),
      ],
    );
  }

  Widget _storeHeader(_SellerProfileData seller) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 270,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (seller.coverImageUrl != null)
                Image.network(
                  seller.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _coverFallback(),
                )
              else
                _coverFallback(),
              Container(color: Colors.black.withValues(alpha: 0.28)),
            ],
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.24),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 172, 20, 0),
          child: _profileCard(seller),
        ),
      ],
    );
  }

  Widget _coverFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3D2E), Color(0xFF132118)],
        ),
      ),
    );
  }

  Widget _profileCard(_SellerProfileData seller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: _cardDecoration(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 48,
              backgroundColor: _surface,
              backgroundImage: seller.avatarUrl == null
                  ? null
                  : NetworkImage(seller.avatarUrl!),
              child: seller.avatarUrl == null
                  ? Text(
                      seller.initials,
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  seller.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (seller.identityVerified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _metricPill(Icons.shield_outlined, 'Trust ${seller.trustScore}'),
              _metricPill(Icons.star_rounded, seller.ratingLabel),
              if (seller.location != null)
                _metricPill(Icons.location_on_outlined, seller.location!),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _followButton(seller)),
              const SizedBox(width: 10),
              _actionButton(Icons.chat_bubble_outline_rounded, seller),
              const SizedBox(width: 10),
              _actionButton(Icons.phone_outlined, seller),
            ],
          ),
        ],
      ),
    );
  }

  Widget _followButton(_SellerProfileData seller) {
    final isOwnStore = _visibleIsOwnStore(seller);
    final isFollowing = _visibleIsFollowing(seller);
    final label = isOwnStore
        ? 'Your store'
        : (isFollowing ? 'Following' : 'Follow');
    final icon = isOwnStore
        ? Icons.storefront_rounded
        : (isFollowing ? Icons.check_rounded : Icons.add_rounded);

    return FilledButton.icon(
      onPressed: _isFollowLoading || isOwnStore
          ? null
          : () => _toggleFollow(seller),
      icon: _isFollowLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: isFollowing ? _ink : _primaryColor,
        disabledBackgroundColor: const Color(0xFFE6ECE6),
        disabledForegroundColor: _muted,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _sellerStats(_SellerProfileData seller) {
    return Row(
      children: [
        _stat('${_visibleFollowersCount(seller)}', 'Followers'),
        const SizedBox(width: 10),
        _stat(seller.memberSinceLabel, 'Member since'),
        const SizedBox(width: 10),
        _stat('${seller.ratingCount}', 'Reviews'),
      ],
    );
  }

  Widget _aboutCard(_SellerProfileData seller) {
    final tags = <Widget>[
      if (seller.phoneVerified) _verificationTag(Icons.phone, 'Phone verified'),
      if (seller.faceVerified) _verificationTag(Icons.face, 'Face verified'),
      if (seller.identityVerified)
        _verificationTag(Icons.badge_outlined, 'Identity verified'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About seller',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (seller.bio != null) ...[
            const SizedBox(height: 8),
            Text(
              seller.bio!,
              style: const TextStyle(
                color: _muted,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: tags),
          ],
        ],
      ),
    );
  }

  Widget _listingsHeader() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Active listings',
        style: TextStyle(
          color: _ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _sellerListings() {
    return FutureBuilder<List<dynamic>>(
      future: _listingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: CircularProgressIndicator(color: _primaryColor),
              ),
            ),
          );
        }
        final listings = (snapshot.data ?? [])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .where((item) => item['status']?.toString() == 'active')
            .toList();
        if (listings.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'No active listings from this seller yet.',
                style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _listingCard(listings[index]),
              childCount: listings.length,
            ),
          ),
        );
      },
    );
  }

  Widget _listingCard(Map<String, dynamic> listing) {
    final image = _imageUrl(listing);
    final title = listing['title']?.toString() ?? 'Untitled listing';
    final location = listing['location']?.toString();
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
        decoration: _cardDecoration(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: image == null
                  ? Image.asset(
                      _fallbackImage,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      image,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        _fallbackImage,
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
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _priceLabel(listing['price']),
                    style: const TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (location != null && location.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: _muted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, _SellerProfileData seller) {
    return InkWell(
      onTap: () async {
        if (icon == Icons.chat_bubble_outline_rounded) {
          final allowed = await requireAuthenticated(
            context,
            title: 'Sign up to message sellers',
            message:
                'Create an account to contact sellers and keep your conversations saved.',
          );
          if (!allowed || !mounted) return;
          try {
            final conversation = await ApiService.instance.startConversation(
              sellerId: seller.id,
            );
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  conversationId: conversation['id']?.toString(),
                  title: seller.name,
                  avatarUrl: seller.avatarUrl,
                  sellerId: seller.id,
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
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: _ink, size: 21),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: _cardDecoration(16),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricPill(IconData icon, String label) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _primaryColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _primaryColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(double radius) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.045),
          blurRadius: 14,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }

  static String? _imageUrl(Map<String, dynamic> listing) {
    final images = listing['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) return first['url']?.toString();
      return first?.toString();
    }
    return null;
  }

  static String _priceLabel(dynamic value) {
    final number = num.tryParse(value?.toString() ?? '');
    if (number == null) return 'Price on request';
    final formatted = number
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    return 'NGN $formatted';
  }
}

class _SellerProfileData {
  const _SellerProfileData({
    required this.id,
    required this.name,
    required this.initials,
    required this.trustScore,
    required this.ratingAverage,
    required this.ratingCount,
    required this.followersCount,
    required this.isFollowing,
    required this.isOwnStore,
    required this.memberSince,
    required this.phoneVerified,
    required this.faceVerified,
    required this.identityVerified,
    this.bio,
    this.location,
    this.coverImageUrl,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String initials;
  final int trustScore;
  final double ratingAverage;
  final int ratingCount;
  final int followersCount;
  final bool isFollowing;
  final bool isOwnStore;
  final DateTime? memberSince;
  final bool phoneVerified;
  final bool faceVerified;
  final bool identityVerified;
  final String? bio;
  final String? location;
  final String? coverImageUrl;
  final String? avatarUrl;

  factory _SellerProfileData.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final displayName = json['displayName']?.toString().trim();
    final firstName = user['firstName']?.toString().trim() ?? '';
    final lastName = user['lastName']?.toString().trim() ?? '';
    final accountName = '$firstName $lastName'.trim();
    final name = accountName.isNotEmpty
        ? accountName
        : displayName != null && displayName.isNotEmpty
        ? displayName
        : 'Zidash Seller';

    return _SellerProfileData(
      id: json['id']?.toString() ?? '',
      name: name,
      initials: _initials(name),
      trustScore: _intValue(json['trustScore']),
      ratingAverage: _doubleValue(json['ratingAverage']),
      ratingCount: _intValue(json['ratingCount']),
      followersCount: _intValue(json['followersCount']),
      isFollowing: json['isFollowing'] == true,
      isOwnStore: json['isOwnStore'] == true,
      memberSince: DateTime.tryParse(json['memberSince']?.toString() ?? ''),
      phoneVerified: user['phoneVerifiedAt'] != null,
      faceVerified: user['faceVerifiedAt'] != null,
      identityVerified: user['identityVerifiedAt'] != null,
      bio: _nullableText(json['bio']),
      location: _nullableText(json['location']),
      coverImageUrl: _nullableText(json['coverImageUrl']),
      avatarUrl: _nullableText(user['avatarUrl']),
    );
  }

  _SellerProfileData copyWith({
    int? followersCount,
    bool? isFollowing,
    bool? isOwnStore,
  }) {
    return _SellerProfileData(
      id: id,
      name: name,
      initials: initials,
      trustScore: trustScore,
      ratingAverage: ratingAverage,
      ratingCount: ratingCount,
      followersCount: followersCount ?? this.followersCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isOwnStore: isOwnStore ?? this.isOwnStore,
      memberSince: memberSince,
      phoneVerified: phoneVerified,
      faceVerified: faceVerified,
      identityVerified: identityVerified,
      bio: bio,
      location: location,
      coverImageUrl: coverImageUrl,
      avatarUrl: avatarUrl,
    );
  }

  String get ratingLabel {
    if (ratingCount == 0) return 'No reviews yet';
    return '${ratingAverage.toStringAsFixed(1)} ($ratingCount)';
  }

  String get memberSinceLabel {
    final value = memberSince;
    if (value == null) return 'New';
    return value.year.toString();
  }

  static String _initials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((value) => value.trim().isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'ZS';
    return parts.map((value) => value[0].toUpperCase()).join();
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
