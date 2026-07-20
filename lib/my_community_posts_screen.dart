import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6FBF6);

class MyCommunityPostsScreen extends StatefulWidget {
  const MyCommunityPostsScreen({super.key});

  @override
  State<MyCommunityPostsScreen> createState() => _MyCommunityPostsScreenState();
}

class _MyCommunityPostsScreenState extends State<MyCommunityPostsScreen> {
  late Future<List<_CommunityPostItem>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts();
  }

  Future<List<_CommunityPostItem>> _loadPosts() async {
    final posts = await ApiService.instance.myCommunityPosts();
    return posts
        .map((post) => _CommunityPostItem.fromJson((post as Map).cast<String, dynamic>()))
        .toList();
  }

  void _refresh() {
    setState(() => _postsFuture = _loadPosts());
  }

  Future<void> _editPost(_CommunityPostItem post) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _EditCommunityPostSheet(post: post),
    );
    if (updated == true) _refresh();
  }

  Future<void> _deletePost(_CommunityPostItem post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete community post?'),
        content: Text('This removes "${post.title}" from the community page.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance.deleteMyCommunityPost(post.id);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Community post deleted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
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
          'My community posts',
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: FutureBuilder<List<_CommunityPostItem>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }
          if (snapshot.hasError) {
            return _state(
              Icons.cloud_off_rounded,
              'Could not load posts',
              snapshot.error.toString(),
              action: _refresh,
            );
          }
          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return _state(
              Icons.forum_outlined,
              'No community posts',
              'Posts you share in the community page will appear here.',
              action: _refresh,
            );
          }
          return RefreshIndicator(
            color: _primaryColor,
            onRefresh: () async {
              _refresh();
              await _postsFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _postCard(posts[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _postCard(_CommunityPostItem post) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDE9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: post.imageUrl == null
                ? Container(
                    width: 58,
                    height: 58,
                    color: _surface,
                    child: const Icon(Icons.forum_outlined, color: _ink),
                  )
                : Image.network(
                    post.imageUrl!,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 58,
                      height: 58,
                      color: _surface,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  post.priceLabel,
                  style: const TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (post.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${post.location} • ${post.likesCount} likes',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _editPost(post);
              if (value == 'delete') _deletePost(post);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _state(
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _muted, size: 44),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: action,
              style: FilledButton.styleFrom(backgroundColor: _primaryColor),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditCommunityPostSheet extends StatefulWidget {
  const _EditCommunityPostSheet({required this.post});

  final _CommunityPostItem post;

  @override
  State<_EditCommunityPostSheet> createState() => _EditCommunityPostSheetState();
}

class _EditCommunityPostSheetState extends State<_EditCommunityPostSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _priceController = TextEditingController(
      text: widget.post.price.toStringAsFixed(0),
    );
    _descriptionController = TextEditingController(
      text: widget.post.description,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ApiService.instance.updateMyCommunityPost(widget.post.id, {
        'title': _titleController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'description': _descriptionController.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomInset),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit community post',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                _field(
                  _titleController,
                  'Title',
                  validator: (value) {
                    if ((value ?? '').trim().length < 3) {
                      return 'Enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  _priceController,
                  'Price',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    final price = double.tryParse((value ?? '').trim());
                    if (price == null || price < 0) return 'Enter a valid price';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(_descriptionController, 'Description', maxLines: 4),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isSaving ? 'Saving...' : 'Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8E2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryColor),
        ),
      ),
    );
  }
}

class _CommunityPostItem {
  const _CommunityPostItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.likesCount,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final String location;
  final int likesCount;
  final String? imageUrl;

  String get priceLabel {
    final formatted = price
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    return 'NGN $formatted';
  }

  factory _CommunityPostItem.fromJson(Map<String, dynamic> json) {
    final data = _parseBody(json['body']?.toString());
    final media = json['media'];
    final firstMedia = media is List && media.isNotEmpty
        ? (media.first as Map).cast<String, dynamic>()
        : null;
    return _CommunityPostItem(
      id: json['id']?.toString() ?? '',
      title: data.title,
      description: data.description,
      price: data.price,
      location: json['location']?.toString() ?? 'Lagos, NG',
      likesCount: int.tryParse(json['likesCount']?.toString() ?? '') ?? 0,
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
