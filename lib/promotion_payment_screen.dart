import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF1C1F1C);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6F7F6);

class PromotionPaymentScreen extends StatefulWidget {
  const PromotionPaymentScreen({
    super.key,
    required this.listingId,
    required this.listingTitle,
    required this.days,
    required this.amount,
  });

  final String listingId;
  final String listingTitle;
  final int days;
  final int amount;

  @override
  State<PromotionPaymentScreen> createState() => _PromotionPaymentScreenState();
}

class _PromotionPaymentScreenState extends State<PromotionPaymentScreen> {
  String _method = 'wallet';
  bool _isPaying = false;

  Future<void> _pay() async {
    if (_isPaying) return;
    setState(() => _isPaying = true);
    try {
      await ApiService.instance.payListingPromotion(
        widget.listingId,
        days: widget.days,
        method: _method,
      );
      if (!mounted) return;
      if (_method == 'bank_transfer') {
        _showBankTransferSheet();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promotion payment received')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      if (_isInsufficientBalanceError(error)) {
        await _showInsufficientBalanceDialog();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  bool _isInsufficientBalanceError(Object error) {
    if (error is ApiException && error.statusCode == 402) return true;
    return error.toString().toLowerCase().contains('insufficient');
  }

  Future<void> _showInsufficientBalanceDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF3E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFFE46E1C),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Insufficient balance',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 21,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your wallet balance is not enough to pay ${_money(widget.amount)} for this promo. Choose bank transfer to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      if (!mounted) return;
                      setState(() => _method = 'bank_transfer');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Use bank transfer',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Not now',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: _surface,
        title: const Text(
          'Pay for promotion',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _summaryCard(),
          const SizedBox(height: 16),
          _paymentOption(
            value: 'wallet',
            title: 'Wallet balance',
            subtitle: 'Pay instantly using your available Zidash balance.',
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 12),
          _paymentOption(
            value: 'bank_transfer',
            title: 'Bank transfer',
            subtitle:
                'Transfer to the displayed account and use your reference.',
            icon: Icons.account_balance_outlined,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isPaying ? null : _pay,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryColor.withValues(alpha: 0.55),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isPaying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _method == 'wallet'
                          ? 'Pay ${_money(widget.amount)}'
                          : 'Generate bank transfer',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBankTransferSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        final screenHeight = MediaQuery.sizeOf(sheetContext).height;
        var accountCopied = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.account_balance_outlined,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bank transfer',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Complete your promo payment',
                                  style: TextStyle(
                                    color: _muted.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded, color: _ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE7E9E7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Amount to send',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _money(widget.amount),
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Send payment to',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _accountNumberCard(
                        copied: accountCopied,
                        onCopy: () async {
                          const accountNumber = '7066400165';
                          await Clipboard.setData(
                            const ClipboardData(text: accountNumber),
                          );
                          if (!sheetContext.mounted) return;
                          setSheetState(() => accountCopied = true);
                          Future<void>.delayed(const Duration(seconds: 2), () {
                            if (!sheetContext.mounted) return;
                            setSheetState(() => accountCopied = false);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _detail('Bank name', 'Safehaven bank'),
                      _detail('Account name', 'Zidash checkout'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: Color(0xFFB45309),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Account expires in 30 minutes',
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            Navigator.of(context).pop(false);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'I have made transfer',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _accountNumberCard({
    required bool copied,
    required Future<void> Function() onCopy,
  }) {
    const accountNumber = '7066400165';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              accountNumber,
              style: TextStyle(
                color: _ink,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 18,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: copied ? 1 : 0,
                  child: const Text(
                    'Copied',
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy account number',
                onPressed: onCopy,
                style: IconButton.styleFrom(
                  backgroundColor: _primaryColor.withValues(alpha: 0.12),
                  foregroundColor: _primaryColor,
                ),
                icon: Icon(
                  copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP promo',
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.listingTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _pill('${widget.days} days'),
              const Spacer(),
              Text(
                _money(widget.amount),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _method == value;
    return InkWell(
      onTap: () => setState(() {
        _method = value;
      }),
      borderRadius: BorderRadius.circular(18),
      child: _card(
        borderColor: selected ? _primaryColor : const Color(0xFFE7E9E7),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected
                    ? _primaryColor.withValues(alpha: 0.12)
                    : _surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: selected ? _primaryColor : _ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? _primaryColor : _muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _primaryColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _card({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? const Color(0xFFE7E9E7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

String _money(int amount) {
  return '₦ ${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
}
