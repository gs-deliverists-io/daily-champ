import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers/dailychamp_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/task_tile.dart';
import '../widgets/add_item_sheet.dart';
import '../widgets/add_section_dialog.dart';
import '../widgets/section_selection_dialog.dart';
import '../widgets/template_selection_dialog.dart';
import 'task_sheet.dart';

/// Today screen - main daily view with clean, modern design
class TodayScreen extends StatefulWidget {
  final DateTime? initialDate;
  final VoidCallback? onNavigateToSettings;

  const TodayScreen({
    super.key,
    this.initialDate,
    this.onNavigateToSettings,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  /// Reset the selected date to today
  void resetToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedDate != today) {
      setState(() {
        _selectedDate = today;
      });
    }
  }

  /// Navigate to previous or next day
  /// Note: Does NOT auto-apply templates - just shows the day as-is
  void _navigateToDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  /// Open date picker for direct date selection
  /// Note: Does NOT auto-apply templates - just shows the day as-is
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Save template ID for a date
  Future<void> _saveTemplateForDate(DateTime date, String templateId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'template_${_formatDateKey(date)}';
    await prefs.setString(key, templateId);
  }

  /// Format date for SharedPreferences key
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Build compact progress indicator for header
  Widget _buildProgressIndicator(DailyEntry entry, ThemeData theme) {
    final progress = entry.completionPercentage;
    final percentage = (progress * 100).toInt();
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percentage%',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Text(
            '${entry.completedCount}/${entry.totalCount}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _showTaskSheet({Task? task}) {
    final provider = context.read<DailyChampProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskSheet(
        task: task,
        onSave: (title, hours) async {
          if (task != null) {
            // Edit existing task
            final updated = task.copyWith(
              title: title,
              estimatedHours: hours,
            );
            provider.updateTask(_selectedDate, updated);
          } else {
            // Add new task
            final newTask = Task(
              title: title,
              estimatedHours: hours,
            );
            final success = await provider.addTask(_selectedDate, newTask);

            if (!success && context.mounted) {
              // Show error if task limit reached
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cannot add more than ${DailyEntry.maxTasks} tasks per day',
                  ),
                  backgroundColor: AppTheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _copyTaskToTomorrow(DailyChampProvider provider, Task task) async {
    // Calculate tomorrow's date
    final tomorrow = _selectedDate.add(const Duration(days: 1));

    // Get tomorrow's entry to show available sections
    final tomorrowEntry = provider.getEntryForDate(tomorrow);

    String? targetSection;

    // If tomorrow has sections, ask which one to use
    if (tomorrowEntry != null && tomorrowEntry.sections.isNotEmpty) {
      targetSection = await showSectionSelectionDialog(
        context,
        tomorrowEntry.sections,
        title: 'Copy to Section',
        subtitle: 'Select which section to add "${task.title}" to',
      );

      // User cancelled
      if (targetSection == null) return;
    }

    // Copy task to tomorrow using the provider's copy method
    try {
      await provider.copyTaskToDate(
        task,
        _selectedDate,
        tomorrow,
        targetSectionName: targetSection,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied "${task.title}" to tomorrow'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show the add item bottom sheet for a section
  void _showAddItemSheet(String sectionName) {
    final provider = context.read<DailyChampProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemSheet(
        sectionName: sectionName,
        onSave: (content, type, hours) async {
          bool success = true;

          if (type == ItemType.task) {
            // Add as task with estimated hours (0.0 if not provided)
            success = await provider.addItemToSection(
              _selectedDate,
              sectionName,
              content,
              isTask: true,
              estimatedHours: hours ?? 0.0,
            );
          } else {
            // Add as note or text (both stored the same way)
            await provider.addItemToSection(
              _selectedDate,
              sectionName,
              content,
              isTask: false,
            );
          }

          if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cannot add more than ${DailyEntry.maxTasks} tasks per day',
                ),
                backgroundColor: AppTheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  /// Show dialog to edit a list item
  void _showEditItemDialog(
      String sectionName, int itemIndex, String currentContent) {
    final provider = context.read<DailyChampProvider>();
    final controller = TextEditingController(text: currentContent);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('Edit Item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Content',
            hintText: 'Enter item text',
          ),
          maxLines: 3,
          minLines: 1,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              provider.updateItemInSection(
                _selectedDate,
                sectionName,
                itemIndex,
                value.trim(),
              );
              Navigator.of(dialogContext).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty) {
                provider.updateItemInSection(
                  _selectedDate,
                  sectionName,
                  itemIndex,
                  newContent,
                );
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to rename a section
  void _showRenameDialog(String currentName) {
    final provider = context.read<DailyChampProvider>();
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('Rename Section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Section Name',
            hintText: 'Enter new name',
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty && value.trim() != currentName) {
              provider.renameSection(_selectedDate, currentName, value.trim());
            }
            Navigator.pop(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                provider.renameSection(_selectedDate, currentName, newName);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  /// Show confirmation dialog before deleting a section
  void _confirmDeleteSection(String sectionName) {
    final provider = context.read<DailyChampProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('Delete Section?'),
        content: Text(
          'Are you sure you want to delete "$sectionName"? This will also remove any tasks in this section.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteSection(_selectedDate, sectionName);
              Navigator.pop(dialogContext);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to add a new section
  void _showAddSectionDialog() {
    final provider = context.read<DailyChampProvider>();

    showAddSectionDialog(
      context: context,
      onSave: (name, type) {
        provider.addSection(_selectedDate, name, type);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if this screen was pushed (has a Navigator route to pop)
    final bool canPop = ModalRoute.of(context)?.canPop ?? false;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: canPop
          ? AppBar(
              backgroundColor: colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('Day View', style: theme.textTheme.titleLarge),
            )
          : null,
      body: SafeArea(
        child: Consumer<DailyChampProvider>(
          builder: (context, provider, child) {
            final entry = provider.getEntryForDate(_selectedDate);
            final dateStr = DateFormat('EEEE, MMMM d').format(_selectedDate);
            final isToday = _isToday(_selectedDate);

            return Column(
              children: [
                // Sync error banner
                if (provider.syncError != null)
                  Material(
                    color: Colors.red.shade50,
                    child: InkWell(
                      onTap: () {
                        // Navigate to settings tab
                        widget.onNavigateToSettings?.call();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.red.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                provider.syncError!,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Main content
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // Header with date navigation and stats
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.space24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date navigation row
                              Row(
                                children: [
                                  // Yesterday button
                                  IconButton(
                                    onPressed: () => _navigateToDate(-1),
                                    icon: const Icon(Icons.chevron_left),
                                    tooltip: 'Yesterday',
                                    style: IconButton.styleFrom(
                                      foregroundColor: colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                  // Date display
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _selectDate,
                                      child: Column(
                                        children: [
                                          Text(
                                            isToday
                                                ? 'Today'
                                                : dateStr.split(',')[0],
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(
                                              height: AppTheme.space4),
                                          Text(
                                            dateStr,
                                            style: theme.textTheme.bodyMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                          // Progress percentage
                                          if (entry != null &&
                                              entry.tasks.isNotEmpty) ...[
                                            const SizedBox(
                                                height: AppTheme.space8),
                                            _buildProgressIndicator(
                                                entry, theme),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Tomorrow button
                                  IconButton(
                                    onPressed: () => _navigateToDate(1),
                                    icon: const Icon(Icons.chevron_right),
                                    tooltip: 'Tomorrow',
                                    style: IconButton.styleFrom(
                                      foregroundColor: colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.space16),
                              // Status badge (centered)
                              if (entry != null)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.space16,
                                      vertical: AppTheme.space8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(entry.status),
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusFull),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getStatusIcon(entry.status),
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: AppTheme.space4),
                                        Text(
                                          entry.status.displayName,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Dynamic Sections from markdown file
                      if (entry != null && entry.sections.isNotEmpty)
                        ...entry.sections.map((section) => _buildSection(
                              section,
                              entry,
                              theme,
                              colorScheme,
                            )),

                      // Add Section button (inline, after sections)
                      if (entry != null && entry.sections.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space24,
                              vertical: AppTheme.space12,
                            ),
                            child: OutlinedButton.icon(
                              onPressed: _showAddSectionDialog,
                              icon: Icon(
                                Icons.add_box_outlined,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              label: Text(
                                'Add section',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                side: BorderSide(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                backgroundColor:
                                    colorScheme.primary.withValues(alpha: 0.05),
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppTheme.space16,
                                  horizontal: AppTheme.space20,
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (entry == null || entry.sections.isEmpty)
                        // Empty state when no sections exist (first time user or empty file)
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.space24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Today',
                                    style: theme.textTheme.titleLarge),
                                const SizedBox(height: AppTheme.space16),
                                _buildEmptyState(
                                  icon: Icons.today_outlined,
                                  message: 'No sections yet',
                                  subtitle:
                                      'Create a section to organize your tasks',
                                  theme: theme,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Action buttons section
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.space24,
                          ),
                          child: Column(
                            children: [
                              // Apply Template button (only show if no entry or empty)
                              if (entry == null || entry.sections.isEmpty)
                                Container(
                                  margin: const EdgeInsets.only(
                                    bottom: AppTheme.space12,
                                  ),
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final templateId =
                                          await showTemplateSelectionDialog(
                                        context,
                                        _selectedDate,
                                      );
                                      // Store template for auto-apply feature
                                      if (templateId != null) {
                                        await _saveTemplateForDate(
                                          _selectedDate,
                                          templateId,
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.layers_outlined,
                                        size: 20),
                                    label: const Text('Apply Template'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppTheme.space16,
                                        horizontal: AppTheme.space20,
                                      ),
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMedium,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom spacing
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppTheme.space48),
                      ),
                    ],
                  ),
                ),

                // Fixed footer with action buttons
                _buildFixedFooter(entry, colorScheme),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build fixed footer with template button
  /// Shows subtle icon when template is applied, hidden when empty day
  Widget _buildFixedFooter(DailyEntry? entry, ColorScheme colorScheme) {
    // Don't show footer for empty days - they have inline "Apply Template" button
    if (entry == null || entry.sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Subtle template change button
            TextButton.icon(
              onPressed: () async {
                final templateId = await showTemplateSelectionDialog(
                  context,
                  _selectedDate,
                );
                if (templateId != null) {
                  await _saveTemplateForDate(_selectedDate, templateId);
                }
              },
              icon: Icon(
                Icons.tune,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              label: Text(
                'Change Template',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space12,
                  vertical: AppTheme.space8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(DailyEntry entry, ThemeData theme) {
    final progress = entry.completionPercentage;
    final percentage = (progress * 100).toInt();
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Large percentage
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Center(
              child: Text(
                '$percentage%',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space20),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.completedCount} of ${entry.totalCount} tasks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
    required ThemeData theme,
    VoidCallback? onAddItem,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppTheme.space12),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            if (onAddItem != null) ...[
              const SizedBox(height: AppTheme.space16),
              FilledButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space16,
                    vertical: AppTheme.space8,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(DayStatus status) {
    switch (status) {
      case DayStatus.win:
        return AppTheme.success;
      case DayStatus.loss:
        return AppTheme.error;
      case DayStatus.pending:
        return AppTheme.warning;
      case DayStatus.scheduled:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(DayStatus status) {
    switch (status) {
      case DayStatus.win:
        return Icons.check_circle;
      case DayStatus.loss:
        return Icons.cancel;
      case DayStatus.pending:
        return Icons.schedule;
      case DayStatus.scheduled:
        return Icons.calendar_today;
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildSection(Section section, DailyEntry entry, ThemeData theme,
      ColorScheme colorScheme) {
    final provider = context.read<DailyChampProvider>();

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header with actions
            Row(
              children: [
                Expanded(
                  child: Text(section.name, style: theme.textTheme.titleLarge),
                ),
                // Section menu (removed Add button - moved to inline)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  tooltip: 'Section options',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        _showRenameDialog(section.name);
                        break;
                      case 'delete':
                        _confirmDeleteSection(section.name);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: AppTheme.space12),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: AppTheme.error,
                          ),
                          const SizedBox(width: AppTheme.space12),
                          Text(
                            'Delete',
                            style: TextStyle(color: AppTheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space16),

            // Section content based on type
            if (section.items.isEmpty)
              _buildEmptyState(
                icon: Icons.notes_outlined,
                message: 'No items yet',
                subtitle: 'Tap the button below to add an item',
                theme: theme,
              )
            else if (section.type == SectionType.text)
              // Text type: render as markdown paragraphs
              Container(
                padding: const EdgeInsets.all(AppTheme.space16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                child: MarkdownBody(
                  data: section.items.join('\n\n'),
                  styleSheet: MarkdownStyleSheet(
                    p: theme.textTheme.bodyMedium,
                    a: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    strong: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    em: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                    code: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  onTapLink: (text, href, title) async {
                    if (href != null) {
                      final uri = Uri.parse(href);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    }
                  },
                ),
              )
            else
              // List or tasks type: render items individually
              ...section.items.asMap().entries.map((mapEntry) {
                final item = mapEntry.value;
                final isCheckbox = item.trim().startsWith('- [');

                if (isCheckbox) {
                  // Find the actual task from entry.tasks (preserves task ID for operations)
                  final task = _findTaskForLine(item, entry);
                  if (task != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space8),
                      child: TaskTile(
                        task: task,
                        onToggle: () =>
                            provider.toggleTask(_selectedDate, task),
                        onTap: () => _showTaskSheet(task: task),
                        onDelete: () =>
                            provider.deleteTask(_selectedDate, task),
                        onCopyToTomorrow: () =>
                            _copyTaskToTomorrow(provider, task),
                      ),
                    );
                  }
                }

                // Render as regular list item with swipe actions
                final itemIndex = mapEntry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space8),
                  child: Slidable(
                    key: Key('${section.name}_$itemIndex'),
                    // Swipe left: Edit & Delete (same as TaskTile)
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      extentRatio: 0.4,
                      children: [
                        // Edit action
                        CustomSlidableAction(
                          onPressed: (context) {
                            _showEditItemDialog(section.name, itemIndex, item);
                          },
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(AppTheme.radius12),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        // Delete action
                        CustomSlidableAction(
                          onPressed: (context) {
                            provider.deleteItemFromSection(
                              _selectedDate,
                              section.name,
                              itemIndex,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Item deleted'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(AppTheme.radius12),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    // Swipe right: Copy to tomorrow
                    startActionPane: ActionPane(
                      motion: const StretchMotion(),
                      extentRatio: 0.2,
                      children: [
                        CustomSlidableAction(
                          onPressed: (context) {
                            provider.copyItemToTomorrow(
                              _selectedDate,
                              section.name,
                              itemIndex,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Item copied to tomorrow'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radius8),
                                ),
                              ),
                            );
                          },
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radius12),
                          child: const Icon(
                            Icons.copy_outlined,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.space16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bullet container - matches TaskTile checkbox dimensions (24x24)
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primary.withValues(alpha: 0.1),
                            ),
                            child: Icon(
                              Icons.circle,
                              size: 8,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space16),
                          // Content with markdown support
                          Expanded(
                            child: MarkdownBody(
                              data: item,
                              styleSheet: MarkdownStyleSheet(
                                p: theme.textTheme.bodyLarge,
                                a: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                                strong: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                em: theme.textTheme.bodyLarge?.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                                code: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                ),
                              ),
                              onTapLink: (text, href, title) async {
                                if (href != null) {
                                  final uri = Uri.parse(href);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

            // Inline Add button (after all items) - aligned to the right
            const SizedBox(height: AppTheme.space12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showAddItemSheet(section.name),
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(section.type == SectionType.tasks
                      ? 'Add task'
                      : 'Add item'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.space12,
                      horizontal: AppTheme.space16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Find a task from entry.tasks that matches the checkbox line
  /// This ensures we use the same Task object (with correct ID) for operations
  Task? _findTaskForLine(String line, DailyEntry entry) {
    final trimmed = line.trim();

    if (!trimmed.startsWith('- [')) return null;

    // Parse title from the line
    String remainder;

    if (trimmed.startsWith('- [x]') || trimmed.startsWith('- [X]')) {
      remainder = trimmed.substring(5).trim();
    } else if (trimmed.startsWith('- [ ]')) {
      remainder = trimmed.substring(5).trim();
    } else {
      return null;
    }

    // Extract title (before the | separator)
    String title;
    if (remainder.contains('|')) {
      title = remainder.split('|')[0].trim();
    } else {
      title = remainder.trim();
    }

    if (title.isEmpty) return null;

    // Find matching task in entry.tasks by title
    try {
      return entry.tasks.firstWhere((t) => t.title == title);
    } catch (e) {
      // No matching task found - this shouldn't happen in normal use
      // Fall back to creating a temporary task for display only
      return null;
    }
  }
}
