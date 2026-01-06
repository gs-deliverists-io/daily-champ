import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/file_service.dart';
import '../services/template_service.dart';

/// Provider for managing DailyChamp app state
///
/// Handles CRUD operations for daily entries and syncs with file storage
class DailyChampProvider with ChangeNotifier {
  final FileService _fileService;

  List<DailyEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  String? _syncError;
  DateTime _selectedDate = DateTime.now();
  StreamSubscription? _fileWatcherSubscription;
  StreamSubscription? _syncErrorSubscription;

  DailyChampProvider({FileService? fileService})
      : _fileService = fileService ?? FileService() {
    // Start watching for file changes
    _fileService.startWatching();
    _fileWatcherSubscription = _fileService.changes.listen((_) {
      // Reload entries when file changes externally
      loadEntries();
    });

    // Listen for sync errors
    _syncErrorSubscription = _fileService.syncErrors.listen((error) {
      _syncError = error;
      notifyListeners();
    });

    // Initialize sync if configured
    _initializeSync();
  }

  @override
  void dispose() {
    _fileWatcherSubscription?.cancel();
    _syncErrorSubscription?.cancel();
    _fileService.dispose();
    super.dispose();
  }

  // Getters
  List<DailyEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get syncError => _syncError;
  DateTime get selectedDate => _selectedDate;

  /// Get entry for selected date
  DailyEntry? get selectedEntry => getEntryForDate(_selectedDate);

  /// Get entry for today
  DailyEntry? get todayEntry {
    final now = DateTime.now();
    return getEntryForDate(DateTime(now.year, now.month, now.day));
  }

  /// Get entry for specific date
  DailyEntry? getEntryForDate(DateTime date) {
    try {
      return _entries.firstWhere(
        (e) =>
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get entries for a specific month
  List<DailyEntry> getEntriesForMonth(int year, int month) {
    return _entries
        .where((e) => e.date.year == year && e.date.month == month)
        .toList();
  }

  /// Get entries in date range
  List<DailyEntry> getEntriesInRange(DateTime start, DateTime end) {
    return _entries.where((e) {
      return e.date.isAfter(start.subtract(const Duration(days: 1))) &&
          e.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  /// Load all entries from storage
  Future<void> loadEntries() async {
    _setLoading(true);
    _clearError();

    try {
      _entries = await _fileService.readEntries();
      _sortEntries();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load entries: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create or update an entry
  Future<void> saveEntry(DailyEntry entry) async {
    _clearError();

    try {
      // Update in memory
      final index = _entries.indexWhere(
        (e) =>
            e.date.year == entry.date.year &&
            e.date.month == entry.date.month &&
            e.date.day == entry.date.day,
      );

      if (index != -1) {
        _entries[index] = entry;
      } else {
        _entries.add(entry);
      }

      _sortEntries();
      notifyListeners();

      // Persist to storage
      await _fileService.writeDay(entry);
    } catch (e) {
      _setError('Failed to save entry: $e');
      // Reload from storage to restore consistent state
      await loadEntries();
    }
  }

  /// Delete an entry
  Future<void> deleteEntry(DateTime date) async {
    _clearError();

    try {
      // Remove from memory
      _entries.removeWhere(
        (e) =>
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day,
      );

      notifyListeners();

      // Persist to storage
      await _fileService.deleteDay(date);
    } catch (e) {
      _setError('Failed to delete entry: $e');
      // Reload from storage to restore consistent state
      await loadEntries();
    }
  }

  /// Add a task to an entry
  /// Returns true if successful, false if task limit reached
  Future<bool> addTask(DateTime date, Task task) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      final success = entry.addTask(task);
      if (success) {
        await saveEntry(entry);
      }
      return success;
    } else {
      // Create new entry if it doesn't exist
      final newEntry = DailyEntry(date: date);
      final success = newEntry.addTask(task);
      if (success) {
        await saveEntry(newEntry);
      }
      return success;
    }
  }

  /// Update a task in an entry
  Future<void> updateTask(DateTime date, Task task) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      entry.updateTask(task);
      await saveEntry(entry);
    }
  }

  /// Delete a task from an entry
  Future<void> deleteTask(DateTime date, Task task) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      entry.removeTask(task);
      await saveEntry(entry);
    }
  }

  /// Toggle task completion
  Future<void> toggleTask(DateTime date, Task task) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      task.toggle();
      entry.updateTask(task);
      await saveEntry(entry);
    }
  }

  /// Add a goal to an entry
  Future<void> addGoal(DateTime date, String goal) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      entry.addGoal(goal);
      await saveEntry(entry);
    } else {
      final newEntry = DailyEntry(date: date);
      newEntry.addGoal(goal);
      await saveEntry(newEntry);
    }
  }

  /// Remove a goal from an entry
  Future<void> removeGoal(DateTime date, int index) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      entry.removeGoal(index);
      await saveEntry(entry);
    }
  }

  /// Add a note to an entry
  Future<void> addNote(DateTime date, String note) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      entry.addNote(note);
      await saveEntry(entry);
    } else {
      final newEntry = DailyEntry(date: date);
      newEntry.addNote(note);
      await saveEntry(newEntry);
    }
  }

  /// Remove a note from an entry
  Future<void> removeNote(DateTime date, int index) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      entry.removeNote(index);
      await saveEntry(entry);
    }
  }

  // ============================================================================
  // SECTION MANAGEMENT
  // ============================================================================

  /// Add a new section to an entry
  Future<void> addSection(DateTime date, String name, SectionType type) async {
    var entry = getEntryForDate(date);

    // Create new entry if it doesn't exist
    entry ??= DailyEntry(date: date);

    final section = Section(name: name, items: [], type: type);
    entry.addSection(section);
    await saveEntry(entry);
  }

  /// Delete a section from an entry
  Future<void> deleteSection(DateTime date, String sectionName) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      entry.deleteSection(sectionName);
      await saveEntry(entry);
    }
  }

  /// Rename a section in an entry
  Future<void> renameSection(
      DateTime date, String oldName, String newName) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      entry.renameSection(oldName, newName);
      await saveEntry(entry);
    }
  }

  /// Add an item to a section
  /// For tasks (isTask=true), also adds to the global tasks list
  /// Returns true if successful, false if task limit reached
  Future<bool> addItemToSection(
    DateTime date,
    String sectionName,
    String item, {
    bool isTask = false,
    double estimatedHours = 1.0,
  }) async {
    var entry = getEntryForDate(date);

    // Create new entry if it doesn't exist
    entry ??= DailyEntry(date: date);

    if (isTask) {
      // Check task limit before adding
      if (entry.tasks.length >= DailyEntry.maxTasks) {
        return false;
      }

      // Create task object
      final task = Task(
        title: item,
        estimatedHours: estimatedHours,
      );

      // Format as checkbox line for section storage
      final checkboxLine =
          '- [ ] $item | ${estimatedHours.toStringAsFixed(1)}h';
      entry.addItemToSection(sectionName, checkboxLine, task: task);
    } else {
      // Regular item (note) - stored without the "- " prefix
      // The markdown writer adds it back
      entry.addItemToSection(sectionName, item);
    }

    await saveEntry(entry);
    return true;
  }

  /// Delete an item from a section
  Future<void> deleteItemFromSection(
      DateTime date, String sectionName, int itemIndex) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      entry.deleteItemFromSection(sectionName, itemIndex);
      await saveEntry(entry);
    }
  }

  /// Update an item in a section
  Future<void> updateItemInSection(DateTime date, String sectionName,
      int itemIndex, String newContent) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      final sectionIndex =
          entry.sections.indexWhere((s) => s.name == sectionName);

      if (sectionIndex != -1) {
        final section = entry.sections[sectionIndex];
        if (itemIndex >= 0 && itemIndex < section.items.length) {
          section.items[itemIndex] = newContent;
          await saveEntry(entry);
        }
      }
    }
  }

  /// Copy an item to tomorrow's same section
  Future<void> copyItemToTomorrow(
      DateTime date, String sectionName, int itemIndex) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      final section = entry.sections.firstWhere(
        (s) => s.name == sectionName,
        orElse: () => Section(name: sectionName, items: []),
      );

      if (itemIndex >= 0 && itemIndex < section.items.length) {
        final item = section.items[itemIndex];
        final tomorrow = date.add(const Duration(days: 1));

        // Add item to tomorrow's section
        await addItemToSection(tomorrow, sectionName, item, isTask: false);

        // Copy template association from source to target date
        await _copyTemplateAssociation(date, tomorrow);
      }
    }
  }

  /// Update reflections for an entry
  Future<void> updateReflections(DateTime date, String reflections) async {
    final entry = getEntryForDate(date);

    if (entry != null) {
      entry.reflections = reflections;
      await saveEntry(entry);
    } else {
      final newEntry = DailyEntry(date: date, reflections: reflections);
      await saveEntry(newEntry);
    }
  }

  /// Set selected date
  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  /// Select today
  void selectToday() {
    final now = DateTime.now();
    setSelectedDate(DateTime(now.year, now.month, now.day));
  }

  /// Get statistics
  Future<Map<String, int>> getStatistics() async {
    return _fileService.getStatistics();
  }

  /// Create a backup
  Future<String> createBackup() async {
    try {
      return await _fileService.createBackup();
    } catch (e) {
      _setError('Failed to create backup: $e');
      rethrow;
    }
  }

  /// Restore from backup
  Future<void> restoreFromBackup(String backupPath) async {
    _clearError();

    try {
      await _fileService.restoreFromBackup(backupPath);
      await loadEntries();
    } catch (e) {
      _setError('Failed to restore backup: $e');
      rethrow;
    }
  }

  /// Clear all data
  Future<void> clearAll() async {
    _clearError();

    try {
      _entries.clear();
      notifyListeners();
      await _fileService.clearAll();
    } catch (e) {
      _setError('Failed to clear data: $e');
      await loadEntries();
    }
  }

  /// Get win streak (consecutive wins)
  int getWinStreak() {
    if (_entries.isEmpty) return 0;

    // Sort by date descending (newest first)
    final sorted = List<DailyEntry>.from(_entries);
    sorted.sort((a, b) => b.date.compareTo(a.date));

    var streak = 0;

    for (final entry in sorted) {
      // Only count past days
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final entryDay =
          DateTime(entry.date.year, entry.date.month, entry.date.day);

      if (entryDay.isAfter(today) || entryDay.isAtSameMomentAs(today)) {
        continue;
      }

      if (entry.status == DayStatus.win) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Get total wins
  int getTotalWins() {
    return _entries.where((e) => e.status == DayStatus.win).length;
  }

  /// Get total losses
  int getTotalLosses() {
    return _entries.where((e) => e.status == DayStatus.loss).length;
  }

  /// Get win rate (0.0 to 1.0)
  double getWinRate() {
    final pastEntries = _entries.where((e) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final entryDay = DateTime(e.date.year, e.date.month, e.date.day);
      return entryDay.isBefore(today);
    }).toList();

    if (pastEntries.isEmpty) return 0.0;

    final wins = pastEntries.where((e) => e.status == DayStatus.win).length;
    return wins / pastEntries.length;
  }

  /// Alias for getWinStreak - used by stats screen
  int get currentWinStreak => getWinStreak();

  /// Calculate statistics - used by stats screen
  Map<String, dynamic> calculateStats() {
    final totalWins = getTotalWins();
    final totalLosses = getTotalLosses();
    final totalDays = totalWins + totalLosses;
    final winRateDecimal = getWinRate();
    final winRatePercentage = (winRateDecimal * 100).round();

    return {
      'totalWins': totalWins,
      'totalLosses': totalLosses,
      'totalDays': totalDays,
      'winRate': winRatePercentage,
    };
  }

  /// Export markdown content
  Future<String> exportMarkdown() async {
    try {
      return await _fileService.exportMarkdown();
    } catch (e) {
      _setError('Failed to export markdown: $e');
      rethrow;
    }
  }

  /// Import markdown content
  Future<void> importMarkdown(String content) async {
    _clearError();

    try {
      await _fileService.importMarkdown(content);
      await loadEntries();
    } catch (e) {
      _setError('Failed to import markdown: $e');
      rethrow;
    }
  }

  // Nextcloud sync methods

  /// Initialize Nextcloud sync if configured
  Future<void> _initializeSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check for Nextcloud
      if (prefs.containsKey('nextcloud_server_url')) {
        final server = prefs.getString('nextcloud_server_url')!;
        final username = prefs.getString('nextcloud_username')!;
        final password = prefs.getString('nextcloud_password')!;
        final filePath = prefs.getString('nextcloud_file_path');

        await _fileService.initNextcloudSync(
          serverUrl: server,
          username: username,
          password: password,
          filePath: filePath,
        );

        // Create default template files and upload to Nextcloud
        final templateService = TemplateService(
          customBasePath: _fileService.customPath,
        );
        templateService.configureNextcloud(
          serverUrl: server,
          username: username,
          password: password,
          filePath: filePath,
        );
        await templateService.createDefaultTemplateFiles();
      }
      // Check for Google Drive
      else if (prefs.containsKey('google_drive_configured') &&
          prefs.getBool('google_drive_configured') == true) {
        await _fileService.initGoogleDriveSync();
      }

      // Also create local default template files (even without cloud sync)
      final templateService = TemplateService(
        customBasePath: _fileService.customPath,
      );
      await templateService.createDefaultTemplateFiles();
    } catch (e) {
      // Silently fail - sync is optional
      debugPrint('Failed to initialize sync: $e');
    }
  }

  /// Check if it's a new day and auto-apply default template if configured
  ///
  /// This should be called on app startup. It checks if:
  /// 1. The date has changed since last app session
  /// 2. Today's entry is empty
  /// 3. A default template is configured
  ///
  /// If all conditions are met, applies the default template to today.
  Future<bool> checkAndApplyNewDayTemplate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final lastOpenDate = prefs.getString('last_open_date');

      // Check if this is a new day
      if (lastOpenDate == todayKey) {
        return false; // Same day, no need to auto-apply
      }

      // Update last open date
      await prefs.setString('last_open_date', todayKey);

      // Check if today's entry is empty
      final todayEntry = getEntryForDate(today);
      final isEmpty = todayEntry == null ||
          (todayEntry.sections.isEmpty && todayEntry.tasks.isEmpty);

      if (!isEmpty) {
        return false; // Today already has content
      }

      // Check for default template
      final defaultTemplateId = prefs.getString('default_template_id');
      if (defaultTemplateId == null ||
          defaultTemplateId.isEmpty ||
          defaultTemplateId == 'blank') {
        return false; // No default template configured
      }

      // Apply the default template
      await createEntryFromTemplate(today, defaultTemplateId);

      // Store template association for today
      await prefs.setString('template_$todayKey', defaultTemplateId);

      debugPrint(
          'Auto-applied default template "$defaultTemplateId" for new day');
      return true;
    } catch (e) {
      debugPrint('Failed to check/apply new day template: $e');
      return false;
    }
  }

  /// Initialize Nextcloud sync with credentials
  Future<void> initNextcloudSync({
    required String serverUrl,
    required String username,
    required String password,
    String? filePath,
  }) async {
    await _fileService.initNextcloudSync(
      serverUrl: serverUrl,
      username: username,
      password: password,
      filePath: filePath,
    );
  }

  /// Stop Nextcloud sync
  void stopNextcloudSync() {
    _fileService.stopNextcloudSync();
  }

  /// Initialize Google Drive sync
  Future<bool> initGoogleDriveSync() async {
    final success = await _fileService.initGoogleDriveSync();
    if (success) {
      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('google_drive_configured', true);
      await loadEntries(); // Reload after sync starts
    }
    return success;
  }

  /// Stop Google Drive sync
  Future<void> stopGoogleDriveSync() async {
    await _fileService.stopGoogleDriveSync();
    // Clear preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_drive_configured');
  }

  /// Check if Google Drive is signed in
  Future<bool> isGoogleDriveSignedIn() async {
    return await _fileService.isGoogleDriveSignedIn();
  }

  /// Get Google Drive user email
  Future<String?> getGoogleDriveUserEmail() async {
    return await _fileService.getGoogleDriveUserEmail();
  }

  /// Trigger manual sync
  Future<void> syncNow() async {
    await _fileService.syncNow();
    await loadEntries(); // Reload after sync
  }

  /// Get last sync time
  DateTime? get lastSyncTime => _fileService.lastSyncTime;

  // ==========================================================================
  // TEMPLATE MANAGEMENT
  // ==========================================================================

  /// Apply a template to create a new day entry
  ///
  /// If [replace] is true, clears existing sections and replaces with template.
  /// If [replace] is false (default), merges template sections with existing entry.
  Future<void> applyTemplate(
    DateTime date,
    DayTemplate template, {
    bool replace = false,
  }) async {
    var entry = getEntryForDate(date);

    if (entry == null || replace) {
      // Create new entry with template sections (replacing any existing)
      entry = DailyEntry(
        date: date,
        sections: template.toSections(),
      );
    } else {
      // Merge template sections with existing entry
      for (final templateSection in template.sections) {
        // Check if section already exists
        final existingSection = entry.sections.firstWhere(
          (s) => s.name.toLowerCase() == templateSection.name.toLowerCase(),
          orElse: () => Section(name: '', items: []),
        );

        if (existingSection.name.isEmpty) {
          // Section doesn't exist, add it
          entry.sections.add(templateSection.toSection());
        }
      }
    }

    await saveEntry(entry);
  }

  /// Create a new entry from template (for next day)
  Future<void> createEntryFromTemplate(
    DateTime date,
    String templateId,
  ) async {
    final templateService = TemplateService(
      customBasePath: _fileService.customPath,
    );

    // Configure Nextcloud for template loading if available
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('nextcloud_server_url')) {
      templateService.configureNextcloud(
        serverUrl: prefs.getString('nextcloud_server_url')!,
        username: prefs.getString('nextcloud_username')!,
        password: prefs.getString('nextcloud_password')!,
        filePath: prefs.getString('nextcloud_file_path'),
      );
    }

    final template = await templateService.loadTemplate(templateId);
    if (template != null) {
      await applyTemplate(date, template);
    }
  }

  // ==========================================================================
  // COPY FUNCTIONALITY
  // ==========================================================================

  /// Copy a task from one date to another
  ///
  /// [targetSectionName] specifies which section to add the task to.
  /// If null, the task is added to the first tasks section or creates a "Tasks" section.
  Future<void> copyTaskToDate(
    Task task,
    DateTime fromDate,
    DateTime toDate, {
    String? targetSectionName,
  }) async {
    // Get or create target entry
    var targetEntry = getEntryForDate(toDate);
    targetEntry ??= DailyEntry(date: toDate);

    // Create a copy of the task (uncompleted)
    final copiedTask = Task(
      title: task.title,
      estimatedHours: task.estimatedHours,
      isCompleted: false,
    );

    // Determine target section
    String sectionName;
    if (targetSectionName != null) {
      sectionName = targetSectionName;
    } else {
      // Find first tasks section or create "Tasks" section
      final tasksSection = targetEntry.sections.firstWhere(
        (s) => s.type == SectionType.tasks,
        orElse: () => Section(name: '', items: []),
      );

      if (tasksSection.name.isNotEmpty) {
        sectionName = tasksSection.name;
      } else {
        // Create new "Tasks" section
        sectionName = 'Tasks';
        targetEntry.sections.add(Section(
          name: sectionName,
          items: [],
          type: SectionType.tasks,
        ));
      }
    }

    // Add task to target section
    final checkboxLine =
        '- [ ] ${copiedTask.title} | ${copiedTask.estimatedHours.toStringAsFixed(1)}h';
    targetEntry.addItemToSection(sectionName, checkboxLine, task: copiedTask);

    await saveEntry(targetEntry);

    // Copy template association from source to target date
    await _copyTemplateAssociation(fromDate, toDate);
  }

  /// Copy an entire section from one date to another
  ///
  /// If [mergeTasks] is true, tasks are added to the target entry's task list.
  /// Otherwise, only the section structure and non-task items are copied.
  Future<void> copySectionToDate(
    Section section,
    DateTime fromDate,
    DateTime toDate, {
    bool mergeTasks = true,
  }) async {
    // Get or create target entry
    var targetEntry = getEntryForDate(toDate);
    targetEntry ??= DailyEntry(date: toDate);

    // Check if section already exists
    final existingSection = targetEntry.sections.firstWhere(
      (s) => s.name.toLowerCase() == section.name.toLowerCase(),
      orElse: () => Section(name: '', items: []),
    );

    if (existingSection.name.isNotEmpty) {
      // Section exists, merge items
      for (final item in section.items) {
        if (!existingSection.items.contains(item)) {
          // For tasks, parse and add to tasks list
          if (section.type == SectionType.tasks && mergeTasks) {
            final task = _parseTaskFromCheckboxLine(item);
            if (task != null) {
              existingSection.items.add(item);
              targetEntry.tasks.add(task);
            }
          } else {
            existingSection.items.add(item);
          }
        }
      }
    } else {
      // Section doesn't exist, create it
      final newSection = section.copyWith();

      // If merging tasks, add them to entry's task list
      if (section.type == SectionType.tasks && mergeTasks) {
        for (final item in section.items) {
          final task = _parseTaskFromCheckboxLine(item);
          if (task != null) {
            // Reset task to incomplete
            final copiedTask = Task(
              title: task.title,
              estimatedHours: task.estimatedHours,
              isCompleted: false,
            );
            targetEntry.tasks.add(copiedTask);

            // Update checkbox line to uncompleted
            final index = newSection.items.indexOf(item);
            if (index != -1) {
              newSection.items[index] = item.replaceFirst('[x]', '[ ]');
            }
          }
        }
      }

      targetEntry.sections.add(newSection);
    }

    await saveEntry(targetEntry);

    // Copy template association from source to target date
    await _copyTemplateAssociation(fromDate, toDate);
  }

  /// Parse a task from a checkbox line
  Task? _parseTaskFromCheckboxLine(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('- [')) return null;

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

    String title;
    double hours = 1.0;

    if (remainder.contains('|')) {
      final parts = remainder.split('|');
      title = parts[0].trim();

      if (parts.length > 1) {
        final timeStr = parts[1].trim().toLowerCase();
        final match = RegExp(r'(\d+\.?\d*)\s*(m|h)?').firstMatch(timeStr);
        if (match != null) {
          final value = double.tryParse(match.group(1)!) ?? 1.0;
          final unit = match.group(2) ?? 'h';
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
    );
  }

  // Private helpers

  /// Copy template association from source date to target date
  ///
  /// Used when copying items/tasks to preserve template context
  Future<void> _copyTemplateAssociation(
      DateTime sourceDate, DateTime targetDate) async {
    final prefs = await SharedPreferences.getInstance();
    final sourceKey = 'template_${_formatDateKey(sourceDate)}';
    final targetKey = 'template_${_formatDateKey(targetDate)}';

    final sourceTemplate = prefs.getString(sourceKey);
    if (sourceTemplate != null && sourceTemplate.isNotEmpty) {
      // Only copy if target doesn't already have a template
      final targetTemplate = prefs.getString(targetKey);
      if (targetTemplate == null || targetTemplate.isEmpty) {
        await prefs.setString(targetKey, sourceTemplate);
      }
    }
  }

  /// Format date for SharedPreferences key
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void clearSyncError() {
    _syncError = null;
    notifyListeners();
  }

  void _sortEntries() {
    _entries.sort((a, b) => a.date.compareTo(b.date));
  }
}
