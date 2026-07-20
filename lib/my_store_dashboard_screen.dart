import 'package:flutter/material.dart';

import 'my_listings_screen.dart';
import 'sell_screen.dart';
import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6FBF6);

class MyStoreDashboardScreen extends StatefulWidget {
  const MyStoreDashboardScreen({super.key});

  @override
  State<MyStoreDashboardScreen> createState() => _MyStoreDashboardScreenState();
}

class _MyStoreDashboardScreenState extends State<MyStoreDashboardScreen> {
  late Future<_StoreDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDashboard();
  }

  Future<_StoreDashboardData> _loadDashboard() async {
    final results = await Future.wait([
      ApiService.instance.myListings(status: 'listed'),
      ApiService.instance.myListings(status: 'active'),
      ApiService.instance.myListings(status: 'closed'),
    ]);

    return _StoreDashboardData.fromLists(
      listed: results[0],
      active: results[1],
      closed: results[2],
    );
  }

  void _refresh() {
    setState(() {
      _future = _loadDashboard();
    });
  }

  Future<void> _openListings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const MyListingsScreen()));
    _refresh();
  }

  Future<void> _openSellScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SellScreen()));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'My Store',
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: FutureBuilder<_StoreDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          if (snapshot.hasError) {
            return _errorState(snapshot.error.toString());
          }

          final data = snapshot.data ?? _StoreDashboardData.empty();
          return RefreshIndicator(
            color: _primaryColor,
            onRefresh: () async {
              _refresh();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              children: [
                _hero(data),
                const SizedBox(height: 18),
                _metricsGrid(data),
                const SizedBox(height: 22),
                _sectionHeader('Quick actions'),
                const SizedBox(height: 10),
                _quickActions(),
                const SizedBox(height: 24),
                _sectionHeader('Recent listings'),
                const SizedBox(height: 10),
                if (data.recentListings.isEmpty)
                  _emptyListings()
                else
                  ...data.recentListings.map(_recentListingCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hero(_StoreDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white),
          ),
          const SizedBox(height: 18),
          const Text(
            'Store dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.totalListings == 0
                ? 'Publish your first item and start tracking store activity here.'
                : '${data.totalListings} items are currently tracked across your store.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _openSellScreen,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Publish listing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid(_StoreDashboardData data) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.45,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _metricCard(
          'Listed',
          data.listedCount.toString(),
          Icons.inventory_2_outlined,
        ),
        _metricCard(
          'Active',
          data.activeCount.toString(),
          Icons.local_activity_outlined,
        ),
        _metricCard(
          'Closed',
          data.closedCount.toString(),
          Icons.lock_outline_rounded,
        ),
        _metricCard(
          'Boosted',
          data.boostedCount.toString(),
          Icons.bolt_rounded,
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _softDecoration(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: _primaryColor, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionTile(
            icon: Icons.list_alt_rounded,
            title: 'Manage listings',
            subtitle: 'Edit, boost, close',
            onTap: _openListings,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionTile(
            icon: Icons.add_business_rounded,
            title: 'New listing',
            subtitle: 'Add item for sale',
            onTap: _openSellScreen,
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _softDecoration(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _ink, size: 24),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
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

  Widget _recentListingCard(_StoreListing item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDE9)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 64,
              height: 64,
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
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'NGN ${item.price}',
                  style: const TextStyle(
                    color: _primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          _statusPill(item.statusLabel),
        ],
      ),
    );
  }

  Widget _emptyListings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _softDecoration(20),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, color: _muted, size: 34),
          const SizedBox(height: 10),
          const Text(
            'No store activity yet',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your newest listings will appear here once you publish them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _openSellScreen,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create listing'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: _primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _statusPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _primaryColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42, color: _muted),
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
            ElevatedButton(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _softDecoration(double radius) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.045),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _StoreDashboardData {
  const _StoreDashboardData({
    required this.listed,
    required this.active,
    required this.closed,
  });

  final List<_StoreListing> listed;
  final List<_StoreListing> active;
  final List<_StoreListing> closed;

  int get listedCount => listed.length;
  int get activeCount => active.length;
  int get closedCount => closed.length;
  int get totalListings => listedCount + activeCount + closedCount;
  int get boostedCount => allListings.where((item) => item.isBoosted).length;

  List<_StoreListing> get allListings => [...listed, ...active, ...closed];

  List<_StoreListing> get recentListings => allListings.take(4).toList();

  factory _StoreDashboardData.fromLists({
    required List<dynamic> listed,
    required List<dynamic> active,
    required List<dynamic> closed,
  }) {
    return _StoreDashboardData(
      listed: listed.map(_StoreListing.fromDynamic).toList(),
      active: active.map(_StoreListing.fromDynamic).toList(),
      closed: closed.map(_StoreListing.fromDynamic).toList(),
    );
  }

  factory _StoreDashboardData.empty() {
    return const _StoreDashboardData(listed: [], active: [], closed: []);
  }
}

class _StoreListing {
  const _StoreListing({
    required this.title,
    required this.rawPrice,
    required this.status,
    this.imageUrl,
    this.promotedUntil,
  });

  final String title;
  final String rawPrice;
  final String status;
  final String? imageUrl;
  final DateTime? promotedUntil;

  String get price => double.tryParse(rawPrice)?.toStringAsFixed(0) ?? rawPrice;

  String get statusLabel {
    return switch (status) {
      'active' => 'Active',
      'sold' => 'Sold',
      'paused' => 'Paused',
      'draft' => 'Draft',
      _ => 'Listed',
    };
  }

  bool get isBoosted {
    final until = promotedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  factory _StoreListing.fromDynamic(dynamic value) {
    final json = (value as Map).cast<String, dynamic>();
    final images = json['images'];
    final firstImage = images is List && images.isNotEmpty
        ? (images.first as Map).cast<String, dynamic>()
        : null;
    return _StoreListing(
      title: json['title']?.toString() ?? 'Untitled listing',
      rawPrice: json['price']?.toString() ?? '0',
      status: json['status']?.toString() ?? 'listed',
      imageUrl: firstImage?['url']?.toString(),
      promotedUntil: DateTime.tryParse(json['promotedUntil']?.toString() ?? ''),
    );
  }
}
