import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'promotion_payment_screen.dart';
import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _primarySoft = Color(0xFFF1FAF1);
const _ink = Color(0xFF1C1F1C);
const _muted = Color(0xFF8A8F8A);

enum _SellStep { category, subcategory, details }

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _tagsController = TextEditingController();
  final _locationController = TextEditingController(text: 'Lagos, NG');
  final ImagePicker _imagePicker = ImagePicker();
  final List<_SelectedImage> _images = [];

  _SellStep _step = _SellStep.category;
  _SellCategory? _selectedCategory;
  String? _selectedSubcategory;
  String _condition = 'used';
  _PromotionPlan _promotionPlan = _PromotionPlan.none;
  bool _isNegotiable = true;
  bool _isSubmitting = false;
  bool _isProcessingImages = false;

  static const _categories = [
    _SellCategory(
      name: 'Cars',
      icon: 'assets/images/3d_car.png',
      subcategories: [
        'Cars',
        'Buses',
        'Trucks',
        'Motorcycles',
        'Vehicle Parts',
      ],
    ),
    _SellCategory(
      name: 'Furniture',
      icon: 'assets/images/3d_furniture.png',
      subcategories: ['Sofas', 'Beds', 'Tables', 'Chairs', 'Cabinets'],
    ),
    _SellCategory(
      name: 'Phones',
      icon: 'assets/images/3d_phone.png',
      subcategories: [
        'Smartphones',
        'Tablets',
        'Accessories',
        'Smart Watches',
        'Phone Parts',
      ],
    ),
    _SellCategory(
      name: 'Electronics',
      icon: 'assets/images/3d_electronics.png',
      subcategories: ['Laptops', 'TVs', 'Audio', 'Cameras', 'Gaming'],
    ),
    _SellCategory(
      name: 'Fashion',
      icon: 'assets/images/3d_fashion.png',
      subcategories: ['Men', 'Women', 'Shoes', 'Bags', 'Jewelry'],
    ),
    _SellCategory(
      name: 'Real Estate',
      icon: 'assets/images/3d_realestate.png',
      subcategories: [
        'Apartments',
        'Houses',
        'Land',
        'Short Lets',
        'Commercial',
      ],
    ),
    _SellCategory(
      name: 'Household Items',
      icon: 'assets/images/3d_household.png',
      subcategories: ['Kitchen', 'Appliances', 'Decor', 'Cleaning', 'Storage'],
    ),
    _SellCategory(
      name: 'Services',
      icon: 'assets/images/3d_services.png',
      subcategories: [
        'Repairs',
        'Beauty',
        'Events',
        'Logistics',
        'Professional Services',
      ],
    ),
  ];

  static const _conditions = [
    ('new', 'New'),
    ('like_new', 'Like New'),
    ('used', 'Used'),
    ('refurbished', 'Refurbished'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _tagsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _selectCategory(_SellCategory category) {
    setState(() {
      _selectedCategory = category;
      _selectedSubcategory = null;
      _step = _SellStep.subcategory;
    });
  }

  void _selectSubcategory(String subcategory) {
    setState(() {
      _selectedSubcategory = subcategory;
      _step = _SellStep.details;
    });
  }

  void _goBackStep() {
    setState(() {
      if (_step == _SellStep.details) {
        _step = _SellStep.subcategory;
      } else if (_step == _SellStep.subcategory) {
        _step = _SellStep.category;
      }
    });
  }

  Future<void> _pickImages() async {
    if (_isProcessingImages || _images.length >= 8) return;
    setState(() => _isProcessingImages = true);
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 100,
        limit: 8 - _images.length,
      );
      if (picked.isEmpty) return;
      final processed = <_SelectedImage>[];
      for (final image in picked.take(8 - _images.length)) {
        final bytes = await FlutterImageCompress.compressWithFile(
          image.path,
          minWidth: 1600,
          minHeight: 1600,
          quality: 78,
          format: CompressFormat.webp,
          keepExif: false,
        );
        if (bytes == null || bytes.isEmpty) {
          throw ApiException('Could not process ${image.name}');
        }
        processed.add(
          _SelectedImage(
            bytes: Uint8List.fromList(bytes),
            filename:
                '${DateTime.now().millisecondsSinceEpoch}-${processed.length}.webp',
          ),
        );
      }
      if (!mounted) return;
      setState(() => _images.addAll(processed));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isProcessingImages = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedCategory == null || _selectedSubcategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a category and subcategory')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product image')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final imageUrls = await ApiService.instance.uploadImages(
        _images
            .map(
              (image) => UploadFilePayload(
                bytes: image.bytes,
                filename: image.filename,
              ),
            )
            .toList(),
      );
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final listing = await ApiService.instance.createListing({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'category': _selectedCategory!.name,
        'condition': _condition,
        'location': _locationController.text.trim(),
        'imageUrls': imageUrls,
        'metadata': {
          'subcategory': _selectedSubcategory,
          'tags': tags,
          'negotiable': _isNegotiable,
          'promotion': _promotionPlan.metadata,
        },
      });
      if (!mounted) return;
      if (_promotionPlan != _PromotionPlan.none) {
        final listingId = listing['id']?.toString();
        if (listingId == null || listingId.isEmpty) {
          throw ApiException('Listing was created but could not be promoted');
        }
        final paid = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => PromotionPaymentScreen(
              listingId: listingId,
              listingTitle: _titleController.text.trim(),
              days: _promotionPlan.days,
              amount: _promotionPlan.price,
            ),
          ),
        );
        if (!mounted) return;
        if (paid == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Listing submitted for admin review. Promotion payment received.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Listing submitted for admin review. Promotion payment pending.',
              ),
            ),
          );
        }
        _resetFlow();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_successMessage())));
      _resetFlow();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetFlow() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _tagsController.clear();
    _locationController.text = 'Lagos, NG';
    setState(() {
      _images.clear();
      _selectedCategory = null;
      _selectedSubcategory = null;
      _condition = 'used';
      _promotionPlan = _PromotionPlan.none;
      _isNegotiable = true;
      _step = _SellStep.category;
    });
  }

  String _successMessage() {
    return _promotionPlan == _PromotionPlan.none
        ? 'Listing submitted for admin review'
        : 'Listing submitted for admin review with promotion';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: _step == _SellStep.category
            ? null
            : IconButton(
                onPressed: _goBackStep,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
        title: Text(
          _titleForStep(),
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: switch (_step) {
          _SellStep.category => _categoryStep(),
          _SellStep.subcategory => _subcategoryStep(),
          _SellStep.details => _detailsStep(),
        },
      ),
      bottomNavigationBar: _step == _SellStep.details ? _submitBar() : null,
    );
  }

  String _titleForStep() {
    return switch (_step) {
      _SellStep.category => 'Sell an item',
      _SellStep.subcategory => _selectedCategory?.name ?? 'Choose subcategory',
      _SellStep.details => 'Listing details',
    };
  }

  // ---- Steps -------------------------------------------------------------

  Widget _categoryStep() {
    return ListView(
      key: const ValueKey('category-step'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const Text(
          'What are you selling?',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select the category that best matches your item.',
          style: TextStyle(
            color: _muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.12,
          ),
          itemBuilder: (context, index) {
            return _categoryCard(_categories[index]);
          },
        ),
      ],
    );
  }

  Widget _subcategoryStep() {
    final category = _selectedCategory;
    if (category == null) return _categoryStep();

    return ListView(
      key: const ValueKey('subcategory-step'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _categoryIcon(category.icon, size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Choose a more specific type.',
                        style: TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        ...category.subcategories.map(
          (subcategory) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _subcategoryTile(subcategory),
          ),
        ),
      ],
    );
  }

  Widget _detailsStep() {
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('details-step'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _selectionSummary(),
          const SizedBox(height: 24),
          _sectionLabel('Photos', trailing: '${_images.length}/8'),
          const SizedBox(height: 10),
          _imagePickerPanel(),
          const SizedBox(height: 26),
          _sectionLabel('Item details'),
          const SizedBox(height: 10),
          _card(
            child: Column(
              children: [
                _field(
                  _titleController,
                  label: 'Title',
                  hint: 'e.g. iPhone 13 Pro Max 256GB',
                ),
                const _Divider(),
                _field(
                  _descriptionController,
                  label: 'Description',
                  hint: 'Condition, features, reason for selling...',
                  minLines: 4,
                ),
                const _Divider(),
                _field(
                  _tagsController,
                  label: 'Tags',
                  hint: 'apple, 256gb, clean',
                  requiredField: false,
                ),
                const _Divider(),
                _field(
                  _priceController,
                  label: 'Price',
                  hint: '0',
                  keyboardType: TextInputType.number,
                  prefixText: '₦ ',
                ),
                const _Divider(),
                _switchRow(
                  title: 'Negotiable',
                  subtitle: 'Allow buyers to make offers',
                  value: _isNegotiable,
                  onChanged: (value) => setState(() => _isNegotiable = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _sectionLabel('Condition'),
          const SizedBox(height: 10),
          _chipWrap(
            options: _conditions,
            selected: _condition,
            onSelected: (value) => setState(() => _condition = value),
          ),
          const SizedBox(height: 26),
          _sectionLabel('Location'),
          const SizedBox(height: 10),
          _card(
            child: _field(
              _locationController,
              label: 'Location',
              hint: 'City, area',
              icon: Icons.location_on_rounded,
            ),
          ),
          const SizedBox(height: 26),
          _sectionLabel('Promote post'),
          const SizedBox(height: 10),
          _promotionSection(),
        ],
      ),
    );
  }

  // ---- Selection UI ------------------------------------------------------

  Widget _categoryCard(_SellCategory category) {
    return GestureDetector(
      onTap: () => _selectCategory(category),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEDEFED)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _categoryIcon(category.icon),
            const Spacer(),
            Text(
              category.name,
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${category.subcategories.length} subcategories',
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subcategoryTile(String subcategory) {
    return GestureDetector(
      onTap: () => _selectSubcategory(subcategory),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDEFED)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                subcategory,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _selectionSummary() {
    final category = _selectedCategory;
    return _card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (category != null) _categoryIcon(category.icon, size: 48),
            if (category != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${category?.name ?? ''} / ${_selectedSubcategory ?? ''}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Listing category',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _step = _SellStep.category),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryIcon(String assetPath, {double size = 62}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _primarySoft,
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(size * 0.18),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.category_rounded, color: _primaryColor);
        },
      ),
    );
  }

  // ---- Sections -------------------------------------------------------

  Widget _sectionLabel(String text, {String? trailing}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDEFED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: child,
    );
  }

  // ---- Images -----------------------------------------------------------

  Widget _imagePickerPanel() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length + (_images.length < 8 ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == _images.length) {
            return _addImageTile();
          }
          final image = _images[index];
          final isCover = index == 0;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  image.bytes,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              if (isCover)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: _pill('Cover', filled: true),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => setState(() => _images.removeAt(index)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _addImageTile() {
    return GestureDetector(
      onTap: _isProcessingImages ? null : _pickImages,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: _primarySoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _primaryColor.withValues(alpha: 0.35),
            width: 1.4,
          ),
        ),
        child: Center(
          child: _isProcessingImages
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primaryColor,
                  ),
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_rounded,
                      color: _primaryColor,
                      size: 22,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _pill(String text, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? _primaryColor : Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ---- Chips --------------------------------------------------------------

  Widget _chipWrap({
    required List<(String, String)> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final (value, label) = option;
        final isSelected = value == selected;
        return GestureDetector(
          onTap: () => onSelected(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? _primaryColor : const Color(0xFFE4E6E4),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : _ink,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---- Promotion ---------------------------------------------------------

  Widget _promotionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a promotion type for your ad to post it',
          style: TextStyle(
            color: _ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _promotionOption(
          plan: _PromotionPlan.none,
          title: 'No promo',
          priceLabel: 'free',
        ),
        const SizedBox(height: 12),
        _promotionOption(
          plan: _PromotionPlan.top7,
          title: 'TOP promo',
          description:
              'Best choice if you need one fast sale. Your ad will be at the top of search results and get 15X more traffic',
          priceLabel: _PromotionPlan.top7.priceLabel,
          child: Row(
            children: [
              _durationChip(_PromotionPlan.top7),
              const SizedBox(width: 8),
              _durationChip(_PromotionPlan.top30),
            ],
          ),
        ),
      ],
    );
  }

  Widget _promotionOption({
    required _PromotionPlan plan,
    required String title,
    required String priceLabel,
    String? description,
    Widget? child,
  }) {
    final selected = plan == _PromotionPlan.none
        ? _promotionPlan == _PromotionPlan.none
        : _promotionPlan.isTopPromo;
    return InkWell(
      onTap: () => setState(() => _promotionPlan = plan),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _primaryColor : const Color(0xFFE2E4E2),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.018),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  priceLabel,
                  style: TextStyle(
                    color: plan == _PromotionPlan.none ? _ink : _ink,
                    fontSize: plan == _PromotionPlan.none ? 13.5 : 15,
                    fontWeight: plan == _PromotionPlan.none
                        ? FontWeight.w600
                        : FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 14),
              Text(
                description,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (child != null) ...[const SizedBox(height: 14), child],
          ],
        ),
      ),
    );
  }

  Widget _durationChip(_PromotionPlan plan) {
    final selected = _promotionPlan == plan;
    return InkWell(
      onTap: () => setState(() => _promotionPlan = plan),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? _primaryColor.withValues(alpha: 0.18)
              : _primarySoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _primaryColor : const Color(0xFFE3E5E3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: _primaryColor, size: 16),
              const SizedBox(width: 5),
            ],
            Text(
              '${plan.days} days',
              style: const TextStyle(
                color: _ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Fields ---------------------------------------------------------

  Widget _field(
    TextEditingController controller, {
    required String label,
    String? hint,
    IconData? icon,
    int minLines = 1,
    TextInputType? keyboardType,
    String? prefixText,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        minLines: minLines,
        maxLines: minLines == 1 ? 1 : 6,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 15,
          color: _ink,
          fontWeight: FontWeight.w500,
        ),
        validator: (value) {
          if (!requiredField) return null;
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
        decoration: InputDecoration(
          isCollapsed: false,
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w400,
          ),
          labelStyle: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          prefixText: prefixText,
          prefixStyle: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: icon != null ? Icon(icon, color: _muted, size: 20) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
        ),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: _primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ---- Submit bar -------------------------------------------------------

  Widget _submitBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          border: Border(
            top: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
          ),
        ),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _primaryColor.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _promotionPlan == _PromotionPlan.none
                          ? 'Post ad'
                          : 'Buy promo & Post ad (${_promotionPlan.priceLabel})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF0F1F0));
  }
}

class _SellCategory {
  const _SellCategory({
    required this.name,
    required this.icon,
    required this.subcategories,
  });

  final String name;
  final String icon;
  final List<String> subcategories;
}

enum _PromotionPlan {
  none(days: 0, price: 0),
  top7(days: 7, price: 2799),
  top30(days: 30, price: 9999);

  const _PromotionPlan({required this.days, required this.price});

  final int days;
  final int price;

  bool get isTopPromo => this == top7 || this == top30;

  String get priceLabel {
    if (price == 0) return 'free';
    return '₦ ${price.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
  }

  Map<String, dynamic> get metadata {
    return {
      'type': this == none ? 'none' : 'top',
      'days': days,
      'price': price,
      'currency': 'NGN',
    };
  }
}

class _SelectedImage {
  const _SelectedImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}
