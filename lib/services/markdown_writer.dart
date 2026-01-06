import 'package:intl/intl.dart';
import '../models/models.dart';
import 'markdown_parser.dart';

/// Writes DailyEntry objects to markdown format for execute.md
///
/// NOTE: This writer outputs a DEFAULT STRUCTURE when the app creates/modifies entries.
/// Users can edit the markdown with ANY structure (tasks anywhere, custom sections, etc.)
/// and the parser will read it correctly using semantic parsing.
///
/// The writer provides a clean, consistent format for app-generated content.
class MarkdownWriter {
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _dayFormat = DateFormat('EEEE');

  /// Write multiple daily entries to markdown format
  ///
  /// Entries are separated by date headers and sorted by date (newest first)
  ///
  /// NOTE: This writer outputs a default structure when the app creates/modifies entries.
  /// When users edit the markdown file directly with any structure, the parser will
  /// read it correctly (semantic parsing). The writer just provides a sensible default.
  static String write(List<DailyEntry> entries) {
    if (entries.isEmpty) return '';

    // Sort entries by date (newest first - reverse chronological)
    final sorted = List<DailyEntry>.from(entries);
    sorted.sort((a, b) => b.date.compareTo(a.date));

    final buffer = StringBuffer();

    for (var i = 0; i < sorted.length; i++) {
      buffer.write(_writeDay(sorted[i]));

      // Add blank lines between entries (but not after last one)
      if (i < sorted.length - 1) {
        buffer.write('\n\n');
      }
    }

    return buffer.toString();
  }

  /// Write a single daily entry to markdown format
  static String writeDay(DailyEntry entry) {
    return _writeDay(entry);
  }

  /// Internal method to write a single day
  static String _writeDay(DailyEntry entry) {
    final buffer = StringBuffer();

    // Write date header: # 2026-01-05 Monday
    final dateStr = _dateFormat.format(entry.date);
    final dayStr = _dayFormat.format(entry.date);
    buffer.writeln('# $dateStr $dayStr');
    buffer.writeln();

    // SEMANTIC MARKDOWN: Write sections in their original order, preserving structure
    if (entry.sections.isNotEmpty) {
      for (final section in entry.sections) {
        buffer.writeln('## ${section.name}');

        if (section.type == SectionType.text) {
          // Free-form text (like Reflections)
          if (section.items.isNotEmpty) {
            buffer.writeln(section.items.join('\n'));
          }
        } else {
          // List items - need to update checkbox states from entry.tasks
          for (final item in section.items) {
            // Check if this is a checkbox line
            if (item.trim().startsWith('- [')) {
              // Find the matching task by title and update its completion status
              final task = _findTaskForItem(item, entry.tasks);
              if (task != null) {
                // Write the task with current completion status
                buffer.writeln(_formatTask(task));
              } else {
                // Task not found in global list - check if it's an empty placeholder
                if (_isEmptyCheckbox(item)) {
                  // Skip empty checkbox placeholders (e.g., "- [ ] | 1.0h")
                  continue;
                }
                // Write malformed/unknown checkbox as-is
                buffer.writeln(item);
              }
            } else {
              // Skip empty list items (single dash with no content)
              if (item.trim().isEmpty) continue;

              // Regular list item - items are stored without the '- ' prefix
              // so add it back when writing
              buffer.writeln('- $item');
            }
          }
        }
        buffer.writeln();
      }
    }
    // BACKWARD COMPATIBILITY: If no sections defined, write legacy format
    else {
      // Write all tasks first (if any) in a Tasks section
      if (entry.tasks.isNotEmpty) {
        buffer.writeln('## Tasks');
        for (final task in entry.tasks) {
          buffer.writeln(_formatTask(task));
        }
        buffer.writeln();
      }

      // Write Goals section (only if not empty)
      if (entry.goals.isNotEmpty) {
        buffer.writeln('## Goals');
        for (final goal in entry.goals) {
          // Goals preserve all markdown: **bold**, [links](url), etc.
          buffer.writeln('- $goal');
        }
        buffer.writeln();
      }

      // Write Notes section (only if not empty)
      if (entry.notes.isNotEmpty) {
        buffer.writeln('## Notes');
        for (final note in entry.notes) {
          // Notes preserve all markdown: **bold**, [links](url), *italic*, etc.
          buffer.writeln('- $note');
        }
        buffer.writeln();
      }

      // Write Reflections section (only if not empty)
      if (entry.reflections.isNotEmpty) {
        buffer.writeln('## Reflections');
        // Reflections can be multi-line with any markdown:
        // blockquotes, code blocks, tables, etc.
        buffer.writeln(entry.reflections);
        buffer.writeln();
      }
    }

    return buffer.toString().trimRight();
  }

  /// Find a task in the global task list by matching the title from a checkbox line
  static Task? _findTaskForItem(String item, List<Task> tasks) {
    final trimmed = item.trim();

    // Must start with checkbox
    if (!trimmed.startsWith('- [')) return null;

    // Extract the content after checkbox marker
    String remainder;
    if (trimmed.startsWith('- [x]') || trimmed.startsWith('- [X]')) {
      remainder = trimmed.substring(5).trim();
    } else if (trimmed.startsWith('- [ ]')) {
      remainder = trimmed.substring(5).trim();
    } else {
      return null;
    }

    // Parse title (before the | separator if present)
    String title;
    if (remainder.contains('|')) {
      title = remainder.split('|')[0].trim();
    } else {
      title = remainder.trim();
    }

    if (title.isEmpty) return null;

    // Find task with matching title
    try {
      return tasks.firstWhere((t) => t.title == title);
    } catch (e) {
      return null;
    }
  }

  /// Format a task as markdown: - [ ] Task title | 2.0h
  static String _formatTask(Task task) {
    final checkbox = task.isCompleted ? '[x]' : '[ ]';
    final hours = _formatHours(task.estimatedHours);
    return '- $checkbox ${task.title} | $hours';
  }

  /// Format hours as string
  /// For < 1 hour: show as minutes (e.g., "20m", "45m")
  /// For >= 1 hour: show as hours (e.g., "1.0h", "2.5h")
  static String _formatHours(double hours) {
    if (hours < 1.0) {
      // Less than 1 hour - show as minutes for precision
      final minutes = (hours * 60).round();
      return '${minutes}m';
    } else {
      // 1 hour or more - show as hours with one decimal
      return '${hours.toStringAsFixed(1)}h';
    }
  }

  /// Check if a checkbox line is an empty placeholder
  /// Returns true for lines like "- [ ] | 1.0h" (no title, just time)
  static bool _isEmptyCheckbox(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('- [')) return false;

    // Extract content after checkbox marker
    String remainder;
    if (trimmed.startsWith('- [x]') || trimmed.startsWith('- [X]')) {
      remainder = trimmed.substring(5).trim();
    } else if (trimmed.startsWith('- [ ]')) {
      remainder = trimmed.substring(5).trim();
    } else {
      return false;
    }

    // Check if remainder is empty or just has time estimate with no title
    if (remainder.isEmpty) return true;
    if (remainder.startsWith('|')) return true; // e.g., "- [ ] | 1.0h"

    return false;
  }

  /// Append a new day entry to existing markdown content
  ///
  /// Adds blank lines if content already exists
  static String appendDay(String existingMarkdown, DailyEntry entry) {
    if (existingMarkdown.trim().isEmpty) {
      return writeDay(entry);
    }

    return '$existingMarkdown\n\n${writeDay(entry)}';
  }

  /// Update an existing day in markdown content
  ///
  /// Finds the day by date and replaces it with updated entry
  /// Returns the updated markdown, or appends if day not found
  static String updateDay(String existingMarkdown, DailyEntry entry) {
    final entries = MarkdownParser.parse(existingMarkdown);

    // Find and replace existing entry, or add new one
    final index = entries.indexWhere((e) =>
        e.date.year == entry.date.year &&
        e.date.month == entry.date.month &&
        e.date.day == entry.date.day);

    if (index != -1) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }

    return write(entries);
  }

  /// Remove a day from markdown content
  static String removeDay(String existingMarkdown, DateTime date) {
    final entries = MarkdownParser.parse(existingMarkdown);

    // Filter out the entry to remove
    final filtered = entries
        .where((e) => !(e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day))
        .toList();

    return write(filtered);
  }
}
