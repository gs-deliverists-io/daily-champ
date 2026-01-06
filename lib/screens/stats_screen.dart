import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../providers/dailychamp_provider.dart';
import '../theme/theme_compat.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Statistics'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppTheme.borderColor,
          ),
        ),
      ),
      body: Consumer<DailyChampProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    provider.error!,
                    style: AppTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  ElevatedButton(
                    onPressed: () => provider.loadEntries(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final stats = provider.calculateStats();
          final currentStreak = provider.currentWinStreak;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Win Streak Card (Hero stat)
                _buildHeroCard(
                  context,
                  'Current Streak',
                  '$currentStreak',
                  'consecutive wins',
                ),

                const SizedBox(height: AppTheme.spacing16),

                // Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Total Wins',
                        '${stats['totalWins']}',
                        Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Total Losses',
                        '${stats['totalLosses']}',
                        Icons.cancel_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacing16),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Win Rate',
                        '${stats['winRate']}%',
                        Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Total Days',
                        '${stats['totalDays']}',
                        Icons.calendar_today,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacing24),

                // Monthly Chart
                if (provider.entries.isNotEmpty) ...[
                  _buildSectionTitle('Last 30 Days'),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildMonthlyChart(context, provider),
                ],

                const SizedBox(height: AppTheme.spacing24),

                // Recent Activity
                if (provider.entries.isNotEmpty) ...[
                  _buildSectionTitle('Recent Activity'),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildRecentActivity(context, provider),
                ],

                const SizedBox(height: AppTheme.spacing48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(
      BuildContext context, String title, String value, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing32),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: AppTheme.titleLarge.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            subtitle,
            style: AppTheme.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context, String title, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: colorScheme.onSurface),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(
              color: isDark
                  ? colorScheme.onSurface.withOpacity(0.7)
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
          child: Text(
            title,
            style: AppTheme.titleLarge.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthlyChart(BuildContext context, DailyChampProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    // Get last 30 days of data
    final now = DateTime.now();
    final last30Days = List.generate(30, (index) {
      return now.subtract(Duration(days: 29 - index));
    });

    final dataPoints = last30Days.map((date) {
      final entry = provider.getEntryForDate(date);
      if (entry == null) return 0.0;

      switch (entry.status) {
        case DayStatus.win:
          return 1.0;
        case DayStatus.loss:
          return -1.0;
        case DayStatus.pending:
        case DayStatus.scheduled:
          return 0.0;
      }
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: dataPoints.every((point) => point == 0.0)
          ? Center(
              child: Text(
                'No data yet',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            )
          : BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1,
                minY: -1,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() % 5 != 0) return const SizedBox();
                        final date = last30Days[value.toInt()];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${date.month}/${date.day}',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.borderColor,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: dataPoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final value = entry.value;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        color: value > 0
                            ? colorScheme.primary
                            : value < 0
                                ? colorScheme.onSurface.withOpacity(0.5)
                                : AppTheme.borderColor,
                        width: 4,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                          bottom: Radius.circular(2),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildRecentActivity(
      BuildContext context, DailyChampProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    // Get last 7 days
    final recentEntries = provider.entries.take(7).toList();

    if (recentEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Center(
          child: Text(
            'No activity yet',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: recentEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final dailyEntry = entry.value;
          final isLast = index == recentEntries.length - 1;

          return Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(
                      bottom: BorderSide(color: AppTheme.borderColor),
                    ),
            ),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStatusColor(dailyEntry.status),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getStatusLabel(dailyEntry.status),
                      style: AppTheme.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing16),
                // Date and stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(dailyEntry.date),
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        '${dailyEntry.completedTaskCount}/${dailyEntry.tasks.length} tasks completed',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Completion percentage
                Text(
                  '${(dailyEntry.completionPercentage * 100).toStringAsFixed(0)}%',
                  style: AppTheme.titleLarge,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(DayStatus status) {
    switch (status) {
      case DayStatus.win:
        return Colors.black;
      case DayStatus.loss:
        return AppTheme.textSecondary;
      case DayStatus.pending:
        return AppTheme.textTertiary;
      case DayStatus.scheduled:
        return Colors.blue;
    }
  }

  String _getStatusLabel(DayStatus status) {
    switch (status) {
      case DayStatus.win:
        return 'W';
      case DayStatus.loss:
        return 'L';
      case DayStatus.pending:
        return 'P';
      case DayStatus.scheduled:
        return 'S';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      final months = [
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
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}';
    }
  }
}
