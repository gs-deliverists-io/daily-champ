import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/dailychamp_provider.dart';
import '../providers/theme_provider.dart';
import '../services/nextcloud_sync_service.dart';
import '../theme/theme_compat.dart';
import '../theme/app_theme.dart' as theme;
import 'package:flutter/foundation.dart' show kIsWeb;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _nextcloudConfigured = false;
  String? _nextcloudServer;
  // ignore: unused_field - Prepared for future Google Drive feature
  bool _googleDriveConfigured = false;
  DateTime? _lastSyncTime;
  String? _customFilePath;

  @override
  void initState() {
    super.initState();
    _loadSyncConfig();
    _loadFilePath();
  }

  Future<void> _loadFilePath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customFilePath = prefs.getString('custom_file_path');
    });
  }

  Future<void> _loadSyncConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nextcloudConfigured = prefs.containsKey('nextcloud_server_url');
      _nextcloudServer = prefs.getString('nextcloud_server_url');
      _googleDriveConfigured = prefs.containsKey('google_drive_configured') &&
          prefs.getBool('google_drive_configured') == true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppTheme.borderColor,
          ),
        ),
      ),
      body: Consumer<DailyChampProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            children: [
              // Appearance Section
              _buildSectionTitle('Appearance'),
              const SizedBox(height: AppTheme.spacing8),
              _buildThemeSelector(context),

              const SizedBox(height: AppTheme.spacing24),

              // Connections Section (Native apps only)
              if (!kIsWeb) ...[
                _buildSectionTitle('Connections'),
                const SizedBox(height: AppTheme.spacing8),
                _buildConnectionsSection(context, provider),
                const SizedBox(height: AppTheme.spacing24),
              ],

              // Storage Section (macOS only)
              if (!kIsWeb && Platform.isMacOS) ...[
                _buildSectionTitle('Storage'),
                const SizedBox(height: AppTheme.spacing8),
                _buildInfoCard(
                  context,
                  title: 'Local File Path',
                  subtitle:
                      _customFilePath ?? '~/Nextcloud/dailychamp/daily.md',
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(height: AppTheme.spacing12),
                _buildActionCard(
                  context,
                  title: 'Change Location',
                  subtitle: 'Set custom path for daily.md',
                  icon: Icons.edit_location_outlined,
                  onTap: () => _configureFilePath(context, provider),
                ),
                const SizedBox(height: AppTheme.spacing24),
              ],

              // Export/Import Section (Web only)
              if (kIsWeb) ...[
                _buildSectionTitle('File Sync'),
                const SizedBox(height: AppTheme.spacing8),
                _buildActionCard(
                  context,
                  title: 'Export to File',
                  subtitle: 'Download daily.md',
                  icon: Icons.download,
                  onTap: () => _exportToFile(context, provider),
                ),
                const SizedBox(height: AppTheme.spacing12),
                _buildActionCard(
                  context,
                  title: 'Import from File',
                  subtitle: 'Upload daily.md',
                  icon: Icons.upload,
                  onTap: () => _importFromFile(context, provider),
                ),
                const SizedBox(height: AppTheme.spacing24),
              ],

              // Danger Zone
              _buildSectionTitle('Danger Zone'),
              const SizedBox(height: AppTheme.spacing8),

              _buildActionCard(
                context,
                title: 'Clear All Data',
                subtitle: 'Permanently delete all entries',
                icon: Icons.delete_forever,
                isDestructive: true,
                onTap: () => _confirmClearAll(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
      child: Text(
        title,
        style: AppTheme.titleLarge,
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: colorScheme.onSurface),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTheme.titleLarge
                        .copyWith(color: colorScheme.onSurface)),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  subtitle,
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark
                        ? theme.AppTheme.darkTextSecondary
                        : theme.AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isDestructive ? Colors.red.shade300 : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: isDestructive ? Colors.red : colorScheme.onSurface,
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.titleLarge.copyWith(
                      color: isDestructive ? Colors.red : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark
                          ? theme.AppTheme.darkTextSecondary
                          : theme.AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDestructive
                  ? Colors.red
                  : (isDark
                      ? theme.AppTheme.darkTextTertiary
                      : theme.AppTheme.lightTextTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colorScheme = Theme.of(context).colorScheme;

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: _buildThemeIconButton(
                  context,
                  icon: Icons.wb_sunny,
                  themeMode: ThemeMode.light,
                  currentMode: themeProvider.themeMode,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                  tooltip: 'Light',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildThemeIconButton(
                  context,
                  icon: Icons.nightlight_round,
                  themeMode: ThemeMode.dark,
                  currentMode: themeProvider.themeMode,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                  tooltip: 'Dark',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildThemeIconButton(
                  context,
                  icon: Icons.settings_suggest,
                  themeMode: ThemeMode.system,
                  currentMode: themeProvider.themeMode,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                  tooltip: 'System',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeIconButton(
    BuildContext context, {
    required IconData icon,
    required ThemeMode themeMode,
    required ThemeMode currentMode,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final isSelected = themeMode == currentMode;
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected ? colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 24,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the Connections section with hierarchical ExpansionTiles
  Widget _buildConnectionsSection(
      BuildContext context, DailyChampProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Nextcloud Connection
          _buildConnectionExpansionTile(
            context,
            provider: provider,
            title: 'Nextcloud',
            icon:
                _nextcloudConfigured ? Icons.cloud_done : Icons.cloud_outlined,
            isConfigured: _nextcloudConfigured,
            subtitle: _nextcloudConfigured
                ? _nextcloudServer ?? 'Connected'
                : 'Sync with your server',
            children: _nextcloudConfigured
                ? [
                    // Connected state - show sync options
                    _buildConnectionTileAction(
                      context,
                      icon: Icons.sync,
                      title: 'Sync Now',
                      subtitle: _lastSyncTime != null
                          ? 'Last synced: ${_formatTime(_lastSyncTime!)}'
                          : 'Syncing every 5 seconds',
                      onTap: () => _syncNow(context, provider),
                    ),
                    _buildConnectionTileAction(
                      context,
                      icon: Icons.cloud_off,
                      title: 'Disconnect',
                      subtitle: 'Stop syncing with Nextcloud',
                      onTap: () => _disconnectNextcloud(context, provider),
                      isDestructive: true,
                    ),
                  ]
                : [
                    // Not connected state - show connect option
                    _buildConnectionTileAction(
                      context,
                      icon: Icons.add,
                      title: 'Connect',
                      subtitle: 'Enter your Nextcloud credentials',
                      onTap: () => _configureNextcloud(context, provider),
                    ),
                  ],
          ),

          // Divider
          Container(
            height: 1,
            color: AppTheme.borderColor,
          ),

          // Google Drive Connection (Coming Soon)
          _buildConnectionExpansionTile(
            context,
            provider: provider,
            title: 'Google Drive',
            icon: Icons.add_to_drive,
            isConfigured: false,
            subtitle: 'Coming soon',
            isDisabled: true,
            children: const [],
          ),
        ],
      ),
    );
  }

  /// Build an expansion tile for a connection type
  Widget _buildConnectionExpansionTile(
    BuildContext context, {
    required DailyChampProvider provider,
    required String title,
    required IconData icon,
    required bool isConfigured,
    required String subtitle,
    required List<Widget> children,
    bool isDisabled = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        leading: Icon(
          icon,
          color: isDisabled
              ? colorScheme.onSurface.withValues(alpha: 0.3)
              : isConfigured
                  ? theme.AppTheme.success
                  : colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        title: Text(
          title,
          style: AppTheme.bodyLarge.copyWith(
            color: isDisabled
                ? colorScheme.onSurface.withValues(alpha: 0.3)
                : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTheme.bodySmall.copyWith(
            color: isDisabled
                ? colorScheme.onSurface.withValues(alpha: 0.2)
                : colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: isDisabled
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  'Soon',
                  style: AppTheme.labelSmall.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              )
            : null,
        enabled: !isDisabled,
        children: children,
      ),
    );
  }

  /// Build an action item within a connection tile
  Widget _buildConnectionTileAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border(
            top: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive
                  ? Colors.red
                  : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDestructive ? Colors.red : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToFile(
    BuildContext context,
    DailyChampProvider provider,
  ) async {
    try {
      final markdown = await provider.exportMarkdown();

      // Show download instructions for web
      if (kIsWeb) {
        // Show dialog with instructions
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Export Ready'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Copy the text below and save it to:'),
                  const SizedBox(height: 8),
                  Text(
                    '~/Nextcloud/Notes/execute.md',
                    style: AppTheme.bodySmall.copyWith(
                      fontFamily: 'monospace',
                      backgroundColor: AppTheme.surfaceColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        markdown,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importFromFile(
    BuildContext context,
    DailyChampProvider provider,
  ) async {
    // Show dialog to paste markdown content
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import from File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste the contents of execute.md:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '# 2026-01-05 Sunday\n\n## Goals\n...',
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && context.mounted) {
      try {
        await provider.importMarkdown(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import successful!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    DailyChampProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your entries. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await provider.clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared')),
        );
      }
    }
  }

  // Nextcloud sync methods

  Future<void> _configureNextcloud(
    BuildContext context,
    DailyChampProvider provider, {
    String? initialServer,
    String? initialUsername,
    String? initialPassword,
    String? initialFilePath,
  }) async {
    final serverController = TextEditingController(text: initialServer ?? '');
    final usernameController =
        TextEditingController(text: initialUsername ?? '');
    final passwordController =
        TextEditingController(text: initialPassword ?? '');
    final filePathController =
        TextEditingController(text: initialFilePath ?? '/dailychamp/daily.md');

    final result = await showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Configure Nextcloud'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your Nextcloud server details:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: serverController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'cloud.example.com',
                  helperText: 'Without https:// prefix',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  helperText: 'Your Nextcloud username',
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  helperText: 'App password recommended',
                ),
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: filePathController,
                decoration: const InputDecoration(
                  labelText: 'Remote File Path',
                  hintText: '/dailychamp/daily.md',
                  helperText: 'Path to daily.md on your Nextcloud',
                ),
                autocorrect: false,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'server': serverController.text,
              'username': usernameController.text,
              'password': passwordController.text,
              'filePath': filePathController.text,
            }),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      // Show connecting dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to Nextcloud...'),
            ],
          ),
        ),
      );

      try {
        // Normalize server URL - add https:// if missing
        var serverUrl = result['server']!.trim();
        if (!serverUrl.startsWith('http://') &&
            !serverUrl.startsWith('https://')) {
          serverUrl = 'https://$serverUrl';
        }
        // Remove trailing slash
        if (serverUrl.endsWith('/')) {
          serverUrl = serverUrl.substring(0, serverUrl.length - 1);
        }

        // Normalize file path - ensure it starts with /
        var filePath = result['filePath']!.trim();
        if (filePath.isEmpty) {
          filePath = '/dailychamp/daily.md';
        }
        if (!filePath.startsWith('/')) {
          filePath = '/$filePath';
        }

        // Validate credentials
        if (serverUrl.isEmpty ||
            result['username']!.isEmpty ||
            result['password']!.isEmpty) {
          throw Exception('All fields are required');
        }

        // Test connection first
        final testService = NextcloudSyncService(
          serverUrl: serverUrl,
          username: result['username']!,
          password: result['password']!,
          filePath: filePath,
        );

        await testService.exists();

        // Connection successful! Save credentials
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('nextcloud_server_url', serverUrl);
        await prefs.setString('nextcloud_username', result['username']!);
        await prefs.setString('nextcloud_password', result['password']!);
        await prefs.setString('nextcloud_file_path', filePath);

        // Initialize sync in provider
        await provider.initNextcloudSync(
          serverUrl: serverUrl,
          username: result['username']!,
          password: result['password']!,
          filePath: filePath,
        );

        setState(() {
          _nextcloudConfigured = true;
          _nextcloudServer = serverUrl;
        });

        // Close connecting dialog
        if (context.mounted) {
          Navigator.pop(context);
        }

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Connected successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Close connecting dialog
        if (context.mounted) {
          Navigator.pop(context);
        }

        // Show error dialog
        if (context.mounted) {
          final errorMsg = e.toString();
          String title = 'Connection Failed';
          String message = 'Could not connect to Nextcloud server.';
          List<String> suggestions = [];

          if (errorMsg.contains('Authentication') || errorMsg.contains('401')) {
            title = 'Authentication Failed';
            message = 'Your username or password is incorrect.';
            suggestions = [
              'Check your username and password',
              'Try using an app password instead',
              'Verify you have access to the server',
            ];
          } else if (errorMsg.contains('429') ||
              errorMsg.contains('Too Many Requests')) {
            title = 'Too Many Attempts';
            message = 'Please wait a moment before trying again.';
            suggestions = [
              'Wait 1-2 minutes',
              'Check your credentials are correct',
            ];
          } else {
            suggestions = [
              'Check the server URL is correct',
              'Verify you\'re connected to the internet',
              'Make sure the server is accessible',
            ];
          }

          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(title),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Try these solutions:'),
                    const SizedBox(height: 8),
                    ...suggestions.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $s'),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Retry - show config dialog again with same values
                    _configureNextcloud(
                      context,
                      provider,
                      initialServer: result['server'],
                      initialUsername: result['username'],
                      initialPassword: result['password'],
                      initialFilePath: result['filePath'],
                    );
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _syncNow(
    BuildContext context,
    DailyChampProvider provider,
  ) async {
    try {
      await provider.syncNow();
      setState(() {
        _lastSyncTime = DateTime.now();
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync successful!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final errorMsg = e.toString();
        final isAuthError = errorMsg.contains('Authentication failed') ||
            errorMsg.contains('401');

        if (isAuthError) {
          // Show detailed dialog for auth errors
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Authentication Failed'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Nextcloud credentials are incorrect or have expired.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text('Possible solutions:'),
                  SizedBox(height: 8),
                  Text('• Check your username and password'),
                  Text('• Use an app password instead of your main password'),
                  Text('• Verify your server URL is correct'),
                  SizedBox(height: 16),
                  Text(
                    'Please disconnect and reconfigure Nextcloud with correct credentials.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _disconnectNextcloud(context, provider);
                  },
                  child: const Text('Disconnect & Reconfigure'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sync failed: $errorMsg')),
          );
        }
      }
    }
  }

  Future<void> _disconnectNextcloud(
    BuildContext context,
    DailyChampProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Nextcloud?'),
        content: const Text(
            'Automatic syncing will stop. Local data will be preserved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('nextcloud_server_url');
      await prefs.remove('nextcloud_username');
      await prefs.remove('nextcloud_password');

      provider.stopNextcloudSync();

      setState(() {
        _nextcloudConfigured = false;
        _nextcloudServer = null;
        _lastSyncTime = null;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nextcloud disconnected')),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  // Google Drive sync methods - Prepared for future implementation
  // ignore: unused_element
  Future<void> _configureGoogleDrive(
    BuildContext context,
    DailyChampProvider provider,
  ) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Initialize Google Drive sync (triggers OAuth flow)
      final success = await provider.initGoogleDriveSync();

      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (success) {
        // Save configuration flag
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('google_drive_configured', true);

        setState(() {
          _googleDriveConfigured = true;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Drive configured successfully!'),
            ),
          );
        }
      } else {
        throw Exception('Failed to authenticate with Google Drive');
      }
    } catch (e) {
      // Make sure loading indicator is closed
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        // Check if it's a configuration error
        final errorMsg = e.toString();
        if (errorMsg.contains('GIDClientID') ||
            errorMsg.contains('not configured') ||
            errorMsg.contains('PLACEHOLDER')) {
          // Show helpful dialog for missing Google credentials
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Google Drive Not Configured'),
              content: const SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To use Google Drive sync, you need to configure Google OAuth credentials:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Text('1. Create a project at console.cloud.google.com'),
                    SizedBox(height: 8),
                    Text('2. Enable Google Drive API'),
                    SizedBox(height: 8),
                    Text('3. Create OAuth 2.0 credentials for iOS'),
                    SizedBox(height: 8),
                    Text('4. Add the client ID to ios/Runner/Info.plist'),
                    SizedBox(height: 16),
                    Text(
                      'For now, you can use Nextcloud sync instead.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Show generic error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Configuration failed: $e')),
          );
        }
      }
    }
  }

  // ignore: unused_element
  Future<void> _syncGoogleDriveNow(
    BuildContext context,
    DailyChampProvider provider,
  ) async {
    try {
      await provider.syncNow();
      setState(() {
        _lastSyncTime = DateTime.now();
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync successful!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  // ignore: unused_element
  Future<void> _disconnectGoogleDrive(
    BuildContext context,
    DailyChampProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Drive?'),
        content: const Text(
          'Automatic syncing will stop. Local data will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('google_drive_configured');

      await provider.stopGoogleDriveSync();

      setState(() {
        _googleDriveConfigured = false;
        _lastSyncTime = null;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive disconnected')),
        );
      }
    }
  }

  // File path configuration
  Future<void> _configureFilePath(
    BuildContext context,
    DailyChampProvider provider,
  ) async {
    final pathController = TextEditingController(
      text: _customFilePath ?? '',
    );

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configure File Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the directory path where daily.md will be stored:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pathController,
                decoration: const InputDecoration(
                  labelText: 'Directory Path',
                  hintText: '/Users/gs/Nextcloud/Notes',
                  helperText:
                      'File will be saved as: [path]/dailychamp/daily.md',
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              const Text(
                'Examples:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                '• ~/Nextcloud/Notes\n'
                '• ~/Dropbox/Notes\n'
                '• ~/Documents/DailyChamp\n'
                '• ~/Library/Mobile Documents/com~apple~CloudDocs',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Changing the file location will require an app restart. Your existing data will NOT be automatically moved.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Reset to default
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('custom_file_path');
              if (context.mounted) {
                Navigator.pop(context, 'default');
              }
            },
            child: const Text('Reset to Default'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, pathController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      try {
        if (result == 'default') {
          // Reset to default
          setState(() {
            _customFilePath = null;
          });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'File location reset to default. Please restart the app.',
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          // Validate and save custom path
          final path = result.trim();
          if (path.isEmpty) {
            throw Exception('Path cannot be empty');
          }

          // Expand ~ to home directory
          final expandedPath = path.startsWith('~/')
              ? path.replaceFirst('~', Platform.environment['HOME'] ?? '')
              : path;

          // Validate path exists or can be created
          final dir = Directory(expandedPath);
          if (!await dir.exists()) {
            // Try to create it
            await dir.create(recursive: true);
          }

          // Save to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('custom_file_path', expandedPath);

          setState(() {
            _customFilePath = expandedPath;
          });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'File location saved: $expandedPath/dailychamp/daily.md\n'
                  'Please restart the app to apply changes.',
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to set file location: $e')),
          );
        }
      }
    }
  }
}
