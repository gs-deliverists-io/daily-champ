import 'package:flutter/material.dart';
import '../theme/theme_compat.dart';

/// Type of item to add
enum ItemType { task, note, text }

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
  ItemType _selectedType = ItemType.note;
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
            type: ItemType.note,
            icon: Icons.notes_outlined,
            label: 'Note',
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
      case ItemType.note:
        return 'Note';
      case ItemType.text:
        return 'Text';
    }
  }

  String _getContentHint() {
    switch (_selectedType) {
      case ItemType.task:
        return 'What needs to be done?';
      case ItemType.note:
        return 'Add a note...';
      case ItemType.text:
        return 'Enter your text...';
    }
  }

  String _getButtonLabel() {
    switch (_selectedType) {
      case ItemType.task:
        return 'Add Task';
      case ItemType.note:
        return 'Add Note';
      case ItemType.text:
        return 'Add Text';
    }
  }
}
