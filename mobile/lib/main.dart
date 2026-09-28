import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/routing/app_router.dart';
import 'core/storage/local_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/application/auth_state.dart';
import 'features/notifications/data/datasources/push_notification_service.dart';

/// Top-level background message handler.
/// MUST be a top-level function (not a method) and must be annotated as
/// @pragma('vm:entry-point') so it survives tree-shaking in release builds.
/// Keep background work minimal — no UI, no provider access.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Ensure Firebase is initialized in the background isolate.
  await Firebase.initializeApp();
  // The notification display is handled automatically by the FCM SDK.
  // Nothing further is needed here — PostgreSQL remains the source of truth.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase before anything else.
  await Firebase.initializeApp();

  // Register the top-level background/terminated message handler.
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

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
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next is AuthAuthenticated) {
        ref.read(pushNotificationServiceProvider).initialize();
      } else if (next is AuthUnauthenticated) {
        ref.read(pushNotificationServiceProvider).unregisterOnLogout();
      }
    });

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Attach the router to the push service so notification taps can navigate.
    ref.read(pushNotificationServiceProvider).attachRouter(router);

    return MaterialApp.router(
      title: 'Aaspaas',
      debugShowCheckedModeBanner: false,
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
