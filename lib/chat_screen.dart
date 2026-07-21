import 'package:flutter/material.dart';

import 'product_detail_screen.dart';
import 'seller_profile_screen.dart';
import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _bubbleColor = Color(0xFF004D40);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6F7F6);

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.conversationId,
    required this.title,
    this.avatarUrl,
    this.listing,
    this.sellerId,
    this.listingId,
  });

  final String? conversationId;
  final String title;
  final String? avatarUrl;
  final Map<String, dynamic>? listing;
  final String? sellerId;
  final String? listingId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Future<_ChatData> _chatFuture;
  String? _conversationId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _chatFuture = _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<_ChatData> _loadMessages() async {
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty) {
      return _ChatData(
        currentUserId: ApiService.instance.currentUserId,
        conversation: const {},
        messages: const [],
      );
    }
    final response = await ApiService.instance.conversationMessages(
      conversationId,
    );
    final conversation =
        (response['conversation'] as Map?)?.cast<String, dynamic>() ?? {};
    final messages = (response['messages'] as List? ?? [])
        .whereType<Map>()
        .map((item) => _ChatMessage.fromJson(item.cast<String, dynamic>()))
        .toList();
    return _ChatData(
      currentUserId:
          response['currentUserId']?.toString() ??
          ApiService.instance.currentUserId,
      conversation: conversation,
      messages: messages,
    );
  }

  void _refresh() {
    setState(() {
      _chatFuture = _loadMessages();
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      final conversationId = _conversationId;
      if (conversationId == null || conversationId.isEmpty) {
        final conversation = await ApiService.instance.startConversation(
          sellerId: widget.sellerId,
          listingId: widget.listingId,
          message: text,
        );
        _conversationId = conversation['id']?.toString();
        if (_conversationId == null || _conversationId!.isEmpty) {
          throw ApiException('Conversation could not be started');
        }
      } else {
        await ApiService.instance.sendMessage(conversationId, body: text);
      }
      _controller.clear();
      _refresh();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _openSellerProfile() {
    final sellerId = widget.sellerId?.trim();
    if (sellerId == null || sellerId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SellerProfileScreen(sellerId: sellerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: widget.sellerId?.trim().isNotEmpty == true
              ? _openSellerProfile
              : null,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _surface,
                backgroundImage: widget.avatarUrl == null
                    ? null
                    : NetworkImage(widget.avatarUrl!),
                child: widget.avatarUrl == null
                    ? Text(
                        _initials(widget.title),
                        style: const TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (widget.sellerId?.trim().isNotEmpty == true)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _muted,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (widget.listing != null) _listingPreview(widget.listing!),
          Expanded(
            child: FutureBuilder<_ChatData>(
              future: _chatFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  );
                }
                if (snapshot.hasError) {
                  return _state(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load chat',
                    message: snapshot.error.toString(),
                  );
                }
                final data = snapshot.data ?? const _ChatData.empty();
                if (data.messages.isEmpty) {
                  return _state(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Start the conversation',
                    message:
                        'Send a message to keep the conversation inside Zidash.',
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );
                return RefreshIndicator(
                  color: _primaryColor,
                  onRefresh: () async {
                    _refresh();
                    await _chatFuture;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    itemCount: data.messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == data.messages.length) {
                        return _safetyBanner();
                      }
                      final message = data.messages[index];
                      return _messageBubble(
                        message,
                        isMe: message.senderId == data.currentUserId,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _inputArea(),
        ],
      ),
    );
  }

  Widget _listingPreview(Map<String, dynamic> listing) {
    final id = listing['id']?.toString();
    final title = listing['title']?.toString() ?? 'Listing';
    final price = _money(listing['price']);
    final imageUrl = _firstImage(listing);
    return InkWell(
      onTap: id == null || id.isEmpty
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(
                    listingId: id,
                    initialListing: listing,
                  ),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl == null
                  ? Container(
                      width: 44,
                      height: 44,
                      color: Colors.white,
                      child: const Icon(Icons.image_outlined, color: _muted),
                    )
                  : Image.network(
                      imageUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(_ChatMessage message, {required bool isMe}) {
    final color = isMe ? _bubbleColor : _surface;
    final textColor = isMe ? Colors.white : _ink;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isMe ? 62 : 0,
          right: isMe ? 0 : 62,
        ),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.3),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.timeLabel,
                  style: TextStyle(
                    color: isMe ? Colors.white.withValues(alpha: 0.68) : _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all, size: 13, color: Colors.white),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _safetyBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: _primaryColor, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'For your security, verify purchases, do not make payment to unverified merchants',
              style: TextStyle(
                fontSize: 12,
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 46,
              height: 46,
              child: FilledButton(
                onPressed: _isSending ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _state({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _muted, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final letters = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return letters.isEmpty ? 'ZU' : letters;
  }

  static String? _firstImage(Map<String, dynamic> listing) {
    final images = listing['images'] as List?;
    if (images == null || images.isEmpty || images.first is! Map) return null;
    final url = (images.first as Map)['url']?.toString().trim();
    return url == null || url.isEmpty ? null : url;
  }

  static String _money(Object? value) {
    final amount = num.tryParse(value?.toString() ?? '');
    if (amount == null) return 'Price on request';
    return 'NGN ${amount.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
  }
}

class _ChatData {
  const _ChatData({
    required this.currentUserId,
    required this.conversation,
    required this.messages,
  });

  const _ChatData.empty()
    : currentUserId = null,
      conversation = const {},
      messages = const [];

  final String? currentUserId;
  final Map<String, dynamic> conversation;
  final List<_ChatMessage> messages;
}

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.timeLabel,
  });

  final String id;
  final String senderId;
  final String body;
  final String timeLabel;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    return _ChatMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      timeLabel: _timeLabel(json['createdAt']),
    );
  }

  static String _timeLabel(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return '';
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}
