# MAKI MOTOR PARTS — Admin Skin & Rollout Spec

Reference implementation: `MAKI POS Dashboard.dc.html`

---

## 0. The assignment

Overhaul the entire web admin to this skin and theme. **Start with the Dashboard** — it is
the reference screen, and every token, control and layout rule below is already proven on it.
Ship the Dashboard first, get it signed off, then roll the same components outward.

Do not restyle screens one at a time with copied CSS. Build a shared component layer first,
then rebuild each screen out of it. If a screen needs a treatment that does not exist yet,
add it to the component layer — never to the screen.

### Order of work

1. **Tokens** — every value in §2 becomes a CSS custom property in one stylesheet, with the
   `[data-theme="dark"]` override block. After this step no other file may contain a literal
   hex, px font size, radius or shadow.
2. **Primitives** — build the shared set in §7 before touching any screen.
3. **Dashboard** — rebuild it entirely from those primitives. Done when the screen file
   contains nothing but layout (grid/gap) and component usage.
4. **Roll out**, in this order: Inventory → POS → Job Orders → Receiving → Suppliers →
   Expenses → Reports → Void Requests → Users → Activity Logs → HR → Settings.

### Definition of done, per screen

- Tokens only — no hard-coded colors, sizes, radii or shadows.
- Light and dark both checked by eye, not assumed.
- Every table is the shared `DataTable`; every filter row is the shared `FilterBar`;
  every identifier carries the shared `CopyButton`.
- Loading, empty and error states exist for every async region.
- Keyboard reachable: sane tab order, visible focus rings, `Esc` closes drawers.

---

## 1. Typography

Two families, loaded from Google Fonts:

```
IBM Plex Sans — 400, 500, 600, 700   (all UI text)
IBM Plex Mono — 400, 500, 600        (all numerals, IDs, SKUs, timestamps)
```

Rule: **every number the user reads as data goes in IBM Plex Mono.** Money, counts,
percentages, sale numbers, times, SKU codes. Prose, labels and headings stay in Plex Sans.
Add `font-feature-settings: 'tnum'` to large figures so columns align.

### Type scale

| Role | Size | Weight | Family | Letter-spacing |
|---|---|---|---|---|
| Page title (`Dashboard`) | 20px | 600 | Sans | -0.4px |
| Page subtitle | 12.5px | 400 | Sans | — |
| Card heading (`Recent sales`) | 14px | 600 | Sans | -0.15px |
| KPI figure | 23px | 600 | Mono | -1px |
| KPI label | 11.5px | 500 | Sans | — |
| KPI delta chip | 10.5px | 600 | Mono | — |
| KPI note | 10.5px | 400 | Sans | — |
| Table header | 10px | 600 | Sans | 1px, uppercase |
| Table cell — text | 12.5px | 400–500 | Sans | — |
| Table cell — amount | 13px | 600 | Mono | — |
| Table cell — id / time | 12–12.5px | 400–500 | Mono | — |
| Toast message | 12.5px | 500 | Sans | — |
| Sidebar nav item | 13.5px | 500 (600 active) | Sans | — |
| Sidebar group label | 10px | 600 | Sans | 1.1px, uppercase |
| Brand wordmark | 14px | 600 | Sans | 0.3px |
| Status pill | 11px | 500 | Sans | — |
| Chart axis label | 10px | 400 | Mono | — |
| Inventory status figure | 14px | 600 | Mono | — |

Nothing on this screen is below 10px, and 10px is reserved for uppercase micro-labels only.

---

## 2. Color palette

Defined as CSS custom properties on `:root`, overridden under `:root[data-theme="dark"]`.
Every surface, border and text color in the layout reads from a token — no literal hex in
component styles.

### Light (default — airy, cool gray-white)

| Token | Value | Use |
|---|---|---|
| `--bg` | `#f3f5f7` | Page background |
| `--surface` | `#ffffff` | Cards, sidebar, header |
| `--surface-2` | `#f8fafb` | Inset rows, table head, inputs |
| `--surface-3` | `#eef1f4` | Track/rail fills, muted chips |
| `--border` | `#e4e8ed` | Card and control borders |
| `--border-2` | `#eef1f4` | Table row dividers |
| `--text` | `#14171c` | Primary text |
| `--text-2` | `#69727f` | Secondary text |
| `--text-3` | `#98a1ad` | Tertiary / labels |
| `--accent` | `#f2c418` | Amber — fills, bars, primary button |
| `--accent-ink` | `#1d1a08` | Text **on** amber fill |
| `--accent-soft` | `#fdf4d2` | Amber tint background |
| `--accent-line` | `#e0b200` | Amber used as a fill/stroke |
| `--accent-text` | `#8a6300` | Amber used as **text** on tint |
| `--pos` | `#12866a` | Positive figures, "Completed" |
| `--pos-soft` | `#e3f4ef` | Positive tint |
| `--neg` | `#c04b38` | Negative figures, out of stock |
| `--neg-soft` | `#fbeae6` | Negative tint |
| `--shadow` | `0 1px 2px rgba(16,24,40,.04), 0 10px 28px -12px rgba(16,24,40,.10)` | Card lift |

### Dark

| Token | Value |
|---|---|
| `--bg` | `#0d0f12` |
| `--surface` | `#15181d` |
| `--surface-2` | `#1a1e24` |
| `--surface-3` | `#222731` |
| `--border` | `#252b34` |
| `--border-2` | `#1e232a` |
| `--text` | `#eceff3` |
| `--text-2` | `#98a1ad` |
| `--text-3` | `#6a7482` |
| `--accent` | `#f2c418` |
| `--accent-ink` | `#1d1a08` |
| `--accent-soft` | `#332a0a` |
| `--accent-line` | `#f0c53a` |
| `--accent-text` | `#f0c53a` |
| `--pos` | `#3fc79f` · `--pos-soft` `#132a25` |
| `--neg` | `#e5806c` · `--neg-soft` `#2c1a17` |
| `--shadow` | `0 1px 2px rgba(0,0,0,.4), 0 10px 28px -12px rgba(0,0,0,.6)` |

### Two color rules that matter

1. **`--accent-line` is a fill. `--accent-text` is a text color.** They are the same value
   in dark and deliberately different in light — a bright amber on a pale amber tint fails
   contrast. Never use `--accent-line` as `color:`.
2. **Do not put a CSS `transition` on `background` for anything whose background comes from
   a `var()`.** The browser pins the old computed color when the custom property flips, so
   the sidebar and header stay light after a theme switch. Transition `border-color`,
   `opacity` or `color` instead.

---

## 3. Geometry

```
Card radius        14px          Sidebar width      248px
Control radius     10px          Header padding     18px 28px
Pill radius        20px          Content padding    22px 28px 40px
Small chip radius  6–9px         Card padding       15–20px
Bar/track radius   3–6px         Grid gap           12–16px
Border width       1px everywhere
```

Layout: fixed 248px sidebar (`position: sticky`, full height) + fluid main column.
Main column stacks: sticky header → 5-col KPI grid → `1.6fr / 1fr` two-up row →
full-width Recent sales table. All grids use `display:grid` + `gap`, never margins.

---

## 4. Theme switching

`data-theme` is set on `document.documentElement` and persisted to
`localStorage['maki-pos-theme']`. Apply the attribute **inside the handler** that changes
theme state, not in a `componentDidUpdate` — the latter is unreliable in this runtime.

---

## 5. Data wiring — for Claude

Everything on the screen is currently hard-coded sample data matching the screenshot.
Replace each block below with a live source. Field shapes are given as they are consumed.

### 5.1 KPI row — 5 cards

Endpoint suggestion: `GET /api/dashboard/summary?date=YYYY-MM-DD`

```ts
{
  salesCount:   number,   // "Sales today"   → 27
  grossSales:   number,   // "Gross Sales"   → 8945.00
  totalCogs:    number,   // "Total COGS"    → 5246.00
  grossProfit:  number,   // "Gross profit"  → 3699.00
  avgOrder:     number,   // "Avg order"     → 370.37
  compare: {              // prior business day, for the delta chips
    salesCount: number, grossSales: number, avgOrder: number
  }
}
```

Derived in the client, not stored: COGS share (`totalCogs / grossSales`), margin
(`grossProfit / grossSales` → 41.4%), and each delta chip. Delta chip color: `--pos` when
up, `--neg` when down, `--surface-3` / `--text-2` when it is a neutral ratio rather than a
change. Currency formats as `₱` + `toLocaleString('en-PH', {minimumFractionDigits: 2})`.

### 5.2 Sales-through-the-day chart

Endpoint: `GET /api/dashboard/hourly?date=YYYY-MM-DD`

```ts
Array<{ hour: number /* 0-23 */, count: number, gross: number }>
```

Bucket to the store's open hours only. Bar height is `count / max(count) * 100`%; the tallest
bar takes `--accent`, the rest `--surface-3`. The count sits above each bar and is omitted
when zero. The "peak 12:00 PM" caption is the argmax hour.

### 5.3 Margin strip (below the chart)

No new data — computed from 5.1. Bar is two segments: COGS share in `--surface-3`, profit
share in `--accent`.

### 5.4 Inventory status

Endpoint: `GET /api/inventory/status`

```ts
{ total: number, inStock: number, lowStock: number, outOfStock: number }
```

`total` is displayed as-is; the other three each show a share of total (one decimal) and
render as a segmented bar in `--pos` / `--accent` / `--neg`. Low stock means
`quantity <= reorderPoint && quantity > 0`; out of stock means `quantity <= 0`.

### 5.5 Needs attention

Derived from 5.4 plus the void queue — three rows, each linking to its section:

```ts
[
  { label: 'Out of stock',  detail: `${outOfStock} SKUs unavailable at register`, action: 'Reorder', href: '/inventory?filter=out'  },
  { label: 'Low stock',     detail: `${lowStock} SKUs below reorder point`,       action: 'Review',  href: '/inventory?filter=low'  },
  { label: 'Void requests', detail: `${pendingVoids} pending manager approval`,   action: 'Approve', href: '/void-requests'         }
]
```

Hide a row entirely when its count is zero rather than showing "0".

### 5.6 Recent sales table

Endpoint: `GET /api/sales?date=YYYY-MM-DD&limit=8&order=desc`

```ts
Array<{
  saleNo:   string,   // 'SALE-20260831-027'
  soldAt:   string,   // ISO timestamp → render as h:mm A
  itemCount: number,  // → '1 item' | '24 items'
  tender:   'Cash' | 'Card' | 'GCash' | 'Maya' | string,
  status:   'Completed' | 'Voided' | 'Refunded' | 'Pending',
  total:    number
}>
```

Status pill colors: Completed `--pos-soft`/`--pos`; Pending `--accent-soft`/`--accent-text`;
Refunded and Voided `--neg-soft`/`--neg` and `--surface-3`/`--text-3` respectively.
The search field filters on `saleNo` — move this server-side (`?q=`) once the table paginates.
Rows should be clickable and open a sale-detail drawer (line items, subtotal, VAT, tender,
change, cashier, void/refund actions).

### 5.7 Copyable identifiers

**Every machine identifier gets a copy button beside it** — sale numbers, job order
numbers, SKUs, supplier codes, batch/serial numbers, receipt references. Staff read these
aloud and paste them into chats and supplier emails all day.

Markup pattern: the identifier in IBM Plex Mono, then a 22×22 ghost button in a
`display:flex; gap:7px` row. Icon is a 13px two-square outline in `--text-3`; on hover the
button takes `background: var(--surface-3)` and `color: var(--text-2)`. Give it a
`title="Copy …"` and `stopPropagation()` so it never triggers the row's own click.

On click: `navigator.clipboard.writeText(value)`, then a toast — fixed, bottom center,
`--surface` card with a `--pos` check, reading **Copied to clipboard** followed by the
value in mono. Auto-dismisses after ~1.9s; a second copy resets the timer rather than
stacking toasts. Wrap the clipboard call in try/catch — it throws on insecure origins.

### 5.8 Sidebar

Nav structure is static. Two things are live:

- **Badges** — `Job Orders` (open job orders) and `Void Requests` (pending approvals).
  Render nothing when the count is zero.
- **User block** — `{ email, role }` from the session. Role renders uppercase.

Active item comes from the router path, not local state. `Inventory` and `HR` are flat
links — no expanding sub-menus.

### 5.9 Header

- Date: the store's **business date**, not `new Date()` on the client. A shift that runs past
  midnight must still report the opening day. Format `dddd, MMM D YYYY`.
- `Register open` dot: `--pos` when a shift is open, `--text-3` and label `Register closed`
  when not.
- `New sale` routes to the POS screen.

### 5.10 Timezone, currency, rounding

Server should return raw numbers and ISO timestamps; the client formats in
`Asia/Manila` with `en-PH`. Money is stored in centavos as integers and divided at the
edge — never accumulate floats. Percentages round to one decimal.

---

## 7. Shared component library

Build these once. Every screen composes from them. Props listed are the minimum contract —
frameworks differ, the shape does not. None of them accept a `style` or `className` escape
hatch for color; if a caller needs a new look, add a variant here.

### Button
`variant`: `primary` (amber fill `--accent`, text `--accent-ink`) · `secondary` (surface fill,
`--border` outline, `--text-2`) · `ghost` (transparent, hover `--surface-2`) · `danger`
(`--neg-soft` fill, `--neg` text).
`size`: `sm` 12px/7px 12px · `md` 12.5px/9px 14px. Radius 10px, weight 600 on primary.
Also: `icon` (leading SVG), `loading`, `disabled` (opacity .5, no pointer events).

### IconButton
22–28px square, radius 6–8px, `--text-3` icon, hover `--surface-3` + `--text-2`. Always takes
a `title`. This is the base for `CopyButton`.

### CopyButton
Wraps `IconButton`. Props: `value`, `label` (for the title and the toast). Writes to
`navigator.clipboard` inside try/catch, calls `toast.success('Copied to clipboard', value)`,
and stops event propagation so it never fires the row's own click. See §5.7 — it goes beside
**every** sale no., job order no., SKU, supplier code and batch/serial on the site.

### Badge / Pill
`tone`: `positive` `--pos-soft`/`--pos` · `warning` `--accent-soft`/`--accent-text` ·
`negative` `--neg-soft`/`--neg` · `neutral` `--surface-3`/`--text-3`.
`shape`: `pill` (radius 20px, status) · `chip` (radius 6px, mono, for counts and deltas).
Map every domain status through one function — `statusTone(status)` — so "Completed" is the
same green in the sales table, the job order list and the drawer.

### Card
Surface, 1px `--border`, radius 14px, `--shadow`, padding 15–20px. Optional `title`
(14px/600), `subtitle` (11.5px `--text-3`), and a `headerAction` slot (right-aligned text
link or button). Everything on the Dashboard is a Card.

### StatCard
Props: `label`, `value`, `delta`, `deltaTone`, `note`, `format` (`currency` | `number` |
`percent`). Value renders 23px/600 mono with `tnum`. Delta is a mono chip; `note` is 10.5px
`--text-3`. Rows of them use `display:grid; grid-template-columns:repeat(n,1fr); gap:12px` —
the Dashboard runs five.

### SearchInput
Surface-2 fill, `--border`, radius 9px, magnifier in `--text-3`, 12px mono-free input.
Props: `value`, `onChange`, `placeholder`, `debounce` (default 250ms), `onClear`. Debounce
client-side; switch to a server `?q=` once the list paginates.

### FilterBar
A single horizontal row that owns all list filtering: a `SearchInput`, then any of
`SelectFilter` (dropdown), `SegmentedFilter` (2–4 mutually exclusive chips), `DateRangeFilter`,
and a `Toggle` for boolean cuts like "Low stock only". Active chips take `--accent-soft` fill,
`--accent-text` text and an `--accent-text` border; inactive take `--surface`/`--text-2`/
`--border`. The bar exposes one `filters` object and one `onChange` — screens never manage
individual controls. Right-aligns a result count in mono `--text-3`.

### TableViews
The saved-view tab strip that sits above a `FilterBar`: named presets of a filter set
("All", "Unpaid", "Low stock", "Pending approval"), each with a live count. Same active
styling as filter chips. Views are data, not code — `[{ id, label, filters, count }]` — so
new ones can be added per screen without new components.

### DataTable
The one table for the whole admin. Props: `columns`, `rows`, `rowKey`, `onRowClick`,
`sort`, `onSortChange`, `pagination`, `loading`, `empty`, `selection`.
Column: `{ key, header, align, width, render, sortable, mono }`.
Styling is fixed: head row `--surface-2` with 10px/600/1px-tracked uppercase `--text-3`
labels and 1px `--border` above and below; cells 12.5px with `1px --border-2` dividers;
`--surface-2` on row hover; numeric columns right-aligned and mono. Renders `EmptyState`
when `rows` is empty and `Skeleton` rows while `loading`. Never write a bare `<table>` again.

### Charts
Thin wrappers, one visual language: `--accent` for the focus series, `--surface-3` for
context/comparison, `--pos`/`--neg` only for signed values. Axis labels 10px mono `--text-3`.
Bars radius `6px 6px 3px 3px`.
- `BarChart` — `data: [{label, value}]`, optional `highlight` (index or predicate, gets
  `--accent`). The Dashboard's sales-through-the-day.
- `SegmentedBar` — `segments: [{label, value, color}]`, one 10px rounded strip with 2px gaps.
  Margin strip and inventory status bar.
- `LineChart` — trends over time in Reports.
- `MiniBar` — inline stock/progress rails inside table cells.
Every chart takes `loading` and `empty` and never invents a color outside the token set.

### Toast
Global, one at a time, fixed bottom center. Surface card, `--border`, radius 12px, big soft
shadow, 12.5px/500 message plus an optional mono detail in `--text-3`. Tones reuse the Badge
palette. Auto-dismiss ~1.9s; a second toast resets the timer instead of stacking. Exposed as
an imperative singleton — `toast.success()`, `toast.error()`, `toast.info()`.

### Drawer
Right-side panel, 390px, `--surface`, left `--border`, heavy shadow, slides in over a
`rgba(12,16,22,.32)` scrim. Closes on scrim click and `Esc`. Header holds the record id (with
its `CopyButton`) and status pills; footer pins the primary and secondary actions. Sale
detail, job order detail and supplier detail all use this.

### EmptyState / Skeleton / ErrorState
`EmptyState`: centered, 44px vertical padding, 13px `--text-3` message plus an optional
action button. `Skeleton`: `--surface-3` blocks at the real content's dimensions — never a
spinner inside a card. `ErrorState`: `--neg` message with a Retry button.

### Layout shell
`AppShell` owns the 248px sticky sidebar and the sticky header so no screen re-implements
them. Sidebar: brand block, flat nav grouped by SELL / STOCK / MONEY / ADMIN with uppercase
10px group labels, live badges, and the user block pinned to the bottom. Active state comes
from the router path. Header: page title (20px/600) + subtitle, then business date, register
status, theme toggle, and a screen-level primary action.

### ThemeProvider
Owns `data-theme` on `document.documentElement` and the `localStorage['maki-pos-theme']`
round trip. Apply the attribute inside the setter, never in an update lifecycle hook — see §4.
Expose `useTheme()` for the toggle only; components read colors from CSS variables, never
from JS.

---

## 8. Still to design


Not yet built, listed so the wiring can anticipate them: sale-detail drawer, POS register
screen, inventory table with stock bars, reports (revenue over time, category mix),
void-request approval queue, and the empty/loading/error states for each card above.

Build them from §7 primitives. If one of them needs something the library lacks, extend the
library and note it here — the component set is the deliverable, the screens are its output.
