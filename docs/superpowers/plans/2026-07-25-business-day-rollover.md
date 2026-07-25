# Business-Day Rollover + Unsettled-Drawer Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Today-scoped data rolls over at midnight; an unclosed sales-day raises a banner, blocks new sale creation (client gates + a server-hard Firestore rule via `drawer_state`), and becomes closable from the EOD screen.

**Architecture:** One clock (`businessDayProvider`, injectable time, midnight timer + resume re-check) feeds every today-scoped provider. A query-based detector finds the oldest unsettled day for the banner/EOD target. Enforcement is layered: cart/bill-out client gates plus a `drawer_state/state` doc (`lastSaleDay`/`lastClosedDay` as `yyyymmdd` ints, PH=UTC+8) that a `sales`-create rule checks server-side. Web checkout stamps the same doc so its sales keep passing the rule.

**Tech Stack:** Flutter + Riverpod; firestore.rules + emulator suite; one small web_admin (TS) change.

**Spec:** `docs/superpowers/specs/2026-07-25-business-day-rollover-design.md`

## Global Constraints

- Branch: create `feat/business-day-rollover` off current `main`.
- PH business day = UTC+8, no DST. Integer day format `yyyymmdd` (e.g. `20260725`) everywhere the doc/rules are concerned.
- Unsettled = past business day with ≥1 COMPLETED sale and no closing; zero-sale days never block; oldest-first; 14-day scan cap.
- Rules: `drawer_state` writes field-constrained (`lastSaleDay` must equal rules-`phDay()`; `lastClosedDay` ≤ `phDay()`; no delete); `sales` create gains `drawerSettled()`; missing doc ⇒ allow. **NO deploy in this plan.**
- Write-time timestamps (sale/closing createdAt) UNCHANGED. EOD target locked at screen open (midnight flip must not retarget a form in progress).
- Suites: `flutter test`/`analyze`, `cd tools/firestore-rules-test && npm test`, and (Task 7 only) web_admin typecheck/test.

---

### Task 1: The clock — `nextMidnightAfter` + `businessDayProvider`

**Files:**
- Create: `lib/core/utils/business_day.dart`, `lib/presentation/providers/business_day_provider.dart`
- Modify: `lib/presentation/providers/providers.dart` (barrel); the app root widget (grep `WidgetsBindingObserver` under `lib/` and READ how the app shell/root is structured — register the resume hook where an observer already lives or add a tiny `_BusinessDayLifecycleObserver` registered from the root's initState)
- Test: `test/core/utils/business_day_test.dart`, `test/presentation/providers/business_day_provider_test.dart`

**Interfaces (produced):**

```dart
// lib/core/utils/business_day.dart
/// Next local midnight strictly after [t] (PH has no DST — plain next 00:00).
DateTime nextMidnightAfter(DateTime t) => DateTime(t.year, t.month, t.day + 1);

/// Midnight-truncated date for [t].
DateTime businessDateOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// yyyymmdd int for the drawer_state doc / rules comparisons.
int businessDayInt(DateTime t) => t.year * 10000 + t.month * 100 + t.day;
```

```dart
// business_day_provider.dart
/// Injectable clock (override in tests).
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class BusinessDayNotifier extends Notifier<DateTime> {
  Timer? _timer;
  @override
  DateTime build() {
    final now = ref.read(nowProvider)();
    _arm(now);
    ref.onDispose(() => _timer?.cancel());
    return businessDateOf(now);
  }

  void _arm(DateTime now) {
    _timer?.cancel();
    _timer = Timer(
      nextMidnightAfter(now).difference(now) + const Duration(seconds: 1),
      _tick,
    );
  }

  void _tick() {
    final now = ref.read(nowProvider)();
    final day = businessDateOf(now);
    if (day != state) state = day;
    _arm(now);
  }

  /// Called from the app-lifecycle observer on resume.
  void recheck() => _tick();
}

final businessDayProvider =
    NotifierProvider<BusinessDayNotifier, DateTime>(BusinessDayNotifier.new);
```

Resume hook: on `AppLifecycleState.resumed`, call `ref.read(businessDayProvider.notifier).recheck()` (wire per the app root's existing structure).

- [ ] **Step 1:** Failing tests: `nextMidnightAfter` (mid-day → next 00:00; 23:59:59 → next day; month/year boundary via `DateTime(2026,12,31,23) → 2027-01-01`); `businessDayInt(DateTime(2026,7,25)) == 20260725`; notifier: override `nowProvider` with a fake mutable clock, read initial state, advance fake clock past midnight, call `recheck()`, expect new date; same-day recheck does not change state identity.
- [ ] **Step 2:** RED. **Step 3:** implement per the interfaces above + resume wiring. **Step 4:** GREEN + `flutter analyze`. **Step 5:** commit `feat(mobile): businessDayProvider — injectable midnight-rollover clock`.

---

### Task 2: Today-scoped consumers follow the clock

**Files:**
- Modify: `lib/presentation/providers/sale_provider.dart` (`todaysSalesSummaryProvider`, `todaysSalesProvider`, `monthToDateSummaryProvider` — their `DateTime.now()` range derivations become `ref.watch(businessDayProvider)`-based; `avgDailySalesProvider`'s `daysElapsed` likewise), `lib/presentation/providers/daily_closing_provider.dart` (`dailyClosingDataProvider`'s isToday comparison watches the clock), `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart` (date header/locals), `lib/presentation/mobile/screens/reports/sales_list_screen.dart` (daily-only forced range)
- Sweep: `grep -rn "DateTime.now()" lib/presentation/ lib/domain/usecases/` — classify EVERY hit today-scope (swap to the clock) vs timestamp/tap-time/one-shot (keep: createdAt stamps, JO number minting, report presets computed on tap, PO velocity windows). Record the classification table in your report.
- Test: extend `test/presentation/providers/` — a test per swapped provider proving a `businessDayProvider` override flips the queried range (fake repo captures the requested dates; flip the overridden day; expect recompute with new range). Widget: dashboard header shows the overridden day's date.

**Interfaces:** Consumes Task 1's `businessDayProvider`. `topSellingTodayProvider` derives from `todaysSalesProvider` — verify the chain recomputes (one test).

Steps: failing tests → RED → swap + classify → GREEN + analyze + full `flutter test` (guard against subtle provider cycles) → commit `feat(mobile): today-scoped providers and screens follow businessDayProvider`.

---

### Task 3: Unsettled-day detection

**Files:**
- Create: `lib/presentation/providers/unsettled_day_provider.dart`
- Modify: barrel; `lib/domain/repositories/daily_closing_repository.dart` + impl IF a "latest closing" fetch is missing (READ them — `watchClosings(limit)` exists; add `Future<DailyClosingEntity?> latestClosing()` mirroring `getClosing`'s style if needed); `lib/domain/repositories/sale_repository.dart` + impl IF a cheap "any completed sale on date" probe is missing (add `Future<bool> hasCompletedSaleOn(DateTime date)` using a `limit(1)` query mirroring existing date-range query style)
- Test: `test/presentation/providers/unsettled_day_provider_test.dart` (fake repos)

**Interfaces (produced):** `final unsettledBusinessDayProvider = FutureProvider<DateTime?>(...)` — OLDEST unsettled day or null. Algorithm (exact):

```dart
final unsettledBusinessDayProvider = FutureProvider<DateTime?>((ref) async {
  final today = ref.watch(businessDayProvider);
  final closingRepo = ref.watch(dailyClosingRepositoryProvider);
  final saleRepo = ref.watch(saleRepositoryProvider);
  // Re-run when a close lands (same invalidation closeDay already fires).
  ref.watch(dailyClosingHistoryProvider);

  final latest = await closingRepo.latestClosing();
  var start = latest == null
      ? today.subtract(const Duration(days: 14))
      : latest.businessDate.add(const Duration(days: 1));
  final floor = today.subtract(const Duration(days: 14));
  if (start.isBefore(floor)) start = floor; // 14-day scan cap

  for (var d = start; d.isBefore(today); d = d.add(const Duration(days: 1))) {
    if (await closingRepo.getClosing(d) != null) continue; // gap already closed
    if (await saleRepo.hasCompletedSaleOn(d)) return d;    // oldest unsettled
  }
  return null;
});
```

- [ ] Failing tests per the spec's matrix: no closings + no sales → null; gap day with sales → that day; zero-sale gap skipped; two gaps → oldest; day beyond the 14-day cap ignored; closing the day (fake repo mutates + invalidate) → advances/clears. RED → implement → GREEN + analyze → commit `feat(mobile): unsettledBusinessDayProvider — oldest unclosed sales-day detector`.

---

### Task 4: `drawer_state` writes (mobile)

**Files:**
- Modify: `lib/core/constants/firestore_collections.dart` (`static const String drawerState = 'drawer_state';` + doc comment; doc id `'state'`), `lib/data/repositories/sale_repository_impl.dart` (`createSale` transaction: `tx.set(drawerStateRef, {'lastSaleDay': businessDayInt(now)}, SetOptions(merge: true))` beside the existing sale/counter writes — READ the tx and mirror its ref/now usage), `lib/domain/usecases/daily_closing/close_day_usecase.dart` + its write path (`saveClosing` impl — READ; add the merge-write `{'lastClosedDay': businessDayInt(closing.businessDate)}` to the same batch/tx that persists the closing; note lastClosedDay uses the CLOSED day, which for a past-day close is < today — allowed by rules' ≤ phDay constraint)
- Test: extend `test/data/repositories/` sale-create test (fake firestore asserts the merge write happened with today's int) and the close-day usecase/repo test (closing writes `lastClosedDay` = closed day's int)

**Interfaces:** Consumes `businessDayInt` (Task 1). Produces the doc shape Task 6's rules validate: `{ lastSaleDay: int, lastClosedDay: int }` at `drawer_state/state`, both merge-written (either field may be absent early).

Steps: failing tests → RED → implement → GREEN + analyze → commit `feat(mobile): sales and closings stamp drawer_state (lastSaleDay/lastClosedDay)`.

---

### Task 5a: Banner + client gates

**Files:**
- Create: `lib/presentation/shared/widgets/common/unsettled_drawer_banner.dart` — warning-styled (mirror `ReportsWarningBanner`'s look — READ it), text `"The drawer for <MMM d> hasn't been closed. Close it before new sales."`, trailing `Close Day` button routing to EOD with the target date (Task 5b's route)
- Modify: `lib/presentation/mobile/screens/pos/pos_screen.dart` (banner above the cart area when `unsettledBusinessDayProvider` has a value), `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart` (banner below header), `lib/presentation/providers/cart_provider.dart` (`canProceedToCheckout` NOTE: CartState is pure — gate at the SCREEN layer instead: the POS checkout button's enable condition adds `&& unsettled == null`, mirroring how `canProceedToCheckout` is consumed; do NOT put a provider read inside CartState), `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart` (Bill-out button disable + `_billOut` early-return with `context.showWarningSnackBar('Close the previous day before billing out')` when unsettled)
- Test: banner widget test (renders date, button pushes the EOD route with the date); POS test: checkout disabled when provider overridden to a date, enabled when null; draft-edit: bill-out blocked/enabled likewise (READ each harness)

**Interfaces:** Consumes `unsettledBusinessDayProvider`; the EOD date route from Task 5b (`RoutePaths.endOfDay` + query/extra param — Task 5b defines `RouteNames.endOfDay` accepting an optional `date` extra; the banner passes it; if executing 5a first, route with the plain EOD path and a TODO-free comment noting 5b wires the target — better: EXECUTE 5b BEFORE 5a (order below is 5b then 5a) so the param exists.)

Steps (after 5b): failing tests → RED → implement → GREEN + analyze → commit `feat(mobile): unsettled-drawer banner + sale-creation client gates`.

---

### Task 5b: EOD screen closes a target day (EXECUTE BEFORE 5a)

**Files:**
- Modify: `lib/config/router/app_routes.dart` (EOD route accepts an optional `DateTime` via `state.extra` — READ how other routes pass extras), `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`:
  - `EndOfDayScreen({this.targetDate})`; state resolves ONCE in `initState`: `_target = widget.targetDate ?? unsettled-or-today` — resolve the default via `ref.read(unsettledBusinessDayProvider)` value if already loaded, else today; the resolved `_target` is FINAL for the screen's lifetime (midnight flip must not retarget — replace the `_today` getter usages with `_target`).
  - AppBar title shows `'End-of-Day Closing'` for today, `'Closing <MMM d>'` otherwise.
  - Verify at implementation time: `CloseDayUseCase.execute` has NO today-assertion (READ it; report if one exists — do not silently remove guards).
- Test: extend `test/presentation/mobile/screens/reports/end_of_day_screen_test.dart`: pumping with `targetDate` shows the dated title and watches that date's providers (override `dailyClosingForDateProvider`/`dailyClosingDataProvider` and assert the overridden family receives the target date — the existing harness overrides families wholesale; capture the date param in the override); a `businessDayProvider` flip after pump does NOT change the watched date.

**Interfaces (produced):** `EndOfDayScreen({DateTime? targetDate})`; route pushes `extra: date`. 5a consumes.

Steps: failing tests → RED → implement → GREEN + analyze → commit `feat(mobile): EOD screen closes a locked target day (past-day close)`.

---

### Task 6: firestore.rules — `drawer_state` + `drawerSettled()` gate

**Files:**
- Modify: `firestore.rules`, `tools/firestore-rules-test/test/rules.test.js`

Rules (exact; helpers beside the existing ones):

```
    // PH business day (UTC+8, no DST) as a yyyymmdd int for drawer_state math.
    function phDay() {
      let t = request.time + duration.value(8, 'h');
      return t.year() * 10000 + t.month() * 100 + t.day();
    }

    // True when no past sales-day is awaiting closing: the state doc is
    // missing (fresh DB / pre-rollout), today already has sales (day is
    // live), or the latest sales-day has been closed.
    function drawerSettled() {
      return !exists(/databases/$(database)/documents/drawer_state/state) ||
        get(/databases/$(database)/documents/drawer_state/state).data.lastSaleDay == phDay() ||
        (get(/databases/$(database)/documents/drawer_state/state).data
            .get('lastClosedDay', 0) >=
         get(/databases/$(database)/documents/drawer_state/state).data.lastSaleDay);
    }
```

New block (near settings):

```
    // ==================== DRAWER STATE (single doc) ====================
    // Denormalized latest-sale-day / latest-closed-day so the sales-create
    // rule can enforce "no new sales on an unsettled drawer" server-side.
    match /drawer_state/{docId} {
      allow read: if isValidUser() && isActiveUser();
      // lastSaleDay may only be stamped to the CURRENT PH day; lastClosedDay
      // may only be set to today or a past day. No delete.
      allow create, update: if isValidUser() && isActiveUser() &&
        (!request.resource.data.diff(resource == null ? {} : resource.data)
            .affectedKeys().hasAny(['lastSaleDay']) ||
          request.resource.data.lastSaleDay == phDay()) &&
        (!request.resource.data.diff(resource == null ? {} : resource.data)
            .affectedKeys().hasAny(['lastClosedDay']) ||
          request.resource.data.lastClosedDay <= phDay());
      allow delete: if false;
    }
```

NOTE for the implementer: `resource` is null on create — if `resource == null ? {} : resource.data` is rejected by the rules compiler inside `diff()`, split the rule into separate `allow create` (validate present fields directly: `!('lastSaleDay' in request.resource.data) || request.resource.data.lastSaleDay == phDay()`, same shape for lastClosedDay) and `allow update` (diff-based) — behavior must match the spec either way.

`sales` create becomes: `allow create: if isValidUser() && isActiveUser() && drawerSettled();`

Emulator tests (extend the suite; USE the file's `as()`/seed helpers; compute today's PH int in JS: `const phDay = (d=new Date()) => { const t = new Date(d.getTime() + 8*3600*1000); return t.getUTCFullYear()*10000 + (t.getUTCMonth()+1)*100 + t.getUTCDate(); }`):
- drawer_state: cashier stamps `lastSaleDay: phDay()` OK; spoofed `phDay()-1`/`+1` denied; `lastClosedDay: phDay()-1` OK; `phDay()+1` denied; delete denied.
- sales create: missing doc → allowed; seeded `{lastSaleDay: phDay()}` → allowed; `{lastSaleDay: phDay()-1}` (no lastClosedDay) → DENIED; `{lastSaleDay: phDay()-1, lastClosedDay: phDay()-1}` → allowed.
- TDD order: tests first (RED: the allow-cases needing the new block fail; sales-deny case fails because create is currently allowed) → rules → GREEN (all pre-existing 132 + new pass).

Commit `feat(rules): drawer_state + drawerSettled sales-create gate (NOT deployed)`. **Do NOT deploy.**

---

### Task 7: Web stamps `lastSaleDay`

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreSaleRepository.ts` (`create()` transaction: `tx.set(doc(db,'drawer_state','state'), { lastSaleDay: phDayInt() }, { merge: true })` beside the sale write — READ the tx), Create: `web_admin/src/core/utils/businessDay.ts`:

```ts
/** PH (UTC+8) business day as yyyymmdd — must match mobile/rules math. */
export function phDayInt(now: Date = new Date()): number {
  const t = new Date(now.getTime() + 8 * 3600 * 1000);
  return t.getUTCFullYear() * 10000 + (t.getUTCMonth() + 1) * 100 + t.getUTCDate();
}
```

- Test: `web_admin/src/core/utils/businessDay.test.ts` (fixed Date fixtures incl. a UTC time that crosses the PH date line: `2026-07-25T17:00:00Z` → `20260726`); extend the repository/checkout test that pins the create-transaction writes (READ how it fakes the tx) to assert the drawer_state merge write.

Steps: failing tests → RED → implement → GREEN + `npm run typecheck` + `npm run test` from web_admin → commit `feat(web): checkout stamps drawer_state.lastSaleDay`.

---

### Task 8: Full verification

- [ ] `flutter test` + `flutter analyze`; `cd tools/firestore-rules-test && npm test`; `cd web_admin && npm run typecheck && npm run test -- --run && npm run build`. All green; `git status --short` clean apart from the two pre-existing untracked scripts.

After Task 8: final whole-branch review (most capable model — money + rules + timezone math), then finish per `superpowers:finishing-a-development-branch`. Rules deploy + hosting deploy + the +16 APK all remain user-gated (this feature joins the held bundle; SEQUENCING at ship time: rules deploy and APK/hosting can go in any order — the missing-doc allowance keeps old writers safe — but the gate only enforces once a new client writes the doc).
