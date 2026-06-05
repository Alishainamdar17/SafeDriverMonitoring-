// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:safe_drive_monitor/config/app_config.dart';
import 'package:safe_drive_monitor/services/background_service.dart';
import 'package:safe_drive_monitor/services/live_drive_state.dart';
import 'package:safe_drive_monitor/pages/dashboard_page.dart';
import 'package:safe_drive_monitor/pages/login_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. App config
  await dotenv.load();
  await AppConfig.init();
  await AppConfig.loadSettings();

  // 3. Background service
  BackgroundService.startService();

  // 4. Load drive history whenever user logs in
  //    This runs once at startup (if already logged in) and again after login.
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      debugPrint('👤 User logged in: ${user.uid} — loading drive history...');
      LiveDriveState.instance.loadHistory();
    }
  });

  // 5. Silence non-SDM logs in release
  if (!kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Drive Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00D4FF),
        scaffoldBackgroundColor: const Color(0xFF050508),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF050508),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D4FF),
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0C0C14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF00D4FF), width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.grey),
          hintStyle: const TextStyle(color: Colors.grey),
        ),
        useMaterial3: true,
      ),

      // StreamBuilder listens to Firebase auth — auto-switches between
      // LoginPage and DashboardPage without any manual state management.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Still connecting to Firebase
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF050508),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00D4FF),
                ),
              ),
            );
          }

          // Logged in → Dashboard
          if (snapshot.hasData && snapshot.data != null) {
            return const DashboardPage();
          }

          // Not logged in → Login
          return const LoginPage();
        },
      ),
    );
  }
}