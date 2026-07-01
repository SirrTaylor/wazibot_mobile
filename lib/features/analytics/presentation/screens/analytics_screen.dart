/// lib/features/analytics/presentation/screens/analytics_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/providers/cached_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/loading_shimmer.dart';


class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(cachedAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(cachedAnalyticsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: WaziBotColors.primary,
        onRefresh: () async {
          await Haptics.refresh();
          ref.invalidate(cachedAnalyticsProvider);
        },
        child: analyticsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: ShimmerList(count: 6, itemHeight: 100),
          ),
          error: (e, _) => Center(child: Text(apiErrorMessage(e))),
          data: (data) => _AnalyticsDashboard(data: data),
        ),
      ),
    );
  }
}

class _AnalyticsDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnalyticsDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = DashboardStats.fromJson(data);
    final currency =
        NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    final pct = NumberFormat.percentPattern();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            StatCard(
              label: 'Total Revenue',
              value: currency.format(stats.todayRevenue),
              icon: Icons.attach_money,
              color: WaziBotColors.primary,
            ),
            StatCard(
              label: 'Active Customers',
              value: stats.activeCustomers.toString(),
              icon: Icons.people_outline,
              color: WaziBotColors.info,
            ),
            StatCard(
              label: 'Conversion Rate',
              value: pct.format(stats.conversionRate / 100),
              icon: Icons.trending_up,
              color: WaziBotColors.warning,
            ),
            StatCard(
              label: 'QR Scans',
              value: stats.qrScans.toString(),
              icon: Icons.qr_code_scanner,
              color: const Color(0xFF8B5CF6),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Text('Business Health Score', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        _HealthBar(score: stats.healthScore),
        const SizedBox(height: 20),

        Text('WhatsApp Activity', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _StatRow(
                  label: 'Total Conversations',
                  value: stats.conversations.toString()),
              const Divider(height: 16),
              _StatRow(
                  label: 'Active Customers',
                  value: stats.activeCustomers.toString()),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        Text('Orders Summary', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _StatRow(
                  label: "Today's Orders",
                  value: stats.todayOrders.toString()),
              const Divider(height: 16),
              _StatRow(
                  label: 'Pending Orders',
                  value: stats.pendingOrders.toString()),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        if (data['weekly_revenue'] != null) ...[
          Text('Weekly Revenue', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          _WeeklyChart(
              data: (data['weekly_revenue'] as List<dynamic>)
                  .map((v) => (v as num).toDouble())
                  .toList()),
          const SizedBox(height: 20),
        ],

        // AI vs Human handled
        if (stats.aiHandled > 0 || stats.humanHandled > 0) ...[
          Text('Conversation Handling', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _StatRow(label: 'AI Handled', value: stats.aiHandled.toString()),
                const Divider(height: 16),
                _StatRow(label: 'Agent Handled', value: stats.humanHandled.toString()),
                const Divider(height: 16),
                _StatRow(label: 'Paid Orders', value: stats.paidOrders.toString()),
                const Divider(height: 16),
                _StatRow(label: 'Total Orders', value: stats.totalOrders.toString()),
              ]),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Extra stats from other providers
        const _RepeatCustomerCard(),
        const SizedBox(height: 20),
        const _AcquisitionCard(),
      ],
    );
  }
}


// ── Repeat customers card ─────────────────────────────────────────────────────
class _RepeatCustomerCard extends ConsumerWidget {
  const _RepeatCustomerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final topAsync = ref.watch(topCustomersProvider);

    return topAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (customers) {
        if (customers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Customers', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: customers.take(5).map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: WaziBotColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                (c.name ?? c.phone).isNotEmpty
                                    ? (c.name ?? c.phone)[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: WaziBotColors.primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                c.name ?? c.phone,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ),
                        Text(
                          NumberFormat.currency(symbol: r'$', decimalDigits: 0)
                              .format(c.totalSpent),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: WaziBotColors.primary),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Acquisition stats card ────────────────────────────────────────────────────
class _AcquisitionCard extends ConsumerWidget {
  const _AcquisitionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Uses the cached analytics data which already has acquisition merged
    final statsAsync = ref.watch(cachedAnalyticsProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final qrScans = (data['qr_scans'] as num?)?.toInt() ?? 0;
        final linkClicks = (data['link_clicks'] as num?)?.toInt() ?? 0;
        if (qrScans == 0 && linkClicks == 0) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer Acquisition', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _StatRow(label: 'QR Code Scans', value: qrScans.toString()),
                  if (linkClicks > 0) ...[
                    const Divider(height: 16),
                    _StatRow(label: 'Link Clicks', value: linkClicks.toString()),
                  ],
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HealthBar extends StatelessWidget {
  final double score;
  const _HealthBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (score / 100).clamp(0.0, 1.0);
    final color = score >= 75
        ? WaziBotColors.success
        : score >= 50
            ? WaziBotColors.warning
            : WaziBotColors.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    score >= 75
                        ? 'Excellent'
                        : score >= 50
                            ? 'Good'
                            : 'Needs attention',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: color)),
                Text('${score.toInt()}/100',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: color, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<double> data;
  const _WeeklyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal =
        data.isEmpty ? 1.0 : data.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.2,
              barGroups: List.generate(
                data.length,
                (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i],
                      color: WaziBotColors.primary,
                      width: 22,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(
                      days[v.toInt() % days.length],
                      style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.colorScheme.outline,
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ),
    );
  }
}
