# Handoff: Weekly Payslip (Receipt-style)

## Overview
A compact, receipt-style weekly payslip for **MAKI Motorcycle Parts & Accessories Shop**. It shows one employee's earnings, deductions, weekly attendance, and net pay for a pay period, plus a system-generated footnote. It is intended to be printable/shareable at a narrow "receipt" width.

## About the Design Files
The file in this bundle (`Payslip.dc.html`) is a **design reference created in HTML** — a prototype showing the intended look and behavior, **not production code to copy directly**. The task is to **recreate this design in the target codebase's existing environment** (React, Vue, SwiftUI, native, etc.) using its established components, tokens, and patterns. If no environment exists yet, choose the most appropriate framework for the project and implement it there.

> Note: `Payslip.dc.html` is a "Design Component" — an HTML template plus a small logic class that supplies the row data. Treat the logic class as the data model and the template as the view.

## Fidelity
**High-fidelity (hifi).** Final colors, typography, spacing, and layout are specified below. Recreate the UI faithfully using the codebase's existing libraries and patterns; substitute equivalent design tokens where the codebase already defines them.

## Screens / Views

### Payslip Card
- **Name**: Weekly Payslip
- **Purpose**: Employee views their pay breakdown and net pay for the week.
- **Layout**:
  - Centered card on a light gray page background (`#e9eaea`), page padding `40px 16px`.
  - Card: fixed width **380px**, white background, `border-radius: 14px`, `overflow: hidden`, shadow `0 20px 50px -20px rgba(18,28,29,.45), 0 2px 8px rgba(18,28,29,.08)`.
  - Vertical stack: Header → Body → Footer.

#### 1. Header (dark bar)
- Background `#121c1d`, padding `22px 28px 20px`, `display:flex; align-items:center; gap:14px`.
- **Logo**: 40×40 box, `object-fit: contain`. Asset: `assets/maki_logo_yellow.png` (yellow gear/dog mark, transparent PNG).
- **Text block** (column, gap 2px):
  - Company name: two lines, `#ffffff`, 13px, weight 700, line-height 1.15 — "MAKI MOTORCYCLE PARTS" / "& ACCESSORIES SHOP".
  - Address: `#9aa5a6`, 10px, weight 500 — "Buanoy, Balamban, Cebu".

#### 2. Body (padding `24px 28px 20px`)
- **Employee block** (centered, margin-bottom 20px):
  - Eyebrow "PAYSLIP": 11px, weight 600, letter-spacing `.14em`, uppercase, `#8a9192`.
  - Name "Maybelle Tampos": 19px, weight 700, `#121c1d`.
  - Period "Jul 20 – Jul 26, 2026": 13px, `#6b7273`.
- **Attendance** (top & bottom `1px dashed #cfd3d3`, padding `14px 0`, margin-bottom 20px):
  - Label "ATTENDANCE": 10px, weight 600, letter-spacing `.14em`, uppercase, `#8a9192`, centered.
  - 7-column grid (`repeat(7,1fr)`, gap 2px), each column = day label above a status dot:
    - Day label: 10px, weight 600, `#8a9192` — MON…SUN.
    - Status dot: 24×24 circle, 12px weight 700.
      - Present: bg `#e8f0ec`, fg `#2f7d5b`, mark `✓`.
      - Off/absent: bg `#f0f1f1`, fg `#b0b6b6`, mark `—`.
    - Current data: Mon–Sat present, Sun off.
- **Earnings** section:
  - Section label "EARNINGS": 10px, weight 700, letter-spacing `.14em`, uppercase, `#8a9192`, margin-bottom 10px.
  - Rows (column, gap 9px): label left (14px, `#1e2829`) with optional mono note (11px, `#9aa0a0`, JetBrains Mono, margin-left 6px); amount right (14px, weight 500, `#1e2829`, tabular-nums).
- **Deductions** section: same structure; amounts colored `#b23b3b` (red).
- **Totals** (top `1px dashed #cfd3d3`, padding-top 14px, column gap 8px): Gross and Total Deductions rows, 14px `#4a5152`, tabular-nums. Total Deductions prefixed with "– ".
- **Net Pay** bar: bg `#121c1d`, `border-radius: 10px`, padding `16px 18px`, space-between. Label "NET PAY" `#f5b921` 12px weight 700 letter-spacing `.14em` uppercase; amount `#ffffff` 23px weight 800 tabular-nums.

#### 3. Footer (top `1px dashed #cfd3d3`, padding `16px 28px 22px`, centered)
- "Generated Jul 22, 2026": 12px, `#6b7273`.
- System note: 10.5px, `#a3a9a9`, JetBrains Mono, letter-spacing `.04em` — "This is a System-Generated payslip. No signature required."

## Interactions & Behavior
Static display component — no click handlers, animations, or form input in this design. Link default/hover colors defined: `#b8892b` / `#8f6a1f`. Responsive behavior: card is fixed 380px; on narrow viewports rely on page padding. For production, consider making width `min(380px, 100%)`.

## State Management
No interactive state. Data model (all values currently hardcoded in the logic class) that should be driven by props/API:
- `employee`: name, pay period start/end, generated date.
- `week[]`: 7 entries `{ label, present: boolean }` → maps to present/off styling.
- `earnings[]`: `{ label, note?, amount }`.
- `deductions[]`: `{ label, amount }`.
- Derived: gross, totalDeductions, netPay (compute from rows rather than hardcoding).

## Design Tokens
Colors:
- Ink / dark surface: `#121c1d`
- Body text: `#1e2829`; secondary `#4a5152`; muted `#6b7273`; faint `#8a9192` / `#9aa5a6` / `#a3a9a9`
- Brand yellow: `#f5b921` (accent on dark); logo yellow ~`#f5b921`
- Deduction red: `#b23b3b`
- Present chip: bg `#e8f0ec`, fg `#2f7d5b`; Off chip: bg `#f0f1f1`, fg `#b0b6b6`
- Page bg: `#e9eaea`; card bg `#ffffff`; dashed rule `#cfd3d3`
- Link: `#b8892b` / hover `#8f6a1f`

Typography:
- Primary: **Inter** (400/500/600/700/800)
- Mono (notes, system note): **JetBrains Mono** (400/500/600)
- Numbers use `font-variant-numeric: tabular-nums`.

Radius: card 14px, net-pay bar 10px, status dot 50%.
Spacing: card padding `24px 28px`; section gaps 9–20px.
Shadow (card): `0 20px 50px -20px rgba(18,28,29,.45), 0 2px 8px rgba(18,28,29,.08)`.

## Assets
- `assets/maki_logo_yellow.png` — MAKI logo (yellow, transparent PNG, 800×797, user-provided). Use at 40×40 in header; scalable.

## Files
- `Payslip.dc.html` — the design reference (template + data logic).
- `assets/maki_logo_yellow.png` — logo asset.
