import 'package:flutter/material.dart';

import 'auth_required_dialog.dart';
import 'services/api_service.dart';

const _jobApplyPrimary = Color(0xFF66C665);
const _jobApplyInk = Color(0xFF172317);
const _jobApplyMuted = Color(0xFF7E867E);
const _jobApplySurface = Color(0xFFF6F7F6);

Future<bool> showJobApplicationSheet(
  BuildContext context, {
  required String jobId,
  required String title,
  required String company,
}) async {
  final allowed = await requireAuthenticated(
    context,
    title: 'Sign up to apply for jobs',
    message:
        'Create an account to apply for jobs and keep your applications saved.',
  );
  if (!allowed || !context.mounted) return false;
  if (jobId.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This job is not available for applications.'),
      ),
    );
    return false;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _JobApplicationSheet(jobId: jobId, title: title, company: company),
  );
  return result == true;
}

class _JobApplicationSheet extends StatefulWidget {
  const _JobApplicationSheet({
    required this.jobId,
    required this.title,
    required this.company,
  });

  final String jobId;
  final String title;
  final String company;

  @override
  State<_JobApplicationSheet> createState() => _JobApplicationSheetState();
}

class _JobApplicationSheetState extends State<_JobApplicationSheet> {
  final TextEditingController _coverController = TextEditingController();
  final TextEditingController _resumeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _coverController.dispose();
    _resumeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final coverLetter = _coverController.text.trim();
    final resumeUrl = _resumeController.text.trim();
    if (coverLetter.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a short application message.')),
      );
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ApiService.instance.applyForJob(widget.jobId, {
        'coverLetter': coverLetter,
        if (resumeUrl.isNotEmpty) 'resumeUrl': resumeUrl,
      });
      if (!mounted) return;
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
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
                      color: const Color(0xFFE0E3E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _jobApplyPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.work_outline_rounded,
                        color: _jobApplyPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _jobApplyInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.company,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _jobApplyMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _jobApplyInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _field(
                  controller: _coverController,
                  label: 'Application message',
                  hint:
                      'Introduce yourself and explain why you are a good fit.',
                  minLines: 5,
                  maxLines: 8,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _resumeController,
                  label: 'Resume or portfolio link',
                  hint: 'https://...',
                  minLines: 1,
                  maxLines: 1,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _jobApplyPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _jobApplyPrimary.withValues(
                        alpha: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit application',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int minLines,
    required int maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _jobApplyInk,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _jobApplySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E9E7)),
          ),
          child: TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: _jobApplyMuted,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }
}
