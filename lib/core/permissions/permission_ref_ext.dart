import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';

/// Imperative permission checks from inside callbacks and builders.
///
/// Prefer [PermissionGate] for declarative widget visibility; use these
/// extensions when branching inside `onPressed`, `itemBuilder`, etc.
extension PermissionRefX on WidgetRef {
  UserEntity? get currentUser => watch(currentUserProvider).valueOrNull;

  UserRole? get currentRole => currentUser?.role;

  bool hasPermission(Permission permission) =>
      currentUser?.hasPermission(permission) ?? false;

  bool hasAnyOf(List<Permission> permissions) {
    final user = currentUser;
    if (user == null) return false;
    return permissions.any(user.hasPermission);
  }

  bool hasAllOf(List<Permission> permissions) {
    final user = currentUser;
    if (user == null || permissions.isEmpty) return false;
    return permissions.every(user.hasPermission);
  }
}

/// Same checks for [Ref] (used inside Riverpod providers, not widgets).
extension PermissionProviderRefX on Ref {
  UserEntity? get currentUser => watch(currentUserProvider).valueOrNull;

  bool hasPermission(Permission permission) =>
      currentUser?.hasPermission(permission) ?? false;
}
