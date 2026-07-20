import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------
const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6FBF6);
const _adminAccent = Color(0xFFDC2626);

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------
class _AdminUser {
  const _AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isBlocked,
    required this.listingsCount,
    required this.createdAt,
  });

  factory _AdminUser.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName'] as String? ?? '';
    final lastName = json['lastName'] as String? ?? '';
    final displayName = json['displayName'] as String? ?? '';

    String name;
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      name = '${firstName} ${lastName}'.trim();
    } else if (displayName.isNotEmpty) {
      name = displayName;
    } else {
      name = 'Unknown User';
    }

    return _AdminUser(
      id: json['id'] as String? ?? '',
      name: name,
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      isBlocked: json['blocked'] == true || json['status'] == 'blocked',
      listingsCount: json['listingsCount'] as int? ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  final String id;
  final String name;
  final String email;
  final String role;
  final bool isBlocked;
  final int listingsCount;
  final String createdAt;

  String get joinedLabel {
    final joinedAt = DateTime.tryParse(createdAt);
    if (joinedAt == null) return createdAt.isNotEmpty ? createdAt : '—';
    return DateFormat('MMM d, yyyy').format(joinedAt.toLocal());
  }

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return 'U';
    if (words.length == 1) {
      return words[0].isNotEmpty ? words[0][0].toUpperCase() : 'U';
    }
    final a = words[0].isNotEmpty ? words[0][0].toUpperCase() : '';
    final b = words[1].isNotEmpty ? words[1][0].toUpperCase() : '';
    final result = '$a$b';
    return result.isNotEmpty ? result : 'U';
  }

  _AdminUser copyWith({bool? isBlocked}) => _AdminUser(
    id: id,
    name: name,
    email: email,
    role: role,
    isBlocked: isBlocked ?? this.isBlocked,
    listingsCount: listingsCount,
    createdAt: createdAt,
  );
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();

  List<_AdminUser> _users = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  Timer? _debounce;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Data loading
  // -------------------------------------------------------------------------
  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _users = [];
        _currentPage = 1;
        _hasMore = true;
        _hasError = false;
        _errorMessage = '';
        _isLoading = true;
      });
    }

    try {
      final response = await ApiService.instance.adminUsers(
        page: _currentPage,
        query: _searchQuery,
      );

      final items = response['items'] as List? ?? [];
      final parsed = items
          .map((e) => _AdminUser.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        if (reset || _currentPage == 1) {
          _users = parsed;
        } else {
          _users = [..._users, ...parsed];
        }
        _hasMore = parsed.length >= 20;
        _currentPage++;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // -------------------------------------------------------------------------
  // Search
  // -------------------------------------------------------------------------
  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _searchQuery = value);
      _load(reset: true);
    });
  }

  // -------------------------------------------------------------------------
  // Pagination
  // -------------------------------------------------------------------------
  Future<void> _onScrollNearEnd() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    await _load();
    setState(() => _isLoadingMore = false);
  }

  // -------------------------------------------------------------------------
  // Block / Unblock
  // -------------------------------------------------------------------------
  Future<void> _blockUser(_AdminUser user) async {
    final willBlock = !user.isBlocked;
    final action = willBlock ? 'Block' : 'Unblock';
    final body = willBlock
        ? 'This user will no longer be able to access the platform.'
        : 'This user will regain access to the platform.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$action ${user.name}?'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willBlock ? _adminAccent : _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.instance.adminSetUserBlocked(
        user.id,
        blocked: willBlock,
      );
      setState(() {
        final idx = _users.indexWhere((u) => u.id == user.id);
        if (idx != -1) {
          _users[idx] = _users[idx].copyWith(isBlocked: willBlock);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.name} has been ${willBlock ? 'blocked' : 'unblocked'}.',
            ),
            backgroundColor: willBlock ? _adminAccent : _primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: _adminAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // User detail bottom sheet
  // -------------------------------------------------------------------------
  void _openUserDetail(_AdminUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _UserDetailSheet(
        user: user,
        onBlockToggle: () {
          Navigator.pop(ctx);
          _blockUser(user);
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: const TextStyle(color: _ink, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search users by name or email',
                hintStyle: const TextStyle(color: _muted, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: _muted, size: 20),
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: _primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // List area
          Flexible(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _users.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    if (_hasError && _users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _adminAccent, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage,
                style: const TextStyle(color: _muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, color: _muted, size: 52),
            const SizedBox(height: 12),
            const Text(
              'No users found',
              style: TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try a different search term.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length + 1, // +1 for footer
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _users.length) {
          return _buildListFooter();
        }
        return _buildUserTile(_users[index]);
      },
    );
  }

  Widget _buildListFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _primaryColor,
            ),
          ),
        ),
      );
    }
    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton(
            onPressed: _onScrollNearEnd,
            style: TextButton.styleFrom(foregroundColor: _primaryColor),
            child: const Text(
              'Load more',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 16);
  }

  Widget _buildUserTile(_AdminUser user) {
    return GestureDetector(
      onTap: () => _openUserDetail(user),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: user.isBlocked ? Colors.red[100] : _surface,
              child: Text(
                user.initials,
                style: TextStyle(
                  color: user.isBlocked ? _adminAccent : _primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name / email / listings
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.role == 'admin') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _adminAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _adminAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.email,
                    style: const TextStyle(fontSize: 12, color: _muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${user.listingsCount} listings',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Status badge + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusBadge(isBlocked: user.isBlocked),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: _muted, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge helper widget
// ---------------------------------------------------------------------------
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isBlocked});

  final bool isBlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isBlocked
            ? _adminAccent.withValues(alpha: 0.1)
            : _primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isBlocked ? 'Blocked' : 'Active',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isBlocked ? _adminAccent : _primaryColor,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User detail bottom sheet
// ---------------------------------------------------------------------------
class _UserDetailSheet extends StatelessWidget {
  const _UserDetailSheet({required this.user, required this.onBlockToggle});

  final _AdminUser user;
  final VoidCallback onBlockToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          const SizedBox(height: 16),

          // Header row
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: user.isBlocked ? Colors.red[100] : _surface,
                child: Text(
                  user.initials,
                  style: TextStyle(
                    color: user.isBlocked ? _adminAccent : _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(fontSize: 13, color: _muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Info rows
          _InfoRow(label: 'Role', value: _capitalize(user.role)),
          const SizedBox(height: 8),
          _InfoRow(label: 'Listings', value: user.listingsCount.toString()),
          const SizedBox(height: 8),
          _InfoRow(label: 'Joined', value: user.joinedLabel),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Status',
            value: user.isBlocked ? 'Blocked' : 'Active',
            valueColor: user.isBlocked ? _adminAccent : _primaryColor,
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              if (user.role != 'admin') ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onBlockToggle,
                    icon: Icon(
                      user.isBlocked
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded,
                      size: 18,
                    ),
                    label: Text(user.isBlocked ? 'Unblock' : 'Block'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: user.isBlocked
                          ? _primaryColor
                          : _adminAccent,
                      side: BorderSide(
                        color: user.isBlocked ? _primaryColor : _adminAccent,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _surface,
                    foregroundColor: _ink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
}

// ---------------------------------------------------------------------------
// Info row helper
// ---------------------------------------------------------------------------
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = _ink,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _muted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
