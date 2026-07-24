# Shared-List Permissions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let cashiers add/edit — and staff fully manage — the shared lists (product/expense categories, units, void reasons, mechanics, motorcycle models), with an inline "Add mechanic…" in the POS picker, enforced both in-app and in firestore.rules.

**Architecture:** A new `Permission.editLists` (all roles) becomes the entry bar for the four settings routes; the existing `Permission.manageCategories` becomes the "full manage" tier (staff + admin) that gates deactivate/reactivate affordances. `SettingsCrudRow` gets a nullable toggle callback; the three editors and their dialogs read `currentUserProvider` to decide. firestore.rules mirror the split: create/update open to active users, updates touching `isActive` require staff/admin, delete stays admin-only.

**Tech Stack:** Flutter + Riverpod, firestore.rules, `@firebase/rules-unit-testing` emulator suite (Mocha).

**Spec:** `docs/superpowers/specs/2026-07-24-shared-list-permissions-design.md`

## Global Constraints

- Branch: `feat/shared-list-permissions` (already created; spec committed on it).
- Permission matrix: cashier = add + edit only; staff = full manage incl. deactivate/reactivate; admin unchanged. Applies to ALL list kinds: product categories, expense categories, units, void reasons, mechanics, motorcycle models.
- No hard-delete paths added anywhere; "delete" in-app remains the deactivate toggle.
- Web admin (`web_admin/`) untouched.
- **firestore.rules are edited and tested in this plan but NOT deployed** — deploy is a separate, user-confirmed step after merge.
- Flutter checks: `flutter test <file>` per task, full `flutter test` + `flutter analyze` in the final task. Rules suite: `cd tools/firestore-rules-test && npm test`.
- Tests mirror `lib/` structure under `test/`.

---

### Task 1: Permission model — `editLists` + staff `manageCategories`

**Files:**
- Modify: `lib/core/constants/role_permissions.dart`
- Test: `test/core/constants/role_permissions_test.dart`

**Interfaces:**
- Consumes: existing `Permission` enum, `RolePermissions` sets.
- Produces (used by Tasks 2–4): `Permission.editLists` — held by cashier, staff, admin. `Permission.manageCategories` — held by staff and admin (cashier does NOT hold it).

- [ ] **Step 1: Write the failing tests**

Append a new group at the end of `main()` in `test/core/constants/role_permissions_test.dart`:

```dart
  group('RolePermissions — shared lists (editLists / manageCategories)', () {
    test('all roles hold editLists', () {
      for (final role in UserRole.values) {
        expect(
          RolePermissions.hasPermission(role, Permission.editLists),
          isTrue,
          reason: '$role should hold editLists',
        );
      }
    });

    test('staff and admin hold manageCategories; cashier does not', () {
      expect(
        RolePermissions.hasPermission(
            UserRole.cashier, Permission.manageCategories),
        isFalse,
      );
      expect(
        RolePermissions.hasPermission(
            UserRole.staff, Permission.manageCategories),
        isTrue,
      );
      expect(
        RolePermissions.hasPermission(
            UserRole.admin, Permission.manageCategories),
        isTrue,
      );
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/role_permissions_test.dart`
Expected: COMPILE ERROR — `Permission.editLists` is not defined.

- [ ] **Step 3: Implement in `lib/core/constants/role_permissions.dart`**

(a) In the `Permission` enum's Settings section, replace:

```dart
  manageCategories, // Manage product/expense category lists
```

with:

```dart
  manageCategories, // Full shared-list manage incl. deactivate/reactivate (staff + admin)
  editLists, // Add/edit shared list entries — categories, units, void reasons, mechanics, motorcycle models (all roles)
```

(b) In `_cashierPermissions`, after `Permission.editOwnProfile,` add:

```dart
    // Shared lists (2026-07-24): cashiers add and edit entries; deactivate /
    // reactivate stays staff+admin (manageCategories).
    Permission.editLists,
```

(c) In `_staffPermissions`, after `Permission.editOwnProfile,` add:

```dart
    // Shared lists (2026-07-24): staff fully manage incl. deactivate.
    Permission.editLists,
    Permission.manageCategories,
```

(d) In `_adminPermissions`, immediately after `Permission.manageCategories,` add:

```dart
    Permission.editLists,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/constants/role_permissions_test.dart`
Expected: ALL PASS (existing groups + new one).

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/role_permissions.dart test/core/constants/role_permissions_test.dart
git commit -m "feat(mobile): Permission.editLists for all roles; staff gains manageCategories"
```

---

### Task 2: Route guards — shared-list routes open at `editLists`

**Files:**
- Modify: `lib/config/router/route_guards.dart`
- Modify: `test/config/router/route_guards_mechanics_test.dart`
- Modify: `test/config/router/route_guards_motorcycle_models_test.dart`
- Create: `test/config/router/route_guards_shared_lists_test.dart`

**Interfaces:**
- Consumes: `Permission.editLists` from Task 1.
- Produces: `/settings/categories`, `/settings/categories/<kind>`, `/settings/mechanics`, `/settings/motorcycle-models` all pass `RouteGuards.canAccess` for any active user (any role).

- [ ] **Step 1: Write the failing tests**

(a) In `test/config/router/route_guards_mechanics_test.dart`, replace the `'cashier cannot access mechanics editor'` test with:

```dart
    test('cashier and staff can access mechanics editor (editLists)', () {
      expect(
        RouteGuards.canAccess(RoutePaths.mechanics, user(UserRole.cashier)),
        true,
      );
      expect(
        RouteGuards.canAccess(RoutePaths.mechanics, user(UserRole.staff)),
        true,
      );
    });
```

(b) In `test/config/router/route_guards_motorcycle_models_test.dart`, make the same replacement for its cashier-cannot test, using `RoutePaths.motorcycleModels`:

```dart
    test('cashier and staff can access models editor (editLists)', () {
      expect(
        RouteGuards.canAccess(
            RoutePaths.motorcycleModels, user(UserRole.cashier)),
        true,
      );
      expect(
        RouteGuards.canAccess(
            RoutePaths.motorcycleModels, user(UserRole.staff)),
        true,
      );
    });
```

(c) Create `test/config/router/route_guards_shared_lists_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  UserEntity user(UserRole role, {bool isActive = true}) => UserEntity(
        id: 'u1',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: isActive,
        createdAt: DateTime(2026, 7, 24),
      );

  group('RouteGuards — shared-list routes open to every active role', () {
    for (final role in UserRole.values) {
      test('$role can access the categories hub and a per-kind editor', () {
        expect(
          RouteGuards.canAccess(RoutePaths.categorySettings, user(role)),
          true,
        );
        expect(
          RouteGuards.canAccess(
              '${RoutePaths.categorySettings}/unit', user(role)),
          true,
        );
      });
    }

    test('inactive user is denied', () {
      expect(
        RouteGuards.canAccess(
            RoutePaths.categorySettings, user(UserRole.staff, isActive: false)),
        false,
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/config/router/`
Expected: FAIL — cashier/staff access assertions are false (routes still demand `manageCategories`).

- [ ] **Step 3: Implement in `lib/config/router/route_guards.dart`**

(a) In `protectedRoutes`, replace:

```dart
    '/settings/categories': Permission.manageCategories,
    '/settings/mechanics': Permission.manageCategories,
    '/settings/motorcycle-models': Permission.manageCategories,
```

with:

```dart
    '/settings/categories': Permission.editLists,
    '/settings/mechanics': Permission.editLists,
    '/settings/motorcycle-models': Permission.editLists,
```

(b) In `_checkDynamicRoute`, replace:

```dart
    if (path.startsWith('${RoutePaths.categorySettings}/')) {
      return user.hasPermission(Permission.manageCategories);
    }
```

with:

```dart
    if (path.startsWith('${RoutePaths.categorySettings}/')) {
      return user.hasPermission(Permission.editLists);
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/config/router/`
Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/config/router/route_guards.dart test/config/router/
git commit -m "feat(mobile): shared-list settings routes open at editLists"
```

---

### Task 3: Settings screen — Lists section for all roles

**Files:**
- Modify: `lib/presentation/mobile/screens/settings/settings_screen.dart`
- Create: `test/presentation/widgets/settings_lists_section_test.dart`

**Interfaces:**
- Consumes: `Permission.editLists`; `UserEntity.hasPermission`.
- Produces: the Manage Lists / Mechanics / Motorcycle Models tiles render for any user with `editLists` under a new "Lists" section; the Administration section keeps only User Management, Activity Logs, Cost Code Settings.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/widgets/settings_lists_section_test.dart` (harness mirrors `settings_mechanics_tile_test.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/theme_mode_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/settings_screen.dart';

UserEntity _user(UserRole role) => UserEntity(
      id: 'u1',
      email: 'u@x.com',
      displayName: 'U',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 7, 24),
    );

Widget _harness(UserRole role) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
        themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );

void main() {
  testWidgets('cashier sees the three list tiles but no admin tiles',
      (tester) async {
    await tester.pumpWidget(_harness(UserRole.cashier));
    await tester.pumpAndSettle();

    expect(find.text('Manage Lists'), findsOneWidget);
    expect(find.text('Mechanics'), findsOneWidget);
    expect(find.text('Motorcycle Models'), findsOneWidget);
    expect(find.text('User Management'), findsNothing);
    expect(find.text('Cost Code Settings'), findsNothing);
  });

  testWidgets('admin keeps admin tiles and also sees the list tiles',
      (tester) async {
    await tester.pumpWidget(_harness(UserRole.admin));
    await tester.pumpAndSettle();

    expect(find.text('User Management'), findsOneWidget);
    expect(find.text('Manage Lists'), findsOneWidget);
    expect(find.text('Mechanics'), findsOneWidget);
    expect(find.text('Motorcycle Models'), findsOneWidget);
  });
}
```

NOTE: the tiles may render below the fold in the 800×600 test viewport; `find.text` still finds them because `ListView` in a `pumpWidget` harness builds lazily — if `findsNothing` fires spuriously for the admin test, add `await tester.scrollUntilVisible(find.text('Motorcycle Models'), 200);` before the assertions and keep the assertions unchanged.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/widgets/settings_lists_section_test.dart`
Expected: FAIL — cashier test finds no 'Manage Lists' tile.

- [ ] **Step 3: Implement in `settings_screen.dart`**

(a) Add import (with the other package imports):

```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
```

(b) In `build`, after `final isAdmin = ...`, add:

```dart
    final canEditLists =
        currentUser?.hasPermission(Permission.editLists) ?? false;
```

(c) Replace the entire `if (isAdmin) ...[ ... ]` Administration block with two blocks — Administration keeps the first three tiles; a new Lists section holds the three list tiles:

```dart
          if (isAdmin) ...[
            const _SectionHeader('Administration'),
            _SectionCard(
              children: [
                SettingsTile(
                  icon: LucideIcons.users,
                  title: 'User Management',
                  subtitle: 'Add, edit, and manage users',
                  onTap: () => context.push(RoutePaths.users),
                ),
                SettingsTile(
                  icon: LucideIcons.clock,
                  title: 'Activity Logs',
                  subtitle: 'View user activity and audit trail',
                  onTap: () => context.push(RoutePaths.userLogs),
                ),
                SettingsTile(
                  icon: LucideIcons.code,
                  title: 'Cost Code Settings',
                  subtitle: 'Configure cost encoding',
                  onTap: () => context.push(RoutePaths.costCodeSettings),
                ),
              ],
            ),
          ],
          if (canEditLists) ...[
            const _SectionHeader('Lists'),
            _SectionCard(
              children: [
                SettingsTile(
                  icon: LucideIcons.tag,
                  title: 'Manage Lists',
                  subtitle: 'Product / expense categories and units',
                  onTap: () => context.push(RoutePaths.categorySettings),
                ),
                SettingsTile(
                  icon: LucideIcons.wrench,
                  title: 'Mechanics',
                  subtitle: 'Assign a mechanic to a service draft',
                  onTap: () => context.push(RoutePaths.mechanics),
                ),
                SettingsTile(
                  icon: LucideIcons.bike,
                  title: 'Motorcycle Models',
                  subtitle: 'Models picked on job orders',
                  onTap: () => context.push(RoutePaths.motorcycleModels),
                ),
              ],
            ),
          ],
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/widgets/settings_lists_section_test.dart test/presentation/widgets/settings_mechanics_tile_test.dart test/presentation/widgets/settings_motorcycle_models_tile_test.dart`
Expected: ALL PASS (the two existing tile tests assert admin-visible tiles, which still hold).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/settings/settings_screen.dart test/presentation/widgets/settings_lists_section_test.dart
git commit -m "feat(mobile): Lists settings section visible to every role with editLists"
```

---

### Task 4: Editors — hide deactivate affordances from cashiers

**Files:**
- Modify: `lib/presentation/mobile/widgets/settings/settings_crud_row.dart`
- Modify: `lib/presentation/mobile/screens/settings/mechanic_editor_screen.dart`
- Modify: `lib/presentation/mobile/screens/settings/category_editor_screen.dart`
- Modify: `lib/presentation/mobile/screens/settings/motorcycle_model_editor_screen.dart`
- Modify (harness updates + new tests): `test/presentation/widgets/mechanic_editor_screen_test.dart`, `test/presentation/widgets/category_editor_screen_test.dart`, `test/presentation/widgets/motorcycle_model_editor_screen_test.dart`

**Interfaces:**
- Consumes: `Permission.manageCategories` (staff+admin per Task 1), `currentUserProvider`, `UserEntity.hasPermission`.
- Produces: `SettingsCrudRow.onToggleActive` becomes `VoidCallback?` — null hides the archive/reactivate button. All three editors pass null for users without `manageCategories`; the mechanic and category edit dialogs hide their "Active" `SwitchListTile` for those users (the motorcycle dialog has no switch).

- [ ] **Step 1: Update existing harnesses and write the failing tests**

The three editor test files pump their screens inside a `ProviderScope`. First READ each file. In each harness's `overrides` list, add a `currentUserProvider` override if not already present, parameterized by role (default admin so every existing test keeps its current behavior):

```dart
currentUserProvider.overrideWith((ref) => Stream.value(UserEntity(
      id: 'u1',
      email: 'u@x.com',
      displayName: 'U',
      role: role, // new harness parameter, default UserRole.admin
      isActive: true,
      createdAt: DateTime(2026, 7, 24),
    ))),
```

(Adapt to the harness function's existing shape — add a `UserRole role = UserRole.admin` parameter. Imports needed: `package:maki_mobile_pos/core/enums/enums.dart`, `package:maki_mobile_pos/presentation/providers/auth_provider.dart` if absent.)

Then add one new test to EACH of the three files (adapting the harness call and the seeded list-entry name to that file's existing fixtures):

```dart
  testWidgets('cashier sees edit but no deactivate toggle', (tester) async {
    await tester.pumpWidget(harness(role: UserRole.cashier));
    await tester.pumpAndSettle();

    // Edit affordance still present on every row…
    expect(find.byIcon(LucideIcons.squarePen), findsWidgets);
    // …but the archive (deactivate) affordance is gone.
    expect(find.byIcon(LucideIcons.archive), findsNothing);
    expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
  });
```

And in `mechanic_editor_screen_test.dart` only, add a dialog-switch test (open the edit dialog by tapping a row's name — `AppCard.onTap` is the edit action):

```dart
  testWidgets('cashier edit dialog has no Active switch', (tester) async {
    await tester.pumpWidget(harness(role: UserRole.cashier));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.squarePen).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Mechanic'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
  });
```

(`LucideIcons` import: `package:lucide_icons_flutter/lucide_icons.dart` if absent.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/presentation/widgets/mechanic_editor_screen_test.dart test/presentation/widgets/category_editor_screen_test.dart test/presentation/widgets/motorcycle_model_editor_screen_test.dart`
Expected: the new cashier tests FAIL (archive icon still present); existing tests still pass.

- [ ] **Step 3: Implement**

(a) `settings_crud_row.dart` — make the toggle optional. Change the field and constructor param:

```dart
  const SettingsCrudRow({
    super.key,
    required this.name,
    required this.isActive,
    required this.onEdit,
    this.onToggleActive,
    this.leadingIcon,
  });
```

```dart
  /// Archive/reactivate action; null hides the toggle button entirely
  /// (users without full list-manage permission).
  final VoidCallback? onToggleActive;
```

And in `build`, replace the second `_RowIconButton` with a null-guarded version (use a local for promotion):

```dart
            if (onToggleActive != null)
              _RowIconButton(
                icon: isActive ? LucideIcons.archive : LucideIcons.rotateCcw,
                color: isActive ? muted : reactivate,
                tooltip: isActive ? 'Deactivate' : 'Reactivate',
                onPressed: onToggleActive!,
              ),
```

(b) In each of the three editor screens, add imports (where absent):

```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
```

(Check first: `mechanic_editor_screen.dart` imports neither; the others may differ. `motorcycle_model_editor_screen.dart` imports `providers/motorcycle_model_provider.dart` only; `category_editor_screen.dart` imports `providers/category_provider.dart` only.)

(c) In each editor's `_buildList`, compute the flag and gate the row callback. Mechanic editor:

```dart
  Widget _buildList(BuildContext context, List<MechanicEntity> mechanics) {
    final canManage = ref.watch(currentUserProvider).valueOrNull
            ?.hasPermission(Permission.manageCategories) ??
        false;
```

and change the row to:

```dart
          onToggleActive: canManage ? () => _toggleActive(mechanic) : null,
```

Category editor — same two edits with its own variable (`category`):

```dart
    final canManage = ref.watch(currentUserProvider).valueOrNull
            ?.hasPermission(Permission.manageCategories) ??
        false;
```

```dart
          onToggleActive: canManage ? () => _toggleActive(category) : null,
```

Motorcycle editor — same with `m`:

```dart
          onToggleActive: canManage ? () => _toggleActive(m) : null,
```

(d) Hide the Active switch in the two dialogs that have one. In `_MechanicFormDialogState.build`, at the top of `build` add:

```dart
    final canManage = ref.watch(currentUserProvider).valueOrNull
            ?.hasPermission(Permission.manageCategories) ??
        false;
```

and change `if (_isEdit) ...[` (the `SwitchListTile` block) to `if (_isEdit && canManage) ...[`.

Same change in `_CategoryFormDialogState.build` in `category_editor_screen.dart`. The motorcycle `_ModelFormDialog` has no switch — no dialog change.

Note on the save path: with the switch hidden, `_isActive` keeps the entity's existing value, so a cashier's update never changes `isActive` — which is exactly what the Task 6 rules require.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/widgets/mechanic_editor_screen_test.dart test/presentation/widgets/category_editor_screen_test.dart test/presentation/widgets/motorcycle_model_editor_screen_test.dart`
Expected: ALL PASS (new cashier tests + all pre-existing tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/settings/settings_crud_row.dart lib/presentation/mobile/screens/settings/ test/presentation/widgets/
git commit -m "feat(mobile): deactivate affordances gated by manageCategories in list editors"
```

---

### Task 5: POS mechanic picker — inline "Add mechanic…"

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/mechanic_picker.dart`
- Modify: `test/presentation/widgets/mechanic_picker_test.dart`

**Interfaces:**
- Consumes: `mechanicOperationsProvider` (`MechanicOperationsNotifier.create({required MechanicEntity mechanic}) → Future<MechanicEntity?>`), `activeMechanicsProvider`.
- Produces: `MechanicPicker` keeps its exact public API (`selectedMechanicId`, `onChanged(MechanicEntity?)`, `nonePlaceholder`) but becomes a `ConsumerStatefulWidget` with a `➕ Add mechanic…` menu entry. Reuse rule: a case-insensitive match against the loaded active list selects the existing mechanic without creating.

- [ ] **Step 1: Write the failing tests**

READ `test/presentation/widgets/mechanic_picker_test.dart` first; keep its `host(...)` harness and `_mech` fixture, extending `host` with an optional `List<Override> extraOverrides = const []` appended to the `ProviderScope` overrides. Then add this group (imports to add: `package:maki_mobile_pos/presentation/providers/auth_provider.dart` is NOT needed; add nothing beyond what the fake requires):

```dart
class _FakeMechanicOps extends MechanicOperationsNotifier {
  _FakeMechanicOps(super.ref);

  MechanicEntity? createdWith;

  @override
  Future<MechanicEntity?> create({required MechanicEntity mechanic}) async {
    createdWith = mechanic;
    return MechanicEntity(
      id: 'new-1',
      name: mechanic.name,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );
  }
}
```

```dart
  group('MechanicPicker — inline add', () {
    testWidgets('menu offers Add mechanic…', (tester) async {
      await tester.pumpWidget(host(onChanged: (_) {}));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      expect(find.text('➕ Add mechanic…'), findsWidgets);
    });

    testWidgets('existing name (case-insensitive) is reused, not recreated',
        (tester) async {
      _FakeMechanicOps? fake;
      MechanicEntity? picked;
      await tester.pumpWidget(host(
        onChanged: (m) => picked = m,
        extraOverrides: [
          mechanicOperationsProvider.overrideWith((ref) {
            fake = _FakeMechanicOps(ref);
            return fake!;
          }),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('➕ Add mechanic…').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'juan dela cruz');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(picked?.id, 'm1'); // existing Juan Dela Cruz reused
      expect(fake?.createdWith, isNull); // no create call
    });

    testWidgets('new name is created and selected', (tester) async {
      _FakeMechanicOps? fake;
      MechanicEntity? picked;
      await tester.pumpWidget(host(
        onChanged: (m) => picked = m,
        extraOverrides: [
          mechanicOperationsProvider.overrideWith((ref) {
            fake = _FakeMechanicOps(ref);
            return fake!;
          }),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('➕ Add mechanic…').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Mang Kanor');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(fake?.createdWith?.name, 'Mang Kanor');
      expect(picked?.id, 'new-1');
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/presentation/widgets/mechanic_picker_test.dart`
Expected: FAIL — no `➕ Add mechanic…` entry exists (and `extraOverrides` param must be added to `host` to compile).

- [ ] **Step 3: Rewrite `mechanic_picker.dart`**

Replace the whole file body (keep the doc comment style; the public API is unchanged). Mirror `motorcycle_model_picker.dart`'s sentinel + `_rev` reset pattern:

```dart
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';

/// Pick-or-add mechanic dropdown (canonical "C1" signature).
///
/// Watches [activeMechanicsProvider] and reports the picked mechanic (or null
/// for "— None —") via [onChanged]. "➕ Add mechanic…" creates a mechanic
/// inline (reusing an existing one on a case-insensitive name match) and
/// selects it. The PARENT owns where the selection goes (the cart in POS, a
/// draft working-copy in the draft editor), so the same widget is reused
/// verbatim in both places.
class MechanicPicker extends ConsumerStatefulWidget {
  const MechanicPicker({
    super.key,
    this.selectedMechanicId,
    required this.onChanged,
    this.nonePlaceholder = '— None —',
  });

  /// Currently-assigned mechanic id (null = none).
  final String? selectedMechanicId;

  /// Reports the chosen mechanic; null means the placeholder was picked.
  final void Function(MechanicEntity? mechanic) onChanged;

  /// Label for the no-mechanic option (e.g. "— Optional —" at create).
  final String nonePlaceholder;

  @override
  ConsumerState<MechanicPicker> createState() => _MechanicPickerState();
}

class _MechanicPickerState extends ConsumerState<MechanicPicker> {
  static const _addNew = '__add_mechanic__';

  /// Bumped after the "Add mechanic…" flow so the underlying [AppDropdown]
  /// rebuilds fresh — resetting its display off the sentinel whether or not
  /// a mechanic was actually added (handles cancel).
  int _rev = 0;

  @override
  Widget build(BuildContext context) {
    final mechanicsAsync = ref.watch(activeMechanicsProvider);

    return mechanicsAsync.when(
      data: (mechanics) {
        // If the assigned mechanic was deactivated (no longer in the active
        // list), fall back to no selection so the dropdown value stays valid.
        final hasSelected = widget.selectedMechanicId != null &&
            mechanics.any((m) => m.id == widget.selectedMechanicId);

        return AppDropdown<String>(
          key: ValueKey('$_rev|${widget.selectedMechanicId}'),
          initialValue: hasSelected ? widget.selectedMechanicId : null,
          decoration: const InputDecoration(
            labelText: 'Mechanic',
            prefixIcon: Icon(LucideIcons.wrench),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(widget.nonePlaceholder),
            ),
            for (final m in mechanics)
              DropdownMenuItem<String>(value: m.id, child: Text(m.name)),
            const DropdownMenuItem<String>(
              value: _addNew,
              child: Text('➕ Add mechanic…'),
            ),
          ],
          onChanged: (id) {
            if (id == _addNew) {
              _onAddNew(mechanics);
            } else {
              widget.onChanged(
                id == null ? null : mechanics.firstWhere((m) => m.id == id),
              );
            }
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Failed to load mechanics: $e'),
    );
  }

  Future<void> _onAddNew(List<MechanicEntity> mechanics) async {
    final picked = await _showAddDialog(mechanics);
    if (!mounted) return;
    setState(() => _rev++); // reset the dropdown display off the sentinel
    if (picked != null) widget.onChanged(picked);
  }

  Future<MechanicEntity?> _showAddDialog(List<MechanicEntity> mechanics) {
    final controller = TextEditingController();
    return showDialog<MechanicEntity>(
      context: context,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (ctx) => AppDialog(
        title: 'Add mechanic',
        leadingIcon: LucideIcons.wrench,
        content: TextField(
          style: AppTextStyles.fieldInput,
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(LucideIcons.wrench),
          ),
        ),
        actions: [
          appDialogCancel(ctx, 'Cancel', onTap: () => Navigator.pop(ctx)),
          appDialogPrimary(ctx, 'Add', onTap: () async {
            final name = controller.text.trim();
            if (name.length < 2) return;

            // Reuse an existing active mechanic on a case-insensitive match
            // instead of creating a duplicate.
            final lower = name.toLowerCase();
            for (final m in mechanics) {
              if (m.name.toLowerCase() == lower) {
                Navigator.pop(ctx, m);
                return;
              }
            }

            final created = await ref
                .read(mechanicOperationsProvider.notifier)
                .create(
                  mechanic: MechanicEntity(
                    id: '',
                    name: name,
                    isActive: true,
                    createdAt: DateTime.now(),
                  ),
                );
            if (!ctx.mounted) return;
            Navigator.pop(ctx, created);
            if (created == null && mounted) {
              context.showErrorSnackBar('Failed to add mechanic');
            }
          }),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/widgets/mechanic_picker_test.dart`
Expected: ALL PASS (existing group + new inline-add group).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/pos/mechanic_picker.dart test/presentation/widgets/mechanic_picker_test.dart
git commit -m "feat(mobile): inline pick-or-add mechanic in the POS mechanic dropdown"
```

---

### Task 6: firestore.rules — server-side split + emulator tests

**Files:**
- Modify: `firestore.rules` (the six shared-list collection blocks)
- Modify: `tools/firestore-rules-test/test/rules.test.js` (new describe block at the end, before the final closing braces / after the last existing describe)

**Interfaces:**
- Consumes: existing rules helpers `isAdmin()`, `isStaffOrAdmin()`, `isValidUser()`, `isActiveUser()` (all already defined in `firestore.rules`).
- Produces: for `product_categories`, `expense_categories`, `units`, `void_reasons`, `mechanics` — create/update open to any active valid user, updates touching `isActive` require staff/admin, delete admin-only. `motorcycle_models` — create unchanged (any active user with `createdBy == auth.uid`), update follows the same new pattern, delete admin-only. **NOT deployed in this plan.**

- [ ] **Step 1: Write the failing emulator tests**

READ the tail of `tools/firestore-rules-test/test/rules.test.js` to see where describes end and whether a helper like `db(user)` exists — if one does, use it in place of `testEnv.authenticatedContext(...)` below. Append this describe block after the last existing one:

```js
describe("shared list collections (cashier add/edit, staff full)", () => {
  const LISTS = [
    "product_categories",
    "expense_categories",
    "units",
    "void_reasons",
    "mechanics",
  ];

  const entry = { name: "Test Entry", isActive: true };

  async function seed(coll, id, data) {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().collection(coll).doc(id).set(data)
    );
  }

  // Named authedDb (not `fs`) to avoid shadowing the file's `require("fs")`.
  function authedDb(user) {
    return testEnv.authenticatedContext(user.uid).firestore();
  }

  for (const coll of LISTS) {
    it(`${coll}: cashier can create`, async () => {
      await assertSucceeds(authedDb(USERS.cashier).collection(coll).add(entry));
    });

    it(`${coll}: cashier can edit the name`, async () => {
      await seed(coll, "e1", entry);
      await assertSucceeds(
        authedDb(USERS.cashier).collection(coll).doc("e1").update({ name: "Renamed" })
      );
    });

    it(`${coll}: cashier cannot flip isActive`, async () => {
      await seed(coll, "e1", entry);
      await assertFails(
        authedDb(USERS.cashier).collection(coll).doc("e1").update({ isActive: false })
      );
    });

    it(`${coll}: staff can flip isActive`, async () => {
      await seed(coll, "e1", entry);
      await assertSucceeds(
        authedDb(USERS.staff).collection(coll).doc("e1").update({ isActive: false })
      );
    });

    it(`${coll}: staff cannot delete; admin can`, async () => {
      await seed(coll, "e1", entry);
      await assertFails(authedDb(USERS.staff).collection(coll).doc("e1").delete());
      await assertSucceeds(authedDb(USERS.admin).collection(coll).doc("e1").delete());
    });

    it(`${coll}: inactive staff cannot create`, async () => {
      await assertFails(authedDb(USERS.inactiveStaff).collection(coll).add(entry));
    });
  }

  describe("motorcycle_models", () => {
    const model = (uid) => ({
      name: "Nmax",
      isActive: true,
      createdBy: uid,
    });

    it("cashier create with createdBy=self still allowed", async () => {
      await assertSucceeds(
        authedDb(USERS.cashier)
          .collection("motorcycle_models")
          .add(model(USERS.cashier.uid))
      );
    });

    it("cashier can rename but not flip isActive; staff can flip", async () => {
      await seed("motorcycle_models", "m1", model(USERS.admin.uid));
      await assertSucceeds(
        authedDb(USERS.cashier)
          .collection("motorcycle_models")
          .doc("m1")
          .update({ name: "Nmax v2" })
      );
      await assertFails(
        authedDb(USERS.cashier)
          .collection("motorcycle_models")
          .doc("m1")
          .update({ isActive: false })
      );
      await assertSucceeds(
        authedDb(USERS.staff)
          .collection("motorcycle_models")
          .doc("m1")
          .update({ isActive: false })
      );
    });

    it("delete stays admin-only", async () => {
      await seed("motorcycle_models", "m1", model(USERS.admin.uid));
      await assertFails(
        authedDb(USERS.staff).collection("motorcycle_models").doc("m1").delete()
      );
      await assertSucceeds(
        authedDb(USERS.admin).collection("motorcycle_models").doc("m1").delete()
      );
    });
  });
});
```

- [ ] **Step 2: Run the rules suite to verify the new tests fail**

Run: `cd tools/firestore-rules-test && npm test`
Expected: the new cashier/staff-allow tests FAIL (writes still admin-only); all pre-existing tests still pass. (Requires the Firebase emulator toolchain already used by this suite; if `npm test` fails on missing deps, run `npm install` first.)

- [ ] **Step 3: Edit `firestore.rules`**

For each of the five simple collections — `product_categories`, `expense_categories`, `units`, `void_reasons`, `mechanics` — replace the block's write line. Example for `product_categories` (repeat the identical pattern for the other four, keeping each block's existing `allow read` line and comments above it):

Replace:

```
      // Only admin can manage the category list
      allow write: if isAdmin() && isActiveUser();
```

with:

```
      // Shared-list grants (2026-07-24): any active user may add or edit
      // entries; only staff/admin may flip isActive (deactivate/reactivate);
      // delete stays admin-only (nothing in-app hard-deletes).
      allow create: if isValidUser() && isActiveUser();
      allow update: if isValidUser() && isActiveUser() &&
        (isStaffOrAdmin() ||
          !request.resource.data.diff(resource.data).affectedKeys()
            .hasAny(['isActive']));
      allow delete: if isAdmin() && isActiveUser();
```

(The `mechanics` block's old comment says "Only admin can manage the mechanic list…"; replace that comment + write line with the same pattern. Same for units/void_reasons/expense_categories with their respective comments.)

For `motorcycle_models`, KEEP the existing `allow read` and `allow create` lines exactly as they are, and replace:

```
      // Only admin manages the list (Settings → Motorcycle Models: rename /
      // archive), gated by manageCategories at the route layer.
      allow update, delete: if isAdmin() && isActiveUser();
```

with:

```
      // Shared-list grants (2026-07-24): any active user may rename; only
      // staff/admin may flip isActive; delete stays admin-only.
      allow update: if isValidUser() && isActiveUser() &&
        (isStaffOrAdmin() ||
          !request.resource.data.diff(resource.data).affectedKeys()
            .hasAny(['isActive']));
      allow delete: if isAdmin() && isActiveUser();
```

- [ ] **Step 4: Run the rules suite to verify everything passes**

Run: `cd tools/firestore-rules-test && npm test`
Expected: ALL PASS — new block AND every pre-existing test (regressions here mean the edit touched more than intended).

**Do NOT deploy the rules.** Deploy (`firebase deploy --only firestore:rules`) is a separate user-confirmed step after merge.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules tools/firestore-rules-test/test/rules.test.js
git commit -m "feat(rules): shared lists — active users create/update, isActive flips staff+, delete admin-only (NOT deployed)"
```

---

### Task 7: Full verification

**Files:** none new.

- [ ] **Step 1: Full Flutter suite + analyzer**

Run: `flutter test`
Expected: ALL pass (~1226 pre-existing + this feature's new tests).
Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Rules suite once more (final state)**

Run: `cd tools/firestore-rules-test && npm test`
Expected: ALL PASS.

- [ ] **Step 3: Commit any stragglers**

`git status --short` must be clean apart from pre-existing untracked files (`scripts/create-user.mjs`, `scripts/rename-product-category.mjs`). If fixes were needed:

```bash
git add -A -- lib test firestore.rules tools && git commit -m "fix(mobile): post-verification cleanups for shared-list permissions"
```

After this task: `/code-review` the branch, then finish the branch per `superpowers:finishing-a-development-branch`. Rules deploy remains a separate user-gated action.
