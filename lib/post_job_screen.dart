import 'package:flutter/material.dart';

import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF1C1F1C);
const _muted = Color(0xFF8A8F8A);

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key, this.initialJob});

  final Map<String, dynamic>? initialJob;

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController(text: 'Lagos, NG');
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();
  String _type = 'full_time';
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialJob?['id'] != null;

  static const _types = [
    ('full_time', 'Full-time'),
    ('part_time', 'Part-time'),
    ('contract', 'Contract'),
    ('internship', 'Internship'),
  ];

  @override
  void initState() {
    super.initState();
    final job = widget.initialJob;
    if (job == null) return;
    _titleController.text = job['title']?.toString() ?? '';
    _companyController.text = job['company']?.toString() ?? '';
    _descriptionController.text = job['description']?.toString() ?? '';
    _locationController.text = job['location']?.toString() ?? 'Lagos, NG';
    _salaryMinController.text = _numberText(job['salaryMin']);
    _salaryMaxController.text = _numberText(job['salaryMax']);
    final employmentType = job['employmentType']?.toString();
    if (_types.any((type) => type.$1 == employmentType)) {
      _type = employmentType!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'title': _titleController.text.trim(),
        'company': _companyController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'employmentType': _type,
        if (_salaryMinController.text.trim().isNotEmpty)
          'salaryMin': double.parse(_salaryMinController.text.trim()),
        if (_salaryMaxController.text.trim().isNotEmpty)
          'salaryMax': double.parse(_salaryMaxController.text.trim()),
      };
      if (_isEditing) {
        await ApiService.instance.updateMyJob(
          widget.initialJob!['id'].toString(),
          payload,
        );
      } else {
        await ApiService.instance.postJob(payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Job updated' : 'Job posted')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _numberText(dynamic value) {
    if (value == null) return '';
    final parsed = num.tryParse(value.toString());
    if (parsed == null) return value.toString();
    if (parsed % 1 == 0) return parsed.toInt().toString();
    return parsed.toString();
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
        title: Text(
          _isEditing ? 'Edit job' : 'Post a job',
          style: const TextStyle(
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
            _sectionLabel('Job details'),
            const SizedBox(height: 10),
            _card(
              child: Column(
                children: [
                  _field(
                    _titleController,
                    label: 'Job title',
                    hint: 'e.g. Product Designer',
                  ),
                  const _Divider(),
                  _field(
                    _companyController,
                    label: 'Company',
                    hint: 'e.g. Beams Inc.',
                  ),
                  const _Divider(),
                  _field(
                    _descriptionController,
                    label: 'Description',
                    hint: 'Responsibilities, requirements, benefits…',
                    minLines: 4,
                  ),
                  const _Divider(),
                  _field(
                    _locationController,
                    label: 'Location',
                    hint: 'City, area',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            _sectionLabel('Employment type'),
            const SizedBox(height: 10),
            _chipWrap(
              options: _types,
              selected: _type,
              onSelected: (value) => setState(() => _type = value),
            ),
            const SizedBox(height: 26),
            _sectionLabel('Salary range', trailing: 'Optional'),
            const SizedBox(height: 10),
            _card(
              child: Row(
                children: [
                  Expanded(
                    child: _field(
                      _salaryMinController,
                      label: 'Min',
                      hint: '0',
                      requiredField: false,
                      keyboardType: TextInputType.number,
                      prefixText: '₦ ',
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
                      _salaryMaxController,
                      label: 'Max',
                      hint: '0',
                      requiredField: false,
                      keyboardType: TextInputType.number,
                      prefixText: '₦ ',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _submitBar(),
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

  // ---- Fields ---------------------------------------------------------

  Widget _field(
    TextEditingController controller, {
    required String label,
    String? hint,
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
                : Text(
                    _isEditing ? 'Save changes' : 'Post job',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
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
