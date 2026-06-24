# Handoff: MAKI POS — Inventory (migration)

## Overview
Bundle 04. Migrates the three Inventory screens — **list**, **product form**, **price history** — onto the
elevated global theme. These screens already used `AppColors` + were dark-aware, but shipped **Cupertino icons**
and **mixed elevation** (Material-default `Card` product rows next to flat hairline summary `Container`s) with no
`AppCard` and no hero treatment. This bundle brings them up to the same language as POS/Checkout (02) and Sale
Detail (03). Completed for both light and dark.

## About the Design Files
HTML references — **not production code**. Recreate in the existing Flutter screens
(`lib/presentation/mobile/screens/inventory/…`) using `AppCard`, `SummaryRow`, the shared theme layer, and the
existing tiles (`ProductListTile`, `CostCodePill`, `CostDisplayToggle`, `ProductImageUploader`,
`EmptyStateView`/`LoadingView`/`ErrorStateView`). Translate the CSS values below to Flutter.

- `MAKI POS Inventory.dc.html` — the migrated prototype (3 screens, light + dark).
- `reference_current-ui.html` — current pre-migration screens, for before/after.
- `screenshots/` — light + dark.

## Fidelity
**High-fidelity.** Match colors, type, spacing, radii, shadows, icons.

---

## The migration changes
1. **Consistent elevation** — both **summary stat cards and product rows** become `AppCard` soft-shadow surfaces
   (light `0 2px 8px rgba(17,28,29,.06)`; dark `#18262A` + 1px `#243234`). Removes the old Material-`Card`/flat-
   `Container` mismatch. Stat counts bump to **18/700** (small hero treatment).
2. **Cupertino → Lucide** everywhere (mapping below).
3. **Product form grouped into sectioned cards** — uppercase section headers (`Identity · Pricing · Stock ·
   Classification · Audit`), each an `AppCard`; related short fields paired two-up (Selling/Cost, Quantity/
   Reorder). A **live margin line** sits under the pricing pair. **Submit pinned** to the bottom (footer bar,
   `AppShadows.pinnedFooter`), matching POS/Sale-Detail.
4. **Price history** rows wrapped in an `AppCard`; sparklines moved into their own card with from→to labels.

## Tokens (global theme)
| Role | Light | Dark |
|---|---|---|
| Canvas / card | `#F6F5F3` / `#FFFFFF` (soft shadow) | `#0C1415` / `#18262A` (1px `#243234`) |
| Primary | slate `#283E46` (price pill, Add/Update btn, selected chip, segmented) | gold `#E8B84C` |
| Field fill / border | `#FAFAFA` / `#E2E2E2` | `#0C1415` / `#2C3C3E` |
| Text primary / muted / hint | `#16201F` / `#8A9296` / `#9AA0A3` | `#ECEFEF` / `#93A0A3` / `#6C797C` |
| Total / info (blue) | `#2196F3` | lightened `#5AA9F0` |
| In-stock / success / margin | `#4CAF50`, text `#2E7D32` on `#E8F5E9` | icon `#5FC86A`, text `#8FE39A` on `rgba(76,175,80,.18)` |
| Low / warning | `#F57C00` (icon `#FFC107`) | `#F5B547` |
| Out / error / delete / price-down | `#F44336` | icon/text `#FF6B5E` |

**Type:** Figtree; Roboto Mono for SKU / barcode / cost code. **Radii:** stat/field/btn 14–16, rows/cards 16–18,
segmented & chips & badges pill 999 / 8–12. **Stock badge:** outlined in stock color, qty 18/700 + unit 10.

### Icons (Cupertino → Lucide, `lucide_icons`)
back `chevron-left` · cost toggle `eye`/`eye-off` · sort `arrow-up-down` · overflow `more-vertical` · add `plus` ·
export `download` · total `package` · in-stock `check-circle` · low `alert-triangle` · out `alert-circle` ·
category `layout-grid` · search `search` · clear `x` · filters `sliders-horizontal` · cost-code `lock` (mono code)
· SKU `qr-code` · name `box` · price `tag` · cost `philippine-peso` · margin `trending-up` · qty `hash` · reorder
`alert-triangle` · unit `ruler` · barcode add `scan-barcode` · supplier `briefcase` · notes `list` · audit `info`
· price-history `clock` · delete `trash-2` · save `save` · image `image-plus` · deltas `arrow-up`/`arrow-down`.

---

## Screens

### 1 · Inventory list (`inventory_screen.dart`)
**App bar:** back · title "Inventory" · **cost toggle** (`eye`/`eye-off`, admin; green when on — password +
5-min auto-hide) · **sort** (`arrow-up-down` → Name/SKU/Quantity/Price/Recently Updated, ↑/↓) · **overflow**
(Add Product / Export CSV).
**Body:** **4 summary stat cards** (`AppCard`; Total/In/Low/Out; tap In/Low/Out toggles `StockFilter`, selected
gets 1.5px colored border) → **search** (`AppCard` pill, "Search by name, SKU, or barcode…") → **filter chips**
(All/In/Low/Out + Category popup; selected = primary fill) → **active-filters row** (`sliders-horizontal` +
"Filters active" + "Clear all") → **product rows** (`AppCard`): 40×40 image/stock-tint fallback · name (13/600,
2-line) · SKU (mono) + category chip · **price pill** (primary) + *(costs shown)* cost pill + green margin badge
**or** *(hidden/staff)* `lock` cost-code pill · trailing **stock badge** (outlined stock color, qty 18/700).
**Pinned:** "Add Product" (primary, `plus`) when `addProduct`.
**States:** loading/error/empty-no-products/empty-with-filters/pull-to-refresh. **Roles:** `addProduct` → Add;
admin → cost toggle + Export CSV + long-press delete (dialog copy unchanged).

### 2 · Product form (`product_form_screen.dart`)
Title "Add Product" / "Edit Product". **App bar:** back · *(edit+admin)* cost toggle · *(edit+admin)* delete.
**Body (sectioned `AppCard`s):** role banner *(edit, info-tint)* → **image uploader** → **Identity** (SKU + auto-
generate switch/regenerate on create; Name) → **Pricing** (Selling + Cost two-up; live **margin** line) →
**Stock** (Quantity + Reorder two-up; Unit dropdown; Barcodes chip-list + add) → **Classification** (Category;
Supplier *(admin)*; Notes) → **Audit** *(edit)* → **View price history** *(admin, edit, costs shown)*.
**Pinned:** "Add/Update Product" (primary, `save`), spinner while saving.
**Roles & validation** unchanged from README (admin/staff/cashier gating on price·cost·SKU·qty·supplier·delete;
disabled fields — replace `Opacity(0.38)` with a cleaner locked treatment + helper reason). Keep SKU-change and
delete confirm dialogs + copy; barcode multi-code + dedupe.

### 3 · Price history (`price_history_screen.dart`)
Admin-only, read-only, newest-first (~50). **App bar:** back · "Price History".
**Body:** segmented **All/Price/Cost** (primary selected, on an `AppCard` pill) → **sparklines card** (`AppCard`;
Price + Cost trends with from→to labels; <2 points → "Not enough changes to chart") → **changes `AppCard`**:
hairline-divided rows, each = Price ₱ + delta (`arrow-up` green / `arrow-down` red) and Cost ₱ + delta, then meta
line (date • who • source badge: Created / Manual edit / Receiving(RCV-…) / Edit).
**States:** loading / error / empty ("No price changes yet.").

## Must-keep
- All role-gating (admin/staff/cashier on price·cost·SKU·delete·export; `addProduct`).
- Cost visibility = password + 5-min auto-hide; cost-code pill for non-cost viewers.
- SKU-change + delete confirm dialogs and copy; barcode multi-code + dedupe; CSV export; pull-to-refresh.
- Dark-theme parity.

## Files
- `MAKI POS Inventory.dc.html` — migrated prototype (source of truth).
- `reference_current-ui.html` — current screens, before/after.
- `screenshots/01-light-theme.png`, `02-dark-theme.png`.
