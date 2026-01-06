import 'dart:io' if (dart.library.html) 'dart.html' as io;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watcher/watcher.dart';
import '../models/models.dart';
import 'markdown_parser.dart';
import 'markdown_writer.dart';
import 'nextcloud_sync_service.dart';
// TODO: Uncomment when Google OAuth is configured in Info.plist
// import 'google_drive_sync_service.dart';

/// Sync mode for file storage
enum SyncMode {
  local, // Local file only
  nextcloud, // Nextcloud WebDAV sync (all platforms)
  // googleDrive, // Google Drive sync (all platforms) - DISABLED until OAuth configured
  icloud, // iCloud Drive sync (iOS only, requires paid Apple Developer account)
}

/// Service for reading and writing dailychamp.md file
///
/// **File Location (New Structure):**
/// - Web: localStorage (browser storage)
/// - macOS: ~/Nextcloud/Notes/dailychamp/daily.md
/// - iOS/Android: App Documents/dailychamp/daily.md
///
/// **File Location (Legacy - for backward compatibility):**
/// - macOS: ~/Nextcloud/Notes/execute.md
/// - iOS/Android: App Documents/execute.md
///
/// **Sync Methods:**
/// - Local: File watcher for instant updates (default for macOS with Desktop client)
/// - Nextcloud: WebDAV periodic sync (available on all platforms - macOS, iOS, Android)
/// - iCloud: Ubiquity container (disabled, requires paid account)
class FileService {
  static const String _storageKey = 'dailychamp_md_content';
  static const String _legacyFileName = 'execute.md';
  static const String _newDirName = 'dailychamp';
  static const String _newFileName = 'daily.md';
  static const MethodChannel _icloudChannel = MethodChannel(
    'com.dailychamp.icloud',
  );

  // Feature flags
  static const bool _icloudEnabled =
      false; // Set to true when you have Apple Developer account

  final String? customPath;
  FileWatcher? _watcher;
  StreamSubscription? _watcherSubscription;
  final _changeController = StreamController<void>.broadcast();
  final _syncErrorController = StreamController<String>.broadcast();

  NextcloudSyncService? _nextcloudSync;
  // GoogleDriveSyncService? _googleDriveSync; // DISABLED - uncomment when OAuth configured
  Timer? _syncTimer;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;
  String? _lastSyncError;
  int _consecutiveAuthErrors = 0;
  int _consecutiveErrors = 0;
  Duration _syncInterval = const Duration(seconds: 5);

  // Write tracking for race condition prevention
  // When using Nextcloud Desktop client on macOS, both the Desktop client and
  // our WebDAV sync can create race conditions. After a local write, we need
  // to wait for the Desktop client to upload before downloading from server.
  DateTime? _lastLocalWrite;
  static const _writeGracePeriod = Duration(seconds: 10);

  // Cached file path for Nextcloud Desktop detection
  String? _filePath;

  FileService({this.customPath});

  /// Stream of file changes
  Stream<void> get changes => _changeController.stream;

  /// Stream of sync errors
  Stream<String> get syncErrors => _syncErrorController.stream;

  /// Last sync error message
  String? get lastSyncError => _lastSyncError;

  /// Initialize Nextcloud sync (call from settings after user configures)
  Future<void> initNextcloudSync({
    required String serverUrl,
    required String username,
    required String password,
    String? filePath,
  }) async {
    _nextcloudSync = NextcloudSyncService(
      serverUrl: serverUrl,
      username: username,
      password: password,
      filePath: filePath ?? '/dailychamp/daily.md',
    );

    // Reset error counters
    _consecutiveAuthErrors = 0;
    _consecutiveErrors = 0;
    _syncInterval = const Duration(seconds: 5);

    // Start periodic sync (every 5 seconds initially)
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      await _syncWithNextcloud();
    });

    // Initial sync
    await _syncWithNextcloud();
  }

  /// Stop Nextcloud sync
  void stopNextcloudSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _nextcloudSync = null;
    _consecutiveAuthErrors = 0;
    _consecutiveErrors = 0;
    _syncInterval = const Duration(seconds: 5);
  }

  /// Initialize Google Drive sync - DISABLED until OAuth configured
  Future<bool> initGoogleDriveSync() async {
    // TODO: Uncomment when Google OAuth is configured
    /*
    _googleDriveSync = GoogleDriveSyncService();
    final success = await _googleDriveSync!.initialize();

    if (!success) {
      _googleDriveSync = null;
      return false;
    }

    // Start periodic sync (every 5 seconds)
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _syncWithGoogleDrive();
    });

    // Initial sync
    await _syncWithGoogleDrive();
    return true;
    */
    return false; // Disabled
  }

  /// Stop Google Drive sync - DISABLED until OAuth configured
  Future<void> stopGoogleDriveSync() async {
    // TODO: Uncomment when Google OAuth is configured
    /*
    _syncTimer?.cancel();
    _syncTimer = null;
    if (_googleDriveSync != null) {
      await _googleDriveSync!.signOut();
      _googleDriveSync = null;
    }
    */
  }

  /// Sync with Nextcloud server
  Future<void> _syncWithNextcloud() async {
    if (_nextcloudSync == null || _isSyncing) return;

    // Skip sync if we recently wrote locally (give time for upload to complete)
    // This prevents race conditions where:
    // 1. User toggles checkbox → writes locally
    // 2. Nextcloud Desktop client starts uploading (takes 1-2 sec)
    // 3. This sync timer fires → would download old version from server
    // 4. Old version overwrites local file → checkbox undone!
    if (_lastLocalWrite != null) {
      final timeSinceWrite = DateTime.now().difference(_lastLocalWrite!);
      if (timeSinceWrite < _writeGracePeriod) {
        // ignore: avoid_print
        print(
          'Nextcloud sync skipped: ${timeSinceWrite.inSeconds}s since last write '
          '(grace period: ${_writeGracePeriod.inSeconds}s)',
        );
        return;
      }
    }

    _isSyncing = true;
    try {
      // Get local file content
      final localContent = await _readLocalFile();

      // Get server file content
      final serverContent = await _nextcloudSync!.download();

      if (serverContent == null) {
        // File doesn't exist on server, upload local version (or create empty file)
        final contentToUpload = localContent ?? '';
        await _nextcloudSync!.upload(contentToUpload);
        // ignore: avoid_print
        print('Created new file on Nextcloud server');
      } else {
        // Compare and merge
        if (localContent != serverContent) {
          // Get last modified times
          final serverModified = await _nextcloudSync!.getLastModified();

          // Check if local file exists
          final localFile = io.File(await getFilePath());
          final localExists = await localFile.exists();

          if (!localExists) {
            // No local file, download from server
            await _writeLocalFile(serverContent);
            _changeController.add(null); // Notify listeners
          } else {
            // Both exist, compare modification times
            final localModified = await localFile.lastModified();

            // Use most recent version
            if (serverModified != null &&
                serverModified.isAfter(localModified)) {
              // Server is newer, download
              await _writeLocalFile(serverContent);
              _changeController.add(null); // Notify listeners
            } else {
              // Local is newer, upload
              if (localContent != null) {
                await _nextcloudSync!.upload(localContent);
              }
            }
          }
        }
      }

      _lastSyncTime = DateTime.now();
      _lastSyncError = null;
      _consecutiveAuthErrors = 0;
      _consecutiveErrors = 0;

      // Reset sync interval to normal after successful sync
      if (_syncInterval.inSeconds > 5) {
        _syncInterval = const Duration(seconds: 5);
        _restartSyncTimer();
      }

      // ignore: avoid_print
      print('Nextcloud sync completed at $_lastSyncTime');
    } catch (e) {
      // ignore: avoid_print
      print('Nextcloud sync error: $e');

      final errorMsg = e.toString();
      _lastSyncError = errorMsg;
      _consecutiveErrors++;

      // Check if it's an auth error (401)
      if (errorMsg.contains('Authentication') || errorMsg.contains('401')) {
        _consecutiveAuthErrors++;

        // After 2 consecutive auth errors, notify UI and stop syncing
        if (_consecutiveAuthErrors >= 2) {
          _syncErrorController.add(
            'Authentication failed: Please check your Nextcloud credentials in Settings.',
          );
          // Stop the sync timer to prevent continuous errors
          stopNextcloudSync();
          return;
        }
      }

      // Check if it's a rate limit error (429) or any other repeated error
      // After 2 errors, notify UI once and stop
      if (_consecutiveErrors >= 2) {
        if (errorMsg.contains('429') ||
            errorMsg.contains('Too Many Requests')) {
          _syncErrorController.add(
            'Sync rate limit exceeded. Please check your Nextcloud credentials in Settings.',
          );
        } else {
          _syncErrorController.add(
            'Sync failed repeatedly. Please check your Nextcloud credentials in Settings.',
          );
        }
        stopNextcloudSync();
        return;
      }

      // Implement exponential backoff for any repeated errors
      if (_consecutiveErrors >= 2) {
        // Double the interval, max 60 seconds
        final newInterval = Duration(
          seconds: (_syncInterval.inSeconds * 2).clamp(5, 60),
        );

        if (newInterval != _syncInterval) {
          _syncInterval = newInterval;
          _restartSyncTimer();
          // ignore: avoid_print
          print(
              'Increasing sync interval to ${_syncInterval.inSeconds}s due to errors');
        }
      }

      // Don't throw, just log - app should work offline
    } finally {
      _isSyncing = false;
    }
  }

  /// Restart sync timer with current interval
  void _restartSyncTimer() {
    if (_nextcloudSync == null) return;

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      await _syncWithNextcloud();
    });
  }

  /// Sync with Google Drive - DISABLED until OAuth configured
  // ignore: unused_element
  Future<void> _syncWithGoogleDrive() async {
    // TODO: Implement when Google Drive OAuth is configured
    return;
  }

  /// Get current sync mode
  Future<SyncMode> getSyncMode() async {
    if (kIsWeb) return SyncMode.local;

    final prefs = await SharedPreferences.getInstance();

    // Check if Nextcloud WebDAV is configured (works on all platforms)
    final hasNextcloud = prefs.containsKey('nextcloud_server_url');
    if (hasNextcloud) {
      return SyncMode.nextcloud;
    }

    // Check if Google Drive is configured (works on all platforms)
    // Google Drive sync disabled
    // final hasGoogleDrive = prefs.containsKey('google_drive_enabled');
    // if (hasGoogleDrive) {
    //   return SyncMode.googleDrive;
    // }

    // Check if iCloud is available (only if enabled on iOS)
    if (_icloudEnabled && io.Platform.isIOS) {
      try {
        final String? iCloudPath = await _icloudChannel.invokeMethod(
          'getICloudPath',
        );
        if (iCloudPath != null && iCloudPath.isNotEmpty) {
          return SyncMode.icloud;
        }
      } catch (e) {
        // iCloud not available
      }
    }

    // Default to local storage
    return SyncMode.local;
  }

  /// Start watching the file for changes (native platforms only)
  void startWatching() {
    if (kIsWeb) return;

    stopWatching(); // Stop any existing watcher

    getFilePath().then((path) {
      try {
        _watcher = FileWatcher(path);
        _watcherSubscription = _watcher!.events.listen(
          (event) {
            // Notify listeners when file changes
            _changeController.add(null);
          },
          onError: (error) {
            // Silently handle errors (file might not exist yet)
          },
        );
      } catch (e) {
        // File might not exist yet, that's okay
      }
    });
  }

  /// Stop watching the file
  void stopWatching() {
    _watcherSubscription?.cancel();
    _watcherSubscription = null;
    _watcher = null;
  }

  /// Dispose resources
  void dispose() {
    stopWatching();
    stopNextcloudSync();
    stopGoogleDriveSync();
    _changeController.close();
  }

  /// Get the path to the execute.md file
  Future<String> getFilePath() async {
    // Return cached path if available
    if (_filePath != null) return _filePath!;

    if (kIsWeb) {
      _filePath = 'localStorage://$_storageKey';
      return _filePath!;
    }

    // Use custom path if provided AND we're on macOS (where desktop paths are valid)
    // On iOS/Android, always use the app sandbox directory regardless of customPath
    if (customPath != null && customPath!.isNotEmpty && io.Platform.isMacOS) {
      // customPath should be a directory path (e.g., "/Users/gs/Nextcloud/Notes")
      // We'll create: [customPath]/dailychamp/daily.md

      // If customPath ends with .md (legacy), extract parent directory
      if (customPath!.endsWith('.md')) {
        final parentDir = io.File(customPath!).parent.path;
        _filePath = '$parentDir/$_newDirName/$_newFileName';
      } else {
        // customPath is a directory
        _filePath = '$customPath/$_newDirName/$_newFileName';
      }

      // Create parent directory if it doesn't exist
      final file = io.File(_filePath!);
      if (!await file.exists()) {
        await file.parent.create(recursive: true);
      }

      return _filePath!;
    }

    // macOS fallback: use Nextcloud Desktop synced folder with new structure
    if (io.Platform.isMacOS) {
      const nextcloudPath = '/Users/gs/Nextcloud/Notes/dailychamp/daily.md';
      final nextcloudFile = io.File(nextcloudPath);

      // Create parent directory if it doesn't exist
      if (!await nextcloudFile.exists()) {
        await nextcloudFile.parent.create(recursive: true);
      }

      _filePath = nextcloudPath;
      return _filePath!;
    }

    // For iOS/Android: check if iCloud is enabled and available
    if (_icloudEnabled && io.Platform.isIOS) {
      try {
        final String? iCloudPath = await _icloudChannel.invokeMethod(
          'getICloudPath',
        );
        if (iCloudPath != null && iCloudPath.isNotEmpty) {
          // Use iCloud Documents folder
          final documentsDir = io.Directory('$iCloudPath/Documents');
          await documentsDir.create(recursive: true);
          _filePath = '${documentsDir.path}/$_newDirName/$_newFileName';
          return _filePath!;
        }
      } catch (e) {
        // iCloud not available, fall through to local storage
        // ignore: avoid_print
        print('iCloud not available: $e');
      }
    }

    // iOS/Android: use local app documents directory (sandbox)
    // This is where the app has write permissions
    // Nextcloud sync happens via WebDAV, not local file paths
    final directory = await getApplicationDocumentsDirectory();
    final appDir = io.Directory(directory.path);

    // Ensure the directory exists
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    _filePath = '${directory.path}/$_newDirName/$_newFileName';
    return _filePath!;
  }

  /// Check if using Nextcloud Desktop client (file in ~/Nextcloud/ folder on macOS)
  /// When using Desktop client, it handles sync via file watching, so our WebDAV
  /// sync should be less aggressive to avoid conflicts.
  // ignore: unused_element
  bool _isUsingNextcloudDesktop() {
    if (!io.Platform.isMacOS) return false;
    return _filePath?.contains('/Nextcloud/') == true;
  }

  /// Read local file content
  Future<String?> _readLocalFile() async {
    try {
      final file = io.File(await getFilePath());
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Write local file content
  Future<void> _writeLocalFile(String content) async {
    final file = io.File(await getFilePath());
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Check if data exists
  Future<bool> fileExists() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_storageKey);
    } else {
      final file = io.File(await getFilePath());
      return file.existsSync();
    }
  }

  /// Read all entries
  Future<List<DailyEntry>> readEntries() async {
    try {
      String contents;

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        contents = prefs.getString(_storageKey) ?? '';
      } else {
        final file = io.File(await getFilePath());
        if (await file.exists()) {
          contents = await file.readAsString();
        } else {
          contents = '';
        }
      }

      if (contents.trim().isEmpty) {
        return [];
      }

      return MarkdownParser.parse(contents);
    } catch (e) {
      throw FileServiceException('Failed to read entries: $e');
    }
  }

  /// Write all entries
  Future<void> writeEntries(List<DailyEntry> entries) async {
    try {
      final markdown = MarkdownWriter.write(entries);

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, markdown);
      } else {
        final file = io.File(await getFilePath());
        // Create parent directory if it doesn't exist
        await file.parent.create(recursive: true);
        await file.writeAsString(markdown);

        // Track write time to prevent sync from overwriting our changes
        // This gives Nextcloud Desktop client time to upload before we download
        _lastLocalWrite = DateTime.now();

        // If Nextcloud sync is enabled, trigger upload (but not download)
        if (_nextcloudSync != null) {
          await _nextcloudSync!.upload(markdown);
        }

        // Google Drive sync disabled
        // if (_googleDriveSync != null) {
        //   await _googleDriveSync!.upload(markdown);
        // }
      }
    } catch (e) {
      throw FileServiceException('Failed to write entries: $e');
    }
  }

  /// Read a single day's entry
  Future<DailyEntry?> readDay(DateTime date) async {
    final entries = await readEntries();

    try {
      return entries.firstWhere(
        (e) =>
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day,
      );
    } catch (e) {
      return null;
    }
  }

  /// Write or update a single day's entry
  Future<void> writeDay(DailyEntry entry) async {
    try {
      final entries = await readEntries();

      final index = entries.indexWhere(
        (e) =>
            e.date.year == entry.date.year &&
            e.date.month == entry.date.month &&
            e.date.day == entry.date.day,
      );

      if (index != -1) {
        entries[index] = entry;
      } else {
        entries.add(entry);
      }

      await writeEntries(entries);

      // Note: writeEntries() already handles Nextcloud upload.
      // Don't call _syncWithNextcloud() here as it may race with the upload
      // and download an old version from the server before upload completes.
    } catch (e) {
      throw FileServiceException('Failed to write day: $e');
    }
  }

  /// Delete a day's entry
  Future<bool> deleteDay(DateTime date) async {
    try {
      final entries = await readEntries();
      final originalLength = entries.length;

      entries.removeWhere(
        (e) =>
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day,
      );

      if (entries.length < originalLength) {
        await writeEntries(entries);
        return true;
      }

      return false;
    } catch (e) {
      throw FileServiceException('Failed to delete day: $e');
    }
  }

  /// Get entries for a specific month
  Future<List<DailyEntry>> getEntriesForMonth(int year, int month) async {
    final entries = await readEntries();

    return entries
        .where((e) => e.date.year == year && e.date.month == month)
        .toList();
  }

  /// Get entries for a date range
  Future<List<DailyEntry>> getEntriesInRange(
    DateTime start,
    DateTime end,
  ) async {
    final entries = await readEntries();

    return entries.where((e) {
      return e.date.isAfter(start.subtract(const Duration(days: 1))) &&
          e.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  /// Create a backup (web only exports to download)
  Future<String> createBackup() async {
    final entries = await readEntries();
    final markdown = MarkdownWriter.write(entries);
    return markdown; // Return the markdown content for download
  }

  /// Restore from backup markdown content
  Future<void> restoreFromBackup(String markdownContent) async {
    try {
      final entries = MarkdownParser.parse(markdownContent);
      await writeEntries(entries);
    } catch (e) {
      throw FileServiceException('Failed to restore backup: $e');
    }
  }

  /// Clear all data
  Future<void> clearAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } else {
      final file = io.File(await getFilePath());
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Get statistics about entries
  Future<Map<String, int>> getStatistics() async {
    final entries = await readEntries();

    var wins = 0;
    var losses = 0;
    var pending = 0;

    for (final entry in entries) {
      switch (entry.status) {
        case DayStatus.win:
          wins++;
          break;
        case DayStatus.loss:
          losses++;
          break;
        case DayStatus.pending:
        case DayStatus.scheduled:
          pending++;
          break;
      }
    }

    return {
      'totalEntries': entries.length,
      'wins': wins,
      'losses': losses,
      'pending': pending,
    };
  }

  /// Export markdown (for download on web)
  Future<String> exportMarkdown() async {
    final entries = await readEntries();
    return MarkdownWriter.write(entries);
  }

  /// Import markdown content
  Future<void> importMarkdown(String content) async {
    final entries = MarkdownParser.parse(content);
    await writeEntries(entries);
  }

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Force sync now
  Future<void> syncNow() async {
    if (_nextcloudSync != null) {
      await _syncWithNextcloud();
    }
    // TODO: Uncomment when Google Drive is configured
    // else if (_googleDriveSync != null) {
    //   await _syncWithGoogleDrive();
    // }
  }

  /// Check if Google Drive is signed in - DISABLED
  Future<bool> isGoogleDriveSignedIn() async {
    // TODO: Uncomment when Google Drive is configured
    // if (_googleDriveSync == null) return false;
    // return await _googleDriveSync!.isSignedIn();
    return false;
  }

  /// Get Google Drive user email - DISABLED
  Future<String?> getGoogleDriveUserEmail() async {
    // TODO: Uncomment when Google Drive is configured
    // if (_googleDriveSync == null) return null;
    // return await _googleDriveSync!.getUserEmail();
    return null;
  }
}

/// Custom exception for file service errors
class FileServiceException implements Exception {
  final String message;

  FileServiceException(this.message);

  @override
  String toString() => 'FileServiceException: $message';
}
