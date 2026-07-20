import 'package:flutter/material.dart';

import 'post_job_screen.dart';
import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6FBF6);

class MyJobPostsScreen extends StatefulWidget {
  const MyJobPostsScreen({super.key});

  @override
  State<MyJobPostsScreen> createState() => _MyJobPostsScreenState();
}

class _MyJobPostsScreenState extends State<MyJobPostsScreen> {
  final Map<String, Future<List<_JobPost>>> _futures = {};

  static const _tabs = {
    'all': 'All',
    'open': 'Open',
    'closed': 'Closed',
    'draft': 'Drafts',
  };

  @override
  void initState() {
    super.initState();
    for (final key in _tabs.keys) {
      _futures[key] = _loadJobs(key);
    }
  }

  Future<List<_JobPost>> _loadJobs(String status) async {
    final items = await ApiService.instance.myJobs(
      status: status == 'all' ? null : status,
    );
    return items
        .map((item) => _JobPost.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  void _refresh([String? status]) {
    setState(() {
      if (status == null) {
        for (final key in _tabs.keys) {
          _futures[key] = _loadJobs(key);
        }
      } else {
        _futures[status] = _loadJobs(status);
      }
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _editJob(_JobPost job) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PostJobScreen(initialJob: job.raw),
      ),
    );
    if (updated == true) _refresh();
  }

  Future<void> _deleteJob(_JobPost job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete job post?'),
        content: Text('This removes "${job.title}" from your job posts.'),
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
    await _runAction(() => ApiService.instance.deleteMyJob(job.id));
  }

  Future<void> _createJob() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const PostJobScreen()),
    );
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
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
            'My job posts',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _createJob,
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Post job',
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: _primaryColor,
            labelColor: _ink,
            unselectedLabelColor: _muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900),
            tabs: _tabs.values.map((label) => Tab(text: label)).toList(),
          ),
        ),
        body: TabBarView(
          children: _tabs.keys.map((status) => _tabBody(status)).toList(),
        ),
      ),
    );
  }

  Widget _tabBody(String status) {
    return FutureBuilder<List<_JobPost>>(
      future: _futures[status],
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryColor),
          );
        }
        if (snapshot.hasError) {
          return _emptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load jobs',
            subtitle: snapshot.error.toString(),
            action: () => _refresh(status),
          );
        }
        final jobs = snapshot.data ?? [];
        if (jobs.isEmpty) {
          return _emptyState(
            icon: Icons.work_outline_rounded,
            title: 'No ${_tabs[status]!.toLowerCase()} jobs',
            subtitle: 'Your job posts will appear here.',
            action: _createJob,
            actionLabel: 'Post a job',
          );
        }
        return RefreshIndicator(
          color: _primaryColor,
          onRefresh: () async {
            _refresh(status);
            await _futures[status];
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: jobs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _jobCard(jobs[index]),
          ),
        );
      },
    );
  }

  Widget _jobCard(_JobPost job) {
    final isClosed = job.status == 'closed';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.work_outline_rounded, color: _ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _tag(_statusLabel(job.status), _statusColor(job.status)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _meta(Icons.location_on_outlined, job.location),
              _meta(Icons.schedule_rounded, job.typeLabel),
              _meta(Icons.payments_outlined, job.salaryLabel),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: () => _editJob(job),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: isClosed
                      ? Icons.play_circle_outline_rounded
                      : Icons.pause_circle_outline_rounded,
                  label: isClosed ? 'Reopen' : 'Close',
                  onTap: () => _runAction(() {
                    return isClosed
                        ? ApiService.instance.reopenMyJob(job.id)
                        : ApiService.instance.closeMyJob(job.id);
                  }),
                ),
              ),
              const SizedBox(width: 8),
              _iconAction(
                icon: Icons.delete_outline_rounded,
                color: Colors.red,
                onTap: () => _deleteJob(job),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        side: BorderSide(color: Colors.grey.shade200),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 40,
      width: 42,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: Colors.grey.shade200),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Icon(icon, size: 19),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback action,
    String actionLabel = 'Refresh',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _muted, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w900,
                fontSize: 17,
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: action,
              style: FilledButton.styleFrom(backgroundColor: _primaryColor),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'open' => Colors.green,
      'closed' => Colors.orange,
      'draft' => _muted,
      _ => _muted,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'open' => 'Open',
      'closed' => 'Closed',
      'draft' => 'Draft',
      _ => status,
    };
  }
}

class _JobPost {
  const _JobPost({
    required this.raw,
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.employmentType,
    required this.status,
    this.salaryMin,
    this.salaryMax,
  });

  final Map<String, dynamic> raw;
  final String id;
  final String title;
  final String company;
  final String location;
  final String employmentType;
  final String status;
  final num? salaryMin;
  final num? salaryMax;

  String get typeLabel {
    return employmentType
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join('-');
  }

  String get salaryLabel {
    if (salaryMin == null && salaryMax == null) return 'Salary open';
    if (salaryMin != null && salaryMax == null) {
      return 'From ${_money(salaryMin!)}';
    }
    if (salaryMin == null && salaryMax != null) {
      return 'Up to ${_money(salaryMax!)}';
    }
    return '${_money(salaryMin!)} - ${_money(salaryMax!)}';
  }

  factory _JobPost.fromJson(Map<String, dynamic> json) {
    return _JobPost(
      raw: json,
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled job',
      company: json['company']?.toString() ?? 'Company',
      location: json['location']?.toString() ?? 'Remote',
      employmentType: json['employmentType']?.toString() ?? 'full_time',
      status: json['status']?.toString() ?? 'open',
      salaryMin: _numValue(json['salaryMin']),
      salaryMax: _numValue(json['salaryMax']),
    );
  }

  static num? _numValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  static String _money(num value) {
    final amount = value.round();
    return '₦${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
  }
}
