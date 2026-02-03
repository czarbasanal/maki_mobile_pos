import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:maki_mobile_pos/firebase_options.dart';

/// Service class for Firebase initialization and configuration.
///
/// This class handles:
/// - Firebase app initialization
/// - Firestore settings configuration
/// - Auth persistence settings
/// - Emulator connections for development
class FirebaseService {
  static FirebaseService? _instance;

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  bool _isInitialized = false;

  // Private constructor for singleton
  FirebaseService._();

  /// Gets the singleton instance of FirebaseService.
  static FirebaseService get instance {
    _instance ??= FirebaseService._();
    return _instance!;
  }

  /// Returns true if Firebase has been initialized.
  bool get isInitialized => _isInitialized;

  /// Gets the FirebaseAuth instance.
  /// Throws if Firebase is not initialized.
  FirebaseAuth get auth {
    _ensureInitialized();
    return _auth!;
  }

  /// Gets the FirebaseFirestore instance.
  /// Throws if Firebase is not initialized.
  FirebaseFirestore get firestore {
    _ensureInitialized();
    return _firestore!;
  }

  /// Initializes Firebase with the default options.
  ///
  /// This should be called once at app startup, typically in main().
  ///
  /// Parameters:
  /// - [useEmulator]: If true, connects to local Firebase emulators (for development)
  /// - [emulatorHost]: Host address for emulators (default: 'localhost')
  ///
  /// Example:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await FirebaseService.instance.initialize();
  ///   runApp(const MyApp());
  /// }
  /// ```
  Future<void> initialize({
    bool useEmulator = false,
    String emulatorHost = 'localhost',
  }) async {
    if (_isInitialized) {
      debugPrint('FirebaseService: Already initialized');
      return;
    }

    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Get instances
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      // Configure Firestore settings
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Configure Auth persistence
      await _auth!.setPersistence(Persistence.LOCAL);

      // Connect to emulators in development
      if (useEmulator) {
        await _connectToEmulators(emulatorHost);
      }

      _isInitialized = true;
      debugPrint('FirebaseService: Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('FirebaseService: Initialization failed - $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Connects to Firebase emulators for local development.
  Future<void> _connectToEmulators(String host) async {
    try {
      // Auth emulator (default port: 9099)
      await _auth!.useAuthEmulator(host, 9099);
      debugPrint('FirebaseService: Connected to Auth emulator');

      // Firestore emulator (default port: 8080)
      _firestore!.useFirestoreEmulator(host, 8080);
      debugPrint('FirebaseService: Connected to Firestore emulator');
    } catch (e) {
      debugPrint('FirebaseService: Failed to connect to emulators - $e');
    }
  }

  /// Ensures Firebase is initialized before accessing services.
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'FirebaseService is not initialized. '
        'Call FirebaseService.instance.initialize() first.',
      );
    }
  }

  /// Signs out the current user and clears local data.
  Future<void> signOut() async {
    _ensureInitialized();
    await _auth!.signOut();
    debugPrint('FirebaseService: User signed out');
  }

  /// Gets the currently signed-in user, if any.
  User? get currentUser {
    _ensureInitialized();
    return _auth!.currentUser;
  }

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges {
    _ensureInitialized();
    return _auth!.authStateChanges();
  }

  /// Stream of user changes (includes token refresh).
  Stream<User?> get userChanges {
    _ensureInitialized();
    return _auth!.userChanges();
  }
}
