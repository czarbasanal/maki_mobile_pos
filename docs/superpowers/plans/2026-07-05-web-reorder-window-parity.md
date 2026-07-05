# Web Reorder Window/Cap Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the web reorder engine's velocity window match mobile's yesterday-cutoff semantics, raise the sales-sample cap to 10,000, and surface the currently-silent "sample capped" warning.

**Architecture:** Extract the window math into a pure helper in `web_admin/src/domain/reorder/` (unit-testable without repo mocks), wire it into the existing `useReorderSuggestions` hook, and add a tiny self-contained `CappedNotice` component to the reorder page. The pure reorder formula (`computeReorderSuggestions`) is untouched.

**Tech Stack:** React + TypeScript + Vite, Vitest (jsdom), @testing-library/react (installed, first use in this repo), date-fns, Tailwind tokens.

**Spec:** `docs/superpowers/specs/2026-07-05-web-reorder-window-parity-design.md` (commit it alongside Task 1).

## Global Constraints

- All changes inside `web_admin/`; run all commands from `web_admin/`.
- No mobile changes, no Firestore schema or rules changes.
- Window semantics must match mobile exactly (`lib/presentation/providers/purchase_order_provider.dart:68-84`): `windowDays` complete days, ending yesterday 23:59:59.999; today's partial day excluded.
- Sales cap: **10,000** (mobile `reorderSalesCap` parity).
- Warning styling: reuse the existing token pattern `rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-bodySmall text-warning-dark` (as in `InventoryFormPage.tsx:347`) — no new colors.
- Work on branch `feat/web-reorder-window-parity`; commit per task; do not push.

---

### Task 1: `reorderWindow` pure helper

**Files:**
- Create: `web_admin/src/domain/reorder/reorderWindow.ts`
- Test: `web_admin/src/domain/reorder/reorderWindow.test.ts`
- Also add (docs, same commit): `docs/superpowers/specs/2026-07-05-web-reorder-window-parity-design.md`, `docs/superpowers/plans/2026-07-05-web-reorder-window-parity.md`

**Interfaces:**
- Consumes: `date-fns` (`startOfDay`, `endOfDay`, `subDays` — already a dependency).
- Produces: `reorderWindow(now: Date, windowDays: number): { start: Date; end: Date }` — Task 2 imports it from `@/domain/reorder/reorderWindow`.

- [ ] **Step 1: Create branch**

```bash
git checkout -b feat/web-reorder-window-parity
```

- [ ] **Step 2: Write the failing test**

Create `web_admin/src/domain/reorder/reorderWindow.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { reorderWindow } from './reorderWindow';

describe('reorderWindow', () => {
  it('ends at yesterday end-of-day, excluding today', () => {
    const now = new Date(2026, 6, 5, 9, 30); // Jul 5, 09:30
    const { end } = reorderWindow(now, 30);
    expect(end).toEqual(new Date(2026, 6, 4, 23, 59, 59, 999));
  });

  it('starts windowDays full days before today', () => {
    const now = new Date(2026, 6, 5, 9, 30);
    const { start } = reorderWindow(now, 7);
    expect(start).toEqual(new Date(2026, 5, 28, 0, 0, 0, 0)); // Jun 28 00:00
  });

  it('spans exactly windowDays complete days', () => {
    const { start, end } = reorderWindow(new Date(2026, 6, 5, 12, 0), 14);
    const days = Math.round((end.getTime() + 1 - start.getTime()) / 86_400_000);
    expect(days).toBe(14);
  });

  it('crosses a month boundary correctly', () => {
    const now = new Date(2026, 6, 1, 8, 0); // Jul 1
    const { start, end } = reorderWindow(now, 30);
    expect(start).toEqual(new Date(2026, 5, 1, 0, 0, 0, 0)); // Jun 1
    expect(end).toEqual(new Date(2026, 5, 30, 23, 59, 59, 999)); // Jun 30
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- src/domain/reorder/reorderWindow.test.ts`
Expected: FAIL — cannot resolve `./reorderWindow`.

- [ ] **Step 4: Write minimal implementation**

Create `web_admin/src/domain/reorder/reorderWindow.ts`:

```ts
import { endOfDay, startOfDay, subDays } from 'date-fns';

/**
 * Sales window for reorder velocity: `windowDays` complete days ending
 * yesterday. Today's partial day is excluded so it never dilutes velocity
 * (parity with the mobile purchase-order window).
 */
export function reorderWindow(
  now: Date,
  windowDays: number,
): { start: Date; end: Date } {
  return {
    start: startOfDay(subDays(now, windowDays)),
    end: endOfDay(subDays(now, 1)),
  };
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm run test -- src/domain/reorder/reorderWindow.test.ts`
Expected: 4 tests PASS.

- [ ] **Step 6: Commit (include spec + plan docs)**

```bash
git add web_admin/src/domain/reorder/reorderWindow.ts web_admin/src/domain/reorder/reorderWindow.test.ts docs/superpowers/specs/2026-07-05-web-reorder-window-parity-design.md docs/superpowers/plans/2026-07-05-web-reorder-window-parity.md
git commit -m "feat(reorder): pure yesterday-cutoff window helper + spec/plan"
```

---

### Task 2: Wire the window + cap into `useReorderSuggestions`

**Files:**
- Modify: `web_admin/src/presentation/hooks/useReorderSuggestions.ts`

**Interfaces:**
- Consumes: `reorderWindow(now, windowDays)` from Task 1.
- Produces: exported `REORDER_SALES_CAP = 10_000` (Task 3's page imports it); hook return shape unchanged (`{ suggestions, isLoading, error, capped }`).

The hook has no direct tests (it needs repo/react-query mocking, which this codebase doesn't do); it is covered by the helper's unit tests plus typecheck and browser verification.

- [ ] **Step 1: Edit the hook**

In `web_admin/src/presentation/hooks/useReorderSuggestions.ts`:

Replace the `date-fns` import (line 3):

```ts
import { reorderWindow } from '@/domain/reorder/reorderWindow';
```

Replace the cap constant (line 13) with an export:

```ts
export const REORDER_SALES_CAP = 10_000;
```

Replace the `range` memo (lines 19–25):

```ts
  const range = useMemo(
    () => reorderWindow(now, params.windowDays),
    [now, params.windowDays],
  );
```

Update the two remaining `SALES_CAP` references (query `limit` on line 29 and the `capped` computation on line 42) to `REORDER_SALES_CAP`.

- [ ] **Step 2: Typecheck and run the full suite**

Run: `npm run typecheck && npm run test`
Expected: typecheck clean; all tests PASS (existing count + 4 new).

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/presentation/hooks/useReorderSuggestions.ts
git commit -m "feat(reorder): yesterday-cutoff window + 10k sales cap in hook (mobile parity)"
```

---

### Task 3: `CappedNotice` + page wiring + header copy fix

**Files:**
- Create: `web_admin/src/presentation/features/inventory/CappedNotice.tsx`
- Test: `web_admin/src/presentation/features/inventory/CappedNotice.test.tsx`
- Modify: `web_admin/src/presentation/features/inventory/ReorderSuggestionsPage.tsx`

**Interfaces:**
- Consumes: `REORDER_SALES_CAP` from Task 2 (`@/presentation/hooks/useReorderSuggestions`); the hook's existing `capped: boolean`.
- Produces: `CappedNotice({ capped, cap }: { capped: boolean; cap: number })` — renders `null` when not capped.

Note: this is the repo's first `.test.tsx` component test. Tooling is already in place (vitest `environment: 'jsdom'`, `@testing-library/react`, jest-dom matchers via `src/test/setup.ts`) — no config changes needed. `CappedNotice` lives in its own file (not inside the page) so the test never imports the page's DI-container/Firebase dependency chain.

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/presentation/features/inventory/CappedNotice.test.tsx`:

```tsx
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { CappedNotice } from './CappedNotice';

describe('CappedNotice', () => {
  it('renders the warning when the sales sample is capped', () => {
    render(<CappedNotice capped cap={10_000} />);
    expect(screen.getByText(/most recent 10,000 sales/i)).toBeInTheDocument();
  });

  it('renders nothing when not capped', () => {
    const { container } = render(<CappedNotice capped={false} cap={10_000} />);
    expect(container).toBeEmptyDOMElement();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test -- src/presentation/features/inventory/CappedNotice.test.tsx`
Expected: FAIL — cannot resolve `./CappedNotice`.

- [ ] **Step 3: Write minimal implementation**

Create `web_admin/src/presentation/features/inventory/CappedNotice.tsx`:

```tsx
/** Warns that velocity is computed from a truncated sales sample. */
export function CappedNotice({ capped, cap }: { capped: boolean; cap: number }) {
  if (!capped) return null;
  return (
    <p className="rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-bodySmall text-warning-dark">
      Velocity is computed from the most recent {cap.toLocaleString()} sales — it may be
      understated for this window.
    </p>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test -- src/presentation/features/inventory/CappedNotice.test.tsx`
Expected: 2 tests PASS.

- [ ] **Step 5: Wire into the page**

In `web_admin/src/presentation/features/inventory/ReorderSuggestionsPage.tsx`:

Add imports:

```tsx
import { REORDER_SALES_CAP, useReorderSuggestions } from '@/presentation/hooks/useReorderSuggestions';
import { CappedNotice } from './CappedNotice';
```

(replacing the existing `useReorderSuggestions` import on line 4).

Destructure `capped` (line 19):

```tsx
  const { suggestions, isLoading, error, capped } = useReorderSuggestions(params, now);
```

Fix the header copy (line 73–75) — the current text claims a supplier-lead-time term the formula never had, and should state the new window semantics:

```tsx
        <p className="text-bodySmall text-light-text-secondary">
          Suggested order quantity from recent sales velocity × days of cover. Velocity uses
          complete days ending yesterday.
        </p>
```

Render the notice directly after the controls `<div>` (after line 94, before the `{error ? …}` block):

```tsx
      <CappedNotice capped={capped} cap={REORDER_SALES_CAP} />
```

- [ ] **Step 6: Typecheck and run the full suite**

Run: `npm run typecheck && npm run test`
Expected: typecheck clean; all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add web_admin/src/presentation/features/inventory/CappedNotice.tsx web_admin/src/presentation/features/inventory/CappedNotice.test.tsx web_admin/src/presentation/features/inventory/ReorderSuggestionsPage.tsx
git commit -m "feat(reorder): surface capped-sample warning + window copy on reorder page"
```

---

### Task 4: Build + browser verification

**Files:** none (verification only).

- [ ] **Step 1: Production build**

Run (from `web_admin/`): `npm run build`
Expected: build succeeds, no type errors.

- [ ] **Step 2: Browser smoke**

Run `npm run dev`, open `/inventory/reorder` (admin login), and confirm:
- Suggestions render and change when the window dropdown changes.
- Header copy shows the new "complete days ending yesterday" text.
- No capped banner with normal data volume (< 10,000 sales in window).
- Spot-check one product's velocity against mobile's PO suggestion for the same window (both now exclude today, so they should agree).

- [ ] **Step 3: Session-level wrap-up**

Back in the main session: run `/code-review`, then `/verify`, then finish the branch (merge to main per `finishing-a-development-branch`). Deploy (`firebase deploy --only hosting` from repo root) only if the user asks — the page is already live and this changes its numbers.
