import 'package:flutter/material.dart';

import 'job_application_sheet.dart';
import 'services/api_service.dart';

const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
const _surface = Color(0xFFF6F7F6);

class FindJobScreen extends StatefulWidget {
  const FindJobScreen({super.key});

  @override
  State<FindJobScreen> createState() => _FindJobScreenState();
}

class _FindJobScreenState extends State<FindJobScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<dynamic>> _jobsFuture;
  String _selectedType = 'all';

  static const _types = [
    ('all', 'All'),
    ('full_time', 'Full-time'),
    ('part_time', 'Part-time'),
    ('contract', 'Contract'),
    ('internship', 'Internship'),
  ];

  @override
  void initState() {
    super.initState();
    _jobsFuture = ApiService.instance.jobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _jobsFuture = ApiService.instance.jobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: _surface,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          'Find a Job',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: () async {
          _refresh();
          await _jobsFuture;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _searchBox(),
            const SizedBox(height: 14),
            _typeFilters(),
            const SizedBox(height: 22),
            FutureBuilder<List<dynamic>>(
              future: _jobsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: CircularProgressIndicator(color: _primaryColor),
                    ),
                  );
                }
                if (snapshot.hasError) return _errorState(snapshot.error);

                final jobs = _filteredJobs(snapshot.data ?? []);
                if (jobs.isEmpty) return _emptyState();

                return Column(
                  children: jobs
                      .map((job) => _jobCard(_JobItem.fromJson(job)))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      decoration: _cardDecoration(18),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search role, company, or location',
          hintStyle: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: _muted),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, color: _muted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _typeFilters() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _types.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = _types[index];
          final selected = value == _selectedType;
          return ChoiceChip(
            selected: selected,
            label: Text(label),
            onSelected: (_) => setState(() => _selectedType = value),
            selectedColor: _primaryColor,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? _primaryColor
                  : Colors.black.withValues(alpha: 0.06),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _ink,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filteredJobs(List<dynamic> data) {
    final query = _searchController.text.trim().toLowerCase();
    return data
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .where((job) => job['status']?.toString() != 'closed')
        .where((job) {
          if (_selectedType == 'all') return true;
          return job['employmentType']?.toString() == _selectedType;
        })
        .where((job) {
          if (query.isEmpty) return true;
          final haystack = [
            job['title'],
            job['company'],
            job['location'],
            job['description'],
          ].whereType<Object>().join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList();
  }

  Widget _jobCard(_JobItem job) {
    return InkWell(
      onTap: () => _showJobDetails(job),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(20),
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
                    color: _primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.work_outline_rounded,
                    color: _primaryColor,
                  ),
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
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(Icons.location_on_outlined, job.location),
                _pill(Icons.schedule_rounded, job.typeLabel),
                _pill(Icons.payments_outlined, job.salaryLabel),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  job.statusLabel,
                  style: const TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const Text(
                  'View details',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, color: _ink, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _muted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showJobDetails(_JobItem job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.76,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  job.title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  job.company,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(Icons.location_on_outlined, job.location),
                    _pill(Icons.schedule_rounded, job.typeLabel),
                    _pill(Icons.payments_outlined, job.salaryLabel),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Job description',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  job.description,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final applied = await showJobApplicationSheet(
                      this.context,
                      jobId: job.id,
                      title: job.title,
                      company: job.company,
                    );
                    if (!mounted || !applied) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Application submitted.')),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: const Text('Apply now'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _errorState(Object? error) {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: _muted, size: 42),
          const SizedBox(height: 12),
          Text(
            error?.toString() ?? 'Could not load jobs',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _refresh,
            style: FilledButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: _muted, size: 44),
          SizedBox(height: 12),
          Text(
            'No jobs match your search.',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(double radius) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

class _JobItem {
  const _JobItem({
    required this.id,
    required this.title,
    required this.company,
    required this.description,
    required this.location,
    required this.employmentType,
    required this.status,
    this.salaryMin,
    this.salaryMax,
  });

  final String id;
  final String title;
  final String company;
  final String description;
  final String location;
  final String employmentType;
  final String status;
  final num? salaryMin;
  final num? salaryMax;

  factory _JobItem.fromJson(Map<String, dynamic> json) {
    return _JobItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled job',
      company: json['company']?.toString() ?? 'Company',
      description:
          json['description']?.toString() ?? 'No description provided yet.',
      location: json['location']?.toString() ?? 'Remote',
      employmentType: json['employmentType']?.toString() ?? 'full_time',
      status: json['status']?.toString() ?? 'open',
      salaryMin: _numValue(json['salaryMin']),
      salaryMax: _numValue(json['salaryMax']),
    );
  }

  String get typeLabel {
    return employmentType
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join('-');
  }

  String get salaryLabel {
    if (salaryMin == null && salaryMax == null) return 'Salary open';
    if (salaryMax == null || salaryMax == salaryMin) {
      return _formatMoney(salaryMin);
    }
    return '${_formatMoney(salaryMin)} - ${_formatMoney(salaryMax)}';
  }

  String get statusLabel {
    if (status == 'draft') return 'Draft';
    if (status == 'closed') return 'Closed';
    return 'Open';
  }

  static num? _numValue(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  static String _formatMoney(num? value) {
    if (value == null) return 'Salary open';
    final formatted = value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    return '₦$formatted';
  }
}
