import 'package:flutter/material.dart';
import '../theme/theme_compat.dart';

/// Type of item to add
enum ItemType { task, text }

/// Time unit for task duration
enum TimeUnit { minutes, hours }

/// Bottom sheet for adding items to a section
class AddItemSheet extends StatefulWidget {
  final String sectionName;
  final Function(String content, ItemType type, double? hours) onSave;

  const AddItemSheet({
    super.key,
    required this.sectionName,
    required this.onSave,
  });

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contentController;
  late TextEditingController _timeController;
  ItemType _selectedType = ItemType.task;
  TimeUnit _selectedTimeUnit = TimeUnit.hours;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _timeController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _contentController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final content = _contentController.text.trim();
      double? hours;

      if (_selectedType == ItemType.task) {
        final timeValue = double.tryParse(_timeController.text) ?? 1.0;
        // Convert to hours based on selected unit
        hours = _selectedTimeUnit == TimeUnit.hours
            ? timeValue
            : timeValue / 60.0; // Convert minutes to hours
      }

      widget.onSave(content, _selectedType, hours);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
                Expanded(
                  child: Text(
                    'Add to ${widget.sectionName}',
                    style: theme.textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.space20),

            // Item type selector
            Text(
              'Type',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppTheme.space8),
            _buildTypeSelector(theme, colorScheme),

            const SizedBox(height: AppTheme.space20),

            // Content input
            TextFormField(
              controller: _contentController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _getContentLabel(),
                hintText: _getContentHint(),
              ),
              textInputAction: _selectedType == ItemType.task
                  ? TextInputAction.next
                  : TextInputAction.done,
              maxLines: _selectedType == ItemType.text ? 3 : 1,
              onFieldSubmitted:
                  _selectedType != ItemType.task ? (_) => _save() : null,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Content is required';
                }
                return null;
              },
            ),

            // Time input (only for tasks)
            if (_selectedType == ItemType.task) ...[
              const SizedBox(height: AppTheme.space16),
              // Duration input field
              TextFormField(
                controller: _timeController,
                decoration: InputDecoration(
                  labelText: 'Duration (optional)',
                  hintText: _selectedTimeUnit == TimeUnit.hours ? '1' : '30',
                  helperText: 'Leave empty for 1 hour default',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                validator: (value) {
                  // Allow empty - will default to 1.0
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
              // Unit selector (segmented button style - no keyboard dismissal)
              Row(
                children: [
                  Text(
                    'Unit:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: _buildUnitSelector(theme, colorScheme),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppTheme.space32),

            // Save button
            FilledButton(
              onPressed: _save,
              child: Text(_getButtonLabel()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          _buildTypeOption(
            theme: theme,
            colorScheme: colorScheme,
            type: ItemType.task,
            icon: Icons.check_box_outlined,
            label: 'Task',
            isFirst: true,
          ),
          _buildTypeOption(
            theme: theme,
            colorScheme: colorScheme,
            type: ItemType.text,
            icon: Icons.text_fields_outlined,
            label: 'Text',
            isLast: true,
          ),
        ],
      ),
    );
  }

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

  Widget _buildTypeOption({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required ItemType type,
    required IconData icon,
    required String label,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isSelected = _selectedType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.space12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isFirst
                  ? const Radius.circular(AppTheme.radiusMedium - 1)
                  : Radius.zero,
              right: isLast
                  ? const Radius.circular(AppTheme.radiusMedium - 1)
                  : Radius.zero,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: AppTheme.space4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getContentLabel() {
    switch (_selectedType) {
      case ItemType.task:
        return 'Task';
      case ItemType.text:
        return 'Text';
    }
  }

  String _getContentHint() {
    switch (_selectedType) {
      case ItemType.task:
        return 'What needs to be done?';
      case ItemType.text:
        return 'Enter your text...';
    }
  }

  String _getButtonLabel() {
    switch (_selectedType) {
      case ItemType.task:
        return 'Add Task';
      case ItemType.text:
        return 'Add Text';
    }
  }
}
