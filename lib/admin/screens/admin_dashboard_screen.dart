import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _primaryColor = Color(0xFF66C665);
const _ink = Color(0xFF172317);
const _muted = Color(0xFF7E867E);
// ignore: unused_element
const _surface = Color(0xFFF6FBF6);
const _adminAccent = Color(0xFFDC2626);

// ─── Data models ──────────────────────────────────────────────────────────────

class _DailyStat {
  const _DailyStat({required this.date, required this.amount});
  final String date;
  final double amount;
}

class _AnalyticsData {
  const _AnalyticsData({
    required this.totalUsers,
    required this.activeListings,
    required this.totalRevenue,
    required this.pendingVerifications,
    required this.dailyStats,
  });

  final int totalUsers;
  final int activeListings;
  final double totalRevenue;
  final int pendingVerifications;
  final List<_DailyStat> dailyStats;

  factory _AnalyticsData.fromJson(Map<String, dynamic> json) {
    final rawDaily = json['dailyRevenue'] as List?;

    List<_DailyStat> stats;
    if (rawDaily != null && rawDaily.isNotEmpty) {
      stats = rawDaily.map((item) {
        final map = item as Map<String, dynamic>;
        return _DailyStat(
          date: (map['date'] as String?) ?? '',
          amount: ((map['amount'] ?? 0) as num).toDouble(),
        );
      }).toList();
    } else {
      stats = _generateEmptyStats();
    }

    return _AnalyticsData(
      totalUsers: (json['totalUsers'] as int?) ?? 0,
      activeListings: (json['activeListings'] as int?) ?? 0,
      totalRevenue: ((json['totalRevenue'] ?? 0) as num).toDouble(),
      pendingVerifications: (json['pendingVerifications'] as int?) ?? 0,
      dailyStats: stats,
    );
  }

  factory _AnalyticsData.empty() {
    return _AnalyticsData(
      totalUsers: 0,
      activeListings: 0,
      totalRevenue: 0.0,
      pendingVerifications: 0,
      dailyStats: _generateEmptyStats(),
    );
  }

  static List<_DailyStat> _generateEmptyStats() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final label =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return _DailyStat(date: label, amount: 0.0);
    });
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.onOpenTab});

  final ValueChanged<int>? onOpenTab;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<_AnalyticsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnalyticsData> _load() async {
    try {
      final response = await ApiService.instance.adminAnalytics();
      return _AnalyticsData.fromJson(response);
    } catch (_) {
      return _AnalyticsData.empty();
    }
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: () async => _refresh(),
      child: FutureBuilder<_AnalyticsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: _muted),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: _muted, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                    ),
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data ?? _AnalyticsData.empty();
          return _buildContent(data);
        },
      ),
    );
  }

  Widget _buildContent(_AnalyticsData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 20),
        _buildKpiGrid(data),
        const SizedBox(height: 24),
        const Text(
          '7-Day Revenue',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),
        _buildRevenueChart(data),
        const SizedBox(height: 24),
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),
        _buildQuickActions(),
      ],
    );
  }

  // ── Header card ─────────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr =
        '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('🚀', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: const TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.70),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── KPI grid ─────────────────────────────────────────────────────────────────

  Widget _buildKpiGrid(_AnalyticsData data) {
    final revenue = _formatCurrency(data.totalRevenue);

    final kpis = [
      _KpiItem(
        icon: Icons.people_rounded,
        color: Colors.blue,
        value: '${data.totalUsers}',
        label: 'Total Users',
      ),
      _KpiItem(
        icon: Icons.inventory_2_rounded,
        color: _primaryColor,
        value: '${data.activeListings}',
        label: 'Active Listings',
      ),
      _KpiItem(
        icon: Icons.attach_money_rounded,
        color: Colors.orange,
        value: '₦$revenue',
        label: 'Total Revenue',
      ),
      _KpiItem(
        icon: Icons.pending_actions_rounded,
        color: _adminAccent,
        value: '${data.pendingVerifications}',
        label: 'Pending Verifications',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: kpis.map(_buildKpiCard).toList(),
    );
  }

  Widget _buildKpiCard(_KpiItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 22, color: item.color),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: _ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 11,
              color: _muted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Revenue bar chart ────────────────────────────────────────────────────────

  Widget _buildRevenueChart(_AnalyticsData data) {
    final amounts = data.dailyStats.map((s) => s.amount).toList();
    final maxAmount = amounts.isEmpty
        ? 1000.0
        : amounts.reduce((a, b) => a > b ? a : b);
    final maxY = (maxAmount * 1.3).clamp(1000.0, double.infinity);

    final barGroups = data.dailyStats.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: stat.amount,
            color: _primaryColor,
            width: 22,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.dailyStats.length) {
                    return const SizedBox.shrink();
                  }
                  final dayLabel = _shortDayLabel(data.dailyStats[index].date);
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      dayLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Quick actions ────────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(
      children: [
        _QuickActionTile(
          icon: Icons.people_rounded,
          title: 'Manage Users',
          subtitle: 'View, block, or search users',
          color: Colors.blue,
          onTap: () => widget.onOpenTab?.call(1),
        ),
        const SizedBox(height: 10),
        _QuickActionTile(
          icon: Icons.inventory_2_rounded,
          title: 'Manage Listings',
          subtitle: 'Pause or remove products',
          color: _primaryColor,
          onTap: () => widget.onOpenTab?.call(2),
        ),
        const SizedBox(height: 10),
        _QuickActionTile(
          icon: Icons.verified_user_rounded,
          title: 'Review Verifications',
          subtitle: 'Approve or reject identity requests',
          color: Colors.orange,
          onTap: () => widget.onOpenTab?.call(4),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write(',');
      buffer.write(parts[i]);
    }
    return buffer.toString();
  }

  /// Derives a short weekday label (Mon, Tue, …) from a date string like
  /// '2026-07-02'. Falls back to the raw string if parsing fails.
  String _shortDayLabel(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return dateStr;
      final dt = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return labels[dt.weekday - 1];
    } catch (_) {
      return dateStr;
    }
  }
}

// ─── Helper data classes ──────────────────────────────────────────────────────

class _KpiItem {
  const _KpiItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;
}

// ─── Quick action tile widget ─────────────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}
