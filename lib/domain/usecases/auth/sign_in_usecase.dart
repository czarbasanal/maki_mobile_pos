import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/auth_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Signs in with email + password and emits a login activity log entry on
/// success. No `assertPermission` — anyone can attempt to authenticate; the
/// repo rejects bad credentials and the firestore.rules layer enforces what
/// the resulting session can do.
class SignInUseCase {
  final AuthRepository _repository;
  final ActivityLogger _logger;

  SignInUseCase({
    required AuthRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<UserEntity>> execute({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _logger.logLogin(user: user);
      return UseCaseResult.successData(user);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Sign-in failed: $e');
    }
  }
}
