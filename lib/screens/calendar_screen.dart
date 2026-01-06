import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/models.dart';
import '../providers/dailychamp_provider.dart';
import '../theme/theme_compat.dart';
import 'today_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Calendar'),
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

          return SingleChildScrollView(
            child: Column(
              children: [
                // Calendar widget
                Container(
                  margin: const EdgeInsets.all(AppTheme.spacing16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: TableCalendar(
                    firstDay: DateTime(2020, 1, 1),
                    lastDay: DateTime(2030, 12, 31),
                    focusedDay: _focusedDay,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });

                      // Navigate to TodayScreen with selected date
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TodayScreen(initialDate: selectedDay),
                        ),
                      );
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                    // Calendar styling
                    calendarStyle: CalendarStyle(
                      // Default days
                      defaultTextStyle: AppTheme.bodyLarge.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      // Weekend days
                      weekendTextStyle: AppTheme.bodyLarge.copyWith(
                        color: isDark
                            ? colorScheme.onSurface.withOpacity(0.7)
                            : AppTheme.textSecondary,
                      ),
                      // Outside days (other months)
                      outsideTextStyle: AppTheme.bodyMedium.copyWith(
                        color: isDark
                            ? colorScheme.onSurface.withOpacity(0.3)
                            : AppTheme.textTertiary,
                      ),
                      // Selected day
                      selectedDecoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: AppTheme.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      // Today
                      todayDecoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: colorScheme.primary, width: 2),
                      ),
                      todayTextStyle: AppTheme.bodyLarge.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      // Markers
                      markerDecoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 1,
                      cellMargin: const EdgeInsets.all(4),
                      cellPadding: const EdgeInsets.all(0),
                    ),
                    // Header styling
                    headerStyle: HeaderStyle(
                      titleTextStyle: AppTheme.headlineMedium.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      formatButtonVisible: false,
                      titleCentered: true,
                      leftChevronIcon: Icon(
                        Icons.chevron_left,
                        color: colorScheme.onSurface,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurface,
                      ),
                      headerPadding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacing16,
                      ),
                    ),
                    // Days of week styling
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: AppTheme.labelSmall.copyWith(
                        color: isDark
                            ? colorScheme.onSurface.withOpacity(0.7)
                            : AppTheme.textSecondary,
                      ),
                      weekendStyle: AppTheme.labelSmall.copyWith(
                        color: isDark
                            ? colorScheme.onSurface.withOpacity(0.7)
                            : AppTheme.textSecondary,
                      ),
                    ),
                    // Custom builder for day cells
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        return _buildDayCell(day, provider);
                      },
                      selectedBuilder: (context, day, focusedDay) {
                        return _buildDayCell(day, provider, isSelected: true);
                      },
                      todayBuilder: (context, day, focusedDay) {
                        return _buildDayCell(day, provider, isToday: true);
                      },
                      outsideBuilder: (context, day, focusedDay) {
                        return _buildDayCell(day, provider, isOutside: true);
                      },
                    ),
                  ),
                ),

                // Legend
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing8,
                  ),
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Legend', style: AppTheme.titleLarge),
                      const SizedBox(height: AppTheme.spacing12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLegendItem('Win', DayStatus.win),
                          _buildLegendItem('Loss', DayStatus.loss),
                          _buildTodayLegendItem(colorScheme),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacing16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day,
    DailyChampProvider provider, {
    bool isSelected = false,
    bool isToday = false,
    bool isOutside = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entry = provider.getEntryForDate(day);
    final status = entry?.status;

    // IMPORTANT: Today should NEVER show win/loss background colors
    // Only past days show colored backgrounds
    final showStatusColor = !isOutside &&
        !isToday &&
        (status == DayStatus.win || status == DayStatus.loss);
    final hasWinStatus = showStatusColor && status == DayStatus.win;
    final hasLossStatus = showStatusColor && status == DayStatus.loss;

    // Determine background color
    Color backgroundColor;
    if (isSelected) {
      backgroundColor = colorScheme.primary;
    } else if (hasWinStatus) {
      backgroundColor = AppTheme.success;
    } else if (hasLossStatus) {
      backgroundColor = AppTheme.error;
    } else {
      backgroundColor = Colors.transparent;
    }

    // Determine text color
    Color textColor;
    if (isSelected || showStatusColor) {
      // White text on colored backgrounds
      textColor = Colors.white;
    } else if (isOutside) {
      textColor = isDark
          ? colorScheme.onSurface.withValues(alpha: 0.3)
          : AppTheme.textTertiary;
    } else {
      textColor = colorScheme.onSurface;
    }

    // Determine border for Today indicator
    Border? border;
    if (isToday && !isSelected) {
      // Today always gets primary color border (no colored background to contrast)
      border = Border.all(color: colorScheme.primary, width: 2);
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: border,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: AppTheme.bodyLarge.copyWith(
            color: textColor,
            fontWeight: isToday || isSelected || showStatusColor
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, DayStatus status) {
    final badgeText = status == DayStatus.win
        ? 'W'
        : status == DayStatus.loss
            ? 'L'
            : status == DayStatus.pending
                ? 'P'
                : 'S';
    final badgeColor = status == DayStatus.win
        ? AppTheme.success
        : status == DayStatus.loss
            ? AppTheme.error
            : status == DayStatus.pending
                ? AppTheme.warning
                : Colors.blue;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              badgeText,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacing8),
        Text(label, style: AppTheme.bodyMedium),
      ],
    );
  }

  Widget _buildTodayLegendItem(ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.primary, width: 2),
          ),
        ),
        const SizedBox(width: AppTheme.spacing8),
        Text('Today', style: AppTheme.bodyMedium),
      ],
    );
  }
}
