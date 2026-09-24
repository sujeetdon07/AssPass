import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/storage/local_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file.
  await dotenv.load(fileName: '.env');

  // Initialize SharedPreferences once at startup so it can be
  // injected synchronously into providers via ProviderScope override.
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // Override sharedPreferencesProvider with the real instance.
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const AaspaasApp(),
    ),
  );
}

/// The root application widget.
class AaspaasApp extends ConsumerWidget {
  const AaspaasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Aaspaas',
      debugShowCheckedModeBanner: AppConfig.isDevelopment,
      routerConfig: router,

      // Internationalization ready for future translation modules
      supportedLocales: const [
        Locale('en'), // English
        Locale('hi'), // Hindi
      ],

      // Centralized Aaspaas Material 3 Design System
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
    );
  }
}
