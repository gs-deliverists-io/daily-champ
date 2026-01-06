import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/dailychamp_provider.dart';
import '../services/template_service.dart';

/// Dialog for selecting a template to apply to a date
class TemplateSelectionDialog extends StatefulWidget {
  final DateTime date;

  const TemplateSelectionDialog({
    super.key,
    required this.date,
  });

  @override
  State<TemplateSelectionDialog> createState() =>
      _TemplateSelectionDialogState();
}

class _TemplateSelectionDialogState extends State<TemplateSelectionDialog> {
  late TemplateService _templateService;
  List<DayTemplate>? _templates;
  String? _error;
  bool _isLoading = true;
  String? _defaultTemplateId;

  @override
  void initState() {
    super.initState();
    _templateService = TemplateService();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    // Configure Nextcloud if credentials are available
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('nextcloud_server_url')) {
      final serverUrl = prefs.getString('nextcloud_server_url');
      final username = prefs.getString('nextcloud_username');
      final password = prefs.getString('nextcloud_password');
      final filePath = prefs.getString('nextcloud_file_path');

      if (serverUrl != null && username != null && password != null) {
        _templateService.configureNextcloud(
          serverUrl: serverUrl,
          username: username,
          password: password,
          filePath: filePath,
        );
      }
    }

    // Load default template ID
    _defaultTemplateId = await _templateService.getDefaultTemplateId();

    await _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final templates = await _templateService.listTemplates();

      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load templates: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _setAsDefault(String templateId) async {
    await _templateService.setDefaultTemplateId(templateId);
    setState(() {
      _defaultTemplateId = templateId;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Set "$templateId" as default template'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _applyTemplate(DayTemplate template) async {
    final provider = context.read<DailyChampProvider>();
    final existingEntry = provider.getEntryForDate(widget.date);

    // Check if day already has content
    final hasExistingContent = existingEntry != null &&
        (existingEntry.sections.isNotEmpty || existingEntry.tasks.isNotEmpty);

    bool shouldReplace = true;

    if (hasExistingContent) {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace Current Day?'),
          content: const Text(
            'This day already has content. Applying this template will replace all existing sections and tasks.\n\nContinue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Replace'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return; // User cancelled
      }
      shouldReplace = true;
    }

    try {
      await provider.applyTemplate(widget.date, template,
          replace: shouldReplace);

      if (mounted) {
        Navigator.of(context).pop(template.id); // Return template ID on success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied "${template.name}" template'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Select Template'),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(null),
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(),
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTemplates,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_templates == null || _templates!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No templates available'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _templates!.length,
      itemBuilder: (context, index) {
        final template = _templates![index];
        final isDefault = template.id == _defaultTemplateId;

        return ListTile(
          leading: isDefault
              ? const Icon(Icons.star, color: Colors.amber)
              : const Icon(Icons.description_outlined),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  template.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: template.description != null
              ? Text(template.description!)
              : Text('${template.sections.length} sections'),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'apply') {
                _applyTemplate(template);
              } else if (value == 'default') {
                _setAsDefault(template.id);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'apply',
                child: Row(
                  children: [
                    Icon(Icons.check),
                    SizedBox(width: 8),
                    Text('Apply'),
                  ],
                ),
              ),
              if (!isDefault)
                const PopupMenuItem(
                  value: 'default',
                  child: Row(
                    children: [
                      Icon(Icons.star_outline),
                      SizedBox(width: 8),
                      Text('Set as Default'),
                    ],
                  ),
                ),
            ],
          ),
          onTap: () => _applyTemplate(template),
        );
      },
    );
  }
}

/// Show template selection dialog
/// Returns the template ID if a template was applied, null if cancelled
Future<String?> showTemplateSelectionDialog(
  BuildContext context,
  DateTime date,
) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (context) => TemplateSelectionDialog(date: date),
  );
}
