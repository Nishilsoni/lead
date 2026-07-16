import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/lead_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'core/config/environment_service.dart';
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
  // Never let a missing platform config (e.g. iOS's GoogleService-Info.plist,
  // added later) block app startup — push notifications just stay off for
  // that platform until its config file is added.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    if (kDebugMode) debugPrint('[Firebase] init failed, push disabled: $e');
  }
  await NotificationService.initialize();
  await NotificationService.requestPermissions();
  runApp(const OceanCRMApp());
}

class OceanCRMApp extends StatelessWidget {
  const OceanCRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthStatus()),
        ChangeNotifierProvider(create: (_) => LeadProvider()),
        ChangeNotifierProvider(create: (_) => TagProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'OceanCRM Leads',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
