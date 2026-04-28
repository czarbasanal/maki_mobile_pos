import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/auth_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Verifies the current user's password (e.g. before a destructive action
/// like void-sale or cost-code edit) and logs both success and failure so
/// repeated failed attempts surface in /logs.
class VerifyPasswordUseCase {
  final AuthRepository _repository;
  final ActivityLogger _logger;

  VerifyPasswordUseCase({
    required AuthRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<bool>> execute({
    required UserEntity actor,
    required String password,
    String purpose = 'sensitive action',
  }) async {
    try {
      final ok = await _repository.verifyPassword(password);
      if (ok) {
        await _logger.logPasswordVerified(user: actor, purpose: purpose);
      } else {
        await _logger.logPasswordFailed(user: actor, purpose: purpose);
      }
      return UseCaseResult.successData(ok);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Password verification failed: $e');
    }
  }
}
