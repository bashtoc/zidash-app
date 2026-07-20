import 'package:flutter/material.dart';

import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _primarySoft = Color(0xFFEFF9EF);
const _ink = Color(0xFF1C1F1C);
const _muted = Color(0xFF8A8F8A);

class BecomeCreatorScreen extends StatefulWidget {
  const BecomeCreatorScreen({super.key});

  @override
  State<BecomeCreatorScreen> createState() => _BecomeCreatorScreenState();
}

class _BecomeCreatorScreenState extends State<BecomeCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _nichesController = TextEditingController(text: 'Fashion, Tech');
  final _followersController = TextEditingController();
  final _engagementController = TextEditingController();
  final _portfolioController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bioController.dispose();
    _nichesController.dispose();
    _followersController.dispose();
    _engagementController.dispose();
    _portfolioController.dispose();
    super.dispose();
  }

  List<String> get _niches => _nichesController.text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ApiService.instance.becomeCreator({
        'bio': _bioController.text.trim(),
        'niches': _niches,
        if (_followersController.text.trim().isNotEmpty)
          'followersCount': int.parse(_followersController.text.trim()),
        if (_engagementController.text.trim().isNotEmpty)
          'engagementRate': double.parse(_engagementController.text.trim()),
        'pricingPackages': [
          {'name': 'Starter UGC Video', 'price': 50000, 'currency': 'NGN'},
        ],
        if (_portfolioController.text.trim().isNotEmpty)
          'portfolioUrl': _portfolioController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creator profile created')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
        title: const Text(
          'Become a creator',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _introBanner(),
            const SizedBox(height: 24),
            _sectionLabel('About you'),
            const SizedBox(height: 10),
            _card(
              child: _field(
                _bioController,
                label: 'Creator bio',
                hint: 'Tell brands what you create and who you reach…',
                minLines: 4,
              ),
            ),
            const SizedBox(height: 26),
            _sectionLabel('Niches'),
            const SizedBox(height: 10),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(
                    _nichesController,
                    label: 'Niches',
                    hint: 'Comma separated, e.g. Fashion, Tech',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ListenableBuilder(
              listenable: _nichesController,
              builder: (context, _) {
                if (_niches.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _niches.map(_nichePreviewChip).toList(),
                );
              },
            ),
            const SizedBox(height: 26),
            _sectionLabel('Audience', trailing: 'Optional'),
            const SizedBox(height: 10),
            _card(
              child: Row(
                children: [
                  Expanded(
                    child: _field(
                      _followersController,
                      label: 'Followers',
                      hint: '0',
                      keyboardType: TextInputType.number,
                      requiredField: false,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: const Color(0xFFF0F1F0),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  Expanded(
                    child: _field(
                      _engagementController,
                      label: 'Engagement %',
                      hint: '0',
                      keyboardType: TextInputType.number,
                      requiredField: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            _sectionLabel('Portfolio', trailing: 'Optional'),
            const SizedBox(height: 10),
            _card(
              child: _field(
                _portfolioController,
                label: 'Portfolio URL',
                hint: 'Link to your videos or social profile',
                requiredField: false,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _submitBar(),
    );
  }

  // ---- Intro banner -------------------------------------------------------

  Widget _introBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primarySoft, Colors.white],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5F1E5)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.stars_rounded, color: _primaryColor, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Get discovered by brands looking for creators like you to make UGC content',
              style: TextStyle(
                color: _ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
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

  Widget _nichePreviewChip(String niche) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        niche,
        style: const TextStyle(
          color: _primaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }

  // ---- Fields ---------------------------------------------------------

  Widget _field(
      TextEditingController controller, {
        required String label,
        String? hint,
        int minLines = 1,
        TextInputType? keyboardType,
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
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w400),
          labelStyle: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
        ),
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
                : const Text(
              'Create creator profile',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
            ),
          ),
        ),
      ),
    );
  }
}