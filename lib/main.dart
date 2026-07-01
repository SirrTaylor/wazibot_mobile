/// lib/main.dart
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/cache/cache_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/security/security_service.dart';
import 'core/sync/sync_engine.dart';
import 'features/settings/presentation/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final prefs = await SharedPreferences.getInstance();

  // Firebase — uncomment after adding google-services.json (see FIREBASE_SETUP.md)
  // if (!kIsWeb) {
  //   await Firebase.initializeApp(
  //     options: DefaultFirebaseOptions.currentPlatform,
  //   );
  // }

  runApp(ProviderScope(
    overrides: [
      cacheServiceProvider.overrideWithValue(CacheService(prefs)),
      sharedPrefsForSyncProvider.overrideWithValue(prefs),
    ],
    child: const WaziBotApp(),
  ));
}

class WaziBotApp extends ConsumerStatefulWidget {
  const WaziBotApp({super.key});

  @override
  ConsumerState<WaziBotApp> createState() => _WaziBotAppState();
}

class _WaziBotAppState extends ConsumerState<WaziBotApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb) {
        final router = ref.read(routerProvider);
        NotificationService.init(router);
      }
      ref.read(securityProvider);
      // Start background sync engine
      ref.read(syncProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final security = ref.watch(securityProvider);

    return MaterialApp.router(
      title: 'WaziBot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (security.isLocked) return const BiometricLockScreen();
        return ActivityTracker(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
