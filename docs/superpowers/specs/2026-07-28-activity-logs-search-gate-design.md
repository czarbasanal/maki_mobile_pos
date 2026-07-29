# Activity Logs — filter-then-Search (mobile + web)

**Date:** 2026-07-28
**Surfaces:** Flutter app (`lib/presentation/mobile/screens/logs/`), React web admin (`web_admin/src/presentation/features/logs/`)

## Problem

Both activity-log screens open a **live Firestore subscription immediately** on mount and
stream forever:

- Mobile — `activity_logs_screen.dart:35` watches `activityLogsStreamProvider`, newest 100.
- Web — `ActivityLogsPage.tsx:159` calls `useActivityLogs`, newest 200 via `onSnapshot`.

The only filter on either is activity type. There is no date filter and no time filter.

Consequences: every visit to the screen burns reads whether or not the admin wanted data,
the subscription keeps billing while the screen sits open, and there is no way to ask a
specific question ("what happened between 8 AM and noon last Tuesday?").

## Goal

Nothing is fetched until the admin sets filters and explicitly taps **Search**.

## Decisions taken during brainstorming

| Question | Decision |
|---|---|
| Branch / store filter | **Skipped.** No branch field exists on log records and multi-branch is still a deferred spec. A dropdown with one option is noise. |
| What "time" means | **Start and end time on the range ends** — one continuous window (`Jul 28 8:00 AM → Jul 28 5:00 PM`), defaulting to whole days. Not a repeating time-of-day window. |
| Live or frozen after Search | **Frozen snapshot** + a Refresh button that re-runs the same search. Cheapest on reads; rows don't shuffle while being read. |
| Starting filter values | **Pre-filled to Today, all operations.** Still fetches nothing until Search — the common case is one tap. |
| Operations filter | **Multi-select.** Tick several types (e.g. Sale + Void Sale + Refund) or leave All. |
| Mobile filter panel | **Collapses to a summary line after a successful Search.** |
| Dead log providers | **Removed** in the same pass (see §5). |

## 1. Behavior (both surfaces)

| Moment | Behavior |
|---|---|
| Screen opens | No query is issued. Filter controls + a placeholder: *"Pick your filters and tap Search."* |
| Filters offered | **Operations** (multi-select, or All) · **From** date + time · **To** date + time |
| Initial values | Operations = All; date = Today; time = start-of-day → end-of-day |

The range is **one continuous window, not a per-day window.** With a multi-day date range and
times of 8:00 AM → 5:00 PM, the query runs from *the first day at 8:00 AM* straight through to
*the last day at 5:00 PM*, including every overnight hour in between. Filtering "only 8–5 on
each day" is explicitly out of scope.

Bounds are inclusive at both ends: the default end time resolves to `23:59:59.999` so the last
minute of the day is not silently dropped.
| Tap **Search** | Exactly one read. Results render as a frozen snapshot. |
| Filter changed after a search | Results stay put. A hint appears: *"Filters changed — tap Search."* |
| **Refresh** | Re-runs the currently-submitted filters. |
| Navigate away and back | State resets to nothing-loaded. |

### Empty / edge states

- **Before first search** — placeholder as above (not the "no logs found" state).
- **Search returned nothing** — *"No activity matched these filters."*
- **Hit the cap** — see §3.
- **Invalid range** (From later than To) — Search is disabled with an inline note.

### Mobile specifics

- The AppBar `PopupMenuButton` type filter is **removed**; filtering moves into a filter card
  at the top of the body.
- Card is expanded on arrival. After a search that returns without error it collapses to one
  summary line — `Today · 8:00 AM–5:00 PM · 3 operations` — with a chevron to reopen. A failed
  search leaves it expanded.
- Search is a full-width button inside the card. Refresh sits on the results header.
- The date-grouped `AppCard` results list, `ActivityLogRow`, and `ActivityLogStyle` are unchanged.
- Date input reuses `DateRangePicker` (`lib/presentation/mobile/widgets/reports/date_range_picker.dart`),
  which is already parent-owned and stateless. Time is two additional time-picker pills.

### Web specifics

- A filter row under the page heading: Operations dropdown with checkboxes (plus All / Clear),
  the existing `DateRangePicker`, two `<input type="time">` boxes, Search button.
- `DateRangePicker` gains an optional `defaultPreset` prop (defaulting to its current `'last7'`
  so the six other pages using it are untouched); this page passes `'today'`.
- Results list, `Pager`, and the `usePageSize('activityLogs')` rows-per-page selector are unchanged.
- Paging stays client-side over the fetched result set.
- Refresh sits on the results header, beside the result count. The web filter row does not
  collapse — there is room for it — so only mobile has the collapse behavior.

## 2. Query shape

Single query on `user_logs`, newest first:

- Operations: `where('type', 'in', selectedTypes)` — omitted entirely when All is selected.
  There are 23 activity types, comfortably under Firestore's 30-value `in` limit.
- Range: `where('createdAt', '>=', from)` and `where('createdAt', '<=', to)`.
- `orderBy('createdAt', 'desc')`, then `limit`.

Issued as a **one-shot read** (`getDocs` / `.get()`), never `onSnapshot`.

## 3. Result cap

500 rows per search on both surfaces. When exactly 500 come back, show:
*"Showing the newest 500 — narrow your range."*

Web continues to page through those 500 client-side with the existing rows-per-page control.

Mobile has no pager — it renders the full result set as one date-grouped list, and each day's
group builds all its rows at once inside a single `AppCard`. Today's ceiling is 100; 500 makes a
heavy day noticeably heavier to build. The rows are simple enough that this should hold, but if
scrolling janks during device smoke, drop the **mobile** cap to 200 and leave web at 500.

## 4. Firestore index

The operations filter combined with a `createdAt` range needs a composite index on `user_logs`:
`type` ASC, `createdAt` DESC.

`firestore.indexes.json` currently has **no** `user_logs` entry at all. The index will be added
to that file as part of this work. **It is not deployed by the implementation** — indexes are
additive and carry no rules change, but deployment is the user's call. The operations filter
returns a `failed-precondition` error until the index is live; the All-operations case works
without it.

## 5. Dead-code removal

Verified unreferenced outside the chain being replaced.

**Mobile — `lib/presentation/providers/activity_log_provider.dart`**

| Removed | Only referenced by |
|---|---|
| `activityLogsStreamProvider` | the screen being rewritten |
| `securityLogsProvider` | `session_reset_provider.dart:22` |
| `userActivityLogsProvider` | `session_reset_provider.dart:23` |
| `entityLogsProvider` | `session_reset_provider.dart:24` |

**Mobile — `ActivityLogRepository` + `ActivityLogRepositoryImpl`**

`watchActivityLogs`, `getSecurityLogs`, `getUserLogs`, `getEntityLogs` — each called only by a
provider in the table above. Removed from both the interface and the Firestore implementation.

`session_reset_provider.dart` loses its three `ref.invalidate` lines for these providers. The
remaining resets (cart, suppliers, job order, inventory, receiving) are untouched. The
surviving `activityLogsProvider` is `autoDispose` and screen-scoped, so it needs no reset line.

**Also removed: `deleteOldLogs`.** Introduced in the initial commit (`cac3e0c`), never wired to
any caller — no provider, no screen, no Cloud Function (the repo has no `functions/` directory).
It is also unusable by construction: it batch-deletes from `user_logs`, and `firestore.rules:273`
sets `allow update, delete: if false` on that collection to keep the audit trail append-only, so
every client call fails with permission-denied regardless of role.

The only things that clear `user_logs` are `scripts/wipe-db.mjs` and `scripts/wipe-transactions.mjs`,
which run on the Admin SDK and bypass rules. If log retention is ever wanted, it belongs there —
an Admin-SDK script — not in a client repository method that the rules forbid.

**Web**

`FirestoreActivityLogRepository.watch()` and the `ActivityLogRepository.watch` interface member
are removed — `useActivityLogs.ts:15` was the only caller, and that hook is itself replaced.
`repo.log()` stays: `application/activityLogger.ts` uses it from fourteen mutation hooks.
`useFirestoreSubscription` stays: used by nine other hooks and pages.

## 6. Implementation notes

**Mobile**

- `ActivityLogParams` swaps `ActivityType? type` for `List<ActivityType> types` (empty = All),
  keeping `startDate` / `endDate` / `limit`. `==` and `hashCode` must use a list-aware
  comparison, otherwise two identical searches produce different provider families and refetch.
- `activityLogsProvider` (already `FutureProvider.autoDispose.family`) is the survivor.
- The screen holds `ActivityLogParams? _submitted`. While null, it renders the placeholder and
  **does not watch the provider**. Search does `setState(() => _submitted = built)`; Refresh
  does `ref.invalidate(activityLogsProvider(_submitted!))`.
- State is mutated from button callbacks only — never from `initState` or during build. See
  the receiving-skeleton regression for why that matters.

**Web**

- `ActivityLogQuery` swaps `type?: ActivityType` for `types?: ActivityType[]`.
- New `useActivityLogSearch()` hook wrapping `repo.list`, returning
  `{ data, isLoading, error, run(query) }`. Nothing runs on mount.
- `useActivityLogs.ts` is deleted.

## 7. Testing

Failing tests first, per the repo development loop.

**Flutter**

- Repository: selected types produce a `whereIn` constraint; All produces none; date bounds map
  to the right `createdAt` comparisons.
- `ActivityLogParams`: value equality holds across two separately-built identical type lists.
- Screen widget test:
  - no repository call on open;
  - tapping Search calls it once with the expected params;
  - results render and the filter card collapses;
  - changing a filter afterwards does **not** refetch and surfaces the hint;
  - Refresh refetches.

**Web**

`ActivityLogsPage.test.tsx` is rewritten — its current harness stubs `watch`, which no longer
exists. New assertions: `list` is not called on mount; it is called on Search click with the
expected query; the existing pagination cases re-based onto a searched result set.

**Gates:** `flutter test`, `flutter analyze`, and from `web_admin/`: `npm run typecheck`,
`npm run test`, `npm run build`.

## 8. Shipping

- Web: hosting deploy.
- Mobile: APK build +22, distributed via App Distribution. The user installs and smoke-tests;
  the agent never installs or smoke-tests on device.
- Firestore index: flagged for the user to deploy, not deployed by the implementation.
