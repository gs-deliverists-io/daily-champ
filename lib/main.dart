import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/dailychamp_provider.dart';
import 'providers/theme_provider.dart';
import 'services/file_service.dart';
import 'services/template_service.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load custom file path from settings (macOS only)
  String? customPath;
  if (!kIsWeb && Platform.isMacOS) {
    final prefs = await SharedPreferences.getInstance();
    customPath = prefs.getString('custom_file_path');

    // If no custom path set, use default Nextcloud path
    if (customPath == null || customPath.isEmpty) {
      customPath = '/Users/gs/Nextcloud/Notes';
    }

    // Initialize template service
    final templateService = TemplateService(
      customBasePath: customPath,
    );
    await templateService.createDefaultTemplateFiles();
  }

  runApp(DailyChampApp(customPath: customPath));
}

class DailyChampApp extends StatelessWidget {
  final String? customPath;

  const DailyChampApp({super.key, this.customPath});

  @override
  Widget build(BuildContext context) {
    // Use provided customPath (already loaded from settings in main())
    // On iOS/Android: customPath remains null, FileService will use
    // getApplicationDocumentsDirectory() and sync via Nextcloud WebDAV

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DailyChampProvider(
            fileService: FileService(customPath: customPath),
          )..loadEntries(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'DailyChamp',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/home': (context) => const HomeScreen(),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
