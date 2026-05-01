import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/app_mobile.dart';
import 'package:maki_mobile_pos/app_web.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // Route Firebase init through FirebaseService so the singleton's
  // _isInitialized flag flips. firestoreProvider / firebaseAuthProvider
  // (used by suppliers, petty cash, expenses) read through this getter
  // and throw "FirebaseService is not initialized" when the flag is unset
  // — which is what happened when init was done via Firebase.initializeApp
  // directly. As a bonus this also configures Firestore offline persistence
  // and Auth LOCAL persistence in one place.
  Object? initError;
  try {
    await FirebaseService.instance.initialize();
  } catch (e, st) {
    initError = e;
    debugPrint('Firebase init failed: $e\n$st');
  }

  runApp(
    ProviderScope(
      child: initError != null
          ? _StartupErrorApp(error: initError)
          : (kIsWeb ? const MAKIPOSWebApp() : const MAKIPOSMobileApp()),
    ),
  );
}

/// Last-resort UI shown when Firebase initialisation fails. Without this
/// the app would keep rendering past a broken backend, then surface
/// confusing errors deep inside individual screens.
class _StartupErrorApp extends StatelessWidget {
  final Object error;
  const _StartupErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Could not connect to backend',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
