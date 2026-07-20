import 'package:flutter/material.dart';

import 'email_auth_screen.dart';
import 'services/api_service.dart';
import 'welcome_screen.dart';

const _authRequiredGreen = Color(0xFF66C665);
const _authRequiredInk = Color(0xFF172317);
const _authRequiredMuted = Color(0xFF7E867E);

Future<bool> requireAuthenticated(
  BuildContext context, {
  String title = 'Create an account to continue',
  String message =
      'Sign up or log in to use this feature and keep your activity saved.',
}) async {
  await ApiService.instance.loadSession();
  final isAnonymous = await ApiService.instance.isAnonymousSession();
  if (!isAnonymous && ApiService.instance.isAuthenticated) return true;
  if (!context.mounted) return false;

  var signedOutAnonymous = false;
  final shouldSignUp = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF8EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: _authRequiredGreen,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _authRequiredInk,
                  fontSize: 20,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _authRequiredMuted,
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
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _authRequiredGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Sign up now',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (isAnonymous) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    await ApiService.instance.clearSession();
                    signedOutAnonymous = true;
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(false);
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out anonymous'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(
                  'Not now',
                  style: TextStyle(
                    color: _authRequiredMuted,
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

  if (signedOutAnonymous && context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (_) => false,
    );
    return false;
  }

  if (shouldSignUp == true && context.mounted) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const EmailAuthScreen()));
  }
  return false;
}
