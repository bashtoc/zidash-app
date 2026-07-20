import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6FBF6);
const _adminAccent = Color(0xFFDC2626);

// ─── Data model ───────────────────────────────────────────────────────────────

class _AdminVerification {
  _AdminVerification({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.docType,
    required this.status,
    this.docUrl,
    this.submittedAt,
  });

  factory _AdminVerification.fromJson(Map<String, dynamic> json) {
    // Safe cast of user sub-map
    final userMap = json['user'] is Map ? json['user'] as Map<String, dynamic> : null;

    // userId
    final userId = (userMap?['id'] as String?) ??
        (json['userId'] as String?) ??
        '';

    // userName – compose from first/last, fallback
    String userName;
    final firstName = userMap?['firstName'] as String?;
    final lastName = userMap?['lastName'] as String?;
    if (firstName != null || lastName != null) {
      userName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
      if (userName.isEmpty) userName = json['userName'] as String? ?? 'Unknown';
    } else {
      userName = json['userName'] as String? ?? 'Unknown';
    }

    // userEmail
    final userEmail = (userMap?['email'] as String?) ??
        (json['email'] as String?) ??
        '';

    return _AdminVerification(
      id: (json['id'] ?? '') as String,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      docType: (json['documentType'] ?? json['docType'] ?? 'Identity Document') as String,
      status: (json['status'] ?? 'pending') as String,
      docUrl: json['documentUrl'] as String? ?? json['docUrl'] as String?,
      submittedAt: DateTime.tryParse((json['createdAt'] ?? '') as String),
    );
  }

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String docType;
  final String status;
  final String? docUrl;
  final DateTime? submittedAt;

  /// First characters of the first two words of [userName], uppercase.
  String get initials {
    final words = userName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || (words.length == 1 && words.first.isEmpty)) {
      return 'ID';
    }
    final first = words[0].isNotEmpty ? words[0][0].toUpperCase() : '';
    final second = words.length > 1 && words[1].isNotEmpty
        ? words[1][0].toUpperCase()
        : '';
    final result = '$first$second';
    return result.isEmpty ? 'ID' : result;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminVerificationsScreen extends StatefulWidget {
  const AdminVerificationsScreen({super.key});

  @override
  State<AdminVerificationsScreen> createState() =>
      _AdminVerificationsScreenState();
}

class _AdminVerificationsScreenState extends State<AdminVerificationsScreen> {
  String _statusFilter = 'pending';
  List<_AdminVerification> _verifications = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;

  static const _filterLabels = ['Pending', 'Approved', 'Rejected'];
  static const _filterValues = ['pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
        _currentPage = 1;
      });
    }

    try {
      final response = await ApiService.instance.adminVerifications(
        page: _currentPage,
        status: _statusFilter,
      );
      final raw = response['items'];
      final items = (raw is List ? raw : <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_AdminVerification.fromJson)
          .toList();

      setState(() {
        if (reset) {
          _verifications = items;
        } else {
          _verifications = [..._verifications, ...items];
        }
        final hasNextPage = items.length >= 20;
        _currentPage++;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _setFilter(String status) {
    if (_statusFilter == status) return;
    setState(() => _statusFilter = status);
    _load(reset: true);
  }

  Future<void> _review(_AdminVerification item, bool approved) async {
    String? reason;

    if (!approved) {
      // Show dialog with optional reason field
      final reasonController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Reject Verification?',
            style: TextStyle(fontWeight: FontWeight.bold, color: _ink),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Optionally provide a reason for rejecting ${item.userName}\'s verification.',
                style: const TextStyle(color: _muted, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Reason (optional)',
                  hintStyle: const TextStyle(color: _muted),
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: _muted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _adminAccent),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      reason = reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : null;
    } else {
      // Approve confirm dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Approve Verification?',
            style: TextStyle(fontWeight: FontWeight.bold, color: _ink),
          ),
          content: Text(
            'This will mark ${item.userName} as identity verified.',
            style: const TextStyle(color: _muted, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: _muted)),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: _primaryColor),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await ApiService.instance.adminReviewVerification(
        item.id,
        approved: approved,
        reason: reason,
      );

      // Remove from list since it moves out of current filter
      setState(() {
        _verifications.removeWhere((v) => v.id == item.id);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? '${item.userName} approved successfully.'
                : '${item.userName} has been rejected.',
          ),
          backgroundColor: approved ? _primaryColor : _adminAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: _adminAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Filter tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filterLabels.length, (i) {
                  final value = _filterValues[i];
                  final label = _filterLabels[i];
                  final isSelected = _statusFilter == value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) => _setFilter(value),
                      selectedColor: _primaryColor.withValues(alpha: 0.15),
                      backgroundColor: _surface,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _primaryColor : _muted,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(
                          color: isSelected
                              ? _primaryColor.withValues(alpha: 0.4)
                              : Colors.grey.shade200,
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }),
              ),
            ),
          ),

          // Body
          Flexible(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: _adminAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _primaryColor),
                onPressed: () => _load(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_verifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_outlined, color: _muted, size: 48),
            const SizedBox(height: 12),
            Text(
              'No ${_statusFilter} verifications',
              style: const TextStyle(color: _muted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: _verifications.length,
      itemBuilder: (ctx, index) =>
          _VerificationTile(
            item: _verifications[index],
            onApprove: () => _review(_verifications[index], true),
            onReject: () => _review(_verifications[index], false),
          ),
    );
  }
}

// ─── Verification tile ────────────────────────────────────────────────────────

class _VerificationTile extends StatelessWidget {
  const _VerificationTile({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  final _AdminVerification item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: _surface,
            child: Text(
              item.initials,
              style: const TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.userName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.userEmail,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 3),
                Text(
                  item.docType,
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
                if (item.submittedAt != null)
                  Text(
                    'Submitted ${_formatDate(item.submittedAt!)}',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
              ],
            ),
          ),

          // Action buttons or status pill
          if (item.status == 'pending')
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _smallFilledButton(
                  icon: Icons.check_circle_outline,
                  label: 'Approve',
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  onPressed: onApprove,
                ),
                const SizedBox(height: 4),
                _smallOutlinedButton(
                  icon: Icons.cancel_outlined,
                  label: 'Reject',
                  foregroundColor: _adminAccent,
                  onPressed: onReject,
                ),
              ],
            )
          else if (item.status == 'approved')
            _statusPill('Approved', _primaryColor)
          else if (item.status == 'rejected')
            _statusPill('Rejected', _adminAccent),
        ],
      ),
    );
  }

  Widget _smallFilledButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        textStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _smallOutlinedButton({
    required IconData icon,
    required String label,
    required Color foregroundColor,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor,
        textStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: foregroundColor.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
