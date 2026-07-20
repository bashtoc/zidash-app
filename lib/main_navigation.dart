import 'package:flutter/material.dart';
import 'auth_required_dialog.dart';
import 'communities_screen.dart';
import 'home_screen.dart';
import 'jobs_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const JobsScreen(),
    const CommunitiesScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  Future<void> _onTabTapped(int index) async {
    if (index == 3 || index == 4) {
      final allowed = await requireAuthenticated(
        context,
        title: index == 3
            ? 'Sign up to view messages'
            : 'Sign up to manage your profile',
        message: index == 3
            ? 'Create an account to message sellers and keep your conversations saved.'
            : 'Create an account to verify your phone, manage listings, and save your details.',
      );
      if (!allowed) return;
    }
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF429417);
    const inactiveColor = Color(0xFF7A7D7A);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: activeColor,
        unselectedItemColor: inactiveColor,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: _NavAssetIcon('assets/nav_icons/home.png'),
            activeIcon: _NavAssetIcon(
              'assets/nav_icons/home.png',
              color: activeColor,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _NavAssetIcon('assets/nav_icons/jobs.png'),
            activeIcon: _NavAssetIcon(
              'assets/nav_icons/jobs.png',
              color: activeColor,
            ),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: _NavAssetIcon('assets/nav_icons/communities.png'),
            activeIcon: _NavAssetIcon(
              'assets/nav_icons/communities.png',
              color: activeColor,
            ),
            label: 'Communities',
          ),
          BottomNavigationBarItem(
            icon: _NavAssetIcon('assets/nav_icons/messages.png'),
            activeIcon: _NavAssetIcon(
              'assets/nav_icons/messages.png',
              color: activeColor,
            ),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: _NavAssetIcon('assets/nav_icons/profile.png'),
            activeIcon: _NavAssetIcon(
              'assets/nav_icons/profile.png',
              color: activeColor,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _NavAssetIcon extends StatelessWidget {
  const _NavAssetIcon(this.asset, {this.color});

  final String asset;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? BottomNavigationBarTheme.of(context).unselectedItemColor;
    return ImageIcon(AssetImage(asset), size: 24, color: effectiveColor);
  }
}
