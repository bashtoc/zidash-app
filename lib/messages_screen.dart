import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6F7F6);

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<_ConversationPreview>> _conversationsFuture;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _loadConversations();
  }

  Future<List<_ConversationPreview>> _loadConversations() async {
    final items = await ApiService.instance.conversations();
    return items
        .whereType<Map>()
        .map(
          (item) => _ConversationPreview.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  void _refresh() {
    setState(() {
      _conversationsFuture = _loadConversations();
    });
  }

  Future<void> _openChat(_ConversationPreview conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation.id,
          title: conversation.name,
          avatarUrl: conversation.avatarUrl,
          listing: conversation.listing,
          sellerId: conversation.sellerId,
        ),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
      ),
      body: FutureBuilder<List<_ConversationPreview>>(
        future: _conversationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }
          if (snapshot.hasError) {
            return _state(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load messages',
              message: snapshot.error.toString(),
              action: _refresh,
            );
          }
          final conversations = snapshot.data ?? [];
          if (conversations.isEmpty) {
            return _state(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No messages yet',
              message:
                  'When you message a seller, the conversation appears here.',
              action: _refresh,
            );
          }
          return RefreshIndicator(
            color: _primaryColor,
            onRefresh: () async {
              _refresh();
              await _conversationsFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemBuilder: (context, index) =>
                  _conversationTile(conversations[index]),
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: conversations.length,
            ),
          );
        },
      ),
    );
  }

  Widget _conversationTile(_ConversationPreview conversation) {
    final hasUnread = conversation.unreadCount > 0;
    return InkWell(
      onTap: () => _openChat(conversation),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9EDE9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: _surface,
                  backgroundImage: conversation.avatarUrl == null
                      ? null
                      : NetworkImage(conversation.avatarUrl!),
                  child: conversation.avatarUrl == null
                      ? Text(
                          conversation.initials,
                          style: const TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: hasUnread
                                ? FontWeight.w900
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (conversation.timeLabel.isNotEmpty)
                        Text(
                          conversation.timeLabel,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasUnread ? _ink : _muted,
                      fontSize: 13,
                      fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (conversation.listingImageUrl != null) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  conversation.listingImageUrl!,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 42,
                    height: 42,
                    color: _surface,
                    child: const Icon(Icons.image_outlined, color: _muted),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _state({
    required IconData icon,
    required String title,
    required String message,
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

class _ConversationPreview {
  const _ConversationPreview({
    required this.id,
    required this.name,
    required this.initials,
    required this.lastMessage,
    required this.unreadCount,
    required this.timeLabel,
    this.avatarUrl,
    this.listingImageUrl,
    this.listing,
    this.sellerId,
  });

  final String id;
  final String name;
  final String initials;
  final String lastMessage;
  final int unreadCount;
  final String timeLabel;
  final String? avatarUrl;
  final String? listingImageUrl;
  final Map<String, dynamic>? listing;
  final String? sellerId;

  factory _ConversationPreview.fromJson(Map<String, dynamic> json) {
    final other = (json['otherUser'] as Map?)?.cast<String, dynamic>() ?? {};
    final sellerProfile = (other['sellerProfile'] as Map?)
        ?.cast<String, dynamic>();
    final listing = (json['listing'] as Map?)?.cast<String, dynamic>();
    final lastMessage = (json['lastMessage'] as Map?)?.cast<String, dynamic>();
    final name = _name(other);
    final images = listing?['images'] as List?;
    String? listingImage;
    if (images != null && images.isNotEmpty && images.first is Map) {
      listingImage = (images.first as Map)['url']?.toString();
    }
    return _ConversationPreview(
      id: json['id']?.toString() ?? '',
      name: name,
      initials: _initials(name),
      avatarUrl: _nullable(other['avatarUrl']),
      lastMessage: _messageText(lastMessage),
      unreadCount: int.tryParse('${json['unreadCount'] ?? 0}') ?? 0,
      timeLabel: _timeLabel(lastMessage?['createdAt'] ?? json['lastMessageAt']),
      listingImageUrl: _nullable(listingImage),
      listing: listing,
      sellerId: _nullable(sellerProfile?['id']),
    );
  }

  static String _name(Map<String, dynamic> user) {
    final first = user['firstName']?.toString() ?? '';
    final last = user['lastName']?.toString() ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Zidash user' : name;
  }

  static String _messageText(Map<String, dynamic>? message) {
    if (message == null) return 'Conversation started';
    final body = message['body']?.toString().trim() ?? '';
    if (body.isNotEmpty) return body;
    return switch (message['type']?.toString()) {
      'image' => 'Image',
      'voice' => 'Voice message',
      'product' => 'Product',
      _ => 'Message',
    };
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

  static String _timeLabel(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return '';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  static String? _nullable(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
