# HR Payroll (Web, Slice 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Admin-only HR section in the web admin: employees registry, manual payroll form with live computation, frozen payslip records, receipt-style payslip with JPG download.

**Architecture:** Pure domain layer (`computePayslip`, `payPeriodFor`) → Firestore data layer mirroring the Mechanic/CostCode patterns (`employees`, `payslips` collections + `settings/hr` doc) → four admin-gated routes under `/hr/*`. JPG via `html2canvas` on the PayslipCard DOM.

**Tech Stack:** React + TS + Vite + Vitest (`web_admin/`), Firestore web SDK, html2canvas (new dep).

**Spec:** `docs/superpowers/specs/2026-07-22-hr-payroll-web-design.md` — authoritative for all formulas, field lists, and rules text.

## Global Constraints

- Branch `feat/hr-payroll-web` (checked out). All commands from `web_admin/` (`npm run test`, `npm run typecheck`) unless noted.
- **Formulas (spec-exact):** hourlyRate = dailyRate/8; basePay = hoursWorked×hourlyRate; overtimePay = overtimeHours×overtimeRatePerHour; holidayPay = regDays×dailyRate×regPct/100 + spcDays×dailyRate×spcPct/100; gross = base+OT+holiday+incentives; totalDeductions = sss+philhealth+pagibig+late+absences+cashAdvance+Σothers.amount; net = gross−totalDeductions.
- **Admin-only everywhere**: new `Permission.manageHr` granted ONLY to admin in the permission map; all 4 routes mapped to it; HR nav hidden without it. `employees`/`payslips` Firestore reads are admin-only by rules — repos/hooks must not be touched by any non-HR page.
- Day statuses: `'present' | 'absent' | 'dayOff'` exactly (stored strings). Dates as `'YYYY-MM-DD'` local strings. weekStartDay ISO 1(Mon)–7(Sun), default 1. Default pcts: regular 100, special 30.
- Mirror existing patterns; do not invent: Employee data layer ← `FirestoreMechanicRepository`/`mechanicConverter`/`MechanicsPage`; HR settings ← `FirestoreCostCodeRepository`/`CostCodeSettingsPage`; route wiring ← the 3 files `routePaths.ts` + `routes.tsx` + `routeGuards.ts` (`protectedRoutes` map) + `Sidebar.tsx`.
- NO prod deploys in Tasks 1–9 (no `firebase deploy` of any kind). Rules deploy + hosting deploy happen only in Task 10 behind user gates.
- Money displayed via `formatMoney` (`@/core/utils/money`). Neutral styling; copy sibling tokens.

---

### Task 1: Domain — types, `computePayslip`, `payPeriodFor`

**Files:**
- Create: `web_admin/src/domain/hr/types.ts`, `web_admin/src/domain/hr/computePayslip.ts`, `web_admin/src/domain/hr/payPeriod.ts`
- Test: `web_admin/src/domain/hr/computePayslip.test.ts`, `web_admin/src/domain/hr/payPeriod.test.ts`

**Interfaces (later tasks depend on these exact names):**

```ts
// types.ts
export type DayStatus = 'present' | 'absent' | 'dayOff';
export interface PayslipDay { date: string; status: DayStatus }
export interface OtherDeduction { label: string; amount: number }
export interface PayslipDeductions {
  sss: number; philhealth: number; pagibig: number;
  late: number; absences: number; cashAdvance: number;
  others: OtherDeduction[];
}
export interface PayslipInputs {
  hoursWorked: number; dailyRate: number;
  overtimeHours: number; overtimeRatePerHour: number;
  regularHolidayDays: number; specialHolidayDays: number;
  regularHolidayPct: number; specialHolidayPct: number;
  incentives: number; deductions: PayslipDeductions;
}
export interface PayslipComputed {
  hourlyRate: number; basePay: number; overtimePay: number; holidayPay: number;
  gross: number; totalDeductions: number; net: number;
}
export interface Employee {
  id: string; name: string; dailyRate: number; isActive: boolean;
  createdAt: Date | null; updatedAt: Date | null;
}
export interface HrSettings { weekStartDay: number; regularHolidayPct: number; specialHolidayPct: number }
export const DEFAULT_HR_SETTINGS: HrSettings = { weekStartDay: 1, regularHolidayPct: 100, specialHolidayPct: 30 };
export interface Payslip {
  id: string; employeeId: string; employeeName: string;
  periodStart: string; periodEnd: string; days: PayslipDay[];
  inputs: PayslipInputs; computed: PayslipComputed;
  createdAt: Date | null; createdBy: string | null; createdByName: string | null;
}
```

- [ ] **Step 1: Failing tests — `computePayslip.test.ts`**

```ts
import { describe, expect, it } from 'vitest';
import { computePayslip } from './computePayslip';
import type { PayslipInputs } from './types';

const BASE: PayslipInputs = {
  hoursWorked: 48, dailyRate: 640,
  overtimeHours: 5, overtimeRatePerHour: 100,
  regularHolidayDays: 1, specialHolidayDays: 2,
  regularHolidayPct: 100, specialHolidayPct: 30,
  incentives: 200,
  deductions: { sss: 45, philhealth: 50, pagibig: 25, late: 0, absences: 0, cashAdvance: 500, others: [{ label: 'Load', amount: 100 }] },
};

describe('computePayslip', () => {
  it('computes the worked example end-to-end', () => {
    const c = computePayslip(BASE);
    expect(c.hourlyRate).toBe(80);        // 640/8
    expect(c.basePay).toBe(3840);         // 48*80
    expect(c.overtimePay).toBe(500);      // 5*100
    expect(c.holidayPay).toBe(1024);      // 1*640*1.0 + 2*640*0.3 = 640+384
    expect(c.gross).toBe(5564);           // 3840+500+1024+200
    expect(c.totalDeductions).toBe(720);  // 45+50+25+0+0+500+100
    expect(c.net).toBe(4844);
  });

  it('all-zero inputs yield all-zero outputs', () => {
    const zero: PayslipInputs = {
      hoursWorked: 0, dailyRate: 0, overtimeHours: 0, overtimeRatePerHour: 0,
      regularHolidayDays: 0, specialHolidayDays: 0, regularHolidayPct: 100, specialHolidayPct: 30,
      incentives: 0,
      deductions: { sss: 0, philhealth: 0, pagibig: 0, late: 0, absences: 0, cashAdvance: 0, others: [] },
    };
    const c = computePayslip(zero);
    expect(c).toEqual({ hourlyRate: 0, basePay: 0, overtimePay: 0, holidayPay: 0, gross: 0, totalDeductions: 0, net: 0 });
  });

  it('net can go negative when deductions exceed gross', () => {
    const c = computePayslip({ ...BASE, hoursWorked: 0, overtimeHours: 0, regularHolidayDays: 0, specialHolidayDays: 0, incentives: 0 });
    expect(c.gross).toBe(0);
    expect(c.net).toBe(-720);
  });
});
```

- [ ] **Step 2: Failing tests — `payPeriod.test.ts`**

```ts
import { describe, expect, it } from 'vitest';
import { payPeriodFor, shiftPeriod } from './payPeriod';

describe('payPeriodFor', () => {
  it('snaps back to the most recent Monday for weekStartDay=1', () => {
    // 2026-07-22 is a Wednesday
    const p = payPeriodFor(new Date(2026, 6, 22), 1);
    expect(p.start).toBe('2026-07-20');
    expect(p.end).toBe('2026-07-26');
    expect(p.dates).toHaveLength(7);
    expect(p.dates[2]).toBe('2026-07-22');
  });

  it('anchor already on the start day stays put', () => {
    const p = payPeriodFor(new Date(2026, 6, 20), 1); // a Monday
    expect(p.start).toBe('2026-07-20');
  });

  it('handles Sunday start (weekStartDay=7)', () => {
    const p = payPeriodFor(new Date(2026, 6, 22), 7);
    expect(p.start).toBe('2026-07-19');
    expect(p.end).toBe('2026-07-25');
  });

  it('spans a year boundary', () => {
    const p = payPeriodFor(new Date(2026, 0, 1), 1); // Thu 2026-01-01
    expect(p.start).toBe('2025-12-29');
    expect(p.end).toBe('2026-01-04');
  });

  it('shiftPeriod moves whole weeks', () => {
    const p = payPeriodFor(new Date(2026, 6, 22), 1);
    expect(shiftPeriod(p, -1).start).toBe('2026-07-13');
    expect(shiftPeriod(p, 1).start).toBe('2026-07-27');
  });
});
```

- [ ] **Step 3: Run to verify failure** — `npx vitest run src/domain/hr/` → FAIL (modules missing)

- [ ] **Step 4: Implement**

`computePayslip.ts`:

```ts
import type { PayslipComputed, PayslipInputs } from './types';

export function computePayslip(i: PayslipInputs): PayslipComputed {
  const hourlyRate = i.dailyRate === 0 ? 0 : i.dailyRate / 8;
  const basePay = i.hoursWorked * hourlyRate;
  const overtimePay = i.overtimeHours * i.overtimeRatePerHour;
  const holidayPay =
    i.regularHolidayDays * i.dailyRate * (i.regularHolidayPct / 100) +
    i.specialHolidayDays * i.dailyRate * (i.specialHolidayPct / 100);
  const gross = basePay + overtimePay + holidayPay + i.incentives;
  const d = i.deductions;
  const totalDeductions =
    d.sss + d.philhealth + d.pagibig + d.late + d.absences + d.cashAdvance +
    d.others.reduce((s, o) => s + o.amount, 0);
  return { hourlyRate, basePay, overtimePay, holidayPay, gross, totalDeductions, net: gross - totalDeductions };
}
```

`payPeriod.ts`:

```ts
export interface PayPeriod { start: string; end: string; dates: string[] }

const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** 7-day period containing `anchor`, starting on ISO weekday `weekStartDay` (1=Mon..7=Sun). */
export function payPeriodFor(anchor: Date, weekStartDay: number): PayPeriod {
  const a = new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate());
  const isoDow = ((a.getDay() + 6) % 7) + 1; // JS Sun=0 → ISO 1..7
  const diff = (isoDow - weekStartDay + 7) % 7;
  const start = new Date(a);
  start.setDate(a.getDate() - diff);
  const dates = Array.from({ length: 7 }, (_, k) => {
    const d = new Date(start);
    d.setDate(start.getDate() + k);
    return iso(d);
  });
  return { start: dates[0], end: dates[6], dates };
}

export function shiftPeriod(p: PayPeriod, weeks: number): PayPeriod {
  const [y, m, d] = p.start.split('-').map(Number);
  const s = new Date(y, m - 1, d + weeks * 7);
  const dates = Array.from({ length: 7 }, (_, k) => {
    const n = new Date(s);
    n.setDate(s.getDate() + k);
    return iso(n);
  });
  return { start: dates[0], end: dates[6], dates };
}
```

`types.ts`: exactly the Interfaces block above.

- [ ] **Step 5: Run to verify pass** — `npx vitest run src/domain/hr/` → PASS; `npm run typecheck` clean

- [ ] **Step 6: Commit** — `git add web_admin/src/domain/hr && git commit -m "feat(web): HR domain — payslip computation + pay-period helpers"`

---

### Task 2: Data layer — converters, repositories, DI

**Files:**
- Create: `web_admin/src/data/converters/employeeConverter.ts`, `web_admin/src/data/converters/payslipConverter.ts`, `web_admin/src/data/repositories/FirestoreEmployeeRepository.ts`, `web_admin/src/data/repositories/FirestorePayslipRepository.ts`, `web_admin/src/data/repositories/FirestoreHrSettingsRepository.ts`, `web_admin/src/domain/repositories/EmployeeRepository.ts`, `web_admin/src/domain/repositories/PayslipRepository.ts`, `web_admin/src/domain/repositories/HrSettingsRepository.ts`
- Modify: `web_admin/src/infrastructure/firebase/collections.ts` (add `employees`, `payslips` + settings doc id `hr`), `web_admin/src/infrastructure/di/container.tsx` (register 3 repos + hooks `useEmployeeRepo`, `usePayslipRepo`, `useHrSettingsRepo`)
- Test: `web_admin/src/data/converters/employeeConverter.test.ts`, `web_admin/src/data/converters/payslipConverter.test.ts`

**Interfaces:**
- `EmployeeRepository`: `watchAll(cb, opts?: {includeInactive?})`, `create({name, dailyRate})`, `update(id, {name?, dailyRate?, isActive?})` — clone `MechanicRepository`'s shape + `dailyRate`.
- `PayslipRepository`: `watchAll(cb)` (ordered periodStart desc then employeeName, client-side sort), `getById(id)`, `create(input: Omit<Payslip,'id'|'createdAt'> )` → id, `delete(id)`.
- `HrSettingsRepository`: `get(): Promise<HrSettings>` (missing doc → `DEFAULT_HR_SETTINGS`), `save(settings: HrSettings)`.
- Converters follow `mechanicConverter`'s toFirestore/fromFirestore structure; payslip stores `inputs`/`computed`/`days` maps verbatim; audit via `serverTimestamp()`.

- [ ] **Step 1: Failing converter tests** — round-trip both converters (build entity → `toFirestore` → assert field map incl. nested `deductions.others`; `fromFirestore` with a fake snapshot → entity; missing-field tolerance: absent `others` → `[]`, absent `days` → `[]`). Mirror `mechanicConverter.test.ts`'s fake-snapshot idiom exactly.
- [ ] **Step 2: Run to verify failure** — `npx vitest run src/data/converters/` → new tests FAIL
- [ ] **Step 3: Implement** converters + repos + registry entries, cloning the named templates (`FirestoreMechanicRepository` for employees; `FirestoreCostCodeRepository` for hr settings incl. its `SettingsDocs` pattern; payslip repo = collection with `getDocs`/`onSnapshot` + `deleteDoc`).
- [ ] **Step 4: Run to verify pass** — converter tests PASS; `npm run typecheck` clean; full `npm run test` green
- [ ] **Step 5: Commit** — `git commit -m "feat(web): HR data layer — employees/payslips/settings repos + DI"` (add all created/modified files)

---

### Task 3: Permission, routes, nav, placeholder pages

**Files:**
- Modify: `web_admin/src/domain/permissions/Permission.ts` (add `manageHr`, grant to admin ONLY), `web_admin/src/presentation/router/routePaths.ts` (`hrEmployees: '/hr/employees'`, `hrPayroll: '/hr/payroll'`, `hrPayslips: '/hr/payslips'`, `hrPayslipDetail: '/hr/payslips/:id'`, `hrSettings: '/hr/settings'`), `web_admin/src/presentation/router/routes.tsx`, `web_admin/src/presentation/router/routeGuards.ts` (map ALL FIVE paths → `Permission.manageHr` in `protectedRoutes`; add the `/hr/payslips/:id` dynamic case to `checkDynamicRoute` mirroring the existing dynamic-route handling), `web_admin/src/presentation/components/common/Sidebar.tsx` (new "HR" group with the 4 nav links, hidden without `manageHr`)
- Create: minimal page components for the 4 pages (heading + "coming in this branch" placeholder) so routes render — real UIs land in Tasks 4–7.
- Test: extend `web_admin/src/presentation/router/routeGuards.test.ts` — admin passes all 5 HR paths incl. a concrete `/hr/payslips/abc123`; cashier and staff are denied all 5.

- [ ] **Step 1: Failing guard tests** (idiom already in that file) → run `npx vitest run src/presentation/router/` → FAIL
- [ ] **Step 2: Implement** permission + paths + routes + guards + sidebar + placeholders
- [ ] **Step 3: Tests PASS** + `npm run typecheck` + full `npm run test` green
- [ ] **Step 4: Commit** — `git commit -m "feat(web): HR section — permission, routes, nav, placeholders"`

---

### Task 4: `/hr/employees` page

**Files:**
- Replace placeholder: `web_admin/src/presentation/features/hr/EmployeesPage.tsx`
- Test: `web_admin/src/presentation/features/hr/EmployeesPage.test.tsx`

Clone `MechanicsPage.tsx`'s structure (list + add/edit dialog + activate/deactivate) with one extra field: **Daily Rate** (numeric, required, > 0, shown in the list via `formatMoney`). Repo hook: `useEmployeeRepo`. TDD with the same harness as MechanicsPage's test (if MechanicsPage has no test, mirror the nearest settings-page test): renders rows from a mocked watchAll; create dialog submits `{name, dailyRate}`; validation blocks empty name / non-positive rate.

- [ ] Steps: failing tests → verify fail → implement → PASS + typecheck + full suite → commit `feat(web): HR employees registry page`

---

### Task 5: `/hr/settings` page

**Files:**
- Replace placeholder: `web_admin/src/presentation/features/hr/HrSettingsPage.tsx`
- Test: `web_admin/src/presentation/features/hr/HrSettingsPage.test.tsx`

Clone `CostCodeSettingsPage.tsx`'s load→edit→save shape for the three fields: week start day (select of 7 weekdays, value 1–7), regular holiday % and special holiday % (numeric ≥ 0). Saves via `useHrSettingsRepo().save`. Tests: loads defaults when repo returns `DEFAULT_HR_SETTINGS`; save called with edited values; invalid (negative pct) blocked.

- [ ] Steps: failing tests → verify fail → implement → PASS + typecheck + full suite → commit `feat(web): HR settings page (week start, holiday percentages)`

---

### Task 6: `/hr/payroll` — the generator form

**Files:**
- Replace placeholder: `web_admin/src/presentation/features/hr/PayrollPage.tsx`
- Create: `web_admin/src/presentation/features/hr/WeekGrid.tsx`, `web_admin/src/presentation/features/hr/usePayslipDraft.ts`
- Test: `web_admin/src/presentation/features/hr/PayrollPage.test.tsx`, `web_admin/src/presentation/features/hr/usePayslipDraft.test.ts`

**Structure:**
- `usePayslipDraft` — string-backed form state hook (mirror the checkout `usePaymentDraft` idiom): every numeric field held as string, parsed with `Number(...) || 0`, negative → validation error; exposes `inputs: PayslipInputs`, `computed` (live `computePayslip(inputs)`), `days`, `setDay(date, status)`, validity.
- `WeekGrid` — renders 7 day cells from `PayPeriod.dates`; click cycles present→absent→dayOff→present; default seed: all present except the LAST day of the period = dayOff (6-day week).
- `PayrollPage` — employee select (active employees via `useEmployeeRepo().watchAll`; picking one prefills `dailyRate` from the record, still editable), period picker (loads `HrSettings` once for weekStartDay + pcts; prev/next week buttons via `shiftPeriod`; label "Jul 20 – Jul 26, 2026"), all numeric inputs + dynamic others rows (add/remove label+amount), live summary panel (base/OT/holiday/incentives/gross/deductions/net via `formatMoney`), **Generate Payslip** button → `usePayslipRepo().create({...})` with the full frozen snapshot (employee name copied, settings pcts copied into inputs) → navigate to `RoutePaths.hrPayslips + '/' + id`.
- Generate is disabled until: employee picked AND all numeric fields valid.

**Tests (harness per sibling feature tests):** live computation shown (seed employee + type hours 48, dailyRate 640 → summary shows ₱3,840.00 base and correct net for the worked example); day-cycling updates the grid; generate calls repo.create with the exact snapshot shape (assert employeeName, periodStart/end, days length 7, computed.net) and navigates; invalid negative input disables Generate.

- [ ] Steps: failing tests → verify fail → implement → PASS + typecheck + full suite → commit `feat(web): payroll generator form with live computation`

---

### Task 7: `/hr/payslips` — history + detail with PayslipCard

**Files:**
- Replace placeholder: `web_admin/src/presentation/features/hr/PayslipsPage.tsx`
- Create: `web_admin/src/presentation/features/hr/PayslipDetailPage.tsx`, `web_admin/src/presentation/features/hr/PayslipCard.tsx`
- Modify: `web_admin/src/presentation/router/routes.tsx` (detail route already wired in Task 3 — point it at the real component)
- Test: `web_admin/src/presentation/features/hr/PayslipsPage.test.tsx`, `web_admin/src/presentation/features/hr/PayslipCard.test.tsx`

**PayslipCard (placeholder layout for the future design handoff):** fixed-width (~420px) white card, monochrome: shop name header ("MAKI MOTORCYCLE PARTS & SERVICES" placeholder constant), employee name + period line, 7-cell attendance mini-row (✓ / ✗ / "off"), earnings table (Base Pay w/ hours×rate caption, Overtime, Holiday Pay, Incentives), deductions table (each nonzero line + every `others` row; zero rows omitted), rule line, Gross / Total Deductions rows, **NET PAY** row emphasized, footer caption "Generated <date> · placeholder layout". All money via `formatMoney`.

**PayslipsPage:** table (period, employee, gross, net) from `watchAll`, row click → detail. **PayslipDetailPage:** loads by route id (`getById`), renders PayslipCard + Delete (confirm dialog, then navigate back) + a disabled "Download JPG" button placeholder (enabled in Task 8).

**Tests:** PayslipCard renders the worked example (asserts NET ₱4,844.00, omits zero-value deduction rows, shows both others labels); list renders rows + navigates; detail delete calls repo + navigates.

- [ ] Steps: failing tests → verify fail → implement → PASS + typecheck + full suite → commit `feat(web): payslip history, detail, receipt-style card`

---

### Task 8: JPG download

**Files:**
- Modify: `web_admin/package.json` (add `html2canvas` — `npm i html2canvas`), `web_admin/src/presentation/features/hr/PayslipDetailPage.tsx` (enable the button)
- Create: `web_admin/src/core/utils/downloadJpg.ts`
- Test: `web_admin/src/core/utils/downloadJpg.test.ts` (mock html2canvas)

```ts
// downloadJpg.ts
import html2canvas from 'html2canvas';

export async function downloadElementAsJpg(el: HTMLElement, filename: string): Promise<void> {
  const canvas = await html2canvas(el, { backgroundColor: '#ffffff', scale: 2 });
  const a = document.createElement('a');
  a.href = canvas.toDataURL('image/jpeg', 0.92);
  a.download = filename;
  a.click();
}
```

Detail page wires a ref on the PayslipCard container:
`downloadElementAsJpg(ref.current, `payslip-${slug(employeeName)}-${periodStart}.jpg`)` where `slug` lowercases and replaces non-alphanumerics with `-`. Test: mock `html2canvas` to resolve a stub canvas; assert anchor download name and that `toDataURL` was called with `image/jpeg`; PayslipDetailPage button invokes it with the card element.

- [ ] Steps: failing tests → verify fail → implement (install dep first) → PASS + typecheck + full suite → commit `feat(web): payslip JPG download via html2canvas`

---

### Task 9: Firestore rules (code only — NO deploy)

**Files:**
- Modify: `firestore.rules` (repo root)

Add beside the mechanics block, using the existing helper functions:

```
    // HR — salary data: admin-only for BOTH read and write (stricter than
    // mechanics' all-user read). See docs/superpowers/specs/2026-07-22-hr-payroll-web-design.md.
    match /employees/{employeeId} {
      allow read, write: if isAdmin() && isActiveUser();
    }
    match /payslips/{payslipId} {
      allow read, create, delete: if isAdmin() && isActiveUser();
      allow update: if false; // payslips are frozen records
    }
```

- [ ] **Step 1:** Insert the block; run `firebase deploy --only firestore:rules --dry-run 2>/dev/null || npx firebase-tools@latest --version` — NOTE: if no offline validator is available, validation happens at Task-10 deploy; at minimum re-read the block for brace balance against neighboring blocks.
- [ ] **Step 2:** Commit — `git add firestore.rules && git commit -m "feat(rules): admin-only employees + frozen payslips collections"`
- **Do NOT deploy.** Task 10 gates it.

---

### Task 10: Final review, verify, gated deploys, finish (controller-run)

- [ ] Whole-branch final review (most capable model): cross-cutting (route gating ↔ nav ↔ rules alignment; snapshot completeness — payslip must survive employee deletion/rate change; period math ↔ grid ↔ card consistency; data-exposure audit: no non-admin path to rates/salaries incl. the rules file).
- [ ] `npm run typecheck` + `npm run test` green; `flutter analyze`/`flutter test` untouched-but-run (repo hygiene).
- [ ] 🛑 **GATE A (user): deploy `firestore.rules`** — present the added block; on "go": `firebase deploy --only firestore:rules`.
- [ ] 🛑 **GATE B (user): hosting deploy** — `cd web_admin && npm run build` then `firebase deploy --only hosting`; verify HTTP 200.
- [ ] User smoke: create employee → generate payslip for this week (broken schedule: mark one weekday absent, move day-off) → verify computed numbers → download JPG → check staff account sees no HR nav and `/hr/payroll` redirects.
- [ ] superpowers:finishing-a-development-branch (merge to main + push).

## Self-Review Notes

- Spec coverage: model (T1/T2), rules (T9, deploy T10), routes/nav/permission (T3), employees (T4), settings (T5), form+grid+live compute (T6), history/detail/card (T7), JPG (T8), gating tests (T3/T4-8 harnesses + final audit), broken schedules (WeekGrid per-day cycling, T6), configurable week start (T5 + payPeriodFor), configurable holiday pcts (T5 + inputs snapshot).
- Worked example is consistent: 640/8=80; 48×80=3840; 5×100=500; 640+384=1024; +200 ⇒ 5564; deductions 720 ⇒ net 4844.
- Placeholder scan: UI tasks defer harness idioms/tokens to named sibling files (established pattern); all logic, names, formulas, copy, and test assertions are concrete.
- Type consistency: `PayslipInputs`/`computed` shapes match between T1 types, T2 converter, T6 form, T7 card tests.
