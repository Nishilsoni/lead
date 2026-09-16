import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'core/navigation/app_navigator.dart';
import 'providers/auth_provider.dart';
import 'providers/lead_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/role_provider.dart';
import 'providers/user_admin_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'core/config/environment_service.dart';
import 'core/config/firebase_env_options.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  // Load persisted environment before anything else touches the network
  await EnvironmentService.instance.load();
  // Initialize Firebase for the currently-selected environment (test/prod).
  // Wrapped so a missing/failed config never blocks app startup — push just
  // stays off until it's sorted (e.g. iOS, which isn't wired for multi-env).
  try {
    await initFirebaseForEnvironment(EnvironmentService.instance.current);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    if (kDebugMode) debugPrint('[Firebase] init failed, push disabled: $e');
  }
  await NotificationService.initialize();
  runApp(const OceanCRMApp());
  // Do not block the first frame on the native iOS permission sheet.
  unawaited(NotificationService.requestPermissions());
  // Check whether this launch was a tap on a killed-app notification, so the
  // target lead id is queued in AppNavigator as soon as possible. Fire-and-
  // forget, not awaited before runApp(): AppNavigator already queues/retries
  // if its navigator isn't attached yet (see _pendingLeadId), so this never
  // needed to block startup — and awaiting it here previously could hang the
  // whole app on a white screen if this native call stalls (e.g. iOS still
  // bundles a stale/invalid Firebase project's GoogleService-Info.plist).
  unawaited(PushNotificationService.instance.consumeInitialMessage());
}

class OceanCRMApp extends StatelessWidget {
  const OceanCRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // lazy: false — SplashScreen doesn't read AuthProvider, so the
        // default lazy creation wouldn't run checkAuthStatus() (token
        // re-registration, etc.) until AuthGate's first build, ~2s later
        // behind the splash timer. Forcing it eager starts that work at
        // actual app launch instead.
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => AuthProvider()..checkAuthStatus(),
        ),
        ChangeNotifierProvider(create: (_) => LeadProvider()),
        ChangeNotifierProvider(create: (_) => TagProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => UserAdminProvider()),
      ],
      child: MaterialApp(
        title: 'OceanCRM Leads',
        debugShowCheckedModeBanner: false,
        navigatorKey: AppNavigator.key,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
