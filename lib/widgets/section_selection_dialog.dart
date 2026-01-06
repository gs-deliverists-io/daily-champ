import 'package:flutter/material.dart';

import '../models/models.dart';

/// Dialog for selecting a target section when copying a task
class SectionSelectionDialog extends StatelessWidget {
  final List<Section> sections;
  final String title;
  final String? subtitle;

  const SectionSelectionDialog({
    super.key,
    required this.sections,
    this.title = 'Select Section',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Filter to only task sections
    final taskSections =
        sections.where((s) => s.type == SectionType.tasks).toList();

    // If no task sections, offer to create one
    if (taskSections.isEmpty) {
      return AlertDialog(
        title: Text(title),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No task sections found.\nThe task will be added to a new "Tasks" section.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('Tasks'),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitle != null) ...[
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],
            ListView.builder(
              shrinkWrap: true,
              itemCount: taskSections.length,
              itemBuilder: (context, index) {
                final section = taskSections[index];
                return ListTile(
                  title: Text(section.name),
                  subtitle: Text('${section.items.length} items'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => Navigator.of(context).pop(section.name),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Show section selection dialog
///
/// Returns the selected section name, or null if cancelled
Future<String?> showSectionSelectionDialog(
  BuildContext context,
  List<Section> sections, {
  String? title,
  String? subtitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => SectionSelectionDialog(
      sections: sections,
      title: title ?? 'Select Section',
      subtitle: subtitle,
    ),
  );
}
