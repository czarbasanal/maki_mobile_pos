# HR Module — Slice 1: Web Payroll Generation — Design

**Date:** 2026-07-22
**Status:** Approved
**Branch:** feat/hr-payroll-web
**Epic:** HR module (mobile + web). Slice 1 = web, manual payroll generation + JPG payslip.
Slice 2 (later) = mobile UI on the same Firestore model. Future = automation fed by
time-in/out (parked roadmap §24) — the data model here is its hook.

## Goal

Admin generates a weekly payslip per employee by manually entering hours, rates,
holiday days, incentives, and deductions; the app computes gross/deductions/net, stores
a frozen payslip record, and renders a receipt-style payslip downloadable as JPG.
Payslip visual design will be handed off later — this slice ships a clean placeholder
layout.

## Data model (Firestore — shared with future mobile slice)

- **`employees`** (new): `{name: string, dailyRate: number, isActive: bool,
  createdAt/updatedAt/createdBy/updatedBy}` + `searchKeywords` (name prefixes, reuse the
  keyword idiom). Admin-managed list mirroring the Mechanics data layer. No SSS/TIN/etc.
  numbers in this slice (YAGNI).
- **`settings/hr`** (new doc in existing `settings` collection):
  `{weekStartDay: int 1-7 ISO (default 1 = Monday), regularHolidayPct: number (default
  100), specialHolidayPct: number (default 30), updatedAt/updatedBy}`. Read rule
  inherited from `settings/*` (all valid users — contains nothing sensitive); write =
  admin (inherited).
- **`payslips`** (new): frozen snapshot per generated payslip —
  `{employeeId, employeeName, periodStart: 'YYYY-MM-DD', periodEnd: 'YYYY-MM-DD',
  days: [{date: 'YYYY-MM-DD', status: 'present'|'absent'|'dayOff'}] (7 entries),
  hoursWorked, dailyRate, hourlyRate, overtimeHours, overtimeRatePerHour,
  regularHolidayDays, specialHolidayDays, regularHolidayPct, specialHolidayPct,
  incentives,
  deductions: {sss, philhealth, pagibig, late, absences, cashAdvance,
               others: [{label: string, amount: number}]},
  computed: {basePay, overtimePay, holidayPay, gross, totalDeductions, net},
  createdAt/createdBy/createdByName}`.
  All money fields are numbers (pesos). Payslips are immutable records: create, read,
  delete (for corrections, regenerate). No in-place edit in this slice.

### Rules (⚠️ production deploy, user-gated)

`employees` and `payslips` are **admin-only for BOTH read and write** (salary data —
stricter than mechanics' all-user read):

```
match /employees/{employeeId} {
  allow read, write: if isAdmin() && isActiveUser();
}
match /payslips/{payslipId} {
  allow read, create, delete: if isAdmin() && isActiveUser();
  allow update: if false; // frozen records
}
```

`settings/hr` needs no rules change (inherits `settings/{settingId}`).

## Computation (pure TS, exhaustively unit-tested)

```
hourlyRate      = dailyRate / 8
basePay         = hoursWorked × hourlyRate
overtimePay     = overtimeHours × overtimeRatePerHour
holidayPay      = regularHolidayDays × dailyRate × regularHolidayPct/100
                + specialHolidayDays × dailyRate × specialHolidayPct/100
gross           = basePay + overtimePay + holidayPay + incentives
totalDeductions = sss + philhealth + pagibig + late + absences + cashAdvance
                + Σ others[].amount
net             = gross − totalDeductions
```

Late/undertime naturally reduce `hoursWorked`; the manual ₱ late/absences deduction
fields remain as correction levers (default 0). All inputs default 0; negative inputs
rejected at the form layer.

## Pay period & broken schedules

- Period = 7 consecutive days starting on `weekStartDay` (picker defaults to the
  current week; admin can move to previous/next weeks).
- The form renders the 7-day grid; each day cycles **Present / Absent / Day-off**
  (default: 6 × present + final day day-off). Broken schedules (absent Wed, day-off
  moved to Thursday) are per-day taps.
- In this slice the grid is a record (stored + printed on the payslip); it does NOT
  auto-compute amounts. It is the future automation hook.
- Week-range generator (`payPeriodFor(anchorDate, weekStartDay)`) is a pure,
  unit-tested function.

## Web UI (all admin-only)

New "HR" nav section in the AdminShell sidebar:

- **`/hr/employees`** — list (name, daily rate, active) + create/edit dialog +
  deactivate. Mirrors the Mechanics settings page structure.
- **`/hr/payroll`** — the generator: employee picker (active employees), period picker
  + 7-day grid, numeric inputs (hours, daily rate — prefilled from employee, editable
  per-slip; OT hours + OT rate/hour; regular/special holiday day counts; incentives),
  deduction inputs (SSS, PhilHealth, Pag-IBIG, late, absences, cash advance, dynamic
  "others" label+amount rows), live computed summary (base/OT/holiday/gross/deductions/
  net), Generate button → writes the payslip → navigates to its detail.
- **`/hr/payslips`** — history list (period, employee, net) + detail page rendering the
  PayslipCard + Download JPG + Delete.
- **`/hr/settings`** — week start day, regular/special holiday %, saved to
  `settings/hr`.
- Route wiring: routePaths.ts + routes.tsx + routeGuards.ts (`protectedRoutes` +
  `checkDynamicRoute` — the known 3-file gotcha). Guard = admin-only (use the same
  admin permission pattern price-history uses).

## Payslip + JPG export

- `PayslipCard` component: receipt-style monochrome **placeholder** layout (shop name
  header, employee + period, attendance grid row, earnings table, deductions table,
  totals with NET PAY emphasized) — structured so the later design handoff restyles in
  place.
- **Download JPG**: `html2canvas` (new dependency) renders the card DOM → canvas →
  `toDataURL('image/jpeg', 0.92)` → anchor download named
  `payslip-<employeeName-slug>-<periodStart>.jpg`. White background enforced (JPEG has
  no alpha).

## Testing

- Unit: computation (every formula branch, others-sum, zero defaults), `payPeriodFor`
  (all 7 weekStartDay values, year boundaries), payslip converter round-trip.
- Component: payroll form computes live totals; generate writes the correct snapshot
  shape; employees CRUD page; gating (staff/cashier see no HR nav and routes redirect).
- `npm run typecheck` + `npm run test`. JPG download = user browser smoke (html2canvas
  is DOM-dependent; not unit-tested beyond a renders-without-error test).

## Out of scope (this slice)

- Mobile UI (slice 2), payslip visual design (handoff later), automation/time-in-out,
  SSS/PhilHealth/Pag-IBIG contribution tables (amounts stay manual), payslip in-place
  editing, multi-week or semi-monthly periods, printing (JPG covers the need).
