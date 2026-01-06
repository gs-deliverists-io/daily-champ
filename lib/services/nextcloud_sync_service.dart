import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service for syncing with Nextcloud via WebDAV
class NextcloudSyncService {
  final String serverUrl;
  final String username;
  final String password;
  final String filePath;

  NextcloudSyncService({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.filePath = '/Notes/dailychamp/daily.md',
  });

  /// Get the full WebDAV URL
  String get webdavUrl => '$serverUrl/remote.php/dav/files/$username$filePath';

  /// Get basic auth header
  String get authHeader {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }

  /// Download file from Nextcloud
  Future<String?> download() async {
    try {
      final response = await http.get(
        Uri.parse(webdavUrl),
        headers: {
          'Authorization': authHeader,
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else if (response.statusCode == 404) {
        // File doesn't exist yet
        return null;
      } else if (response.statusCode == 401) {
        throw NextcloudAuthException(
          'Authentication failed. Please check your username and password.',
        );
      } else {
        throw NextcloudSyncException(
          'Failed to download: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } on NextcloudAuthException {
      rethrow;
    } on NextcloudSyncException {
      rethrow;
    } catch (e) {
      throw NextcloudSyncException('Network error: $e');
    }
  }

  /// Upload file to Nextcloud
  Future<void> upload(String content) async {
    try {
      // First, try to create the parent directory if it doesn't exist
      await _ensureDirectoryExists();

      final response = await http.put(
        Uri.parse(webdavUrl),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'text/markdown',
        },
        body: utf8.encode(content),
      );

      if (response.statusCode == 401) {
        throw NextcloudAuthException(
          'Authentication failed. Please check your username and password.',
        );
      } else if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 204) {
        throw NextcloudSyncException(
          'Failed to upload: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } on NextcloudAuthException {
      rethrow;
    } on NextcloudSyncException {
      rethrow;
    } catch (e) {
      throw NextcloudSyncException('Network error: $e');
    }
  }

  /// Ensure parent directory exists (create if needed)
  Future<void> _ensureDirectoryExists() async {
    try {
      // Extract directory path from filePath
      final pathParts = filePath.split('/');
      if (pathParts.length <= 1) return; // No directory needed

      // Build directory path (everything except the filename)
      final dirPath = pathParts.sublist(0, pathParts.length - 1).join('/');
      final dirUrl = '$serverUrl/remote.php/dav/files/$username$dirPath';

      // Try to create directory (MKCOL = make collection/directory)
      final request = http.Request('MKCOL', Uri.parse(dirUrl));
      request.headers['Authorization'] = authHeader;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // 201 = created, 405 = already exists (both are fine)
      if (response.statusCode != 201 && response.statusCode != 405) {
        // Directory might already exist or parent directories need to be created
        // WebDAV doesn't auto-create parent dirs, so create them recursively
        await _createDirectoriesRecursively(dirPath);
      }
    } catch (e) {
      // If directory creation fails, upload might still work if dir exists
      // ignore: avoid_print
      print('Directory creation warning: $e');
    }
  }

  /// Create directories recursively
  Future<void> _createDirectoriesRecursively(String dirPath) async {
    final parts = dirPath.split('/').where((p) => p.isNotEmpty).toList();
    String currentPath = '';

    for (final part in parts) {
      currentPath += '/$part';
      final dirUrl = '$serverUrl/remote.php/dav/files/$username$currentPath';

      try {
        final request = http.Request('MKCOL', Uri.parse(dirUrl));
        request.headers['Authorization'] = authHeader;

        final streamedResponse = await request.send();
        await http.Response.fromStream(streamedResponse);
        // Ignore response - directory either created or already exists
      } catch (e) {
        // Continue even if one directory fails
      }
    }
  }

  /// Check if file exists on server
  Future<bool> exists() async {
    try {
      final request = http.Request('PROPFIND', Uri.parse(webdavUrl));
      request.headers['Authorization'] = authHeader;
      request.headers['Depth'] = '0';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 207; // Multi-Status = file exists
    } catch (e) {
      return false;
    }
  }

  /// Get file metadata (last modified time)
  Future<DateTime?> getLastModified() async {
    try {
      final request = http.Request('PROPFIND', Uri.parse(webdavUrl));
      request.headers['Authorization'] = authHeader;
      request.headers['Depth'] = '0';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 207) {
        // Parse WebDAV response for last modified
        final body = response.body;
        final modifiedMatch =
            RegExp(r'<d:getlastmodified>(.*?)</d:getlastmodified>')
                .firstMatch(body);

        if (modifiedMatch != null) {
          return HttpDate.parse(modifiedMatch.group(1)!);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// List files in a directory on Nextcloud
  /// Returns list of file names (without path)
  Future<List<String>> listDirectory(String dirPath) async {
    try {
      final dirUrl = '$serverUrl/remote.php/dav/files/$username$dirPath';
      final request = http.Request('PROPFIND', Uri.parse(dirUrl));
      request.headers['Authorization'] = authHeader;
      request.headers['Depth'] = '1'; // List immediate children

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 207) {
        // Parse WebDAV response for file names
        final fileNames = <String>[];
        final body = response.body;

        // Match href elements that contain file paths
        final hrefMatches = RegExp(r'<d:href>(.*?)</d:href>').allMatches(body);

        for (final match in hrefMatches) {
          final href = Uri.decodeFull(match.group(1) ?? '');

          // Skip the directory itself (ends with /)
          if (href.endsWith('/')) continue;

          // Extract filename from path
          final parts = href.split('/');
          if (parts.isNotEmpty) {
            final fileName = parts.last;
            if (fileName.isNotEmpty && fileName.endsWith('.md')) {
              fileNames.add(fileName);
            }
          }
        }

        return fileNames;
      } else if (response.statusCode == 404) {
        // Directory doesn't exist
        return [];
      } else if (response.statusCode == 401) {
        throw NextcloudAuthException(
          'Authentication failed. Please check your username and password.',
        );
      } else {
        throw NextcloudSyncException(
          'Failed to list directory: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } on NextcloudAuthException {
      rethrow;
    } on NextcloudSyncException {
      rethrow;
    } catch (e) {
      throw NextcloudSyncException('Network error: $e');
    }
  }

  /// Download a specific file from a directory
  Future<String?> downloadFile(String path) async {
    try {
      final fileUrl = '$serverUrl/remote.php/dav/files/$username$path';
      final response = await http.get(
        Uri.parse(fileUrl),
        headers: {
          'Authorization': authHeader,
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else if (response.statusCode == 404) {
        return null;
      } else if (response.statusCode == 401) {
        throw NextcloudAuthException(
          'Authentication failed. Please check your username and password.',
        );
      } else {
        throw NextcloudSyncException(
          'Failed to download file: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } on NextcloudAuthException {
      rethrow;
    } on NextcloudSyncException {
      rethrow;
    } catch (e) {
      throw NextcloudSyncException('Network error: $e');
    }
  }

  /// Upload a file to a specific path on Nextcloud
  Future<void> uploadFile(String path, String content) async {
    try {
      // Ensure parent directory exists
      final pathParts = path.split('/');
      if (pathParts.length > 1) {
        final dirPath = pathParts.sublist(0, pathParts.length - 1).join('/');
        await _createDirectoriesRecursively(dirPath);
      }

      final fileUrl = '$serverUrl/remote.php/dav/files/$username$path';
      final response = await http.put(
        Uri.parse(fileUrl),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'text/markdown',
        },
        body: utf8.encode(content),
      );

      if (response.statusCode == 401) {
        throw NextcloudAuthException(
          'Authentication failed. Please check your username and password.',
        );
      } else if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 204) {
        throw NextcloudSyncException(
          'Failed to upload file: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } on NextcloudAuthException {
      rethrow;
    } on NextcloudSyncException {
      rethrow;
    } catch (e) {
      throw NextcloudSyncException('Network error: $e');
    }
  }

  /// Get the templates directory path based on the configured file path
  String get templatesPath {
    // Extract parent directory from filePath and append /templates
    // e.g., /Notes/dailychamp/daily.md -> /Notes/dailychamp/templates
    final pathParts = filePath.split('/');
    if (pathParts.length >= 2) {
      // Remove the filename
      pathParts.removeLast();
      return '${pathParts.join('/')}/templates';
    }
    return '/Notes/dailychamp/templates';
  }
}

/// Exception for Nextcloud sync errors
class NextcloudSyncException implements Exception {
  final String message;

  NextcloudSyncException(this.message);

  @override
  String toString() => 'NextcloudSyncException: $message';
}

/// Exception for Nextcloud authentication errors
class NextcloudAuthException extends NextcloudSyncException {
  NextcloudAuthException(super.message);

  @override
  String toString() => 'NextcloudAuthException: $message';
}
