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
    final hours = widget.task?.estimatedHours ?? 1.0;
    if (hours < 1.0) {
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
      final timeValue = double.tryParse(_timeController.text) ?? 1.0;

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

            // Time input with unit selector
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time value input
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _timeController,
                    decoration: InputDecoration(
                      labelText: 'Duration',
                      hintText:
                          _selectedTimeUnit == TimeUnit.hours ? '1' : '30',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      final time = double.tryParse(value);
                      if (time == null || time <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                // Unit selector dropdown
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<TimeUnit>(
                    value: _selectedTimeUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TimeUnit.minutes,
                        child: Text('min'),
                      ),
                      DropdownMenuItem(
                        value: TimeUnit.hours,
                        child: Text('hrs'),
                      ),
                    ],
                    onChanged: (TimeUnit? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedTimeUnit = newValue;
                        });
                      }
                    },
                  ),
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
}
