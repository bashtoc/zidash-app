import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin/admin_shell.dart';
import 'location_screen.dart';
import 'name_verification_screen.dart';
import 'my_community_posts_screen.dart';
import 'my_job_posts_screen.dart';
import 'my_listings_screen.dart';
import 'my_store_dashboard_screen.dart';
import 'phone_verification_screen.dart';
import 'services/api_service.dart';
import 'welcome_screen.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileData> _profileFuture;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingCover = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<_ProfileData> _loadProfile() async {
    if (await ApiService.instance.isAnonymousSession()) {
      return _ProfileData.empty();
    }
    try {
      final data = await ApiService.instance.bootstrap();
      return _ProfileData.fromJson(data);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await ApiService.instance.clearSession();
        _sendToWelcome();
        return _ProfileData.empty();
      }
      rethrow;
    }
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  void _sendToWelcome() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (_) => false,
      );
    });
  }

  Future<void> _openNameVerification(_ProfileData profile) async {
    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => NameVerificationScreen(
          initialFirstName: profile.firstName,
          initialLastName: profile.lastName,
        ),
      ),
    );
    if (didSave == true) _refreshProfile();
  }

  Future<void> _openPhoneVerification(_ProfileData profile) async {
    final didVerify = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            PhoneVerificationScreen(initialPhone: profile.phone),
      ),
    );
    if (didVerify == true) _refreshProfile();
  }

  Future<void> _openMyListings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const MyListingsScreen()));
    _refreshProfile();
  }

  Future<void> _openStoreDashboard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MyStoreDashboardScreen()),
    );
    _refreshProfile();
  }

  Future<void> _openMyCommunityPosts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MyCommunityPostsScreen()),
    );
    _refreshProfile();
  }

  Future<void> _openMyJobPosts() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const MyJobPostsScreen()));
    _refreshProfile();
  }

  Future<void> _openAdminPanel() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AdminShell()));
  }

  Future<void> _openLocationScreen(_ProfileData profile) async {
    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => LocationScreen(initialLocation: profile.location),
      ),
    );
    if (didSave == true) _refreshProfile();
  }

  Future<void> _openPrivacyPolicy() async {
    final didLaunch = await launchUrl(
      Uri.parse('https://zidash.com/privacy'),
      mode: LaunchMode.externalApplication,
    );
    if (didLaunch || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open privacy policy.')),
    );
  }

  Future<void> _uploadHeaderImage() async {
    if (_isUploadingCover) return;
    setState(() => _isUploadingCover = true);
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked == null) return;

      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 1800,
        minHeight: 900,
        quality: 82,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (compressed == null || compressed.isEmpty) {
        throw ApiException('Could not process selected image');
      }

      final urls = await ApiService.instance.uploadImages([
        UploadFilePayload(
          bytes: Uint8List.fromList(compressed),
          filename:
              'profile-cover-${DateTime.now().millisecondsSinceEpoch}.webp',
        ),
      ]);
      if (urls.isEmpty) throw ApiException('Cover image upload failed');

      await ApiService.instance.updateProfile({
        'sellerProfile': {'coverImageUrl': urls.first},
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Header image updated successfully.')),
      );
      _refreshProfile();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _uploadAvatarImage() async {
    if (_isUploadingAvatar) return;
    setState(() => _isUploadingAvatar = true);
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked == null) return;

      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 720,
        minHeight: 720,
        quality: 86,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (compressed == null || compressed.isEmpty) {
        throw ApiException('Could not process selected image');
      }

      final urls = await ApiService.instance.uploadImages([
        UploadFilePayload(
          bytes: Uint8List.fromList(compressed),
          filename:
              'profile-avatar-${DateTime.now().millisecondsSinceEpoch}.webp',
        ),
      ]);
      if (urls.isEmpty) throw ApiException('Profile image upload failed');

      await ApiService.instance.updateProfile({'avatarUrl': urls.first});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully.')),
      );
      _refreshProfile();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _handleAvatarAction(_ProfileData profile) async {
    if (_isUploadingAvatar) return;
    if (profile.avatarUrl == null) {
      await _uploadAvatarImage();
      return;
    }
    await _deleteAvatarImage();
  }

  Future<void> _deleteAvatarImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEEEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Delete profile image?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your initials will show until you upload a new profile image.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Delete image',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    'Cancel',
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
    if (confirmed != true || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      await ApiService.instance.updateProfile({'avatarUrl': null});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile image deleted.')));
      _refreshProfile();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (_) => false,
    );
  }

  Future<void> _deleteAccount() async {
    try {
      await ApiService.instance.deleteAccount();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    await ApiService.instance.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (_) => false,
    );
  }

  void _showDangerZoneSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 18),
                const Text(
                  'Danger zone',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose an account action. You will be asked to confirm before anything changes.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                _dangerSheetAction(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  subtitle: 'Sign out on this device',
                  color: _ink,
                  onTap: () {
                    Navigator.of(context).pop();
                    _showConfirmDialog(
                      icon: Icons.logout_rounded,
                      title: 'Logout?',
                      message:
                          'You will need to sign in again before using your Zidash account on this device.',
                      confirmText: 'Logout',
                      confirmColor: _primaryColor,
                      onConfirm: _logout,
                    );
                  },
                ),
                const SizedBox(height: 10),
                _dangerSheetAction(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete account',
                  subtitle: 'Permanently disable your Zidash account',
                  color: Colors.red,
                  onTap: () {
                    Navigator.of(context).pop();
                    _showConfirmDialog(
                      icon: Icons.delete_forever_outlined,
                      title: 'Delete account?',
                      message:
                          'This will disable your account and sign you out. This action cannot be undone in the app.',
                      confirmText: 'Delete Account',
                      confirmColor: Colors.red,
                      onConfirm: _deleteAccount,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConfirmDialog({
    required IconData icon,
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: confirmColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: confirmColor, size: 46),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink,
                          side: BorderSide(color: Colors.grey.shade200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          onConfirm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: Text(
                          confirmText,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<_ProfileData>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: _primaryColor),
              );
            }

            if (snapshot.hasError) {
              return _errorState(snapshot.error.toString());
            }

            final profile = snapshot.data ?? _ProfileData.empty();
            return RefreshIndicator(
              color: _primaryColor,
              onRefresh: () {
                _refreshProfile();
                return _profileFuture;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
                children: [
                  _profileHeader(profile),
                  if (profile.isAdmin &&
                      profile.email.trim().toLowerCase() !=
                          'support@zidash.com') ...[
                    const SizedBox(height: 12),
                    _adminShortcutCard(),
                  ],
                  const SizedBox(height: 12),
                  _headerImagePanel(profile),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _statCard(
                        profile.listingsCount.toString(),
                        'Items Listed',
                        Icons.inventory_2_outlined,
                        onTap: _openMyListings,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        profile.trustScore.toString(),
                        'Trust Score',
                        Icons.star_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _sectionTitle('Contact Verification'),
                  const SizedBox(height: 10),
                  _verificationPanel(profile),
                  const SizedBox(height: 28),
                  _sectionTitle('Seller Hub'),
                  const SizedBox(height: 8),
                  _menuTile(
                    Icons.storefront_outlined,
                    'My Store Dashboard',
                    'Analyze your sales and traffic',
                    onTap: _openStoreDashboard,
                  ),
                  _menuTile(
                    Icons.forum_outlined,
                    'My Community Posts',
                    'Edit or delete posts shared in communities',
                    onTap: _openMyCommunityPosts,
                  ),
                  _menuTile(
                    Icons.work_outline_rounded,
                    'My Job Posts',
                    'Update, close, reopen or delete posted jobs',
                    onTap: _openMyJobPosts,
                  ),

                  const SizedBox(height: 24),
                  _sectionTitle('Settings'),
                  const SizedBox(height: 8),
                  _menuTile(
                    Icons.location_on_rounded,
                    'Location Settings',
                    profile.location == null || profile.location!.trim().isEmpty
                        ? 'Update to your current location'
                        : profile.location!,
                    onTap: () => _openLocationScreen(profile),
                  ),
                  // _menuTile(
                  //   Icons.notifications_none_outlined,
                  //   'Notification Settings',
                  //   'Manage alerts and emails',
                  // ),
                  _menuTile(
                    Icons.security_outlined,
                    'Legal - policy',
                    'Legal and privacy policy',
                    onTap: _openPrivacyPolicy,
                  ),
                  _menuTile(
                    Icons.delete,
                    'Danger zone',
                    'Delete account, logout',
                    onTap: _showDangerZoneSheet,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42, color: _muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _refreshProfile,
              style: FilledButton.styleFrom(backgroundColor: _primaryColor),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader(_ProfileData profile) {
    final hasAvatar = profile.avatarUrl != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F5),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isUploadingAvatar
                ? null
                : () => _handleAvatarAction(profile),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 43,
                  backgroundColor: Colors.white,
                  backgroundImage: !hasAvatar
                      ? null
                      : NetworkImage(profile.avatarUrl!),
                  child: !hasAvatar
                      ? Text(
                          profile.initials,
                          style: const TextStyle(
                            color: _primaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                if (_isUploadingAvatar)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: hasAvatar ? Colors.red : _primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isUploadingAvatar
                          ? Icons.hourglass_top
                          : hasAvatar
                          ? Icons.delete_outline_rounded
                          : Icons.edit,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _balancePill(profile.balanceLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balancePill(String balance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: _primaryColor,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            'Balance $balance',
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerImagePanel(_ProfileData profile) {
    final hasCover =
        profile.coverImageUrl != null &&
        profile.coverImageUrl!.trim().isNotEmpty;
    return InkWell(
      onTap: _isUploadingCover ? null : _uploadHeaderImage,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: _softDecoration(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2.7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCover)
                    Image.network(
                      profile.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _coverPlaceholder(),
                    )
                  else
                    _coverPlaceholder(),
                  Container(color: Colors.black.withValues(alpha: 0.12)),
                  Center(
                    child: _isUploadingCover
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: Colors.white,
                                  size: 17,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hasCover
                                      ? 'Change header image'
                                      : 'Upload header image',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: _softIconDecoration(13),
                    child: const Icon(
                      Icons.photo_size_select_actual_outlined,
                      color: _ink,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Public profile header',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Shown on your seller profile storefront',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminShortcutCard() {
    return InkWell(
      onTap: _openAdminPanel,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF172317),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Manage users, listings, payments and verifications',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xB3FFFFFF),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF153D2C), Color(0xFF66C665)],
        ),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Icon(
          Icons.storefront_outlined,
          color: Colors.white.withValues(alpha: 0.18),
          size: 92,
        ),
      ),
    );
  }

  Widget _verificationPanel(_ProfileData profile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _softDecoration(20),
      child: Column(
        children: [
          _verificationItem(
            icon: Icons.person_outline_rounded,
            title: 'Full Name',
            status: profile.hasName ? 'Added' : 'Missing',
            color: profile.hasName ? Colors.green : Colors.orange,
            onTap: () => _openNameVerification(profile),
          ),
          const SizedBox(height: 12),
          _verificationItem(
            icon: Icons.email_outlined,
            title: 'Email Address',
            status: profile.emailVerified ? 'Verified' : 'Not verified',
            color: profile.emailVerified ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 12),
          _verificationItem(
            icon: Icons.phone_android,
            title: 'Phone Number',
            status: profile.phoneVerified ? 'Verified' : 'Not verified',
            color: profile.phoneVerified ? Colors.green : Colors.orange,
            onTap: profile.phoneVerified
                ? null
                : () => _openPhoneVerification(profile),
          ),
        ],
      ),
    );
  }

  Widget _verificationItem({
    required IconData icon,
    required String title,
    required String status,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: _softIconDecoration(13),
              child: Icon(icon, size: 22, color: _ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            _statusPill(status, color),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    String value,
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _softDecoration(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _primaryColor, size: 22),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _muted,
                      size: 18,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _dangerSheetAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _softDecoration(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: _softIconDecoration(14),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _softDecoration(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: _softIconDecoration(14),
                child: Icon(icon, color: _ink, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  BoxDecoration _softDecoration(double radius) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.045),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: _primaryColor.withValues(alpha: 0.035),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  BoxDecoration _softIconDecoration(double radius) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.035),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.initials,
    required this.hasName,
    required this.trustScore,
    required this.emailVerified,
    required this.phoneVerified,
    required this.listingsCount,
    required this.isAdmin,
    required this.walletBalance,
    this.phone,
    this.avatarUrl,
    this.location,
    this.coverImageUrl,
  });

  final String name;
  final String firstName;
  final String lastName;
  final String email;
  final String initials;
  final String? phone;
  final String? avatarUrl;
  final String? location;
  final String? coverImageUrl;
  final bool hasName;
  final int trustScore;
  final bool emailVerified;
  final bool phoneVerified;
  final int listingsCount;
  final bool isAdmin;
  final num walletBalance;

  factory _ProfileData.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final sellerProfile =
        (json['sellerProfile'] as Map?)?.cast<String, dynamic>() ?? {};
    final firstName = user['firstName']?.toString() ?? '';
    final lastName = user['lastName']?.toString() ?? '';
    final displayName = sellerProfile['displayName']?.toString();
    final wallet = (json['walletBalance'] as Map?)?.cast<String, dynamic>();
    final accountName = '$firstName $lastName'.trim();
    final name = accountName.isNotEmpty
        ? accountName
        : (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : '';

    return _ProfileData(
      name: name.isEmpty ? 'Zidash User' : name,
      firstName: firstName,
      lastName: lastName,
      email: user['email']?.toString() ?? '',
      initials: _initials(firstName, lastName, name),
      phone: user['phone']?.toString(),
      avatarUrl: _nullableText(user['avatarUrl']),
      location: sellerProfile['location']?.toString(),
      coverImageUrl: _nullableText(sellerProfile['coverImageUrl']),
      hasName: firstName.trim().isNotEmpty && lastName.trim().isNotEmpty,
      trustScore: _intValue(sellerProfile['trustScore'], fallback: 60),
      emailVerified: user['emailVerifiedAt'] != null,
      phoneVerified: user['phoneVerifiedAt'] != null,
      listingsCount: _intValue(json['listingsCount'], fallback: 0),
      isAdmin: _isAdminRole(user['role']?.toString()),
      walletBalance: _numValue(wallet?['availableBalance']),
    );
  }

  factory _ProfileData.empty() {
    return const _ProfileData(
      name: 'Zidash User',
      firstName: '',
      lastName: '',
      email: '',
      initials: 'ZU',
      hasName: false,
      trustScore: 60,
      emailVerified: false,
      phoneVerified: false,
      listingsCount: 0,
      isAdmin: false,
      walletBalance: 0,
    );
  }

  String get balanceLabel {
    final amount = walletBalance.round();
    return '₦${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
  }

  static String _initials(String firstName, String lastName, String name) {
    final parts = [
      firstName,
      lastName,
    ].where((value) => value.trim().isNotEmpty).toList();
    final source = parts.isEmpty ? name.split(RegExp(r'\s+')) : parts;
    final letters = source
        .where((value) => value.trim().isNotEmpty)
        .take(2)
        .map((value) => value.trim()[0].toUpperCase())
        .join();
    return letters.isEmpty ? 'ZU' : letters;
  }

  static int _intValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static num _numValue(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}

bool _isAdminRole(String? role) => role?.trim().toLowerCase() == 'admin';
