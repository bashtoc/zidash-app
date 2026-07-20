import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'category_listings_screen.dart';

const _green = Color(0xFF429417);
const _softGreen = Color(0xFFD8EBCB);
const _ink = Color(0xFF050505);
const _muted = Color(0xFF777C77);

class AllCategoriesScreen extends StatelessWidget {
  const AllCategoriesScreen({super.key});

  static const _categories = [
    _CategoryItem(
      name: 'Cars',
      icon: 'assets/images/3d_car.png',
      subcategories: 5,
    ),
    _CategoryItem(
      name: 'Furniture',
      icon: 'assets/images/3d_furniture.png',
      subcategories: 5,
    ),
    _CategoryItem(
      name: 'Phones',
      icon: 'assets/images/3d_phone.png',
      subcategories: 5,
    ),
    _CategoryItem(
      name: 'Electronics',
      icon: 'assets/images/3d_electronics.png',
      subcategories: 5,
    ),
    _CategoryItem(
      name: 'Fashion',
      icon: 'assets/images/3d_fashion.png',
      subcategories: 5,
    ),
    _CategoryItem(
      name: 'Real Estate',
      icon: 'assets/images/3d_realestate.png',
      subcategories: 5,
    ),
    _CategoryItem(
      name: 'Household Items',
      icon: 'assets/images/3d_household.png',
      subcategories: 5,
    ),
    _CategoryItem(
      name: 'Services',
      icon: 'assets/images/3d_services.png',
      subcategories: 5,
    ),
  ];

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
              SliverToBoxAdapter(child: _header(context)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
                sliver: SliverGrid.builder(
                  itemCount: _categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.06,
                  ),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return _CategoryTile(
                      category: category,
                      onTap: () => _openCategory(context, category),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 24, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'All categories',
              style: TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCategory(BuildContext context, _CategoryItem category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CategoryListingsScreen(
          categoryName: category.name,
          categoryIcon: category.icon,
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final _CategoryItem category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: _softGreen,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    category.icon,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.category, color: _green),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                category.name,
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
                '${category.subcategories} subcategories',
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
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.name,
    required this.icon,
    required this.subcategories,
  });

  final String name;
  final String icon;
  final int subcategories;
}
