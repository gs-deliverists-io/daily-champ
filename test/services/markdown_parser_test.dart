import 'package:flutter_test/flutter_test.dart';
import 'package:dailychamp_app/models/models.dart';
import 'package:dailychamp_app/services/markdown_parser.dart';

void main() {
  group('MarkdownParser', () {
    test('parses single day with all sections', () {
      const markdown = '''
# 2026-01-05 Monday

## Goals
- Complete website redesign mockups
- Maintain workout streak

## Tasks
- [x] Design homepage | 2.0h
- [ ] Client meeting | 1.0h
- [ ] Workout | 1.0h

## Notes
- Client prefers minimal design
- Focus on mobile-first approach

## Reflections
Great focus today! Made solid progress on the homepage design.
Client feedback was very positive.
''';

      final entries = MarkdownParser.parse(markdown);

      expect(entries.length, 1);

      final entry = entries.first;
      expect(entry.date, DateTime(2026, 1, 5));
      expect(entry.goals.length, 2);
      expect(entry.goals[0], 'Complete website redesign mockups');
      expect(entry.goals[1], 'Maintain workout streak');
      expect(entry.tasks.length, 3);
      expect(entry.tasks[0].title, 'Design homepage');
      expect(entry.tasks[0].estimatedHours, 2.0);
      expect(entry.tasks[0].isCompleted, true);
      expect(entry.tasks[1].title, 'Client meeting');
      expect(entry.tasks[1].estimatedHours, 1.0);
      expect(entry.tasks[1].isCompleted, false);
      expect(entry.notes.length, 2);
      expect(entry.notes[0], 'Client prefers minimal design');
      expect(entry.reflections, contains('Great focus today'));
      expect(entry.reflections, contains('Client feedback was very positive.'));
    });

    test('parses multiple days separated by ---', () {
      const markdown = '''
# 2026-01-05 Monday

## Goals
- Goal 1

## Tasks
- [x] Task 1 | 1.0h

## Notes

## Reflections

---

# 2026-01-06 Tuesday

## Goals
- Goal 2

## Tasks
- [ ] Task 2 | 2.0h

## Notes

## Reflections
''';

      final entries = MarkdownParser.parse(markdown);

      expect(entries.length, 2);
      expect(entries[0].date, DateTime(2026, 1, 5));
      expect(entries[1].date, DateTime(2026, 1, 6));
      expect(entries[0].goals[0], 'Goal 1');
      expect(entries[1].goals[0], 'Goal 2');
    });

    test('parses empty sections', () {
      const markdown = '''
# 2026-01-05 Monday

## Goals

## Tasks

## Notes

## Reflections
''';

      final entries = MarkdownParser.parse(markdown);

      expect(entries.length, 1);
      expect(entries.first.goals.isEmpty, true);
      expect(entries.first.tasks.isEmpty, true);
      expect(entries.first.notes.isEmpty, true);
      expect(entries.first.reflections.isEmpty, true);
    });

    test('parses task with different hour formats', () {
      const markdown = '''
# 2026-01-05 Monday

## Goals

## Tasks
- [ ] Task with decimal | 2.5h
- [ ] Task with integer | 3h
- [ ] Task without hours

## Notes

## Reflections
''';

      final entries = MarkdownParser.parse(markdown);
      final tasks = entries.first.tasks;

      expect(tasks.length, 3);
      expect(tasks[0].estimatedHours, 2.5);
      expect(tasks[1].estimatedHours, 3.0);
      expect(tasks[2].estimatedHours, 1.0); // Default
    });

    test('parses completed tasks with [x] and [X]', () {
      const markdown = '''
# 2026-01-05 Monday

## Goals

## Tasks
- [x] Lowercase completed | 1.0h
- [X] Uppercase completed | 1.0h
- [ ] Not completed | 1.0h

## Notes

## Reflections
''';

      final entries = MarkdownParser.parse(markdown);
      final tasks = entries.first.tasks;

      expect(tasks.length, 3);
      expect(tasks[0].isCompleted, true);
      expect(tasks[1].isCompleted, true);
      expect(tasks[2].isCompleted, false);
    });

    test('handles multi-line reflections', () {
      const markdown = '''
# 2026-01-05 Monday

## Goals

## Tasks

## Notes

## Reflections
This is the first line of reflections.
This is the second line.
And a third line for good measure.
''';

      final entries = MarkdownParser.parse(markdown);

      expect(entries.first.reflections, contains('first line'));
      expect(entries.first.reflections, contains('second line'));
      expect(entries.first.reflections, contains('third line'));
    });

    test('ignores invalid date formats', () {
      const markdown = '''
# Not a date

## Goals

## Tasks

## Notes

## Reflections
''';

      final entries = MarkdownParser.parse(markdown);

      expect(entries.isEmpty, true);
    });

    test('handles missing sections gracefully', () {
      const markdown = '''
# 2026-01-05 Monday

## Goals
- Some goal
''';

      final entries = MarkdownParser.parse(markdown);

      expect(entries.length, 1);
      expect(entries.first.goals.length, 1);
      expect(entries.first.tasks.isEmpty, true);
    });

    test('parseDay convenience method works', () {
      const markdown = '''
# 2026-01-05 Monday

## Goals
- Test goal

## Tasks
- [ ] Test task | 1.0h

## Notes

## Reflections
''';

      final entry = MarkdownParser.parseDay(markdown);

      expect(entry, isNotNull);
      expect(entry!.date, DateTime(2026, 1, 5));
      expect(entry.goals.first, 'Test goal');
    });

    test('isValidFormat validates markdown correctly', () {
      const validMarkdown = '''
# 2026-01-05 Monday

## Goals

## Tasks

## Notes

## Reflections
''';

      const invalidMarkdown = '''
This is not valid markdown
''';

      expect(MarkdownParser.isValidFormat(validMarkdown), true);
      expect(MarkdownParser.isValidFormat(invalidMarkdown), false);
    });

    test('handles extra whitespace and empty lines', () {
      const markdown = '''
# 2026-01-05 Monday


## Goals
- Goal with spaces   


## Tasks
- [ ] Task with spaces   | 1.0h  


## Notes
- Note with spaces   

## Reflections
Reflections with spaces   
''';

      final entries = MarkdownParser.parse(markdown);

      expect(entries.length, 1);
      expect(entries.first.goals.first, 'Goal with spaces');
      expect(entries.first.tasks.first.title, 'Task with spaces');
      expect(entries.first.notes.first, 'Note with spaces');
    });

    test('parses task titles with special characters', () {
      const markdown = '''
# 2026-01-05 Monday

## Goals

## Tasks
- [ ] Review PR #123 for bug fix | 1.0h
- [x] Update docs @ https://example.com | 2.0h
- [ ] Email client: follow-up | 0.5h

## Notes

## Reflections
''';

      final entries = MarkdownParser.parse(markdown);
      final tasks = entries.first.tasks;

      expect(tasks.length, 3);
      expect(tasks[0].title, 'Review PR #123 for bug fix');
      expect(tasks[1].title, 'Update docs @ https://example.com');
      expect(tasks[2].title, 'Email client: follow-up');
    });

    test('parses tasks ANYWHERE (semantic parsing)', () {
      const markdown = '''
# 2026-01-06 Tuesday

## Custom Section
- [ ] Task in custom section | 2.0h
- Regular note here

- [ ] Task without section header | 1.0h

## Goals
- [ ] Task mixed with goals | 0.5h
- Regular goal without checkbox

## Traditional Tasks
- [ ] Task in traditional location | 1.5h

## Notes
- [ ] Task in notes section | 1.0h
''';

      final entries = MarkdownParser.parse(markdown);
      final entry = entries.first;

      // All 5 tasks should be found regardless of section
      expect(entry.tasks.length, 5);
      expect(entry.tasks[0].title, 'Task in custom section');
      expect(entry.tasks[1].title, 'Task without section header');
      expect(entry.tasks[2].title, 'Task mixed with goals');
      expect(entry.tasks[3].title, 'Task in traditional location');
      expect(entry.tasks[4].title, 'Task in notes section');

      // Regular items should be in Goals section (backward compat)
      expect(entry.goals.length, 1);
      expect(entry.goals[0], 'Regular goal without checkbox');

      // Sections should be created dynamically - ALL sections captured!
      expect(entry.sections.length, 4);

      // Custom Section contains EVERYTHING (task + note)
      expect(entry.sections[0].name, 'Custom Section');
      expect(entry.sections[0].type, SectionType.tasks); // Has checkboxes
      expect(entry.sections[0].items.length, 3);
      expect(entry.sections[0].items[0], '- [ ] Task in custom section | 2.0h');
      expect(entry.sections[0].items[1], 'Regular note here');
      expect(entry.sections[0].items[2],
          '- [ ] Task without section header | 1.0h');

      // Goals section contains EVERYTHING (task + goal)
      expect(entry.sections[1].name, 'Goals');
      expect(entry.sections[1].type, SectionType.tasks); // Has checkboxes
      expect(entry.sections[1].items.length, 2);
      expect(entry.sections[1].items[0], '- [ ] Task mixed with goals | 0.5h');
      expect(entry.sections[1].items[1], 'Regular goal without checkbox');

      // Traditional Tasks section
      expect(entry.sections[2].name, 'Traditional Tasks');
      expect(entry.sections[2].type, SectionType.tasks);
      expect(entry.sections[2].items.length, 1);

      // Notes section
      expect(entry.sections[3].name, 'Notes');
      expect(entry.sections[3].type, SectionType.tasks);
      expect(entry.sections[3].items.length, 1);
    });

    test('preserves markdown formatting in tasks and notes', () {
      const markdown = '''
# 2026-01-06 Tuesday

## Goals
- **Primary goal** with emphasis
- Goal with [link](https://example.com)

## Tasks
- [ ] Task with **bold** and *italic* | 2.0h
- [x] ~~Strikethrough~~ completed task | 1.0h
- [ ] Task with `code` reference | 1.5h

## Notes
- Note with [GitHub](https://github.com) link
- Note with *emphasis* text
''';

      final entries = MarkdownParser.parse(markdown);
      final entry = entries.first;

      expect(entry.goals[0], '**Primary goal** with emphasis');
      expect(entry.goals[1], 'Goal with [link](https://example.com)');

      expect(entry.tasks[0].title, 'Task with **bold** and *italic*');
      expect(entry.tasks[1].title, '~~Strikethrough~~ completed task');
      expect(entry.tasks[2].title, 'Task with `code` reference');

      expect(entry.notes[0], 'Note with [GitHub](https://github.com) link');
      expect(entry.notes[1], 'Note with *emphasis* text');
    });

    test('supports alternative list markers', () {
      const markdown = '''
# 2026-01-06 Tuesday

## Notes
- Dash bullet
* Star bullet
+ Plus bullet
1. Numbered item one
2. Numbered item two
''';

      final entries = MarkdownParser.parse(markdown);
      final entry = entries.first;

      expect(entry.notes.length, 5);
      expect(entry.notes[0], 'Dash bullet');
      expect(entry.notes[1], 'Star bullet');
      expect(entry.notes[2], 'Plus bullet');
      expect(entry.notes[3], 'Numbered item one');
      expect(entry.notes[4], 'Numbered item two');
    });

    test('handles sections optional - no sections required', () {
      const markdown = '''
# 2026-01-06 Tuesday

- [ ] Task without any section | 1.0h
- Regular note without section

Some free text for reflections.

- [ ] Another task | 2.0h
''';

      final entries = MarkdownParser.parse(markdown);
      final entry = entries.first;

      expect(entry.tasks.length, 2);
      expect(entry.tasks[0].title, 'Task without any section');
      expect(entry.tasks[1].title, 'Another task');

      expect(entry.notes.length, 1);
      expect(entry.notes[0], 'Regular note without section');

      expect(entry.reflections, contains('free text for reflections'));
    });

    test('handles complex markdown in reflections', () {
      const markdown = '''
# 2026-01-06 Tuesday

## Reflections
**Bold statement**: Today was productive!

> A blockquote
> Multiple lines

Code example:
```dart
void main() {}
```

| Table | Header |
|-------|--------|
| Cell  | Value  |
''';

      final entries = MarkdownParser.parse(markdown);
      final entry = entries.first;

      expect(entry.reflections, contains('**Bold statement**'));
      expect(entry.reflections, contains('> A blockquote'));
      expect(entry.reflections, contains('```dart'));
      expect(entry.reflections, contains('void main()'));
      expect(entry.reflections, contains('| Table | Header |'));
    });
  });
}
