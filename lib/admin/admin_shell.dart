import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_guard.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/admin_listings_screen.dart';
import 'screens/admin_payments_screen.dart';
import 'screens/admin_verifications_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _ink = Color(0xFF172317); // dark text
const _muted = Color(0xFF7E867E); // grey
const _surface = Color(0xFFF6FBF6); // light tint
const _adminAccent = Color(0xFFDC2626); // red for admin UI

/// The top-level admin navigation shell.
///
/// Renders the five admin sections inside an [IndexedStack] and provides a
/// custom [BottomNavigationBar].  The entire Scaffold is wrapped in an
/// [AdminGuard] so non-admin users are redirected automatically.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  // Pre-instantiated screens – kept alive by IndexedStack.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      AdminDashboardScreen(onOpenTab: _onTabTapped),
      const AdminUsersScreen(),
      const AdminListingsScreen(),
      const AdminPaymentsScreen(),
      const AdminVerificationsScreen(),
    ];
  }

  // ── Bottom-nav item definitions ─────────────────────────────────────────────
  static const List<_NavItem> _navItems = [
    _NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
    ),
    _NavItem(
      label: 'Users',
      icon: Icons.people_outline,
      activeIcon: Icons.people,
    ),
    _NavItem(
      label: 'Listings',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
    ),
    _NavItem(
      label: 'Payments',
      icon: Icons.payment_outlined,
      activeIcon: Icons.payment,
    ),
    _NavItem(
      label: 'Verifications',
      icon: Icons.verified_user_outlined,
      activeIcon: Icons.verified_user,
    ),
  ];

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _surface,

          // ── App Bar ──────────────────────────────────────────────────────
          appBar: AppBar(
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            elevation: 0,
            // Back button
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.admin_panel_settings, color: _adminAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          body: IndexedStack(index: _currentIndex, children: _screens),

          // ── Bottom Navigation Bar ─────────────────────────────────────────
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE5EBE5), width: 1),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: _adminAccent,
              unselectedItemColor: _muted,
              elevation: 0,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              items: _navItems
                  .map(
                    (item) => BottomNavigationBarItem(
                      icon: Icon(item.icon),
                      activeIcon: Icon(item.activeIcon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Internal helper ──────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
