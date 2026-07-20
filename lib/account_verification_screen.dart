import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7D857D);
const _surface = Color(0xFFF6FBF6);

class AccountVerificationScreen extends StatefulWidget {
  const AccountVerificationScreen({super.key});

  @override
  State<AccountVerificationScreen> createState() =>
      _AccountVerificationScreenState();
}

class _AccountVerificationScreenState extends State<AccountVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  final _notesController = TextEditingController();

  String _documentType = 'national_id';
  _VerificationImage? _selfie;
  _VerificationImage? _frontId;
  _VerificationImage? _backId;
  bool _isProcessing = false;
  bool _isSubmitting = false;

  static const _documentTypes = [
    ('national_id', 'National ID'),
    ('drivers_license', 'Driver license'),
    ('passport', 'Passport'),
    ('voters_card', 'Voter card'),
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(
    _VerificationSlot slot, {
    ImageSource source = ImageSource.gallery,
  }) async {
    if (_isProcessing || _isSubmitting) return;
    setState(() => _isProcessing = true);
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 100);
      if (picked == null) return;

      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 1400,
        minHeight: 1400,
        quality: 80,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (compressed == null || compressed.isEmpty) {
        throw ApiException('Could not process selected image');
      }

      final image = _VerificationImage(
        bytes: Uint8List.fromList(compressed),
        filename: '${slot.name}-${DateTime.now().millisecondsSinceEpoch}.webp',
      );
      if (!mounted) return;
      setState(() {
        switch (slot) {
          case _VerificationSlot.selfie:
            _selfie = image;
          case _VerificationSlot.frontId:
            _frontId = image;
          case _VerificationSlot.backId:
            _backId = image;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _submit() async {
    if (_selfie == null || _frontId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a selfie and the front of your ID')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final uploadPayloads = <UploadFilePayload>[
        UploadFilePayload(bytes: _selfie!.bytes, filename: _selfie!.filename),
        UploadFilePayload(bytes: _frontId!.bytes, filename: _frontId!.filename),
        if (_backId != null)
          UploadFilePayload(bytes: _backId!.bytes, filename: _backId!.filename),
      ];
      final urls = await ApiService.instance.uploadImages(uploadPayloads);
      if (urls.length < 2) throw ApiException('Verification upload failed');

      await ApiService.instance.submitIdentityVerification({
        'documentType': _documentType,
        'selfieUrl': urls[0],
        'frontUrl': urls[1],
        if (urls.length > 2) 'backUrl': urls[2],
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification submitted for review')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
          'Verify identity',
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
        children: [
          _introCard(),
          const SizedBox(height: 22),
          _sectionTitle('Document type'),
          const SizedBox(height: 10),
          _documentTypeSelector(),
          const SizedBox(height: 24),
          _sectionTitle('Required photos'),
          const SizedBox(height: 10),
          _imageTile(
            title: 'Selfie',
            subtitle: 'Take a clear photo of your face',
            icon: Icons.face_retouching_natural_rounded,
            image: _selfie,
            onTap: () => _pickImage(
              _VerificationSlot.selfie,
              source: ImageSource.camera,
            ),
          ),
          const SizedBox(height: 12),
          _imageTile(
            title: 'Front of ID',
            subtitle: 'Capture the side with your details',
            icon: Icons.badge_outlined,
            image: _frontId,
            onTap: () => _pickImage(_VerificationSlot.frontId),
          ),
          const SizedBox(height: 12),
          _imageTile(
            title: 'Back of ID',
            subtitle: 'Optional unless your document has a back side',
            icon: Icons.credit_card_rounded,
            image: _backId,
            onTap: () => _pickImage(_VerificationSlot.backId),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Notes'),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Anything the review team should know?',
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _primaryColor, width: 1.4),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _isSubmitting || _isProcessing ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Submit for review',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3F2E3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: _primaryColor, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Identity verification helps buyers, sellers, employers, and creators trust who they are dealing with.',
              style: TextStyle(
                color: _ink,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _documentTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _documentTypes.map((item) {
        final isSelected = item.$1 == _documentType;
        return ChoiceChip(
          label: Text(item.$2),
          selected: isSelected,
          onSelected: (_) => setState(() => _documentType = item.$1),
          selectedColor: _primaryColor,
          backgroundColor: _surface,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : _ink,
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide(
            color: isSelected ? _primaryColor : const Color(0xFFE2E8E2),
          ),
        );
      }).toList(),
    );
  }

  Widget _imageTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required _VerificationImage? image,
    required VoidCallback onTap,
  }) {
    final hasImage = image != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasImage ? _primaryColor : const Color(0xFFE5EAE5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: hasImage ? _primaryColor : _surface,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                hasImage ? Icons.check_rounded : icon,
                color: hasImage ? Colors.white : _primaryColor,
              ),
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasImage ? 'Added and compressed as WebP' : subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              hasImage ? Icons.refresh_rounded : Icons.add_photo_alternate,
              color: hasImage ? _primaryColor : _muted,
            ),
          ],
        ),
      ),
    );
  }
}

enum _VerificationSlot { selfie, frontId, backId }

class _VerificationImage {
  const _VerificationImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}
