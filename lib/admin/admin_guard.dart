import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _ink = Color(0xFF172317); // dark text
const _muted = Color(0xFF7E867E); // grey
const _adminAccent = Color(0xFFDC2626); // red for admin UI

/// Wraps an admin screen.
///
/// * If [ApiService.instance.isAdmin] is **false** the widget renders a
///   full-screen "Access Denied" error and automatically pops the current
///   route after 2 seconds.
/// * If the user **is** an admin it simply renders [child].
class AdminGuard extends StatefulWidget {
  const AdminGuard({super.key, required this.child});

  final Widget child;

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  @override
  void initState() {
    super.initState();
    if (!ApiService.instance.isAdmin) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ApiService.instance.isAdmin) {
      return widget.child;
    }
    return _AccessDeniedPage();
  }
}

// ─── Access Denied UI ─────────────────────────────────────────────────────────

class _AccessDeniedPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Remove any system back button affordance.
      body: PopScope(
        canPop: false,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Red circle icon ──────────────────────────────────────
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _adminAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: _adminAccent,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ────────────────────────────────────────────────
                  const Text(
                    'Access Denied',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Subtitle ─────────────────────────────────────────────
                  const Text(
                    "You don't have permission to view this page.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── "Admin only" badge ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: _adminAccent, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Admin only',
                      style: TextStyle(
                        color: _adminAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Auto-dismiss hint ────────────────────────────────────
                  const Text(
                    'Redirecting you back…',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
