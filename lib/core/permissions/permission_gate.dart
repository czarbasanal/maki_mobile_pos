import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';

enum _GateMode { single, any, all }

/// Declarative permission-based visibility for widgets.
///
/// Renders [child] only when the current user holds the required permission(s).
/// Otherwise renders [fallback] (defaults to an empty box).
///
/// Set [disable] to true to render the child wrapped in [IgnorePointer] with
/// reduced opacity instead of replacing it with the fallback. Use this when
/// the control should remain visible but unusable (e.g. greyed-out buttons).
class PermissionGate extends ConsumerWidget {
  final Permission? _single;
  final List<Permission> _many;
  final _GateMode _mode;
  final Widget child;
  final Widget? fallback;
  final bool disable;

  const PermissionGate({
    super.key,
    required Permission permission,
    required this.child,
    this.fallback,
    this.disable = false,
  })  : _single = permission,
        _many = const [],
        _mode = _GateMode.single;

  const PermissionGate.any({
    super.key,
    required List<Permission> permissions,
    required this.child,
    this.fallback,
    this.disable = false,
  })  : _single = null,
        _many = permissions,
        _mode = _GateMode.any;

  const PermissionGate.all({
    super.key,
    required List<Permission> permissions,
    required this.child,
    this.fallback,
    this.disable = false,
  })  : _single = null,
        _many = permissions,
        _mode = _GateMode.all;

  bool _isAllowed(UserEntity? user) {
    if (user == null) return false;
    switch (_mode) {
      case _GateMode.single:
        return user.hasPermission(_single!);
      case _GateMode.any:
        return _many.any(user.hasPermission);
      case _GateMode.all:
        return _many.isNotEmpty && _many.every(user.hasPermission);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (_isAllowed(user)) return child;
    if (disable) {
      return IgnorePointer(
        ignoring: true,
        child: Opacity(opacity: 0.4, child: child),
      );
    }
    return fallback ?? const SizedBox.shrink();
  }
}
