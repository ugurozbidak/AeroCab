import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:myapp/core/database_service.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allRides = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docs =
        await ref.read(databaseServiceProvider).getDriverEarnings(user.uid);
    if (mounted) {
      setState(() {
        _allRides =
            docs.map((d) => d.data() as Map<String, dynamic>).toList();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _ridesInRange(DateTime from) {
    final now = DateTime.now();
    return _allRides.where((r) {
      final ts = r['created_at'] as Timestamp?;
      if (ts == null) return false;
      final d = ts.toDate();
      return d.isAfter(from) && d.isBefore(now.add(const Duration(days: 1)));
    }).toList();
  }

  double _sum(List<Map<String, dynamic>> rides) =>
      rides.fold(0.0, (s, r) => s + (r['price'] as num? ?? 0).toDouble());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(const Duration(days: 6));
    final monthStart = now.subtract(const Duration(days: 29));

    final todayRides = _ridesInRange(todayStart);
    final weekRides = _ridesInRange(weekStart);
    final monthRides = _ridesInRange(monthStart);
    final allRides = _allRides;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Kazançlar'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withValues(alpha: 0.45),
          indicatorColor: cs.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Günlük'),
            Tab(text: 'Haftalık'),
            Tab(text: 'Aylık'),
            Tab(text: 'Tüm Zamanlar'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _DailyTab(rides: todayRides),
                _PeriodicTab(
                  rides: weekRides,
                  periodLabel: 'Son 7 Gün',
                  barData: _buildDailyBars(weekRides, 7),
                  xLabels: _lastNDayLabels(7),
                  total: _sum(weekRides),
                ),
                _PeriodicTab(
                  rides: monthRides,
                  periodLabel: 'Son 4 Hafta',
                  barData: _buildWeeklyBars(monthRides),
                  xLabels: ['4. Hafta', '3. Hafta', '2. Hafta', 'Bu Hafta'],
                  total: _sum(monthRides),
                ),
                _PeriodicTab(
                  rides: allRides,
                  periodLabel: 'Son 12 Ay',
                  barData: _buildMonthlyBars(allRides),
                  xLabels: _lastNMonthLabels(12),
                  total: _sum(allRides),
                ),
              ],
            ),
    );
  }

  List<double> _buildDailyBars(List<Map<String, dynamic>> rides, int days) {
    final now = DateTime.now();
    final result = List<double>.filled(days, 0);
    for (final r in rides) {
      final ts = r['created_at'] as Timestamp?;
      if (ts == null) continue;
      final d = ts.toDate();
      final daysAgo = now.difference(DateTime(d.year, d.month, d.day)).inDays;
      if (daysAgo >= 0 && daysAgo < days) {
        result[days - 1 - daysAgo] +=
            (r['price'] as num? ?? 0).toDouble();
      }
    }
    return result;
  }

  List<double> _buildWeeklyBars(List<Map<String, dynamic>> rides) {
    final result = List<double>.filled(4, 0);
    final now = DateTime.now();
    for (final r in rides) {
      final ts = r['created_at'] as Timestamp?;
      if (ts == null) continue;
      final d = ts.toDate();
      final daysAgo = now.difference(d).inDays;
      final weekIdx = daysAgo ~/ 7;
      if (weekIdx < 4) {
        result[3 - weekIdx] += (r['price'] as num? ?? 0).toDouble();
      }
    }
    return result;
  }

  List<double> _buildMonthlyBars(List<Map<String, dynamic>> rides) {
    final result = List<double>.filled(12, 0);
    final now = DateTime.now();
    for (final r in rides) {
      final ts = r['created_at'] as Timestamp?;
      if (ts == null) continue;
      final d = ts.toDate();
      final monthsAgo =
          (now.year - d.year) * 12 + now.month - d.month;
      if (monthsAgo >= 0 && monthsAgo < 12) {
        result[11 - monthsAgo] +=
            (r['price'] as num? ?? 0).toDouble();
      }
    }
    return result;
  }

  List<String> _lastNDayLabels(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      final d = now.subtract(Duration(days: n - 1 - i));
      return DateFormat('dd/MM').format(d);
    });
  }

  List<String> _lastNMonthLabels(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      final month = DateTime(now.year, now.month - (n - 1 - i));
      return DateFormat('MMM', 'tr').format(month);
    });
  }
}

// ── Daily Tab ──────────────────────────────────────────────────────────────────
class _DailyTab extends StatelessWidget {
  const _DailyTab({required this.rides});
  final List<Map<String, dynamic>> rides;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = rides.fold(
        0.0, (s, r) => s + (r['price'] as num? ?? 0).toDouble());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _TotalCard(total: total, label: 'Bugünkü Kazanç'),
          const SizedBox(height: 20),
          if (rides.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'Bugün tamamlanmış yolculuk yok.',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yolculuklar (${rides.length})',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ...rides.map((r) => _RideTile(ride: r)),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Periodic Tab (Weekly / Monthly / All Time) ─────────────────────────────────
class _PeriodicTab extends StatelessWidget {
  const _PeriodicTab({
    required this.rides,
    required this.periodLabel,
    required this.barData,
    required this.xLabels,
    required this.total,
  });
  final List<Map<String, dynamic>> rides;
  final String periodLabel;
  final List<double> barData;
  final List<String> xLabels;
  final double total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxY = barData.isEmpty
        ? 100.0
        : (barData.reduce((a, b) => a > b ? a : b) * 1.2).clamp(100.0, double.infinity);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TotalCard(total: total, label: '$periodLabel Kazancı'),
          const SizedBox(height: 20),

          // Bar Chart
          Container(
            height: 200,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
            ),
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: barData.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: e.value > 0 ? cs.primary : cs.primary.withValues(alpha: 0.15),
                        width: barData.length <= 7 ? 18 : 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= xLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            xLabels[i],
                            style: TextStyle(
                              fontSize: 9,
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          '₺${value.toInt()}',
                          style: TextStyle(
                            fontSize: 9,
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: cs.outline.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
              ),
            ),
          ),

          if (rides.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Yolculuklar (${rides.length})',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ...rides
                .take(10)
                .map((r) => _RideTile(ride: r)),
            if (rides.length > 10)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${rides.length - 10} daha fazla yolculuk',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Total Card ─────────────────────────────────────────────────────────────────
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.label});
  final double total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₺${total.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ride Tile ──────────────────────────────────────────────────────────────────
class _RideTile extends StatelessWidget {
  const _RideTile({required this.ride});
  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = ride['created_at'] as Timestamp?;
    final date = ts != null
        ? DateFormat('d MMM, HH:mm', 'tr').format(ts.toDate())
        : '';
    final price = (ride['price'] as num? ?? 0).toDouble();
    final destAddr = ride['destination_address'] as String? ?? 'Varış noktası';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_car_rounded,
              color: cs.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destAddr,
                  style:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₺${price.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
