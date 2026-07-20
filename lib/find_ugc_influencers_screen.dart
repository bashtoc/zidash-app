import 'dart:convert';

import 'package:flutter/material.dart';

import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6F7F6);

class FindUgcInfluencersScreen extends StatefulWidget {
  const FindUgcInfluencersScreen({super.key});

  @override
  State<FindUgcInfluencersScreen> createState() =>
      _FindUgcInfluencersScreenState();
}

class _FindUgcInfluencersScreenState extends State<FindUgcInfluencersScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<dynamic>> _creatorsFuture;
  String _selectedNiche = 'All';

  @override
  void initState() {
    super.initState();
    _creatorsFuture = ApiService.instance.creators();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _creatorsFuture = ApiService.instance.creators();
    });
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
          'Find UGC Influencers',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: () async {
          _refresh();
          await _creatorsFuture;
        },
        child: FutureBuilder<List<dynamic>>(
          future: _creatorsFuture,
          builder: (context, snapshot) {
            final creators = (snapshot.data ?? [])
                .whereType<Map>()
                .map(
                  (item) => _CreatorItem.fromJson(item.cast<String, dynamic>()),
                )
                .where((creator) => creator.isAvailable)
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _searchBox(),
                const SizedBox(height: 14),
                _nicheFilters(creators),
                const SizedBox(height: 22),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: CircularProgressIndicator(color: _primaryColor),
                    ),
                  )
                else if (snapshot.hasError)
                  _errorState(snapshot.error)
                else
                  _creatorResults(creators),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      decoration: _cardDecoration(18),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search niche, bio, or creator',
          hintStyle: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: _muted),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, color: _muted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _nicheFilters(List<_CreatorItem> creators) {
    final niches = <String>{'All'};
    for (final creator in creators) {
      niches.addAll(creator.niches);
    }
    final values = niches.toList();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = values[index];
          final selected = value == _selectedNiche;
          return ChoiceChip(
            selected: selected,
            label: Text(value),
            onSelected: (_) => setState(() => _selectedNiche = value),
            selectedColor: _primaryColor,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? _primaryColor
                  : Colors.black.withValues(alpha: 0.06),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _ink,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }

  Widget _creatorResults(List<_CreatorItem> creators) {
    final filtered = _filteredCreators(creators);
    if (filtered.isEmpty) return _emptyState();
    return Column(children: filtered.map(_creatorCard).toList());
  }

  List<_CreatorItem> _filteredCreators(List<_CreatorItem> creators) {
    final query = _searchController.text.trim().toLowerCase();
    return creators.where((creator) {
      final matchesNiche =
          _selectedNiche == 'All' || creator.niches.contains(_selectedNiche);
      if (!matchesNiche) return false;
      if (query.isEmpty) return true;
      return [
        creator.displayName,
        creator.bio,
        creator.niches.join(' '),
        creator.portfolio.map((item) => item.title).join(' '),
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  Widget _creatorCard(_CreatorItem creator) {
    return InkWell(
      onTap: () => _showCreatorDetails(creator),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: _primaryColor.withValues(alpha: 0.14),
                  child: Text(
                    creator.initials,
                    style: const TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creator.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        creator.audienceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Available',
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (creator.bio.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                creator.bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  height: 1.38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: creator.niches.take(4).map(_nichePill).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _metric(Icons.groups_outlined, creator.followersLabel),
                const SizedBox(width: 8),
                _metric(Icons.trending_up_rounded, creator.engagementLabel),
                const Spacer(),
                const Text(
                  'View profile',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, color: _ink, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _nichePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _muted, size: 15),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  void _showCreatorDetails(_CreatorItem creator) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: _primaryColor.withValues(alpha: 0.14),
                      child: Text(
                        creator.initials,
                        style: const TextStyle(
                          color: _primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            creator.displayName,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            creator.audienceLabel,
                            style: const TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: creator.niches.map(_nichePill).toList(),
                ),
                if (creator.bio.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'About creator',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    creator.bio,
                    style: const TextStyle(
                      color: _ink,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (creator.pricingPackages.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'Packages',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...creator.pricingPackages.map(_packageTile),
                ],
                if (creator.portfolio.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'Portfolio',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...creator.portfolio.map(_portfolioTile),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Creator campaign request flow is not live yet.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Request campaign'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _packageTile(_CreatorPackage package) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: _primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              package.name,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            package.priceLabel,
            style: const TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _portfolioTile(_PortfolioItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            item.mediaType == 'image'
                ? Icons.image_outlined
                : Icons.play_circle_outline_rounded,
            color: _primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.mediaUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(Object? error) {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: _muted, size: 42),
          const SizedBox(height: 12),
          Text(
            error?.toString() ?? 'Could not load creators',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _refresh,
            style: FilledButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.person_search_rounded, color: _muted, size: 44),
          SizedBox(height: 12),
          Text(
            'No UGC creators match your search.',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
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
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

class _CreatorItem {
  const _CreatorItem({
    required this.id,
    required this.displayName,
    required this.bio,
    required this.niches,
    required this.followersCount,
    required this.engagementRate,
    required this.pricingPackages,
    required this.portfolio,
    required this.isAvailable,
  });

  final String id;
  final String displayName;
  final String bio;
  final List<String> niches;
  final int followersCount;
  final double engagementRate;
  final List<_CreatorPackage> pricingPackages;
  final List<_PortfolioItem> portfolio;
  final bool isAvailable;

  factory _CreatorItem.fromJson(Map<String, dynamic> json) {
    final niches = _stringList(json['niches']);
    final portfolio = _listValue(json['portfolio'])
        .whereType<Map>()
        .map((item) => _PortfolioItem.fromJson(item.cast<String, dynamic>()))
        .toList();
    final packages = _listValue(json['pricingPackages'])
        .whereType<Map>()
        .map((item) => _CreatorPackage.fromJson(item.cast<String, dynamic>()))
        .toList();
    return _CreatorItem(
      id: json['id']?.toString() ?? '',
      displayName: _displayName(json, niches),
      bio: json['bio']?.toString() ?? '',
      niches: niches.isEmpty ? const ['UGC'] : niches,
      followersCount: _intValue(json['followersCount']),
      engagementRate: _doubleValue(json['engagementRate']),
      pricingPackages: packages,
      portfolio: portfolio,
      isAvailable: json['isAvailable'] != false,
    );
  }

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((value) => value.trim().isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'UG';
    return parts.map((value) => value[0].toUpperCase()).join();
  }

  String get audienceLabel {
    return '$followersLabel followers • $engagementLabel engagement';
  }

  String get followersLabel {
    if (followersCount >= 1000000) {
      return '${(followersCount / 1000000).toStringAsFixed(1)}M';
    }
    if (followersCount >= 1000) {
      return '${(followersCount / 1000).toStringAsFixed(1)}k';
    }
    return followersCount.toString();
  }

  String get engagementLabel => '${engagementRate.toStringAsFixed(1)}%';

  static String _displayName(Map<String, dynamic> json, List<String> niches) {
    final id = json['id']?.toString();
    final suffix = id == null || id.length < 4 ? '' : ' ${id.substring(0, 4)}';
    final niche = niches.isEmpty ? 'UGC' : niches.first;
    return '$niche Creator$suffix';
  }

  static List<String> _stringList(dynamic value) {
    return _listValue(value)
        .map((item) => item?.toString().trim())
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<dynamic> _listValue(dynamic value) {
    if (value is List) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _CreatorPackage {
  const _CreatorPackage({
    required this.name,
    required this.price,
    required this.currency,
  });

  final String name;
  final num price;
  final String currency;

  factory _CreatorPackage.fromJson(Map<String, dynamic> json) {
    return _CreatorPackage(
      name: json['name']?.toString() ?? 'UGC package',
      price: num.tryParse(json['price']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'NGN',
    );
  }

  String get priceLabel {
    final formatted = price
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    return currency == 'NGN' ? '₦$formatted' : '$currency $formatted';
  }
}

class _PortfolioItem {
  const _PortfolioItem({
    required this.title,
    required this.mediaUrl,
    required this.mediaType,
  });

  final String title;
  final String mediaUrl;
  final String mediaType;

  factory _PortfolioItem.fromJson(Map<String, dynamic> json) {
    return _PortfolioItem(
      title: json['title']?.toString() ?? 'Portfolio sample',
      mediaUrl: json['mediaUrl']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? 'video',
    );
  }
}
