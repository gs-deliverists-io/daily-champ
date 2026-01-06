import 'package:intl/intl.dart';
import '../models/models.dart';

/// Parses markdown files in execute.md format into DailyEntry objects
class MarkdownParser {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Parse markdown content into list of DailyEntry objects
  ///
  /// SEMANTIC PARSING: Elements are recognized by their type, not location:
  /// - Checkboxes `- [ ]` or `- [x]` = tasks (work ANYWHERE in the document)
  /// - List items `- text`, `* text`, `+ text`, `1. text` = goals/notes (based on section)
  /// - Free text = reflections
  ///
  /// ALL MARKDOWN FEATURES PRESERVED:
  /// - **bold**, *italic*, ~~strikethrough~~
  /// - [links](url) - clickable in UI
  /// - `inline code`
  /// - ```code blocks```
  /// - > blockquotes
  /// - Nested lists (indented)
  /// - Numbered lists (1. 2. 3.)
  /// - Tables
  ///
  /// Supports multiple days in one file, separated by date headers (# YYYY-MM-DD)
  /// Sections (## Headers) are optional and used for organization only
  ///
  /// Example format:
  /// ```
  /// # 2026-01-05 Monday
  ///
  /// ## Goals
  /// - **Primary goal** with emphasis
  /// - Goal with [link](https://example.com)
  ///
  /// ## Custom Section Name
  /// - [ ] Task with **bold** and [link](url) | 2.0h
  /// - Regular note with *italic* text
  /// 1. Numbered list item
  /// 2. Another numbered item
  ///
  /// - [ ] Task without section header | 1.0h
  ///
  /// Free-form paragraph text here.
  ///
  /// ## Tasks
  /// - [x] ~~Completed~~ traditional task | 1.5h
  ///
  /// ## Reflections
  /// Multi-line free-form text
  /// > With blockquotes
  ///
  /// ```code
  /// code blocks preserved
  /// ```
  ///
  /// # 2026-01-04 Sunday
  ///
  /// ## Tasks
  /// - [x] Previous day's task | 1.0h
  /// ```
  static List<DailyEntry> parse(String markdown) {
    final entries = <DailyEntry>[];

    // Split by date headers (# YYYY-MM-DD) instead of --- separators
    // This makes the parser more robust and doesn't require separators
    final lines = markdown.split('\n');
    final dayBlocks = <String>[];
    StringBuffer? currentBlock;

    for (final line in lines) {
      // Check if line starts with # followed by a date pattern
      if (line.trim().startsWith('#') &&
          RegExp(r'^#\s+\d{4}-\d{2}-\d{2}').hasMatch(line.trim())) {
        // Start of a new day - save previous block if exists
        if (currentBlock != null) {
          dayBlocks.add(currentBlock.toString().trim());
        }
        // Start new block with this header
        currentBlock = StringBuffer(line);
      } else if (currentBlock != null) {
        // Add line to current block
        currentBlock.write('\n');
        currentBlock.write(line);
      }
    }

    // Don't forget the last block
    if (currentBlock != null) {
      dayBlocks.add(currentBlock.toString().trim());
    }

    // Parse each day block
    for (final block in dayBlocks) {
      if (block.isNotEmpty) {
        final entry = _parseDay(block);
        if (entry != null) {
          entries.add(entry);
        }
      }
    }

    return entries;
  }

  /// Parse a single day block
  static DailyEntry? _parseDay(String block) {
    final lines = block.split('\n').map((l) => l.trimRight()).toList();

    if (lines.isEmpty) return null;

    // Parse date from first line: # 2026-01-05 Monday
    final date = _parseDate(lines.first);
    if (date == null) return null;

    final entry = DailyEntry(date: date);

    String? currentSectionName;
    final currentSectionItems = <String>[];
    final reflectionLines = <String>[];
    bool inReflectionsSection = false;

    // Helper to save current section
    void saveCurrentSection() {
      if (currentSectionName != null) {
        // Determine section type based on content
        SectionType type;
        if (inReflectionsSection) {
          type = SectionType.text;
        } else if (currentSectionItems.isNotEmpty) {
          // Check if section contains any checkboxes
          final hasCheckboxes = currentSectionItems.any((item) =>
              item.trim().startsWith('- [') &&
              (item.contains('- [ ]') ||
                  item.contains('- [x]') ||
                  item.contains('- [X]')));

          type = hasCheckboxes ? SectionType.tasks : SectionType.list;
        } else {
          // Empty section - default to list type
          type = SectionType.list;
        }

        final section = Section(
          name: currentSectionName,
          items: List.from(currentSectionItems),
          type: type,
        );
        entry.sections.add(section);
        currentSectionItems.clear();
      }
    }

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];

      // Detect section headers
      if (line.startsWith('## ')) {
        // Save previous section
        saveCurrentSection();

        // Start new section
        currentSectionName = line.substring(3).trim();
        inReflectionsSection =
            currentSectionName.toLowerCase() == 'reflections';
        continue;
      }

      // Skip empty lines EXCEPT in reflections (preserve formatting)
      if (line.trim().isEmpty) {
        if (inReflectionsSection) {
          currentSectionItems.add('');
        }
        continue;
      }

      // SEMANTIC PARSING: Parse by element type

      // 1. Check if this is a checkbox task (- [ ] or - [x])
      final task = _parseTask(line);
      if (task != null) {
        // Add to tasks collection for global task management
        entry.tasks.add(task);

        // ALSO add the original line to the section (keep sections intact!)
        // If no current section, add to last section (tasks can follow empty lines)
        if (currentSectionName != null) {
          currentSectionItems.add(line);
        }
        continue;
      }

      // 2. Check if this is a list item
      final listItem = _parseListItem(line);
      if (listItem != null) {
        if (currentSectionName != null) {
          // Add to current section
          currentSectionItems.add(listItem);

          // BACKWARD COMPATIBILITY: Also populate legacy fields
          final sectionLower = currentSectionName.toLowerCase();
          if (sectionLower == 'goals') {
            entry.goals.add(listItem);
          } else if (sectionLower == 'notes') {
            entry.notes.add(listItem);
          }
        } else {
          // No section - add to notes for backward compatibility
          entry.notes.add(listItem);
        }
        continue;
      }

      // 3. Free-form text (reflections, code blocks, etc.)
      if (inReflectionsSection) {
        currentSectionItems.add(line);
      } else if (currentSectionName != null) {
        // Non-list text in a section goes to that section
        currentSectionItems.add(line);
      } else {
        // No section context - add to reflections for backward compat
        reflectionLines.add(line);
      }
    }

    // Save final section
    saveCurrentSection();

    // Handle standalone reflections (backward compatibility)
    if (reflectionLines.isNotEmpty) {
      entry.reflections = reflectionLines.join('\n').trim();
    }

    // If we have a Reflections section, use that instead
    final reflectionsSection = entry.sections.firstWhere(
      (s) => s.name.toLowerCase() == 'reflections',
      orElse: () => Section(name: '', items: []),
    );
    if (reflectionsSection.name.isNotEmpty) {
      entry.reflections = reflectionsSection.items.join('\n').trim();
    }

    return entry;
  }

  /// Parse date from header line: # 2026-01-05 Monday
  static DateTime? _parseDate(String line) {
    final trimmed = line.trim();

    if (!trimmed.startsWith('#')) return null;

    // Remove # and trim
    final content = trimmed.substring(1).trim();

    // Extract date part (before day name)
    final parts = content.split(' ');
    if (parts.isEmpty) return null;

    final dateStr = parts.first;

    try {
      return _dateFormat.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Parse a list item (goals/notes): - Item text
  /// Supports all markdown in list items: links, bold, italic, etc.
  /// Also supports nested lists (indented with spaces/tabs)
  static String? _parseListItem(String line) {
    final trimmed = line.trim();

    // Support unordered lists: -, *, +
    // IMPORTANT: Check for marker + space to avoid matching **bold** syntax
    if (trimmed.startsWith('- ') ||
        trimmed.startsWith('* ') ||
        trimmed.startsWith('+ ')) {
      // Check if it's a checkbox (handled elsewhere)
      if (trimmed.startsWith('- [')) return null;

      // Remove leading marker (2 chars: marker + space) and trim
      // Keep original markdown formatting (links, bold, etc.)
      return trimmed.substring(2).trim();
    }

    // Support numbered lists: 1. Item text
    final numberedMatch = RegExp(r'^\d+\.\s+(.+)$').firstMatch(trimmed);
    if (numberedMatch != null) {
      return numberedMatch.group(1);
    }

    return null;
  }

  /// Parse a task line: - [ ] Task title | 2.0h
  static Task? _parseTask(String line) {
    final trimmed = line.trim();

    if (!trimmed.startsWith('- [')) return null;

    // Determine completion status
    bool isCompleted = false;
    String remainder;

    if (trimmed.startsWith('- [x]') || trimmed.startsWith('- [X]')) {
      isCompleted = true;
      remainder = trimmed.substring(5).trim();
    } else if (trimmed.startsWith('- [ ]')) {
      isCompleted = false;
      remainder = trimmed.substring(5).trim();
    } else {
      return null;
    }

    // Parse title and hours: "Task title | 2.0h"
    String title;
    double hours = 1.0;

    if (remainder.contains('|')) {
      final parts = remainder.split('|');
      title = parts[0].trim();

      if (parts.length > 1) {
        final timeStr = parts[1].trim().toLowerCase();
        // Extract number and unit from "20m", "2.0h", or "2h"
        final match = RegExp(r'(\d+\.?\d*)\s*(m|h)?').firstMatch(timeStr);
        if (match != null) {
          final value = double.tryParse(match.group(1)!) ?? 1.0;
          final unit = match.group(2) ??
              'h'; // default to hours for backward compatibility

          // Convert to hours (internal storage format)
          hours = unit == 'm' ? value / 60.0 : value;
        }
      }
    } else {
      title = remainder;
    }

    if (title.isEmpty) return null;

    return Task(
      title: title,
      estimatedHours: hours,
      isCompleted: isCompleted,
      completedAt: isCompleted ? DateTime.now() : null,
    );
  }

  /// Parse a single day from markdown (convenience method)
  static DailyEntry? parseDay(String markdown) {
    final entries = parse(markdown);
    return entries.isNotEmpty ? entries.first : null;
  }

  /// Validate markdown format
  static bool isValidFormat(String markdown) {
    try {
      final entries = parse(markdown);
      return entries.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
