import 'dart:io' if (dart.library.html) 'dart.html' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/day_template.dart';
import '../models/section.dart';
import 'nextcloud_sync_service.dart';

/// Service for managing day templates
///
/// Templates are stored as markdown files in the `dailychamp/templates/` directory.
/// Each template file defines the section structure for a new day.
///
/// **File Location:**
/// - macOS: ~/Nextcloud/Notes/dailychamp/templates/*.md
/// - iOS/Android: App Documents/dailychamp/templates/*.md
/// - Web: localStorage (JSON format)
///
/// **Nextcloud Sync:**
/// When Nextcloud sync is configured, templates are also fetched from the server.
/// Server templates take precedence over local ones with the same ID.
class TemplateService {
  static const String _templatesDir = 'templates';
  static const String _webStorageKey = 'dailychamp_templates';
  static const String _defaultTemplateKey = 'default_template_id';

  final String? customBasePath;

  /// Nextcloud sync service for fetching remote templates
  NextcloudSyncService? _nextcloudService;

  // Cached templates directory path
  String? _templatesDirPath;

  // Cached remote templates (to avoid repeated network calls)
  List<DayTemplate>? _cachedRemoteTemplates;
  DateTime? _cacheExpiry;

  TemplateService({this.customBasePath});

  /// Configure Nextcloud sync for templates
  void configureNextcloud({
    required String serverUrl,
    required String username,
    required String password,
    String? filePath,
  }) {
    _nextcloudService = NextcloudSyncService(
      serverUrl: serverUrl,
      username: username,
      password: password,
      filePath: filePath ?? '/Notes/dailychamp/daily.md',
    );
    // Invalidate cache when reconfigured
    _cachedRemoteTemplates = null;
    _cacheExpiry = null;
  }

  /// Stop Nextcloud sync for templates
  void stopNextcloud() {
    _nextcloudService = null;
    _cachedRemoteTemplates = null;
    _cacheExpiry = null;
  }

  /// Check if Nextcloud is configured
  bool get hasNextcloud => _nextcloudService != null;

  /// Get the templates directory path
  Future<String> getTemplatesPath() async {
    if (_templatesDirPath != null) return _templatesDirPath!;

    if (kIsWeb) {
      _templatesDirPath = 'localStorage://$_webStorageKey';
      return _templatesDirPath!;
    }

    String basePath;

    // Use custom path if provided on macOS
    if (customBasePath != null &&
        customBasePath!.isNotEmpty &&
        io.Platform.isMacOS) {
      // Extract directory from file path (e.g., "~/Nextcloud/Notes/dailychamp.md" -> "~/Nextcloud/Notes")
      final parentDir = io.File(customBasePath!).parent.path;
      basePath = '$parentDir/dailychamp';
    } else if (io.Platform.isMacOS) {
      // Default macOS path
      basePath = '/Users/gs/Nextcloud/Notes/dailychamp';
    } else {
      // iOS/Android: use app documents directory
      final directory = await getApplicationDocumentsDirectory();
      basePath = '${directory.path}/dailychamp';
    }

    _templatesDirPath = '$basePath/$_templatesDir';

    // Ensure templates directory exists
    final templatesDir = io.Directory(_templatesDirPath!);
    if (!await templatesDir.exists()) {
      await templatesDir.create(recursive: true);
    }

    return _templatesDirPath!;
  }

  /// List all available templates
  ///
  /// Returns built-in templates plus any user-created templates.
  /// If Nextcloud is configured, also fetches remote templates.
  /// Templates are sorted by name.
  Future<List<DayTemplate>> listTemplates() async {
    final templates = <DayTemplate>[];
    final templateIds = <String>{}; // Track IDs to avoid duplicates

    // Always include built-in templates
    templates.add(DayTemplate.empty());
    templates.add(DayTemplate.weekday());
    templates.add(DayTemplate.weekend());
    templateIds.addAll(['blank', 'weekday', 'weekend']);

    // First, try to load templates from Nextcloud if configured
    if (_nextcloudService != null) {
      try {
        final remoteTemplates = await _loadTemplatesFromNextcloud();
        for (final template in remoteTemplates) {
          if (!templateIds.contains(template.id)) {
            templates.add(template);
            templateIds.add(template.id);
          }
        }
      } catch (e) {
        // Silently fail - continue with local templates
        // ignore: avoid_print
        print('Error loading Nextcloud templates: $e');
      }
    }

    if (kIsWeb) {
      // On web, templates are stored in localStorage as JSON
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_webStorageKey);
      if (json != null) {
        // Parse user-created templates from JSON
        // For now, just use built-in templates on web
      }
    } else {
      // Load user-created templates from local files
      try {
        final templatesPath = await getTemplatesPath();
        final templatesDir = io.Directory(templatesPath);

        if (await templatesDir.exists()) {
          await for (final entity in templatesDir.list()) {
            if (entity is io.File && entity.path.endsWith('.md')) {
              final template = await _loadTemplateFromFile(entity);
              if (template != null) {
                // Skip if already loaded (from Nextcloud or built-in)
                if (!templateIds.contains(template.id)) {
                  templates.add(template);
                  templateIds.add(template.id);
                }
              }
            }
          }
        }
      } catch (e) {
        // Silently fail - return built-in templates only
        // ignore: avoid_print
        print('Error loading templates: $e');
      }
    }

    // Sort by name (but keep Blank first)
    templates.sort((a, b) {
      if (a.id == 'blank') return -1;
      if (b.id == 'blank') return 1;
      return a.name.compareTo(b.name);
    });

    return templates;
  }

  /// Load templates from Nextcloud
  Future<List<DayTemplate>> _loadTemplatesFromNextcloud() async {
    if (_nextcloudService == null) return [];

    // Check cache
    if (_cachedRemoteTemplates != null &&
        _cacheExpiry != null &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      return _cachedRemoteTemplates!;
    }

    final templates = <DayTemplate>[];

    try {
      // List files in templates directory
      final templatesPath = _nextcloudService!.templatesPath;
      final files = await _nextcloudService!.listDirectory(templatesPath);

      for (final fileName in files) {
        // Download and parse each template file
        final filePath = '$templatesPath/$fileName';
        final content = await _nextcloudService!.downloadFile(filePath);

        if (content != null) {
          final id = fileName.replaceAll('.md', '');
          final template = _parseTemplateMarkdown(content, id);
          if (template != null) {
            templates.add(template);
          }
        }
      }

      // Cache for 5 minutes
      _cachedRemoteTemplates = templates;
      _cacheExpiry = DateTime.now().add(const Duration(minutes: 5));
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching Nextcloud templates: $e');
    }

    return templates;
  }

  /// Load a template by ID
  /// Checks built-in templates first, then Nextcloud (if configured), then local files.
  Future<DayTemplate?> loadTemplate(String id) async {
    // Check built-in templates first
    switch (id) {
      case 'blank':
        return DayTemplate.empty();
      case 'weekday':
        return DayTemplate.weekday();
      case 'weekend':
        return DayTemplate.weekend();
    }

    // Try Nextcloud if configured
    if (_nextcloudService != null) {
      try {
        final templatesPath = _nextcloudService!.templatesPath;
        final content =
            await _nextcloudService!.downloadFile('$templatesPath/$id.md');
        if (content != null) {
          final template = _parseTemplateMarkdown(content, id);
          if (template != null) return template;
        }
      } catch (e) {
        // Silently fail - try local file
        // ignore: avoid_print
        print('Error loading Nextcloud template $id: $e');
      }
    }

    if (kIsWeb) {
      // Web: load from localStorage
      return null; // TODO: Implement web template storage
    }

    // Load from local file
    try {
      final templatesPath = await getTemplatesPath();
      final file = io.File('$templatesPath/$id.md');

      if (await file.exists()) {
        return await _loadTemplateFromFile(file);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading template $id: $e');
    }

    return null;
  }

  /// Save a template to file (and optionally to Nextcloud)
  Future<void> saveTemplate(DayTemplate template) async {
    if (kIsWeb) {
      // Web: save to localStorage
      // TODO: Implement web template storage
      return;
    }

    final markdown = _templateToMarkdown(template);

    try {
      // Save locally first
      final templatesPath = await getTemplatesPath();
      final file = io.File('$templatesPath/${template.id}.md');
      await file.writeAsString(markdown);

      // Also upload to Nextcloud if configured
      if (_nextcloudService != null) {
        try {
          final remotePath =
              '${_nextcloudService!.templatesPath}/${template.id}.md';
          await _nextcloudService!.uploadFile(remotePath, markdown);
        } catch (e) {
          // Silently fail Nextcloud upload - local save succeeded
          // ignore: avoid_print
          print('Warning: Failed to upload template to Nextcloud: $e');
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error saving template ${template.id}: $e');
      rethrow;
    }
  }

  /// Delete a template
  Future<void> deleteTemplate(String id) async {
    // Cannot delete built-in templates
    if (['blank', 'weekday', 'weekend'].contains(id)) {
      throw TemplateServiceException('Cannot delete built-in template');
    }

    if (kIsWeb) {
      // TODO: Implement web template deletion
      return;
    }

    try {
      final templatesPath = await getTemplatesPath();
      final file = io.File('$templatesPath/$id.md');

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error deleting template $id: $e');
      rethrow;
    }
  }

  /// Get the default template ID
  Future<String> getDefaultTemplateId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultTemplateKey) ?? 'blank';
  }

  /// Set the default template ID
  Future<void> setDefaultTemplateId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultTemplateKey, id);
  }

  /// Get the default template
  Future<DayTemplate> getDefaultTemplate() async {
    final id = await getDefaultTemplateId();
    return await loadTemplate(id) ?? DayTemplate.empty();
  }

  /// Create default template files if they don't exist (locally and on Nextcloud)
  Future<void> createDefaultTemplateFiles() async {
    if (kIsWeb) return;

    try {
      final templatesPath = await getTemplatesPath();

      // Create weekday.md if it doesn't exist
      final weekdayFile = io.File('$templatesPath/weekday.md');
      final weekdayMarkdown = _templateToMarkdown(DayTemplate.weekday());
      if (!await weekdayFile.exists()) {
        await weekdayFile.writeAsString(weekdayMarkdown);
      }

      // Create weekend.md if it doesn't exist
      final weekendFile = io.File('$templatesPath/weekend.md');
      final weekendMarkdown = _templateToMarkdown(DayTemplate.weekend());
      if (!await weekendFile.exists()) {
        await weekendFile.writeAsString(weekendMarkdown);
      }

      // Also upload to Nextcloud if configured
      if (_nextcloudService != null) {
        try {
          final remoteTemplatesPath = _nextcloudService!.templatesPath;

          // Check if weekday.md exists on Nextcloud
          final remoteWeekday = await _nextcloudService!
              .downloadFile('$remoteTemplatesPath/weekday.md');
          if (remoteWeekday == null) {
            await _nextcloudService!
                .uploadFile('$remoteTemplatesPath/weekday.md', weekdayMarkdown);
          }

          // Check if weekend.md exists on Nextcloud
          final remoteWeekend = await _nextcloudService!
              .downloadFile('$remoteTemplatesPath/weekend.md');
          if (remoteWeekend == null) {
            await _nextcloudService!
                .uploadFile('$remoteTemplatesPath/weekend.md', weekendMarkdown);
          }
        } catch (e) {
          // Silently fail - local files created successfully
          // ignore: avoid_print
          print('Warning: Failed to upload default templates to Nextcloud: $e');
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error creating default template files: $e');
    }
  }

  /// Load a template from a markdown file
  Future<DayTemplate?> _loadTemplateFromFile(io.File file) async {
    try {
      final content = await file.readAsString();
      final fileName = file.path.split('/').last.replaceAll('.md', '');

      return _parseTemplateMarkdown(content, fileName);
    } catch (e) {
      // ignore: avoid_print
      print('Error parsing template file ${file.path}: $e');
      return null;
    }
  }

  /// Parse template markdown into a DayTemplate
  ///
  /// Template format:
  /// ```markdown
  /// ## Section Name
  /// - placeholder item
  /// - [ ] task placeholder | 1.0h
  ///
  /// ## Another Section
  /// Free text section content
  /// ```
  DayTemplate? _parseTemplateMarkdown(String content, String id) {
    final lines = content.split('\n');
    final sections = <TemplateSection>[];

    String? currentSectionName;
    var currentSectionItems = <String>[];
    SectionType currentSectionType = SectionType.list;

    void saveCurrentSection() {
      if (currentSectionName != null) {
        sections.add(TemplateSection(
          name: currentSectionName,
          type: currentSectionType,
          placeholderItems: List.from(currentSectionItems),
        ));
        currentSectionItems = [];
        currentSectionType = SectionType.list;
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();

      // Section header
      if (trimmed.startsWith('## ')) {
        saveCurrentSection();
        currentSectionName = trimmed.substring(3).trim();

        // Detect section type from name
        if (currentSectionName.toLowerCase() == 'reflections') {
          currentSectionType = SectionType.text;
        }
        continue;
      }

      // Skip empty lines outside of text sections
      if (trimmed.isEmpty && currentSectionType != SectionType.text) {
        continue;
      }

      // Add line to current section
      if (currentSectionName != null) {
        // Detect if this is a task section
        if (trimmed.startsWith('- [')) {
          currentSectionType = SectionType.tasks;
          currentSectionItems.add(trimmed);
        } else if (trimmed.startsWith('- ') ||
            trimmed.startsWith('* ') ||
            trimmed.startsWith('+ ')) {
          // Regular list item - store without prefix
          currentSectionItems.add(trimmed.substring(2).trim());
        } else if (currentSectionType == SectionType.text) {
          // Text section - preserve line
          currentSectionItems.add(line);
        } else {
          // Other content
          currentSectionItems.add(trimmed);
        }
      }
    }

    // Save last section
    saveCurrentSection();

    if (sections.isEmpty) {
      return null;
    }

    // Generate display name from id (snake_case to Title Case)
    final name = id
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');

    return DayTemplate(
      id: id,
      name: name,
      sections: sections,
      filePath: '$id.md',
    );
  }

  /// Convert a template to markdown format
  String _templateToMarkdown(DayTemplate template) {
    final buffer = StringBuffer();

    for (final section in template.sections) {
      buffer.writeln('## ${section.name}');

      if (section.type == SectionType.text) {
        // Text sections - write content as-is
        for (final item in section.placeholderItems) {
          buffer.writeln(item);
        }
      } else if (section.type == SectionType.tasks) {
        // Task sections - items should already have checkbox format
        for (final item in section.placeholderItems) {
          if (item.startsWith('- [')) {
            buffer.writeln(item);
          } else {
            // Add checkbox if missing
            buffer.writeln('- [ ] $item');
          }
        }
        // Add empty task placeholder if no items
        if (section.placeholderItems.isEmpty) {
          buffer.writeln('- [ ] | 1.0h');
        }
      } else {
        // List sections
        for (final item in section.placeholderItems) {
          if (item.isEmpty) {
            buffer.writeln('- ');
          } else {
            buffer.writeln('- $item');
          }
        }
        // Add empty placeholder if no items
        if (section.placeholderItems.isEmpty) {
          buffer.writeln('- ');
        }
      }

      buffer.writeln();
    }

    return buffer.toString().trimRight();
  }
}

/// Custom exception for template service errors
class TemplateServiceException implements Exception {
  final String message;

  TemplateServiceException(this.message);

  @override
  String toString() => 'TemplateServiceException: $message';
}
