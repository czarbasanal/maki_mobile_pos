import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/draft_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/supplier_provider.dart';

/// Clears all user-scoped session state when the signed-in user transitions
/// to null (any sign-out path: manual, token expiry, forced). Activate with
/// `ref.watch(sessionResetProvider)` at the app root so the listener lives for
/// the app's lifetime.
final sessionResetProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<UserEntity?>>(currentUserProvider, (prev, next) {
    final wasSignedIn = prev?.valueOrNull != null;
    final nowSignedOut = next.valueOrNull == null && !next.isLoading;
    if (wasSignedIn && nowSignedOut) {
      ref.read(cartProvider.notifier).reset();
      ref.invalidate(allSuppliersProvider);
      ref.invalidate(securityLogsProvider);
      ref.invalidate(userActivityLogsProvider);
      ref.invalidate(entityLogsProvider);
      ref.read(selectedDraftProvider.notifier).state = null;
    }
  });
});
