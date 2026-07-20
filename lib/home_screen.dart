import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'all_categories_screen.dart';
import 'auth_required_dialog.dart';
import 'boost_screen.dart';
import 'category_listings_screen.dart';
import 'preferred_products_screen.dart';
import 'product_detail_screen.dart';
import 'sell_screen.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';

const _green = Color(0xFF429417);
const _softGreen = Color(0xFFD8EBCB);
const _ink = Color(0xFF050505);
const _muted = Color(0xFF777C77);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _listingsFuture;
  final Set<String> _preferredProductIds = {};
  final TextEditingController _searchController = TextEditingController();
  _ListingFilters _filters = const _ListingFilters();
  Timer? _searchDebounce;
  String _currentLocation = '14B Obunanke Street, Lagos, Nigeria';
  bool _checkedLocationPermission = false;
  bool _isUpdatingLocation = false;

  final List<_CategoryItem> _categories = const [
    _CategoryItem('Cars', Icons.directions_car_filled_outlined),
    _CategoryItem('Furniture', Icons.weekend_outlined),
    _CategoryItem('Phones', Icons.phone_iphone_outlined),
    _CategoryItem('Electronics', Icons.laptop_mac_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _listingsFuture = _loadListings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowLocationPermissionPrompt();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadListings() async {
    final items = await ApiService.instance.listings(
      query: _filters.query,
      category: _filters.category,
      condition: _filters.condition,
      minPrice: _filters.minPrice,
      maxPrice: _filters.maxPrice,
      sort: _filters.sort,
    );
    return items
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<void> _refresh() async {
    final refreshedListings = _loadListings();
    setState(() {
      _listingsFuture = refreshedListings;
    });
    await refreshedListings;
  }

  void _reloadListings() {
    setState(() {
      _listingsFuture = _loadListings();
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final query = value.trim();
      if (query == _filters.query) return;
      _filters = _filters.copyWith(query: query);
      _reloadListings();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_filters.query == null) return;
    _filters = _filters.copyWith(query: '');
    _reloadListings();
  }

  Future<void> _openFilters() async {
    final nextFilters = await showModalBottomSheet<_ListingFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ListingFilterSheet(filters: _filters),
    );
    if (nextFilters == null || !mounted) return;
    setState(() {
      _filters = nextFilters.copyWith(query: _searchController.text.trim());
      _listingsFuture = _loadListings();
    });
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _filters = const _ListingFilters();
      _listingsFuture = _loadListings();
    });
  }

  Future<void> _maybeShowLocationPermissionPrompt() async {
    if (_checkedLocationPermission || !mounted) return;
    _checkedLocationPermission = true;
    final permission = await LocationService.instance.permissionStatus();
    debugPrint('[location][home] permission=$permission');
    if (!mounted) return;

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      await _requestAndSaveLocation(showErrors: false);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showLocationPermissionDialog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: _green,
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(context)),
                if (_filters.hasAnyFilter)
                  SliverToBoxAdapter(child: _activeFiltersRow()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _categoriesRow()),
                const SliverToBoxAdapter(child: SizedBox(height: 34)),
                SliverToBoxAdapter(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _listingsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const SizedBox(
                          height: 230,
                          child: Center(
                            child: CircularProgressIndicator(color: _green),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return _inlineState('Could not load listings');
                      }
                      final listings = snapshot.data ?? [];
                      if (listings.isEmpty) {
                        return _inlineState('No listings posted yet');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            'Featured Listings',
                            onSeeAll: () => _openListingsCollection(
                              _ListingsCollectionMode.featured,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _horizontalListings(listings.take(8).toList()),
                          const SizedBox(height: 24),
                          _boostBanner(context),
                          const SizedBox(height: 26),
                          _sectionHeader(
                            'Recently Posted',
                            onSeeAll: () => _openListingsCollection(
                              _ListingsCollectionMode.recent,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _horizontalListings(
                            listings.reversed.take(8).toList(),
                          ),
                          const SizedBox(height: 34),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/zidashlogo.png', height: 36),
              const Spacer(),
              IconButton(
                tooltip: 'Sell',
                onPressed: _openSell,
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Color(0xFF6D716D),
                  size: 26,
                ),
              ),
              IconButton(
                tooltip: 'Preferred products',
                onPressed: _openPreferredProducts,
                icon: const Icon(
                  Icons.favorite_border_rounded,
                  color: Color(0xFF6D716D),
                  size: 31,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(Icons.location_on, size: 15, color: _ink),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _currentLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    onSubmitted: (value) {
                      _searchDebounce?.cancel();
                      _filters = _filters.copyWith(query: value.trim());
                      _reloadListings();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search for items, categories, or sellers',
                      hintStyle: const TextStyle(
                        color: Color(0xFFA0A0A0),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF888C88),
                        size: 22,
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: _clearSearch,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF888C88),
                                size: 18,
                              ),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22.5),
                        borderSide: const BorderSide(color: Color(0xFFE4E4E4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22.5),
                        borderSide: const BorderSide(color: _green),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: _openFilters,
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: const Color(0xFFBDBDBD)),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: _ink,
                        size: 24,
                      ),
                    ),
                    if (_filters.hasStructuredFilters)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: _green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activeFiltersRow() {
    final labels = _filters.labels;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: labels
                    .map(
                      (label) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFFF1F8ED),
                          side: BorderSide.none,
                          label: Text(
                            label,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          TextButton(onPressed: _clearFilters, child: const Text('Clear')),
        ],
      ),
    );
  }

  Widget _categoriesRow() {
    return Container(
      height: 115,
      color: const Color(0xFFFAFCF8),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ..._categories.map(
            (item) => _categoryButton(
              item,
              onTap: () => _openCategory(item.label, item.icon),
            ),
          ),
          _categoryButton(
            const _CategoryItem('See all', Icons.more_horiz_rounded),
            onTap: _openAllCategories,
          ),
        ],
      ),
    );
  }

  Widget _categoryButton(_CategoryItem item, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: _softGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: _green, size: 29),
            ),
            const SizedBox(height: 9),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCategory(String label, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CategoryListingsScreen(
          categoryName: label,
          categoryIcon: 'assets/images/3d_all.png',
        ),
      ),
    );
  }

  void _openAllCategories() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AllCategoriesScreen()),
    );
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: const BoxDecoration(
                    color: _softGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: _green,
                    size: 31,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Use your location?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Allow Zidash to collect your location so we can show nearby listings and save your marketplace location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _requestAndSaveLocation();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Allow Location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Not now',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestAndSaveLocation({bool showErrors = true}) async {
    if (_isUpdatingLocation) return;
    setState(() => _isUpdatingLocation = true);
    try {
      debugPrint('[location][home] requesting current location');
      final result = await LocationService.instance.requestCurrentLocation();
      if (!mounted) return;
      debugPrint('[location][home] resolved location=${result.location}');
      setState(() => _currentLocation = result.location);

      await ApiService.instance.loadSession();
      if (ApiService.instance.isAuthenticated) {
        debugPrint('[location][home] saving location to backend');
        await ApiService.instance.updateLocation(result.location);
      }
    } catch (error) {
      debugPrint('[location][home] error=$error');
      if (!mounted) return;
      if (showErrors) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingLocation = false);
    }
  }

  Widget _sectionHeader(String title, {required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      color: _green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: _green, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _horizontalListings(List<Map<String, dynamic>> listings) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: listings.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return _ListingCard(
            listing: listings[index],
            isPreferred: _isPreferred(listings[index]),
            onTap: () => _openListing(listings[index]),
            onFavorite: () => _togglePreferred(listings[index]),
          );
        },
      ),
    );
  }

  Widget _boostBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 92,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        decoration: BoxDecoration(
          color: _softGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rocket_launch, color: _green, size: 25),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Boost your product',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Get more views and sell faster',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              height: 39,
              child: FilledButton(
                onPressed: _openBoost,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Boost now',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inlineState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _muted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  bool _isPreferred(Map<String, dynamic> listing) {
    final id = listing['id']?.toString();
    return id != null && _preferredProductIds.contains(id);
  }

  void _openListing(Map<String, dynamic> listing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          listingId: listing['id']?.toString() ?? '',
          initialListing: listing,
        ),
      ),
    );
  }

  void _openListingsCollection(_ListingsCollectionMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            _ListingsCollectionScreen(mode: mode, filters: _filters),
      ),
    );
  }

  Future<void> _openSell() async {
    final allowed = await requireAuthenticated(
      context,
      title: 'Sign up to sell an item',
      message:
          'Create an account to upload items, manage listings, and receive buyer messages.',
    );
    if (!allowed || !mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SellScreen()));
  }

  Future<void> _openPreferredProducts() async {
    final allowed = await requireAuthenticated(
      context,
      title: 'Sign up to view saved products',
      message:
          'Create an account to save preferred products and access them across devices.',
    );
    if (!allowed || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PreferredProductsScreen()),
    );
  }

  Future<void> _openBoost() async {
    final allowed = await requireAuthenticated(
      context,
      title: 'Sign up to boost products',
      message:
          'Create an account to promote your listings and track their performance.',
    );
    if (!allowed || !mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const BoostScreen()));
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
    if (!_isBackendListingId(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product is not available to save.')),
      );
      return;
    }
    final listingId = id!;
    try {
      final result = await ApiService.instance.togglePreferredProduct(
        listingId,
      );
      if (!mounted) return;
      final saved = result['saved'] == true;
      setState(() {
        if (saved) {
          _preferredProductIds.add(listingId);
        } else {
          _preferredProductIds.remove(listingId);
        }
      });
    } catch (error) {
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
}

enum _ListingsCollectionMode { featured, recent }

class _ListingsCollectionScreen extends StatefulWidget {
  const _ListingsCollectionScreen({required this.mode, required this.filters});

  final _ListingsCollectionMode mode;
  final _ListingFilters filters;

  @override
  State<_ListingsCollectionScreen> createState() =>
      _ListingsCollectionScreenState();
}

class _ListingsCollectionScreenState extends State<_ListingsCollectionScreen> {
  late Future<List<Map<String, dynamic>>> _listingsFuture;
  final Set<String> _preferredProductIds = {};

  String get _title => switch (widget.mode) {
    _ListingsCollectionMode.featured => 'Featured Listings',
    _ListingsCollectionMode.recent => 'Recently Posted',
  };

  @override
  void initState() {
    super.initState();
    _listingsFuture = _loadListings();
  }

  Future<List<Map<String, dynamic>>> _loadListings() async {
    final items = await ApiService.instance.listings(
      query: widget.filters.query,
      category: widget.filters.category,
      condition: widget.filters.condition,
      minPrice: widget.filters.minPrice,
      maxPrice: widget.filters.maxPrice,
      sort: widget.filters.sort,
    );
    final listings = items
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (widget.mode == _ListingsCollectionMode.recent) {
      return listings.reversed.toList();
    }
    listings.sort((a, b) {
      final promotedA = DateTime.tryParse(a['promotedUntil']?.toString() ?? '');
      final promotedB = DateTime.tryParse(b['promotedUntil']?.toString() ?? '');
      final aActive =
          promotedA != null && promotedA.isAfter(DateTime.now().toUtc());
      final bActive =
          promotedB != null && promotedB.isAfter(DateTime.now().toUtc());
      if (aActive != bActive) return aActive ? -1 : 1;
      return _dateValue(b['createdAt']).compareTo(_dateValue(a['createdAt']));
    });
    return listings;
  }

  Future<void> _refresh() async {
    final refreshedListings = _loadListings();
    setState(() {
      _listingsFuture = refreshedListings;
    });
    await refreshedListings;
  }

  void _openListing(Map<String, dynamic> listing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          listingId: listing['id']?.toString() ?? '',
          initialListing: listing,
        ),
      ),
    );
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
    if (!_isBackendListingId(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product is not available to save.')),
      );
      return;
    }
    final listingId = id!;
    try {
      final result = await ApiService.instance.togglePreferredProduct(
        listingId,
      );
      if (!mounted) return;
      final saved = result['saved'] == true;
      setState(() {
        if (saved) {
          _preferredProductIds.add(listingId);
        } else {
          _preferredProductIds.remove(listingId);
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  bool _isPreferred(Map<String, dynamic> listing) {
    final id = listing['id']?.toString();
    return id != null && _preferredProductIds.contains(id);
  }

  bool _isBackendListingId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8F7),
        surfaceTintColor: const Color(0xFFF7F8F7),
        title: Text(
          _title,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _listingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }
          if (snapshot.hasError) {
            return _collectionState(
              'Could not load listings',
              action: _refresh,
            );
          }
          final listings = snapshot.data ?? [];
          if (listings.isEmpty) {
            return _collectionState('No listings found', action: _refresh);
          }
          return RefreshIndicator(
            color: _green,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemBuilder: (context, index) {
                final listing = listings[index];
                return _ListingRow(
                  listing: listing,
                  isPreferred: _isPreferred(listing),
                  onTap: () => _openListing(listing),
                  onFavorite: () => _togglePreferred(listing),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: listings.length,
            ),
          );
        },
      ),
    );
  }

  Widget _collectionState(
    String message, {
    required Future<void> Function() action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, color: _muted, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: action,
              style: FilledButton.styleFrom(backgroundColor: _green),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime _dateValue(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime(1970);
  }
}

class _ListingFilters {
  const _ListingFilters({
    this.query,
    this.category,
    this.condition,
    this.minPrice,
    this.maxPrice,
    this.sort,
  });

  final String? query;
  final String? category;
  final String? condition;
  final num? minPrice;
  final num? maxPrice;
  final String? sort;

  bool get hasStructuredFilters =>
      _hasText(category) ||
      _hasText(condition) ||
      minPrice != null ||
      maxPrice != null ||
      _hasText(sort);

  bool get hasAnyFilter => _hasText(query) || hasStructuredFilters;

  List<String> get labels {
    final values = <String>[];
    if (_hasText(query)) values.add('Search: $query');
    if (_hasText(category)) values.add(category!);
    if (_hasText(condition)) values.add(_conditionLabel(condition));
    if (minPrice != null || maxPrice != null) {
      if (minPrice != null && maxPrice != null) {
        values.add('${_money(minPrice!)} - ${_money(maxPrice!)}');
      } else if (minPrice != null) {
        values.add('From ${_money(minPrice!)}');
      } else {
        values.add('Up to ${_money(maxPrice!)}');
      }
    }
    if (_hasText(sort)) values.add(_sortLabel(sort));
    return values;
  }

  _ListingFilters copyWith({
    String? query,
    String? category,
    String? condition,
    num? minPrice,
    num? maxPrice,
    String? sort,
  }) {
    return _ListingFilters(
      query: _normalizeText(query ?? this.query),
      category: _normalizeText(category ?? this.category),
      condition: _normalizeText(condition ?? this.condition),
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      sort: _normalizeText(sort ?? this.sort),
    );
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
  static String? _normalizeText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _conditionLabel(String? value) {
    return switch (value) {
      'new' => 'New',
      'like_new' => 'Like new',
      'used' => 'Used',
      'refurbished' => 'Refurbished',
      _ => value ?? '',
    };
  }

  static String _sortLabel(String? value) {
    return switch (value) {
      'price_asc' => 'Price low to high',
      'price_desc' => 'Price high to low',
      'oldest' => 'Oldest first',
      _ => 'Newest first',
    };
  }

  static String _money(num value) {
    final formatted = value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    return 'NGN $formatted';
  }
}

class _ListingFilterSheet extends StatefulWidget {
  const _ListingFilterSheet({required this.filters});

  final _ListingFilters filters;

  @override
  State<_ListingFilterSheet> createState() => _ListingFilterSheetState();
}

class _ListingFilterSheetState extends State<_ListingFilterSheet> {
  static const _categories = ['Cars', 'Furniture', 'Phones', 'Electronics'];
  static const _conditions = <String, String>{
    'new': 'New',
    'like_new': 'Like new',
    'used': 'Used',
    'refurbished': 'Refurbished',
  };
  static const _sorts = <String, String>{
    'newest': 'Newest first',
    'price_asc': 'Price low to high',
    'price_desc': 'Price high to low',
    'oldest': 'Oldest first',
  };

  late String? _category = widget.filters.category;
  late String? _condition = widget.filters.condition;
  late String _sort = widget.filters.sort ?? 'newest';
  late final TextEditingController _minPriceController = TextEditingController(
    text: widget.filters.minPrice?.toStringAsFixed(0) ?? '',
  );
  late final TextEditingController _maxPriceController = TextEditingController(
    text: widget.filters.maxPrice?.toStringAsFixed(0) ?? '',
  );

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.of(context).pop(
      _ListingFilters(
        query: widget.filters.query,
        category: _category,
        condition: _condition,
        minPrice: num.tryParse(
          _minPriceController.text.replaceAll(',', '').trim(),
        ),
        maxPrice: num.tryParse(
          _maxPriceController.text.replaceAll(',', '').trim(),
        ),
        sort: _sort == 'newest' ? null : _sort,
      ),
    );
  }

  void _reset() {
    setState(() {
      _category = null;
      _condition = null;
      _sort = 'newest';
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6DCD6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text(
                    'Filter listings',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
              const SizedBox(height: 16),
              _label('Category'),
              const SizedBox(height: 8),
              _choiceWrap(
                values: _categories,
                selected: _category,
                labelFor: (value) => value,
                onSelected: (value) => setState(() {
                  _category = _category == value ? null : value;
                }),
              ),
              const SizedBox(height: 18),
              _label('Condition'),
              const SizedBox(height: 8),
              _choiceWrap(
                values: _conditions.keys.toList(),
                selected: _condition,
                labelFor: (value) => _conditions[value]!,
                onSelected: (value) => setState(() {
                  _condition = _condition == value ? null : value;
                }),
              ),
              const SizedBox(height: 18),
              _label('Price range'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _priceField(_minPriceController, 'Min')),
                  const SizedBox(width: 10),
                  Expanded(child: _priceField(_maxPriceController, 'Max')),
                ],
              ),
              const SizedBox(height: 18),
              _label('Sort'),
              const SizedBox(height: 8),
              _choiceWrap(
                values: _sorts.keys.toList(),
                selected: _sort,
                labelFor: (value) => _sorts[value]!,
                onSelected: (value) => setState(() => _sort = value),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Apply filters',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _ink,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _choiceWrap({
    required List<String> values,
    required String? selected,
    required String Function(String value) labelFor,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final isSelected = selected == value;
        return ChoiceChip(
          selected: isSelected,
          onSelected: (_) => onSelected(value),
          selectedColor: _green,
          backgroundColor: const Color(0xFFF4F6F4),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : _ink,
            fontWeight: FontWeight.w800,
          ),
          side: BorderSide(
            color: isSelected ? _green : const Color(0xFFE1E5E1),
          ),
          label: Text(labelFor(value)),
        );
      }).toList(),
    );
  }

  Widget _priceField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        hintText: hint,
        prefixText: 'NGN ',
        filled: true,
        fillColor: const Color(0xFFF8FAF8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE1E5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE1E5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _green),
        ),
      ),
    );
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

class _ListingRow extends StatelessWidget {
  const _ListingRow({
    required this.listing,
    required this.isPreferred,
    required this.onTap,
    required this.onFavorite,
  });

  final Map<String, dynamic> listing;
  final bool isPreferred;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _ListingCard._imageUrl(listing);
    final seller = (listing['seller'] as Map?)?.cast<String, dynamic>();
    final title = listing['title']?.toString() ?? 'Untitled listing';
    final price = _ListingCard._formatPrice(listing['price']);
    final sellerName = _sellerDisplayName(seller, fallback: 'Zidash Store');
    final location = listing['location']?.toString() ?? 'Lagos, Nigeria';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl == null
                  ? Image.asset(
                      'assets/images/phone.png',
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      imageUrl,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/phone.png',
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _green,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 13,
                        color: _muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: _muted,
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onFavorite,
              icon: Icon(
                isPreferred
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isPreferred ? Colors.red : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.listing,
    required this.isPreferred,
    required this.onTap,
    required this.onFavorite,
  });

  final Map<String, dynamic> listing;
  final bool isPreferred;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl(listing);
    final seller = (listing['seller'] as Map?)?.cast<String, dynamic>();
    final title = listing['title']?.toString() ?? 'Untitled listing';
    final price = _formatPrice(listing['price']);
    final sellerName = _sellerDisplayName(seller, fallback: 'Zidash Store');
    final location = listing['location']?.toString() ?? 'Lagos, Nigeria';
    final views = _viewsLabel(listing['viewsCount']);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 166,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                imageUrl == null
                    ? Image.asset(
                        'assets/images/phone.png',
                        height: 146,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        imageUrl,
                        height: 146,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset(
                              'assets/images/phone.png',
                              height: 146,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                      ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPreferred
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isPreferred ? Colors.red : Colors.black54,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _green,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 6,
                        backgroundColor: Color(0xFFE7F5E1),
                        child: Icon(Icons.storefront, size: 7, color: _green),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Colors.cyan, size: 9),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFF9A9A9A),
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        views,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFF9A9A9A),
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
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

  static String? _imageUrl(Map<String, dynamic> listing) {
    final images = listing['images'];
    if (images is! List || images.isEmpty) return null;
    final first = images.first;
    if (first is! Map) return null;
    return first['url']?.toString();
  }

  static String _formatPrice(dynamic value) {
    final amount = num.tryParse(value?.toString() ?? '');
    if (amount == null) return '₦0';
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '₦$formatted';
  }

  static String _viewsLabel(dynamic value) {
    final views = int.tryParse(value?.toString() ?? '') ?? 0;
    if (views >= 1000) {
      final compact = views / 1000;
      final text = compact >= 10
          ? compact.toStringAsFixed(0)
          : compact.toStringAsFixed(1).replaceFirst('.0', '');
      return '${text}k Views';
    }
    return '$views Views';
  }
}

class _CategoryItem {
  const _CategoryItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
