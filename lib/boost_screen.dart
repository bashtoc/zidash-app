import 'package:flutter/material.dart';

import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6FBF6);

// ─── Boost plan data ───────────────────────────────────────────────────────────
class _BoostPlan {
  const _BoostPlan({
    required this.label,
    required this.days,
    required this.price,
    required this.tag,
    required this.icon,
    required this.description,
  });

  final String label;
  final int days;
  final int price; // NGN
  final String tag;
  final IconData icon;
  final String description;
}

const _plans = [
  _BoostPlan(
    label: '3-Day Boost',
    days: 3,
    price: 1500,
    tag: 'Quick Spark',
    icon: Icons.bolt_outlined,
    description: 'Get noticed fast — appear in top listings for 3 days.',
  ),
  _BoostPlan(
    label: '7-Day Boost',
    days: 7,
    price: 3000,
    tag: 'Popular',
    icon: Icons.local_fire_department_outlined,
    description: 'A full week of premium placement for maximum reach.',
  ),
  _BoostPlan(
    label: '14-Day Boost',
    days: 14,
    price: 5500,
    tag: 'Best Value',
    icon: Icons.rocket_launch_outlined,
    description: '2 weeks at the top — more views, more buyers, faster sales.',
  ),
  _BoostPlan(
    label: '30-Day Boost',
    days: 30,
    price: 9000,
    tag: 'Power Seller',
    icon: Icons.workspace_premium_outlined,
    description: 'Dominate search for a full month. Perfect for high-value items.',
  ),
];

// ─── Listing model (lightweight) ──────────────────────────────────────────────
class _BoostListing {
  const _BoostListing({
    required this.id,
    required this.title,
    required this.rawPrice,
    required this.category,
    this.imageUrl,
    this.isBoosted = false,
  });

  final String id;
  final String title;
  final String rawPrice;
  final String category;
  final String? imageUrl;
  final bool isBoosted;

  String get priceLabel {
    final amount = double.tryParse(rawPrice);
    if (amount == null) return rawPrice;
    return '₦${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
  }

  factory _BoostListing.fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    final firstImage = images is List && images.isNotEmpty
        ? (images.first as Map).cast<String, dynamic>()
        : null;
    final category =
        (json['category'] as Map?)?.cast<String, dynamic>()['name']?.toString() ??
            json['categoryName']?.toString() ??
            '';
    final promoted = DateTime.tryParse(json['promotedUntil']?.toString() ?? '');
    return _BoostListing(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      rawPrice: json['price']?.toString() ?? '0',
      category: category,
      imageUrl: firstImage?['url']?.toString(),
      isBoosted: promoted != null && promoted.isAfter(DateTime.now()),
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class BoostScreen extends StatefulWidget {
  const BoostScreen({super.key});

  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen>
    with SingleTickerProviderStateMixin {
  // steps: 0 = pick listing  |  1 = pick plan  |  2 = review & pay
  int _step = 0;
  _BoostListing? _selectedListing;
  _BoostPlan? _selectedPlan;
  bool _isProcessing = false;

  late Future<List<_BoostListing>> _listingsFuture;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _listingsFuture = _loadListings();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<List<_BoostListing>> _loadListings() async {
    final results = await Future.wait([
      ApiService.instance.myListings(status: 'listed'),
      ApiService.instance.myListings(status: 'active'),
    ]);
    final all = [...results[0], ...results[1]];
    return all
        .map((item) => _BoostListing.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  void _goStep(int step) {
    _animController.reverse().then((_) {
      setState(() => _step = step);
      _animController.forward();
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      _goStep(_step - 1);
    }
  }

  Future<void> _confirmBoost() async {
    if (_selectedListing == null || _selectedPlan == null) return;
    setState(() => _isProcessing = true);
    try {
      await ApiService.instance.boostMyListing(_selectedListing!.id);
      if (!mounted) return;
      _showSuccessSheet();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _SuccessSheet(
        listing: _selectedListing!,
        plan: _selectedPlan!,
        onDone: () {
          Navigator.pop(context); // close sheet
          Navigator.pop(context); // close boost screen
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AppBar(step: _step, onBack: _back),
            _StepIndicator(step: _step),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: switch (_step) {
                  0 => _StepPickListing(
                      future: _listingsFuture,
                      onRetry: () =>
                          setState(() => _listingsFuture = _loadListings()),
                      selected: _selectedListing,
                      onSelect: (listing) {
                        setState(() => _selectedListing = listing);
                        _goStep(1);
                      },
                    ),
                  1 => _StepPickPlan(
                      listing: _selectedListing!,
                      selected: _selectedPlan,
                      onSelect: (plan) {
                        setState(() => _selectedPlan = plan);
                        _goStep(2);
                      },
                    ),
                  _ => _StepReview(
                      listing: _selectedListing!,
                      plan: _selectedPlan!,
                      isProcessing: _isProcessing,
                      onConfirm: _confirmBoost,
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── App bar ──────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  const _AppBar({required this.step, required this.onBack});

  final int step;
  final VoidCallback onBack;

  static const _titles = [
    'Select a listing',
    'Choose boost plan',
    'Review & Pay',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
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
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _titles[step.clamp(0, 2)],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rocket_launch_rounded, color: _primaryColor, size: 14),
                const SizedBox(width: 4),
                const Text(
                  'Boost',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step indicator dots ───────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final isActive = i == step;
          final isDone = i < step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isDone || isActive ? _primaryColor : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Step 0: Pick listing ─────────────────────────────────────────────────────
class _StepPickListing extends StatelessWidget {
  const _StepPickListing({
    required this.future,
    required this.onRetry,
    required this.selected,
    required this.onSelect,
  });

  final Future<List<_BoostListing>> future;
  final VoidCallback onRetry;
  final _BoostListing? selected;
  final ValueChanged<_BoostListing> onSelect;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_BoostListing>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryColor),
          );
        }
        if (snapshot.hasError) {
          return _centeredError(
            'Could not load your listings',
            snapshot.error.toString(),
            onRetry,
          );
        }
        final listings = snapshot.data ?? [];
        if (listings.isEmpty) {
          return _centeredError(
            'No listings to boost',
            'Publish at least one listing before boosting.',
            onRetry,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          itemCount: listings.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _ListingTile(
            listing: listings[i],
            isSelected: listings[i].id == selected?.id,
            onTap: () => onSelect(listings[i]),
          ),
        );
      },
    );
  }

  Widget _centeredError(String title, String subtitle, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, color: _muted, size: 42),
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
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _primaryColor),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingTile extends StatelessWidget {
  const _ListingTile({
    required this.listing,
    required this.isSelected,
    required this.onTap,
  });

  final _BoostListing listing;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: listing.isBoosted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _primaryColor : const Color(0xFFE9EDE9),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 70,
                height: 70,
                color: _surface,
                child: listing.imageUrl == null
                    ? const Icon(Icons.image_outlined, color: _muted)
                    : Image.network(listing.imageUrl!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: listing.isBoosted ? _muted : _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.priceLabel,
                    style: const TextStyle(
                      color: _primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (listing.category.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      listing.category,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (listing.isBoosted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Active boost',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? _primaryColor : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 1: Pick plan ────────────────────────────────────────────────────────
class _StepPickPlan extends StatelessWidget {
  const _StepPickPlan({
    required this.listing,
    required this.selected,
    required this.onSelect,
  });

  final _BoostListing listing;
  final _BoostPlan? selected;
  final ValueChanged<_BoostPlan> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // Listing summary chip
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: _primaryColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  listing.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                listing.priceLabel,
                style: const TextStyle(
                  color: _primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Choose a boost plan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your listing will appear at the top of search results for the selected duration.',
          style: TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w600, height: 1.4),
        ),
        const SizedBox(height: 16),
        ..._plans.map(
          (plan) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlanCard(
              plan: plan,
              isSelected: plan.days == selected?.days,
              onTap: () => onSelect(plan),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  final _BoostPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBestValue = plan.tag == 'Best Value';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _primaryColor : const Color(0xFFE9EDE9),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : _primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                plan.icon,
                color: isSelected ? Colors.white : _primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : _ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.22)
                              : isBestValue
                                  ? Colors.orange.withValues(alpha: 0.12)
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          plan.tag,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? Colors.white
                                : isBestValue
                                    ? Colors.orange
                                    : _muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plan.description,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.82)
                          : _muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₦${plan.price.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : _ink,
                  ),
                ),
                Text(
                  '${plan.days} days',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.7)
                        : _muted,
                    fontWeight: FontWeight.w700,
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

// ─── Step 2: Review & Pay ─────────────────────────────────────────────────────
class _StepReview extends StatelessWidget {
  const _StepReview({
    required this.listing,
    required this.plan,
    required this.isProcessing,
    required this.onConfirm,
  });

  final _BoostListing listing;
  final _BoostPlan plan;
  final bool isProcessing;
  final VoidCallback onConfirm;

  String _formatNgn(int amount) {
    return '₦${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
  }

  @override
  Widget build(BuildContext context) {
    const vatRate = 0.075;
    final vat = (plan.price * vatRate).round();
    final total = plan.price + vat;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF172317), Color(0xFF2A4228)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(plan.icon, color: _primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${plan.days} days • ${plan.tag}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatNgn(plan.price),
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        color: Colors.white.withValues(alpha: 0.08),
                        child: listing.imageUrl == null
                            ? const Icon(Icons.image_outlined, color: _muted)
                            : Image.network(listing.imageUrl!, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            listing.priceLabel,
                            style: const TextStyle(
                              color: _primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // What you get section
          const Text(
            'What you get',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          ...[
            (Icons.trending_up_rounded, 'Top placement in search results'),
            (Icons.visibility_rounded, 'Up to 10× more views'),
            (Icons.notifications_active_outlined, 'Buyer alerts for your listing'),
            (Icons.verified_outlined, '"Boosted" badge on your item'),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.$1, color: _primaryColor, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Price breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _priceRow('Boost fee', _formatNgn(plan.price)),
                const SizedBox(height: 8),
                _priceRow('VAT (7.5%)', _formatNgn(vat)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
                _priceRow('Total', _formatNgn(total), isTotal: true),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Payment options label
          const Text(
            'Payment method',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          _paymentOption(
            icon: Icons.credit_card_rounded,
            label: 'Card / Bank transfer',
            subtitle: 'Pay securely with Paystack',
            isSelected: true,
          ),
          const SizedBox(height: 8),
          _paymentOption(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Zidash Wallet',
            subtitle: 'Use your in-app balance',
            isSelected: false,
          ),

          const SizedBox(height: 32),

          // Confirm button
          SafeArea(
            minimum: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: isProcessing ? null : onConfirm,
                icon: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.lock_outline_rounded, size: 18),
                label: Text(
                  isProcessing ? 'Processing...' : 'Pay ${_formatNgn(total)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Center(
            child: Text(
              '🔒  Payments are secured by Paystack',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            color: isTotal ? _ink : _muted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 17 : 13,
            fontWeight: FontWeight.w900,
            color: isTotal ? _ink : _ink,
          ),
        ),
      ],
    );
  }

  Widget _paymentOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? _primaryColor : const Color(0xFFE9EDE9),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? _primaryColor.withValues(alpha: 0.1)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isSelected ? _primaryColor : _muted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? _ink : _muted,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? _primaryColor : Colors.transparent,
              border: Border.all(
                color: isSelected ? _primaryColor : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}

// ─── Success bottom sheet ─────────────────────────────────────────────────────
class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({
    required this.listing,
    required this.plan,
    required this.onDone,
  });

  final _BoostListing listing;
  final _BoostPlan plan;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F8E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: _primaryColor,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Boost activated! 🚀',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${listing.title} is now boosted for ${plan.days} days. Sit back and watch the views roll in!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _muted,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
