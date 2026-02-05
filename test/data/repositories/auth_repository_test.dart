import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

// Mock implementation for testing
class MockAuthRepository implements AuthRepository {
  UserEntity? _currentUser;
  bool _shouldFail = false;
  String _failureMessage = '';

  void setMockUser(UserEntity? user) {
    _currentUser = user;
  }

  void setShouldFail(bool shouldFail, [String message = 'Mock error']) {
    _shouldFail = shouldFail;
    _failureMessage = message;
  }

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (_shouldFail) {
      throw Exception(_failureMessage);
    }

    _currentUser = UserEntity(
      id: 'test-uid',
      email: email,
      displayName: 'Test User',
      role: UserRole.cashier,
      isActive: true,
      createdAt: DateTime.now(),
    );

    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    if (_shouldFail) {
      throw Exception(_failureMessage);
    }
    _currentUser = null;
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Stream<UserEntity?> get authStateChanges => Stream.value(_currentUser);

  @override
  Future<bool> verifyPassword(String password) async {
    if (_shouldFail) {
      return false;
    }
    return password == 'correct_password';
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (_shouldFail) {
      throw Exception(_failureMessage);
    }
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_shouldFail) {
      throw Exception(_failureMessage);
    }
  }

  @override
  bool get isSignedIn => _currentUser != null;

  @override
  String? get currentUserId => _currentUser?.id;
}

void main() {
  group('AuthRepository', () {
    late MockAuthRepository authRepository;

    setUp(() {
      authRepository = MockAuthRepository();
    });

    group('signInWithEmailAndPassword', () {
      test('should return user on successful sign in', () async {
        final user = await authRepository.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(user, isA<UserEntity>());
        expect(user.email, 'test@example.com');
        expect(user.isActive, true);
      });

      test('should throw exception on failed sign in', () async {
        authRepository.setShouldFail(true, 'Invalid credentials');

        expect(
          () => authRepository.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'wrong_password',
          ),
          throwsException,
        );
      });
    });

    group('signOut', () {
      test('should clear current user on sign out', () async {
        // Sign in first
        await authRepository.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(authRepository.isSignedIn, true);

        // Sign out
        await authRepository.signOut();

        expect(authRepository.isSignedIn, false);
        expect(authRepository.currentUserId, isNull);
      });
    });

    group('getCurrentUser', () {
      test('should return null when not signed in', () async {
        final user = await authRepository.getCurrentUser();
        expect(user, isNull);
      });

      test('should return user when signed in', () async {
        await authRepository.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        final user = await authRepository.getCurrentUser();

        expect(user, isNotNull);
        expect(user!.email, 'test@example.com');
      });
    });

    group('verifyPassword', () {
      test('should return true for correct password', () async {
        final result = await authRepository.verifyPassword('correct_password');
        expect(result, true);
      });

      test('should return false for incorrect password', () async {
        final result = await authRepository.verifyPassword('wrong_password');
        expect(result, false);
      });
    });

    group('isSignedIn', () {
      test('should return false when not signed in', () {
        expect(authRepository.isSignedIn, false);
      });

      test('should return true when signed in', () async {
        await authRepository.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(authRepository.isSignedIn, true);
      });
    });

    group('currentUserId', () {
      test('should return null when not signed in', () {
        expect(authRepository.currentUserId, isNull);
      });

      test('should return user ID when signed in', () async {
        await authRepository.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(authRepository.currentUserId, 'test-uid');
      });
    });
  });
}
