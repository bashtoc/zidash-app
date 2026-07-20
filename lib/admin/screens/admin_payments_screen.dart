import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6FBF6);
const _adminAccent = Color(0xFFDC2626);

// ─── Data model ───────────────────────────────────────────────────────────────

class _AdminPayment {
  _AdminPayment({
    required this.id,
    required this.reference,
    required this.userEmail,
    required this.amount,
    required this.status,
    required this.type,
    this.createdAt,
  });

  factory _AdminPayment.fromJson(Map<String, dynamic> json) {
    // reference – truncated to 16 chars
    final rawRef = (json['reference'] ?? json['ref'] ?? json['id'] ?? '') as String;
    final reference = rawRef.length > 16 ? rawRef.substring(0, 16) : rawRef;

    // userEmail – safe cast user map
    final userMap = json['user'] is Map ? json['user'] as Map<String, dynamic> : null;
    final userEmail = (userMap?['email'] as String?) ?? (json['email'] as String?) ?? '—';

    // amount – parse as double, format with commas
    final rawAmount = json['amount'];
    double amountVal = 0;
    if (rawAmount is num) {
      amountVal = rawAmount.toDouble();
    } else if (rawAmount is String) {
      amountVal = double.tryParse(rawAmount) ?? 0;
    }
    final amount = _formatNaira(amountVal);

    return _AdminPayment(
      id: (json['id'] ?? '') as String,
      reference: reference,
      userEmail: userEmail,
      amount: amount,
      status: (json['status'] ?? 'pending') as String,
      type: (json['type'] ?? json['purpose'] ?? 'other') as String,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '') as String),
    );
  }

  final String id;
  final String reference;
  final String userEmail;
  final String amount;
  final String status;
  final String type;
  final DateTime? createdAt;

  Color get statusColor {
    switch (status) {
      case 'success':
        return _primaryColor;
      case 'failed':
        return _adminAccent;
      default:
        return Colors.orange;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'success':
        return 'Success';
      case 'failed':
        return 'Failed';
      default:
        return 'Pending';
    }
  }

  String get typeLabel {
    switch (type) {
      case 'boost':
        return 'Boost';
      case 'listing_fee':
        return 'Listing Fee';
      default:
        return 'Payment';
    }
  }
}

// Formats a double as ₦X,XXX,XXX
String _formatNaira(double value) {
  final intPart = value.truncate();
  final formatted = _addCommas(intPart.toString());
  return '₦$formatted';
}

String _addCommas(String s) {
  if (s.length <= 3) return s;
  final result = StringBuffer();
  final reversed = s.split('').reversed.toList();
  for (int i = 0; i < reversed.length; i++) {
    if (i > 0 && i % 3 == 0) result.write(',');
    result.write(reversed[i]);
  }
  return result.toString().split('').reversed.join();
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  List<_AdminPayment> _payments = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

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
        _hasMore = true;
      });
    } else {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final response = await ApiService.instance.adminPayments(page: _currentPage);
      final raw = response['items'];
      final items = (raw is List ? raw : <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_AdminPayment.fromJson)
          .toList();

      setState(() {
        if (reset) {
          _payments = items;
        } else {
          _payments = [..._payments, ...items];
        }
        _hasMore = items.length >= 20;
        _currentPage++;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.message;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _openDetail(_AdminPayment payment) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount + type header row
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: payment.statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: payment.statusColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.amount,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        payment.typeLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Info rows
              _infoRow('Reference', payment.reference),
              _infoRow('User', payment.userEmail),
              _infoRow('Status', payment.statusLabel,
                  valueColor: payment.statusColor),
              if (payment.createdAt != null)
                _infoRow(
                  'Date',
                  _formatDate(payment.createdAt!),
                ),
              const SizedBox(height: 20),

              // Refund note
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Refund processing requires Paystack API credentials.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Close button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(),
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

    if (_payments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, color: _muted, size: 48),
            SizedBox(height: 12),
            Text(
              'No payments found',
              style: TextStyle(color: _muted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _payments.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        if (index == _payments.length) {
          // Load more button
          return Center(
            child: _isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: _primaryColor),
                  )
                : TextButton(
                    onPressed: () => _load(),
                    child: const Text(
                      'Load more',
                      style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600),
                    ),
                  ),
          );
        }
        return _PaymentTile(
          payment: _payments[index],
          onTap: () => _openDetail(_payments[index]),
        );
      },
    );
  }
}

// ─── Payment tile ─────────────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.onTap});

  final _AdminPayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + reference/email + amount/status
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: payment.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: payment.statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.reference,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        payment.userEmail,
                        style: const TextStyle(fontSize: 11, color: _muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      payment.amount,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Status pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: payment.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        payment.statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: payment.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Bottom row: type pill + date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    payment.typeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _muted,
                    ),
                  ),
                ),
                const Spacer(),
                if (payment.createdAt != null)
                  Text(
                    _formatDate(payment.createdAt!),
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
              ],
            ),
          ],
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
