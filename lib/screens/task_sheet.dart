import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme_compat.dart';

/// Time unit for task duration
enum TimeUnit { minutes, hours }

/// Bottom sheet for adding or editing a task
class TaskSheet extends StatefulWidget {
  final Task? task; // null for add, non-null for edit
  final Function(String title, double hours) onSave;

  const TaskSheet({
    super.key,
    this.task,
    required this.onSave,
  });

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  late TextEditingController _titleController;
  late TextEditingController _timeController;
  late TimeUnit _selectedTimeUnit;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');

    // Initialize time value and unit based on existing task
    final hours = widget.task?.estimatedHours ?? 0.0;
    if (hours == 0.0) {
      // No duration set, leave empty (will show default hint)
      _selectedTimeUnit = TimeUnit.hours;
      _timeController = TextEditingController(text: '');
    } else if (hours < 1.0) {
      // Less than 1 hour, show as minutes
      _selectedTimeUnit = TimeUnit.minutes;
      _timeController = TextEditingController(
        text: (hours * 60).toStringAsFixed(0),
      );
    } else {
      // 1 hour or more, show as hours
      _selectedTimeUnit = TimeUnit.hours;
      _timeController = TextEditingController(
        text: hours.toStringAsFixed(1),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text.trim();

      // Duration is optional - if empty, use 0.0
      final timeText = _timeController.text.trim();
      final timeValue =
          timeText.isEmpty ? 0.0 : (double.tryParse(timeText) ?? 0.0);

      // Convert to hours based on selected unit
      final hours = _selectedTimeUnit == TimeUnit.hours
          ? timeValue
          : timeValue / 60.0; // Convert minutes to hours

      widget.onSave(title, hours);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.task != null;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppTheme.space24,
        right: AppTheme.space24,
        top: AppTheme.space24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.space24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'Edit Task' : 'New Task',
                  style: AppTheme.headlineMedium,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppTheme.textSecondary,
                ),
              ],
            ),

            const SizedBox(height: AppTheme.space24),

            // Task title
            TextFormField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Task',
                hintText: 'What needs to be done?',
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Task title is required';
                }
                return null;
              },
            ),

            const SizedBox(height: AppTheme.space16),

            // Duration input field
            TextFormField(
              controller: _timeController,
              decoration: InputDecoration(
                labelText: 'Duration (optional)',
                hintText: _selectedTimeUnit == TimeUnit.hours ? '1' : '30',
                helperText: 'Leave empty for no duration',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              validator: (value) {
                // Allow empty for optional duration
                if (value == null || value.trim().isEmpty) {
                  return null;
                }
                final time = double.tryParse(value);
                if (time == null || time <= 0) {
                  return 'Must be a positive number';
                }
                return null;
              },
            ),

            const SizedBox(height: AppTheme.space12),

            // Unit selector (segmented button style - consistent with AddItemSheet)
            Row(
              children: [
                Text(
                  'Unit:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: _buildUnitSelector(theme, theme.colorScheme),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.space32),

            // Save button
            ElevatedButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save Changes' : 'Add Task'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build unit selector with segmented button style (consistent with AddItemSheet)
  Widget _buildUnitSelector(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          _buildUnitOption(
            theme: theme,
            colorScheme: colorScheme,
            unit: TimeUnit.minutes,
            label: 'Minutes',
            isFirst: true,
          ),
          _buildUnitOption(
            theme: theme,
            colorScheme: colorScheme,
            unit: TimeUnit.hours,
            label: 'Hours',
            isLast: true,
          ),
        ],
      ),
    );
  }

  /// Build individual unit option button
  Widget _buildUnitOption({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required TimeUnit unit,
    required String label,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isSelected = _selectedTimeUnit == unit;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTimeUnit = unit),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.space8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isFirst
                  ? const Radius.circular(AppTheme.radiusSmall - 1)
                  : Radius.zero,
              right: isLast
                  ? const Radius.circular(AppTheme.radiusSmall - 1)
                  : Radius.zero,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
