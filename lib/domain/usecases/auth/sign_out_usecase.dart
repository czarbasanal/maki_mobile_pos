import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/auth_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Signs the actor out, logging the event before the session is dropped.
///
/// `actor` is optional — sign-out can be triggered when the auth stream is
/// already unsettled and `currentUserProvider` returns null. In that case
/// the activity log is skipped (there's no actor to attribute it to) but
/// the repo call still runs.
class SignOutUseCase {
  final AuthRepository _repository;
  final ActivityLogger _logger;

  SignOutUseCase({
    required AuthRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<void>> execute({UserEntity? actor}) async {
    try {
      if (actor != null) {
        await _logger.logLogout(user: actor);
      }
      await _repository.signOut();
      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Sign-out failed: $e');
    }
  }
}
