import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'auth_required_dialog.dart';
import 'chat_screen.dart';
import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6F7F6);

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  static const _locations = [
    'All',
    'Lagos, NG',
    'Abuja, NG',
    'Port Harcourt, NG',
    'Ibadan, NG',
  ];

  String _location = 'All';
  late Future<List<_CommunityPost>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts();
  }

  Future<List<_CommunityPost>> _loadPosts() async {
    final posts = await ApiService.instance.communityPosts(location: _location);
    return posts
        .map(
          (post) =>
              _CommunityPost.fromJson((post as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  void _refresh() {
    setState(() {
      _postsFuture = _loadPosts();
    });
  }

  Future<void> _toggleLike(_CommunityPost post) async {
    final allowed = await requireAuthenticated(
      context,
      title: 'Sign up to like posts',
      message:
          'Create an account to react to community posts and keep your activity saved.',
    );
    if (!allowed) return;
    try {
      await ApiService.instance.toggleCommunityPostLike(post.id);
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openPostSheet() async {
    final allowed = await requireAuthenticated(
      context,
      title: 'Sign up to post in communities',
      message:
          'Create an account to post items for sale and connect with buyers.',
    );
    if (!allowed || !mounted) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF8FAF8),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _CreateCommunityPostSheet(),
    );
    if (created == true) _refresh();
  }

  void _openFilterSheet() {
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
                  'Filter by location',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ..._locations.map(
                  (location) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      location,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: _location == location
                        ? const Icon(Icons.check_circle, color: _primaryColor)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _location = location);
                      _refresh();
                    },
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text(
              'Communities',
              style: TextStyle(
                color: _ink,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              _location == 'All' ? 'All locations' : _location,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: _openFilterSheet,
            icon: const Icon(Icons.tune_rounded, color: _ink),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPostSheet,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Post item',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<List<_CommunityPost>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }
          if (snapshot.hasError) {
            return _emptyState(
              Icons.cloud_off_rounded,
              'Could not load community posts',
              snapshot.error.toString(),
            );
          }
          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return _emptyState(
              Icons.forum_outlined,
              'No community posts yet',
              'Post an item for sale or change your location filter.',
            );
          }
          return RefreshIndicator(
            color: _primaryColor,
            onRefresh: () async {
              _refresh();
              await _postsFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _postCard(posts[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _postCard(_CommunityPost post) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _surface,
                backgroundImage: post.authorAvatar == null
                    ? null
                    : NetworkImage(post.authorAvatar!),
                child: post.authorAvatar == null
                    ? Text(
                        post.authorInitials,
                        style: const TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (post.authorVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${post.location} • ${post.timeLabel}',
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
            ],
          ),
          const SizedBox(height: 12),
          if (post.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                post.imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            post.title,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'NGN ${post.priceLabel}',
            style: const TextStyle(
              color: _primaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (post.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              post.description,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _actionButton(
                icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
                label: post.likesCount.toString(),
                color: post.likedByMe ? Colors.red : _muted,
                onTap: () => _toggleLike(post),
              ),
              const SizedBox(width: 8),
              _actionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Message',
                color: _ink,
                onTap: () async {
                  final allowed = await requireAuthenticated(
                    context,
                    title: 'Sign up to message sellers',
                    message:
                        'Create an account to start conversations and keep your chats saved.',
                  );
                  if (!allowed || !mounted) return;
                  try {
                    final conversation = await ApiService.instance
                        .startConversation(sellerId: post.authorId);
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          conversationId: conversation['id']?.toString(),
                          title: post.authorName,
                          avatarUrl: post.authorAvatar,
                          sellerId: post.authorId,
                        ),
                      ),
                    );
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: _muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateCommunityPostSheet extends StatefulWidget {
  const _CreateCommunityPostSheet();

  @override
  State<_CreateCommunityPostSheet> createState() =>
      _CreateCommunityPostSheetState();
}

class _CreateCommunityPostSheetState extends State<_CreateCommunityPostSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _location;
  String? _locationError;
  String? _submitError;
  _CommunityPostImage? _image;
  bool _isLoadingLocation = true;
  bool _isProcessingImage = false;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadProfileLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileLocation() async {
    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
        _locationError = null;
      });
    }
    try {
      final profile = await ApiService.instance.bootstrap();
      final sellerProfile = (profile['sellerProfile'] as Map?)
          ?.cast<String, dynamic>();
      final location = sellerProfile?['location']?.toString().trim();
      if (!mounted) return;
      setState(() {
        _location = location == null || location.isEmpty ? null : location;
        _locationError = _location == null
            ? 'Add a location to your profile before posting.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _location = null;
        _locationError = 'Could not load your profile location.';
      });
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _pickImage() async {
    if (_isProcessingImage || _isPosting) return;
    setState(() {
      _isProcessingImage = true;
      _submitError = null;
    });
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked == null) return;
      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 1600,
        minHeight: 1600,
        quality: 78,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (compressed == null || compressed.isEmpty) {
        throw ApiException('Could not process that image. Try another one.');
      }
      if (!mounted) return;
      setState(() {
        _image = _CommunityPostImage(
          bytes: Uint8List.fromList(compressed),
          filename: 'community-${DateTime.now().millisecondsSinceEpoch}.webp',
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.toString());
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  Future<void> _post() async {
    if (!_formKey.currentState!.validate()) return;
    final location = _location;
    if (location == null || location.isEmpty) {
      setState(
        () => _submitError =
            'Set your location in Profile, then return here to post.',
      );
      return;
    }
    setState(() {
      _isPosting = true;
      _submitError = null;
    });
    try {
      String? imageUrl;
      final image = _image;
      if (image != null) {
        final urls = await ApiService.instance.uploadImages([
          UploadFilePayload(bytes: image.bytes, filename: image.filename),
        ]);
        if (urls.isEmpty) throw ApiException('Image upload did not complete.');
        imageUrl = urls.first;
      }
      await ApiService.instance.createCommunitySalePost({
        'title': _titleController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'description': _descriptionController.text.trim(),
        'imageUrl': ?imageUrl,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.toString());
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share something with your community',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel('Item photo', optional: true),
                    const SizedBox(height: 9),
                    _imagePickerCard(),
                    const SizedBox(height: 22),
                    _sectionLabel('Item details'),
                    const SizedBox(height: 9),
                    _field(
                      _titleController,
                      'Item title',
                      hint: 'What are you selling?',
                      icon: Icons.inventory_2_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _priceController,
                      'Price',
                      hint: '0.00',
                      icon: Icons.payments_outlined,
                      prefixText: '₦ ',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _descriptionController,
                      'Description',
                      hint: 'Describe the condition, features and details',
                      icon: Icons.notes_rounded,
                      minLines: 4,
                      requiredField: false,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 22),
                    _sectionLabel('Posting location'),
                    const SizedBox(height: 9),
                    _locationCard(),
                    if (_submitError != null) ...[
                      const SizedBox(height: 16),
                      _errorBanner(_submitError!),
                    ],
                  ],
                ),
              ),
            ),
            _submitBar(bottomInset > 0),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Post item for sale',
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton.filled(
            tooltip: 'Close',
            onPressed: _isPosting ? null : () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFEDEFED),
              foregroundColor: _ink,
              disabledBackgroundColor: const Color(0xFFEDEFED),
            ),
            icon: const Icon(Icons.close_rounded, size: 21),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, {bool optional = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          const Text(
            'Optional',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _imagePickerCard() {
    final image = _image;
    if (image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 190,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(image.bytes, fit: BoxFit.cover),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton.filled(
                  tooltip: 'Remove photo',
                  onPressed: _isPosting
                      ? null
                      : () => setState(() => _image = null),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.62),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: _isProcessingImage ? null : _pickImage,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 126,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE3DC)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessingImage)
              const SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(
                  color: _primaryColor,
                  strokeWidth: 2.4,
                ),
              )
            else
              const Icon(
                Icons.add_photo_alternate_outlined,
                color: _primaryColor,
                size: 30,
              ),
            const SizedBox(height: 9),
            Text(
              _isProcessingImage ? 'Preparing photo...' : 'Add a product photo',
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationCard() {
    final hasError = !_isLoadingLocation && _location == null;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError ? const Color(0xFFE7B4B4) : const Color(0xFFDCE3DC),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFEDF8ED),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_outlined, color: _primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoadingLocation
                      ? 'Loading profile location...'
                      : _location ?? 'Location unavailable',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isLoadingLocation
                      ? 'Checking your Zidash profile'
                      : _locationError ?? 'From your Zidash profile',
                  style: TextStyle(
                    color: hasError ? const Color(0xFFB34A4A) : _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingLocation)
            const SizedBox.square(
              dimension: 19,
              child: CircularProgressIndicator(
                color: _primaryColor,
                strokeWidth: 2,
              ),
            )
          else if (hasError)
            IconButton(
              tooltip: 'Retry',
              onPressed: _loadProfileLocation,
              icon: const Icon(Icons.refresh_rounded, color: _ink),
            )
          else
            const Icon(Icons.lock_outline_rounded, color: _muted, size: 19),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB34A4A)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8E3636),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitBar(bool keyboardVisible) {
    if (keyboardVisible) return const SizedBox.shrink();
    final disabled =
        _isPosting ||
        _isProcessingImage ||
        _isLoadingLocation ||
        _location == null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8ECE8))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: disabled ? null : _post,
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFC9D8C9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            icon: _isPosting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 20),
            label: Text(
              _isPosting ? 'Posting...' : 'Post to Community',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    IconData? icon,
    String? prefixText,
    int minLines = 1,
    bool requiredField = true,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : 5,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: _ink,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, size: 21),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: _ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        labelStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
        floatingLabelStyle: const TextStyle(
          color: _primaryColor,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFFA3AAA3),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: minLines == 1 ? 17 : 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFDCE3DC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFDCE3DC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: _primaryColor, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFD45C5C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFD45C5C), width: 1.7),
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (requiredField && text.isEmpty) return '$label is required';
        if (label == 'Item title' && text.isNotEmpty && text.length < 3) {
          return 'Use at least 3 characters';
        }
        if (label == 'Price' && double.tryParse(text) == null) {
          return 'Enter a valid price';
        }
        if (label == 'Price' && (double.tryParse(text) ?? -1) < 0) {
          return 'Price cannot be negative';
        }
        return null;
      },
    );
  }
}

class _CommunityPostImage {
  const _CommunityPostImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

class _CommunityPost {
  const _CommunityPost({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.likesCount,
    required this.likedByMe,
    required this.authorName,
    required this.authorId,
    required this.authorInitials,
    required this.authorVerified,
    required this.createdAt,
    this.authorAvatar,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final String location;
  final int likesCount;
  final bool likedByMe;
  final String authorId;
  final String authorName;
  final String authorInitials;
  final String? authorAvatar;
  final bool authorVerified;
  final DateTime createdAt;
  final String? imageUrl;

  String get priceLabel => price.toStringAsFixed(0);

  String get timeLabel {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inMinutes < 1) return 'now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
    return '${elapsed.inDays}d ago';
  }

  factory _CommunityPost.fromJson(Map<String, dynamic> json) {
    final data = _parseBody(json['body']?.toString());
    final author = (json['author'] as Map?)?.cast<String, dynamic>() ?? {};
    final firstName = author['firstName']?.toString() ?? '';
    final lastName = author['lastName']?.toString() ?? '';
    final media = json['media'];
    final firstMedia = media is List && media.isNotEmpty
        ? (media.first as Map).cast<String, dynamic>()
        : null;
    final authorName = '$firstName $lastName'.trim();
    return _CommunityPost(
      id: json['id']?.toString() ?? '',
      title: data.title,
      description: data.description,
      price: data.price,
      location: json['location']?.toString() ?? 'Lagos, NG',
      likesCount: int.tryParse(json['likesCount']?.toString() ?? '') ?? 0,
      likedByMe: json['likedByMe'] == true,
      authorName: authorName.isEmpty ? 'Zidash User' : authorName,
      authorId: author['id']?.toString() ?? '',
      authorInitials: _initials(firstName, lastName),
      authorAvatar: author['avatarUrl']?.toString(),
      authorVerified: author['identityVerifiedAt'] != null,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      imageUrl: firstMedia?['url']?.toString(),
    );
  }

  static _PostBody _parseBody(String? body) {
    if (body == null || body.isEmpty) return const _PostBody();
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return _PostBody(
        title: decoded['title']?.toString() ?? 'Item for sale',
        description: decoded['description']?.toString() ?? '',
        price: double.tryParse(decoded['price']?.toString() ?? '') ?? 0,
      );
    } catch (_) {
      return _PostBody(title: body, description: '', price: 0);
    }
  }

  static String _initials(String firstName, String lastName) {
    final letters = [firstName, lastName]
        .where((name) => name.trim().isNotEmpty)
        .take(2)
        .map((name) => name.trim()[0].toUpperCase())
        .join();
    return letters.isEmpty ? 'ZU' : letters;
  }
}

class _PostBody {
  const _PostBody({
    this.title = 'Item for sale',
    this.description = '',
    this.price = 0,
  });

  final String title;
  final String description;
  final double price;
}
