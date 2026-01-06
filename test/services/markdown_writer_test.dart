import 'package:flutter_test/flutter_test.dart';
import 'package:dailychamp_app/models/models.dart';
import 'package:dailychamp_app/services/markdown_writer.dart';
import 'package:dailychamp_app/services/markdown_parser.dart';

void main() {
  group('MarkdownWriter', () {
    test('writes single day with all sections', () {
      final entry = DailyEntry(
        date: DateTime(2026, 1, 5),
        goals: ['Complete website redesign mockups', 'Maintain workout streak'],
        tasks: [
          Task(
              title: 'Design homepage', estimatedHours: 2.0, isCompleted: true),
          Task(
              title: 'Client meeting', estimatedHours: 1.0, isCompleted: false),
          Task(title: 'Workout', estimatedHours: 1.0, isCompleted: false),
        ],
        notes: [
          'Client prefers minimal design',
          'Focus on mobile-first approach'
        ],
        reflections: 'Great focus today! Made solid progress.',
      );

      final markdown = MarkdownWriter.writeDay(entry);

      expect(markdown, contains('# 2026-01-05 Monday'));
      expect(markdown, contains('## Goals'));
      expect(markdown, contains('- Complete website redesign mockups'));
      expect(markdown, contains('- Maintain workout streak'));
      expect(markdown, contains('## Tasks'));
      expect(markdown, contains('- [x] Design homepage | 2.0h'));
      expect(markdown, contains('- [ ] Client meeting | 1.0h'));
      expect(markdown, contains('- [ ] Workout | 1.0h'));
      expect(markdown, contains('## Notes'));
      expect(markdown, contains('- Client prefers minimal design'));
      expect(markdown, contains('## Reflections'));
      expect(markdown, contains('Great focus today!'));
    });

    test('writes empty entry with just date header', () {
      // With dynamic sections, empty entries don't write empty sections
      // This is cleaner and more semantic - sections are only written when they have content
      final entry = DailyEntry(
        date: DateTime(2026, 1, 5),
      );

      final markdown = MarkdownWriter.writeDay(entry);

      expect(markdown, contains('# 2026-01-05 Monday'));
      // Empty entries should NOT have section headers (cleaner output)
      // The old behavior wrote empty sections, new behavior omits them
    });

    test('writes multiple days with separators', () {
      final entries = [
        DailyEntry(
          date: DateTime(2026, 1, 5),
          goals: ['Goal 1'],
        ),
        DailyEntry(
          date: DateTime(2026, 1, 6),
          goals: ['Goal 2'],
        ),
      ];

      final markdown = MarkdownWriter.write(entries);

      expect(markdown, contains('# 2026-01-05 Monday'));
      expect(markdown, contains('# 2026-01-06 Tuesday'));
      // Days are separated by date headers, not --- markers
      expect(markdown.split('# 202').length - 1, 2); // Two date headers
    });

    test('sorts entries by date when writing', () {
      final entries = [
        DailyEntry(
          date: DateTime(2026, 1, 7),
          goals: ['Goal for day 7'], // Add content so sections are written
        ),
        DailyEntry(
          date: DateTime(2026, 1, 5),
          goals: ['Goal for day 5'],
        ),
        DailyEntry(
          date: DateTime(2026, 1, 6),
          goals: ['Goal for day 6'],
        ),
      ];

      final markdown = MarkdownWriter.write(entries);

      // Entries are sorted in REVERSE chronological order (newest first)
      final day7Index = markdown.indexOf('2026-01-07');
      final day6Index = markdown.indexOf('2026-01-06');
      final day5Index = markdown.indexOf('2026-01-05');

      expect(day7Index, lessThan(day6Index));
      expect(day6Index, lessThan(day5Index));
    });

    test('formats hours with one decimal place', () {
      final entry = DailyEntry(
        date: DateTime(2026, 1, 5),
        tasks: [
          Task(title: 'Task 1', estimatedHours: 1.0),
          Task(title: 'Task 2', estimatedHours: 2.5),
          Task(title: 'Task 3', estimatedHours: 0.5),
        ],
      );

      final markdown = MarkdownWriter.writeDay(entry);

      expect(markdown, contains('| 1.0h'));
      expect(markdown, contains('| 2.5h'));
      expect(
          markdown, contains('| 30m')); // 0.5h = 30 minutes, formatted as "30m"
    });

    test('round-trip conversion preserves data', () {
      final original = DailyEntry(
        date: DateTime(2026, 1, 5),
        goals: ['Goal 1', 'Goal 2'],
        tasks: [
          Task(title: 'Task 1', estimatedHours: 2.0, isCompleted: true),
          Task(title: 'Task 2', estimatedHours: 1.5, isCompleted: false),
        ],
        notes: ['Note 1', 'Note 2'],
        reflections: 'Reflection text here',
      );

      final markdown = MarkdownWriter.writeDay(original);
      final parsed = MarkdownParser.parseDay(markdown);

      expect(parsed, isNotNull);
      expect(parsed!.date, original.date);
      expect(parsed.goals.length, original.goals.length);
      expect(parsed.goals[0], original.goals[0]);
      expect(parsed.goals[1], original.goals[1]);
      expect(parsed.tasks.length, original.tasks.length);
      expect(parsed.tasks[0].title, original.tasks[0].title);
      expect(parsed.tasks[0].estimatedHours, original.tasks[0].estimatedHours);
      expect(parsed.tasks[0].isCompleted, original.tasks[0].isCompleted);
      expect(parsed.notes.length, original.notes.length);
      expect(parsed.reflections, original.reflections);
    });

    test('preserves time precision for minutes format', () {
      final original = DailyEntry(
        date: DateTime(2026, 1, 6),
        tasks: [
          Task(
              title: 'Task 20min', estimatedHours: 20 / 60.0), // 0.333... hours
          Task(title: 'Task 45min', estimatedHours: 45 / 60.0), // 0.75 hours
          Task(title: 'Task 90min', estimatedHours: 90 / 60.0), // 1.5 hours
        ],
      );

      // Write to markdown
      final markdown = MarkdownWriter.writeDay(original);

      // Verify minute format in markdown for < 1 hour
      expect(markdown, contains('| 20m'));
      expect(markdown, contains('| 45m'));
      expect(markdown, contains('| 1.5h')); // >= 1 hour uses hours format

      // Parse back and verify precision is preserved
      final parsed = MarkdownParser.parseDay(markdown);

      expect(parsed, isNotNull);
      expect(parsed!.tasks.length, 3);

      // Check that 20 minutes round-trips correctly (within small tolerance)
      expect(
          (parsed.tasks[0].estimatedHours - 20 / 60.0).abs(), lessThan(0.001));
      expect(
          (parsed.tasks[1].estimatedHours - 45 / 60.0).abs(), lessThan(0.001));
      expect(
          (parsed.tasks[2].estimatedHours - 90 / 60.0).abs(), lessThan(0.001));
    });

    test('appendDay adds to existing markdown', () {
      const existing = '''
# 2026-01-05 Monday

## Goals
- Goal 1

## Tasks

## Notes

## Reflections
''';

      final newEntry = DailyEntry(
        date: DateTime(2026, 1, 6),
        goals: ['Goal 2'],
      );

      final result = MarkdownWriter.appendDay(existing, newEntry);

      expect(result, contains('# 2026-01-05 Monday'));
      expect(result, contains('# 2026-01-06 Tuesday'));
      // Days are separated by date headers, not --- markers
    });

    test('appendDay to empty markdown works', () {
      final entry = DailyEntry(
        date: DateTime(2026, 1, 5),
        goals: ['Goal 1'],
      );

      final result = MarkdownWriter.appendDay('', entry);

      expect(result, contains('# 2026-01-05 Monday'));
      // Single entry, no separator needed
    });

    test('updateDay replaces existing entry', () {
      const existing = '''
# 2026-01-05 Monday

## Goals
- Old goal

## Tasks

## Notes

## Reflections

---

# 2026-01-06 Tuesday

## Goals
- Goal 2

## Tasks

## Notes

## Reflections
''';

      final updatedEntry = DailyEntry(
        date: DateTime(2026, 1, 5),
        goals: ['New goal'],
      );

      final result = MarkdownWriter.updateDay(existing, updatedEntry);

      expect(result, contains('New goal'));
      expect(result, isNot(contains('Old goal')));
      expect(result, contains('# 2026-01-06 Tuesday'));
    });

    test('updateDay adds new entry if not found', () {
      const existing = '''
# 2026-01-05 Monday

## Goals
- Goal 1

## Tasks

## Notes

## Reflections
''';

      final newEntry = DailyEntry(
        date: DateTime(2026, 1, 6),
        goals: ['Goal 2'],
      );

      final result = MarkdownWriter.updateDay(existing, newEntry);

      expect(result, contains('# 2026-01-05 Monday'));
      expect(result, contains('# 2026-01-06 Tuesday'));
    });

    test('removeDay removes entry from markdown', () {
      const existing = '''
# 2026-01-05 Monday

## Goals
- Goal 1

## Tasks

## Notes

## Reflections

---

# 2026-01-06 Tuesday

## Goals
- Goal 2

## Tasks

## Notes

## Reflections
''';

      final result = MarkdownWriter.removeDay(existing, DateTime(2026, 1, 5));

      expect(result.contains('# 2026-01-05 Monday'), false);
      expect(result.contains('Goal 1'), false);
      expect(result, contains('# 2026-01-06 Tuesday'));
      expect(result, contains('Goal 2'));
    });

    test('handles multi-line reflections', () {
      final entry = DailyEntry(
        date: DateTime(2026, 1, 5),
        reflections: 'Line 1\nLine 2\nLine 3',
      );

      final markdown = MarkdownWriter.writeDay(entry);

      expect(markdown, contains('Line 1'));
      expect(markdown, contains('Line 2'));
      expect(markdown, contains('Line 3'));
    });

    test('handles task titles with special characters', () {
      final entry = DailyEntry(
        date: DateTime(2026, 1, 5),
        tasks: [
          Task(title: 'Review PR #123', estimatedHours: 1.0),
          Task(title: 'Email: follow-up', estimatedHours: 0.5),
          Task(title: 'Update docs @ website', estimatedHours: 2.0),
        ],
      );

      final markdown = MarkdownWriter.writeDay(entry);

      expect(markdown, contains('Review PR #123'));
      expect(markdown, contains('Email: follow-up'));
      expect(markdown, contains('Update docs @ website'));
    });

    test('no separator after last entry', () {
      final entries = [
        DailyEntry(date: DateTime(2026, 1, 5)),
        DailyEntry(date: DateTime(2026, 1, 6)),
      ];

      final markdown = MarkdownWriter.write(entries);

      // Should not end with separator or extra blank lines
      expect(markdown.trimRight().endsWith('# '), false);
    });

    test('handles empty entry list', () {
      final markdown = MarkdownWriter.write([]);

      expect(markdown, isEmpty);
    });

    test('task deletion removes from both tasks list and section items', () {
      // Create entry with tasks in sections
      final entry = DailyEntry(
        date: DateTime(2026, 1, 6),
        sections: [
          Section(
            name: 'Tasks',
            type: SectionType.tasks,
            items: [
              '- [ ] Task 1 | 1.0h',
              '- [ ] Task 2 | 2.0h',
              '- [ ] Task 3 | 30m',
            ],
          ),
        ],
        tasks: [
          Task(title: 'Task 1', estimatedHours: 1.0),
          Task(title: 'Task 2', estimatedHours: 2.0),
          Task(title: 'Task 3', estimatedHours: 0.5),
        ],
      );

      // Remove task 2
      final taskToRemove = entry.tasks[1];
      entry.removeTask(taskToRemove);

      // Write to markdown
      final markdown = MarkdownWriter.writeDay(entry);

      // Verify task 2 is removed from markdown
      expect(markdown, contains('Task 1'));
      expect(markdown, isNot(contains('Task 2'))); // Should NOT appear
      expect(markdown, contains('Task 3'));

      // Verify it's removed from tasks list
      expect(entry.tasks.length, 2);
      expect(entry.tasks.any((t) => t.title == 'Task 2'), false);

      // Verify it's removed from section items
      final taskSection = entry.sections.firstWhere((s) => s.name == 'Tasks');
      expect(taskSection.items.length, 2);
      expect(taskSection.items.any((item) => item.contains('Task 2')), false);
    });
  });
}
