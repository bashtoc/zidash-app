import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6FBF6);

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key, this.initialPhone});

  final String? initialPhone;

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  static const int _otpLength = 6;
  final _phoneController = TextEditingController();
  final _identityNumberController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  bool _hasRequestedCode = false;
  bool _isRequesting = false;
  bool _isVerifying = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  String? _devCode;
  String _identityMethod = 'bvn';

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone ?? '';
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _identityNumberController.dispose();
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = seconds;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() {
          _resendSeconds = 0;
        });
        return;
      }
      setState(() {
        _resendSeconds -= 1;
      });
    });
  }

  void _onCodeChanged(String value, int index) {
    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _requestCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number')),
      );
      return;
    }
    final identityNumber = _identityNumberController.text.trim();
    if (identityNumber.isNotEmpty && identityNumber.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter a valid 11-digit ${_identityMethod.toUpperCase()} number',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isRequesting = true;
    });
    try {
      final result = await ApiService.instance.requestPhoneVerification(
        phone,
        identityMethod: _identityMethod,
        identityNumber: identityNumber.isEmpty ? null : identityNumber,
      );
      if (!mounted) return;
      for (final controller in _codeControllers) {
        controller.clear();
      }
      setState(() {
        _hasRequestedCode = true;
        _devCode = result['devCode'] as String?;
      });
      _startResendTimer((result['resendAfterSeconds'] as int?) ?? 60);
      _focusNodes.first.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _devCode == null
                ? 'Verification code sent'
                : 'Development OTP: $_devCode',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeControllers.map((controller) => controller.text).join();
    if (code.length != _otpLength) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter the 6-digit code')));
      return;
    }

    setState(() {
      _isVerifying = true;
    });
    try {
      await ApiService.instance.verifyPhoneVerification(code);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone number verified')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  String get _requestButtonLabel {
    if (_isRequesting) return 'Sending...';
    if (_hasRequestedCode && _resendSeconds > 0) {
      return 'Resend in ${_resendSeconds}s';
    }
    return _hasRequestedCode ? 'Resend Code' : 'Send Code';
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
          'Verify phone',
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Text(
            'Add a reachable phone number and select the identity option you want linked to this verification.',
            style: TextStyle(
              color: _muted,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !_isVerifying,
            decoration: _inputDecoration('Phone number', '+2348012345678'),
          ),
          const SizedBox(height: 18),
          const Text(
            'Verification method',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _identityOption('bvn', 'BVN')),
              const SizedBox(width: 10),
              Expanded(child: _identityOption('nin', 'NIN')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _identityNumberController,
            keyboardType: TextInputType.number,
            enabled: !_isVerifying && !_hasRequestedCode,
            inputFormatters: [
              LengthLimitingTextInputFormatter(11),
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: _inputDecoration(
              '${_identityMethod.toUpperCase()} number',
              'Optional 11-digit ${_identityMethod.toUpperCase()}',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isRequesting || _resendSeconds > 0
                  ? null
                  : _requestCode,
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                _requestButtonLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (_devCode != null) ...[
            const SizedBox(height: 12),
            Text(
              'Development code: $_devCode',
              style: const TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (_hasRequestedCode) ...[
            const SizedBox(height: 30),
            const Text(
              'Enter verification code',
              style: TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                _otpLength,
                (index) => SizedBox(
                  width: 48,
                  height: 58,
                  child: TextField(
                    controller: _codeControllers[index],
                    focusNode: _focusNodes[index],
                    onChanged: (value) => _onCodeChanged(value, index),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(1),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _surface,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: const BorderSide(
                          color: _primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _isVerifying ? null : _verifyCode,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  _isVerifying ? 'Verifying...' : 'Verify Phone',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _identityOption(String value, String label) {
    final selected = _identityMethod == value;
    return InkWell(
      onTap: _hasRequestedCode || _isVerifying
          ? null
          : () => setState(() => _identityMethod = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: selected ? _primaryColor.withValues(alpha: 0.13) : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _primaryColor : Colors.grey.shade200,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? _primaryColor : _muted,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? _ink : _muted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
        borderSide: const BorderSide(color: _primaryColor, width: 1.6),
      ),
    );
  }
}
