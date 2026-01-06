import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme_compat.dart';

/// Dialog for creating a new section
class AddSectionDialog extends StatefulWidget {
  final Function(String name, SectionType type) onSave;

  const AddSectionDialog({
    super.key,
    required this.onSave,
  });

  @override
  State<AddSectionDialog> createState() => _AddSectionDialogState();
}

class _AddSectionDialogState extends State<AddSectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  SectionType _selectedType = SectionType.list;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      widget.onSave(name, _selectedType);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Text(
        'New Section',
        style: theme.textTheme.titleLarge,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section name input
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Section Name',
                  hintText: 'e.g., Morning Routine, Goals',
                ),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Section name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppTheme.space20),

              // Section type selector
              Text(
                'Section Type',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: AppTheme.space8),

              _buildTypeOption(
                theme: theme,
                colorScheme: colorScheme,
                type: SectionType.list,
                icon: Icons.list_outlined,
                title: 'List',
                subtitle: 'Bullet points and notes',
              ),
              const SizedBox(height: AppTheme.space8),
              _buildTypeOption(
                theme: theme,
                colorScheme: colorScheme,
                type: SectionType.text,
                icon: Icons.text_fields_outlined,
                title: 'Text',
                subtitle: 'Free-form text content',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required SectionType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.8)
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 20,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows the add section dialog and returns the result
Future<void> showAddSectionDialog({
  required BuildContext context,
  required Function(String name, SectionType type) onSave,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AddSectionDialog(onSave: onSave),
  );
}
