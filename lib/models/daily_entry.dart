import 'day_status.dart';
import 'task.dart';
import 'section.dart';

/// Daily entry containing tasks and custom sections
///
/// Sections are dynamically parsed from markdown:
/// - ## Goals -> Section(name: "Goals", type: list)
/// - ## Tasks -> Special handling (checkboxes parsed as Task objects)
/// - ## Notes -> Section(name: "Notes", type: list)
/// - ## Reflections -> Section(name: "Reflections", type: text)
/// - ## Custom Name -> Section(name: "Custom Name", type: list)
class DailyEntry {
  static const int maxTasks = 7; // PowerList-style 7 task limit

  final DateTime date;
  List<Task> tasks;
  List<Section> sections; // Dynamic sections from markdown

  // Legacy properties (kept for backward compatibility)
  List<String> goals;
  List<String> notes;
  String reflections;

  DailyEntry({
    required this.date,
    List<Task>? tasks,
    List<Section>? sections,
    List<String>? goals,
    List<String>? notes,
    this.reflections = '',
  })  : tasks = tasks ?? [],
        sections = sections ?? [],
        goals = goals ?? [],
        notes = notes ?? [];

  /// Get day of week name (Monday, Tuesday, etc.)
  String get dayOfWeek {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[date.weekday - 1];
  }

  /// Calculate day status based on tasks
  DayStatus get status {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(date.year, date.month, date.day);

    // Today = pending (in progress)
    if (entryDay.isAtSameMomentAs(today)) {
      return DayStatus.pending;
    }

    // Future = scheduled (planned)
    if (entryDay.isAfter(today)) {
      return DayStatus.scheduled;
    }

    // Past day
    if (tasks.isEmpty) {
      return DayStatus.loss; // No tasks = automatic loss
    }

    final allCompleted = tasks.every((task) => task.isCompleted);
    return allCompleted ? DayStatus.win : DayStatus.loss;
  }

  /// Check if this is a win (all tasks completed)
  bool get isWin {
    if (tasks.isEmpty) return false;
    return tasks.every((task) => task.isCompleted);
  }

  /// Calculate completion percentage
  double get completionPercentage {
    if (tasks.isEmpty) return 0.0;
    final completed = tasks.where((task) => task.isCompleted).length;
    return completed / tasks.length;
  }

  /// Get total estimated hours
  double get totalHours {
    return tasks.fold(0.0, (sum, task) => sum + task.estimatedHours);
  }

  /// Get completed task count
  int get completedCount {
    return tasks.where((task) => task.isCompleted).length;
  }

  /// Alias for completedCount - used by stats screen
  int get completedTaskCount => completedCount;

  /// Get total task count
  int get totalCount {
    return tasks.length;
  }

  /// Get tasks in their original insertion order
  /// (preserves order regardless of completion status)
  List<Task> get sortedTasks {
    return tasks;
  }

  /// Add a task (enforces 7 task limit)
  bool addTask(Task task) {
    if (tasks.length >= maxTasks) {
      return false; // Cannot add more than max tasks
    }
    tasks.add(task);
    return true;
  }

  /// Remove a task
  void removeTask(Task task) {
    // Remove from global tasks list
    tasks.removeWhere((t) => t.id == task.id);

    // Also remove from any section that contains this task
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final updatedItems = <String>[];

      for (var item in section.items) {
        // Check if this item is a checkbox line for this task
        if (item.trim().startsWith('- [')) {
          final itemTitle = _extractTitleFromCheckboxLine(item);
          // Keep the item only if it doesn't match the task being removed
          if (itemTitle != task.title) {
            updatedItems.add(item);
          }
        } else {
          // Not a task, keep it
          updatedItems.add(item);
        }
      }

      // Update section with filtered items
      if (updatedItems.length != section.items.length) {
        sections[i] = section.copyWith(items: updatedItems);
      }
    }
  }

  /// Update a task
  void updateTask(Task updatedTask) {
    final index = tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      tasks[index] = updatedTask;
    }
  }

  /// Add a goal
  void addGoal(String goal) {
    if (goal.trim().isNotEmpty) {
      goals.add(goal.trim());
    }
  }

  /// Remove a goal
  void removeGoal(int index) {
    if (index >= 0 && index < goals.length) {
      goals.removeAt(index);
    }
  }

  /// Add a note
  void addNote(String note) {
    if (note.trim().isNotEmpty) {
      notes.add(note.trim());
    }
  }

  /// Remove a note
  void removeNote(int index) {
    if (index >= 0 && index < notes.length) {
      notes.removeAt(index);
    }
  }

  // ============================================================================
  // SECTION MANAGEMENT
  // ============================================================================

  /// Add a new section
  void addSection(Section section) {
    // Avoid duplicates by name (case-insensitive)
    if (!sections
        .any((s) => s.name.toLowerCase() == section.name.toLowerCase())) {
      sections.add(section);
    }
  }

  /// Delete a section by name
  void deleteSection(String sectionName) {
    // Also remove any tasks from this section from the global tasks list
    final sectionToRemove = sections.firstWhere(
      (s) => s.name == sectionName,
      orElse: () => Section(name: '', items: []),
    );

    if (sectionToRemove.name.isNotEmpty) {
      // Remove tasks that belong to this section
      for (final item in sectionToRemove.items) {
        if (item.trim().startsWith('- [')) {
          // Find and remove the matching task
          final taskTitle = _extractTitleFromCheckboxLine(item);
          if (taskTitle != null) {
            tasks.removeWhere((t) => t.title == taskTitle);
          }
        }
      }
    }

    sections.removeWhere((s) => s.name == sectionName);
  }

  /// Rename a section
  void renameSection(String oldName, String newName) {
    final index = sections.indexWhere((s) => s.name == oldName);
    if (index != -1) {
      sections[index] = sections[index].copyWith(name: newName);
    }
  }

  /// Add an item to a section
  /// For tasks, also adds to the global tasks list
  void addItemToSection(String sectionName, String item, {Task? task}) {
    final index = sections.indexWhere((s) => s.name == sectionName);
    if (index != -1) {
      final section = sections[index];
      final updatedItems = List<String>.from(section.items);
      updatedItems.add(item);

      // If it's a task, update section type to tasks if it wasn't already
      SectionType newType = section.type;
      if (task != null) {
        newType = SectionType.tasks;
        // Add to global tasks list (with limit check)
        if (tasks.length < maxTasks) {
          tasks.add(task);
        }
      }

      sections[index] = section.copyWith(items: updatedItems, type: newType);
    }
  }

  /// Delete an item from a section by index
  void deleteItemFromSection(String sectionName, int itemIndex) {
    final sectionIndex = sections.indexWhere((s) => s.name == sectionName);
    if (sectionIndex != -1) {
      final section = sections[sectionIndex];
      if (itemIndex >= 0 && itemIndex < section.items.length) {
        final item = section.items[itemIndex];

        // If it's a task, also remove from global tasks list
        if (item.trim().startsWith('- [')) {
          final taskTitle = _extractTitleFromCheckboxLine(item);
          if (taskTitle != null) {
            tasks.removeWhere((t) => t.title == taskTitle);
          }
        }

        final updatedItems = List<String>.from(section.items);
        updatedItems.removeAt(itemIndex);
        sections[sectionIndex] = section.copyWith(items: updatedItems);
      }
    }
  }

  /// Helper to extract task title from a checkbox line
  String? _extractTitleFromCheckboxLine(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('- [')) return null;

    String remainder;
    if (trimmed.startsWith('- [x]') || trimmed.startsWith('- [X]')) {
      remainder = trimmed.substring(5).trim();
    } else if (trimmed.startsWith('- [ ]')) {
      remainder = trimmed.substring(5).trim();
    } else {
      return null;
    }

    // Extract title (before | separator)
    if (remainder.contains('|')) {
      return remainder.split('|')[0].trim();
    }
    return remainder.trim();
  }

  /// Create a copy of this entry
  DailyEntry copyWith({
    DateTime? date,
    List<String>? goals,
    List<Task>? tasks,
    List<String>? notes,
    String? reflections,
    List<Section>? sections,
  }) {
    return DailyEntry(
      date: date ?? this.date,
      goals: goals ?? List.from(this.goals),
      tasks: tasks ?? List.from(this.tasks),
      notes: notes ?? List.from(this.notes),
      reflections: reflections ?? this.reflections,
      sections: sections ?? List.from(this.sections),
    );
  }

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'goals': goals,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'notes': notes,
      'reflections': reflections,
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }

  /// Create from Map
  factory DailyEntry.fromJson(Map<String, dynamic> json) {
    return DailyEntry(
      date: DateTime.parse(json['date'] as String),
      goals: List<String>.from(json['goals'] as List? ?? []),
      tasks: (json['tasks'] as List?)
              ?.map((t) => Task.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      notes: List<String>.from(json['notes'] as List? ?? []),
      reflections: json['reflections'] as String? ?? '',
      sections: (json['sections'] as List?)
              ?.map((s) => Section.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  String toString() {
    return 'DailyEntry(date: $date, tasks: ${tasks.length}, status: ${status.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyEntry &&
        other.date.year == date.year &&
        other.date.month == date.month &&
        other.date.day == date.day;
  }

  @override
  int get hashCode => date.hashCode;
}
