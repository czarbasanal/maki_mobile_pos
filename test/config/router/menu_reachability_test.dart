// Guards the gap that left supplier management unreachable for months:
// RouteGuards.getMenuItems listed /suppliers for admins, the route existed and
// was correctly permission-gated, tests passed — and no screen ever navigated
// there, so nobody could open it.
//
// Permission to reach a destination is not the same as having a way in. This
// test reads the real source and fails when the menu claims a destination that
// no screen navigates to.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';

/// `RoutePaths` constant name -> its literal path, read from route_names.dart.
Map<String, String> _pathByConstant() {
  final src = File('lib/config/router/route_names.dart').readAsStringSync();
  final re = RegExp(r"static const String (\w+)\s*=\s*'([^']+)'");
  return {
    for (final m in re.allMatches(src)) m.group(1)!: m.group(2)!,
  };
}

/// Every `RoutePaths.x` a presentation-layer screen navigates to, mapped to
/// the files doing the navigating.
Map<String, Set<String>> _navigationSites() {
  final found = <String, Set<String>>{};
  final re = RegExp(r'context\.(?:go|push|replace|pushReplacement|goBackOr)\(\s*RoutePaths\.(\w+)');
  for (final entity in Directory('lib/presentation').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    for (final m in re.allMatches(entity.readAsStringSync())) {
      found.putIfAbsent(m.group(1)!, () => <String>{}).add(entity.path);
    }
  }
  return found;
}

/// Whether `file` lives inside the feature that owns `path`.
///
/// A feature returning to its own root — a supplier form popping back to the
/// supplier list — is not a way IN. Counting it lets a feature vouch for its
/// own reachability, which is how the original bug hid: the supplier form
/// navigated to /suppliers, so a naive scan saw the destination as reached
/// while no other screen offered any route to it.
bool _isInsideOwnFeature(String file, String path) {
  final slug = path.split('/').where((s) => s.isNotEmpty).first.replaceAll('-', '_');
  final dir = file.replaceAll(r'\', '/');
  return dir.contains('/$slug/');
}

void main() {
  test('the source scanners find something (guards against a silent no-op)', () {
    // A typo in either regex would make the reachability test vacuously pass,
    // so assert both actually see the codebase before trusting them.
    expect(_pathByConstant(), isNotEmpty);
    expect(_navigationSites().length, greaterThan(5));
  });

  test('every menu destination has a screen that navigates to it', () {
    final pathByConstant = _pathByConstant();
    final constantByPath = {
      for (final e in pathByConstant.entries) e.value: e.key,
    };
    final sites = _navigationSites();

    final unreachable = <String>[];
    for (final role in UserRole.values) {
      for (final item in RouteGuards.getMenuItems(role)) {
        final constant = constantByPath[item.path];
        expect(
          constant,
          isNotNull,
          reason: 'Menu destination ${item.path} is not a RoutePaths constant',
        );
        // Only navigation from OUTSIDE the destination's own feature counts.
        final entryPoints = (sites[constant] ?? const <String>{})
            .where((f) => !_isInsideOwnFeature(f, item.path));
        if (entryPoints.isEmpty) {
          unreachable.add(
            '${item.title} (${item.path}) — listed for $role, but no screen '
            'outside its own feature navigates to RoutePaths.$constant',
          );
        }
      }
    }

    expect(
      unreachable,
      isEmpty,
      reason: 'These destinations are in the menu but have no way in:\n'
          '${unreachable.join('\n')}',
    );
  });
}
