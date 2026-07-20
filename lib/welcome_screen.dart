import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'email_auth_screen.dart';
import 'main_navigation.dart';
import 'services/api_service.dart';
import 'third_party_auth/apple_auth.dart';
import 'third_party_auth/google_auth.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const Color _green = Color(0xFF429417);
  static const Color _ink = Color(0xFF050505);
  static const Color _muted = Color(0xFF1B1B1B);
  static const Color _dotGrey = Color(0xFF9D9F9C);

  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _timer;
  String? _authProviderLoading;
  bool _isContinuingAnonymous = false;
  bool _isAnonymousSession = false;

  final List<_WelcomeSlide> _slides = const [
    _WelcomeSlide(
      image: 'assets/images/welcome_business.png',
      title: 'Grow your business\nwith Zidash',
      subtitle:
          'Reach more customers, showcase your products\nand sell with confidence.',
    ),
    _WelcomeSlide(
      image: 'assets/images/welcome_buy_sell.png',
      title: 'Buy and sell within\nyour community',
      subtitle:
          'Discover jobs, products, services and trusted\nconnections in one place.',
    ),
    _WelcomeSlide(
      image: 'assets/images/welcome_thrive.png',
      title: 'Grow, earn and\nthrive',
      subtitle:
          'Whether you’re buying selling, hiring or creating,\nZidash helps you move forward.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAnonymousState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients) return;
      final next = _currentIndex == _slides.length - 1 ? 0 : _currentIndex + 1;
      setState(() => _currentIndex = next);
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAnonymousState() async {
    final isAnonymous = await ApiService.instance.isAnonymousSession();
    if (!mounted) return;
    setState(() => _isAnonymousSession = isAnonymous);
  }

  Future<void> _signOutAnonymous() async {
    await ApiService.instance.clearSession();
    if (!mounted) return;
    setState(() => _isAnonymousSession = false);
    _showAuthDialog(
      context,
      title: 'Signed out',
      message: 'Your anonymous session has been cleared on this device.',
      icon: Icons.logout_rounded,
      color: _green,
    );
  }

  void _openEmailAuth(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmailAuthScreen()),
    );
  }

  Future<void> _continueAnonymous(BuildContext context) async {
    if (_isContinuingAnonymous) return;
    setState(() => _isContinuingAnonymous = true);
    await ApiService.instance.startAnonymousSession();
    if (mounted) setState(() => _isAnonymousSession = true);
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigation()),
    );
    if (mounted) setState(() => _isContinuingAnonymous = false);
  }

  Future<void> _runThirdPartyAuth(
    BuildContext context, {
    required String provider,
    required Future<Map<String, dynamic>> Function() signIn,
  }) async {
    if (_authProviderLoading != null) return;
    setState(() => _authProviderLoading = provider);
    try {
      final result = await signIn();
      if (!context.mounted) return;
      if (result['success'] == true) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
          (_) => false,
        );
        return;
      }
      _showAuthDialog(
        context,
        title:
            result['title']?.toString() ??
            (result['cancelled'] == true
                ? '${_providerName(provider)} sign-in cancelled'
                : 'Could not continue with ${_providerName(provider)}'),
        message:
            result['message']?.toString() ??
            'We could not complete ${_providerName(provider)} sign-in. Please try again or use email instead.',
        icon: result['cancelled'] == true
            ? Icons.close_rounded
            : Icons.error_outline_rounded,
        color: result['cancelled'] == true ? _ink : Colors.red,
      );
    } finally {
      if (mounted) setState(() => _authProviderLoading = null);
    }
  }

  String _providerName(String provider) {
    return provider == 'apple' ? 'Apple' : 'Google';
  }

  void _showAuthDialog(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 34),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.monaSans(
                    color: _ink,
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.monaSans(
                    color: _muted,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'Got it',
                      style: GoogleFonts.monaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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
    final height = MediaQuery.of(context).size.height;
    final compact = height < 760;
    final tight = height < 860;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentHeight = constraints.maxHeight;
              final heroHeight = tight
                  ? (contentHeight * 0.25).clamp(150.0, 220.0)
                  : (contentHeight * 0.31).clamp(220.0, 285.0);

              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 430,
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tight ? 28 : 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: compact ? 8 : (tight ? 16 : 26)),
                          Image.asset(
                            'assets/zidashlogo.png',
                            height: compact ? 34 : (tight ? 38 : 44),
                            fit: BoxFit.contain,
                          ),
                          SizedBox(height: compact ? 15 : (tight ? 24 : 24)),
                          SizedBox(
                            height: heroHeight,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _slides.length,
                              onPageChanged: (index) {
                                setState(() => _currentIndex = index);
                              },
                              itemBuilder: (context, index) {
                                return Image.asset(
                                  _slides[index].image,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                );
                              },
                            ),
                          ),
                          SizedBox(height: compact ? 24 : (tight ? 34 : 34)),
                          _DotsIndicator(
                            count: _slides.length,
                            currentIndex: _currentIndex,
                          ),
                          SizedBox(height: compact ? 14 : (tight ? 16 : 28)),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeOutCubic,
                            child: _SlideText(
                              key: ValueKey(_currentIndex),
                              slide: _slides[_currentIndex],
                              compact: compact || tight,
                            ),
                          ),
                          SizedBox(height: compact ? 34 : (tight ? 74 : 54)),
                          _AuthButton(
                            label: _authProviderLoading == 'google'
                                ? 'Signing in...'
                                : 'Sign up with google',
                            onTap: () => _runThirdPartyAuth(
                              context,
                              provider: 'google',
                              signIn: signInWithGoogle,
                            ),
                            foregroundColor: _ink,
                            backgroundColor: Colors.white,
                            borderColor: const Color(0xFF181818),
                            child: Image.asset(
                              'assets/googleicon.png',
                              height: 22,
                            ),
                          ),
                          SizedBox(height: compact ? 8 : 10),
                          _AuthButton(
                            label: _authProviderLoading == 'apple'
                                ? 'Signing in...'
                                : 'Sign up with Apple ID',
                            onTap: () => _runThirdPartyAuth(
                              context,
                              provider: 'apple',
                              signIn: signInOrSignUpWithApple,
                            ),
                            foregroundColor: _ink,
                            backgroundColor: Colors.white,
                            borderColor: const Color(0xFF181818),
                            child: const Icon(
                              Icons.apple,
                              color: Colors.black,
                              size: 29,
                            ),
                          ),
                          SizedBox(height: compact ? 8 : 10),
                          _AuthButton(
                            label: 'Sign up with email',
                            onTap: () => _openEmailAuth(context),
                            foregroundColor: Colors.white,
                            backgroundColor: _green,
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          SizedBox(height: compact ? 8 : 10),
                          SizedBox(
                            width: double.infinity,
                            height: compact ? 48 : 50,
                            child: OutlinedButton.icon(
                              onPressed: _isContinuingAnonymous
                                  ? null
                                  : () => _continueAnonymous(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _green,
                                side: const BorderSide(
                                  color: Color(0xFF66C665),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                textStyle: GoogleFonts.monaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              icon: const Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                              ),
                              label: Text(
                                _isContinuingAnonymous
                                    ? 'Continuing...'
                                    : 'Login as anonymous',
                              ),
                            ),
                          ),
                          if (_isAnonymousSession) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: compact ? 44 : 46,
                              child: TextButton.icon(
                                onPressed: _signOutAnonymous,
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  size: 18,
                                ),
                                label: const Text('Sign out anonymous session'),
                                style: TextButton.styleFrom(
                                  foregroundColor: _muted,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  textStyle: GoogleFonts.monaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return Container(
          width: isActive ? 20 : 7,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: isActive
                ? _WelcomeScreenState._green
                : _WelcomeScreenState._dotGrey,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _SlideText extends StatelessWidget {
  const _SlideText({super.key, required this.slide, required this.compact});

  final _WelcomeSlide slide;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: GoogleFonts.monaSans(
            color: _WelcomeScreenState._ink,
            fontSize: compact ? 24 : 34,
            height: 1.24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: compact ? 8 : 18),
        Text(
          slide.subtitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: GoogleFonts.monaSans(
            color: _WelcomeScreenState._muted,
            fontSize: compact ? 12 : 16,
            height: 1.28,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _WelcomeSlide {
  const _WelcomeSlide({
    required this.image,
    required this.title,
    required this.subtitle,
  });

  final String image;
  final String title;
  final String subtitle;
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.onTap,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.child,
    this.borderColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color? borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 51,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: borderColor ?? backgroundColor,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 28, child: Center(child: child)),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: GoogleFonts.monaSans(
                        color: foregroundColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
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
}
