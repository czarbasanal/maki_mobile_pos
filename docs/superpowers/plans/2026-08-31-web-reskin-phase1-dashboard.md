# Web Admin Reskin — Phase 1: Tokens, Component Library, Dashboard

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the new admin skin from `design/MAKI POS Dashboard - Spec.md` — CSS-variable design tokens with light/dark themes, the shared §7 component library, and a complete Dashboard rebuild as the reference screen.

**Architecture:** A new `theme.css` holds every color token as a CSS custom property on `:root` with a `[data-theme="dark"]` override; Tailwind maps semantic class names (`bg-surface`, `text-ink-2`, `text-pos`…) onto those variables so dark mode needs zero `dark:` classes. A new `src/presentation/components/ui/` directory holds the shared primitives (Button, Badge, Card, StatCard, DataTable, charts, Toast, CopyButton…). The Dashboard is rebuilt purely from those primitives plus three new pure domain functions (hourly bucketing, inventory summary, delta math) and one new repository (drawer/register state read path). Legacy screens keep working untouched — they get the new fonts and page background immediately, and are restyled screen-by-screen in later phases.

**Tech Stack:** React 18, TypeScript, Vite 6, Tailwind 3.4, IBM Plex Sans/Mono via @fontsource, @heroicons/react 24/outline (per user decision — NOT lucide), Vitest 2 + RTL, Firestore via the existing DI container.

**Spec:** `design/MAKI POS Dashboard - Spec.md` (the referenced `MAKI POS Dashboard.dc.html` does not exist anywhere — the spec text is the sole authority).

## Global Constraints

- **Working dir:** all commands run from `web_admin/` unless prefixed. Branch: `feat/web-reskin-dashboard` (create in Task 1).
- **Icons: `@heroicons/react/24/outline` only.** The user explicitly overrode any lucide idea. Never add lucide-react.
- **Tokens only in new code**: no literal hex, no raw px font-size, radius, or shadow in any `ui/` component or the rebuilt Dashboard/shell. Colors via the semantic Tailwind classes below; font sizes via the named `text-*` scale; radii via `rounded-card|ctl|field|pill|chip`; shadow via `shadow-card`. (Arbitrary px for *spacing/dimensions* — `py-[7px]`, `h-[22px]` — is allowed; the spec's ban covers colors, font sizes, radii, shadows.)
- **`--accent-line` is a fill, never a `color:`** (spec §2 rule 1). Only `text-accent-text` may put amber on text.
- **No CSS `transition` on `background` for any element whose background comes from a `var()`** (spec §2 rule 2). Use `transition-[color]`, `transition-opacity`, or none. `transition-colors` is banned in the new components.
- **Every data numeral is IBM Plex Mono** (`font-mono`): money, counts, percentages, sale numbers, times, SKUs. Large figures add the `tnum` class.
- **ui/ components accept no `className`/`style` props** (spec §7: no escape hatch). New looks become variants in the library.
- **Conventions:** named exports, function declarations, `import type`, colocated `*.test.tsx`, `@/` path alias, PascalCase component files.
- **Existing helpers to reuse, never re-implement:** `formatMoney` (`@/core/utils/money`), `summarizeSales` (`@/domain/sales/summarizeSales`), `shopTimeOf/shopStartOfDay/shopEndOfDay/shopDayInt/shopDateKey/formatInShopZone` (`@/domain/time/shopTime`), `saleGrandTotal/saleIsVoided/saleTotalItemCount` (`@/domain/entities`), `getStockStatus` (`@/domain/entities`), `hasPermission` (`@/domain/permissions/Permission`), `canAccess` (`@/presentation/router/routeGuards`).
- **Verification gate per task:** `npm run typecheck` and the task's tests must pass before its commit. Task 17 runs the full suite + build.
- **Do NOT touch:** `firestore.rules`, any Firestore write path, the `@media print` block in `index.css`, `PayslipCard.tsx` (intentionally out-of-system), any legacy screen except where a task names it.
- **Deferred to Phase 2+ (do not build now):** FilterBar, TableViews, SelectFilter/SegmentedFilter/DateRangeFilter/Toggle, Drawer reskin, LineChart, MiniBar, DataTable sort/pagination/selection, `?filter=` deep links on Inventory, sale-detail drawer, restyling the 12 rollout screens. The spec's "never screen-local" rule is honored by adding these to the library when the first screen needs them.

---

### Task 1: Design tokens, fonts, Tailwind mapping

**Files:**
- Create: `src/core/theme/theme.css`
- Modify: `tailwind.config.ts`, `src/index.css`, `index.html`, `package.json` (two @fontsource deps)

**Interfaces:**
- Produces (for every later task): Tailwind classes `bg-bg`, `bg-surface`, `bg-surface-2`, `bg-surface-3`, `border-line`, `border-line-2`, `text-ink`, `text-ink-2`, `text-ink-3`, `bg-accent`, `text-accent-ink`, `bg-accent-soft`, `bg-accent-line`, `text-accent-text`, `text-pos`, `bg-pos`, `bg-pos-soft`, `text-neg`, `bg-neg`, `bg-neg-soft`; `shadow-card`; `rounded-card` (14px) / `rounded-ctl` (10px) / `rounded-field` (9px) / `rounded-pill` (20px) / `rounded-chip` (6px); `w-sidebar` (248px); font sizes `text-page-title`, `text-page-sub`, `text-card-title`, `text-kpi`, `text-kpi-label`, `text-micro`, `text-micro-caps`, `text-group-caps`, `text-cell`, `text-amount`, `text-nav`, `text-pill`, `text-axis`, `text-inv-figure`, `text-brand`, `text-ctl-sm`, `text-ctl-md`; utility class `tnum`; CSS var `--radius-bar`.

- [ ] **Step 1: Branch**

```bash
cd /Users/czar/dev/MAKI_Mobile_POS/maki_mobile_pos && git checkout -b feat/web-reskin-dashboard
```

- [ ] **Step 2: Install fonts**

```bash
cd web_admin && npm install @fontsource/ibm-plex-sans @fontsource/ibm-plex-mono
```

- [ ] **Step 3: Create `src/core/theme/theme.css`** — every §2 value, verbatim:

```css
/* Design tokens — spec: design/MAKI POS Dashboard - Spec.md §2.
   The ONLY file in the app allowed to contain literal color values for the
   new skin. Light is the default; dark overrides under [data-theme="dark"]. */
:root {
  --bg: #f3f5f7;
  --surface: #ffffff;
  --surface-2: #f8fafb;
  --surface-3: #eef1f4;
  --border: #e4e8ed;
  --border-2: #eef1f4;
  --text: #14171c;
  --text-2: #69727f;
  --text-3: #98a1ad;
  --accent: #f2c418;
  --accent-ink: #1d1a08;
  --accent-soft: #fdf4d2;
  --accent-line: #e0b200;
  --accent-text: #8a6300;
  --pos: #12866a;
  --pos-soft: #e3f4ef;
  --neg: #c04b38;
  --neg-soft: #fbeae6;
  --shadow: 0 1px 2px rgba(16, 24, 40, 0.04), 0 10px 28px -12px rgba(16, 24, 40, 0.1);
  --radius-bar: 6px 6px 3px 3px;
}

:root[data-theme='dark'] {
  --bg: #0d0f12;
  --surface: #15181d;
  --surface-2: #1a1e24;
  --surface-3: #222731;
  --border: #252b34;
  --border-2: #1e232a;
  --text: #eceff3;
  --text-2: #98a1ad;
  --text-3: #6a7482;
  --accent: #f2c418;
  --accent-ink: #1d1a08;
  --accent-soft: #332a0a;
  --accent-line: #f0c53a;
  --accent-text: #f0c53a;
  --pos: #3fc79f;
  --pos-soft: #132a25;
  --neg: #e5806c;
  --neg-soft: #2c1a17;
  --shadow: 0 1px 2px rgba(0, 0, 0, 0.4), 0 10px 28px -12px rgba(0, 0, 0, 0.6);
}

/* Tabular numerals for large aligned figures (spec §1). */
.tnum {
  font-feature-settings: 'tnum';
}
```

- [ ] **Step 4: Map into Tailwind** — edit `tailwind.config.ts`. Inside `theme.extend`, replace the `colors`, `fontFamily`, `fontSize`, and `width` entries and add `borderRadius`/`boxShadow` as follows (keep every legacy key that isn't shown — `light`, `dark`, `success*`, `warning*`, `error*`, `info*`, `role`, `primary-dark`, `primary-accent`, `brand-slate`, the `tk-*` spacing, `height.topbar`, `maxWidth.content`, `sidebar-extended`/`sidebar-collapsed` widths, the plugin list):

```ts
      colors: {
        // …all existing legacy keys stay exactly as they are, EXCEPT `pos`
        // which is merged below…

        // ---- New skin: semantic names over CSS variables (theme.css) ----
        bg: 'var(--bg)',
        surface: { DEFAULT: 'var(--surface)', 2: 'var(--surface-2)', 3: 'var(--surface-3)' },
        line: { DEFAULT: 'var(--border)', 2: 'var(--border-2)' },
        ink: { DEFAULT: 'var(--text)', 2: 'var(--text-2)', 3: 'var(--text-3)' },
        accent: {
          DEFAULT: 'var(--accent)',
          ink: 'var(--accent-ink)',
          soft: 'var(--accent-soft)',
          line: 'var(--accent-line)', // fill/stroke ONLY — never text (spec §2)
          text: 'var(--accent-text)',
        },
        pos: { DEFAULT: 'var(--pos)', soft: 'var(--pos-soft)', ...colors.pos },
        neg: { DEFAULT: 'var(--neg)', soft: 'var(--neg-soft)' },
      },
      borderRadius: {
        card: '14px',
        ctl: '10px',
        field: '9px',
        pill: '20px',
        chip: '6px',
      },
      boxShadow: {
        card: 'var(--shadow)',
      },
      width: {
        'sidebar-extended': layout.sidebarExtended,
        'sidebar-collapsed': layout.sidebarCollapsed,
        sidebar: '248px',
      },
      fontFamily: {
        sans: ['IBM Plex Sans', 'system-ui', 'sans-serif'],
        mono: ['IBM Plex Mono', 'ui-monospace', 'Menlo', 'monospace'],
      },
      fontSize: {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ...(fontSize as any), // legacy named scale, untouched
        // ---- New skin type scale (spec §1) ----
        'page-title': ['20px', { lineHeight: '28px', letterSpacing: '-0.4px', fontWeight: '600' }],
        'page-sub': ['12.5px', { lineHeight: '18px' }],
        'card-title': ['14px', { lineHeight: '20px', letterSpacing: '-0.15px', fontWeight: '600' }],
        kpi: ['23px', { lineHeight: '28px', letterSpacing: '-1px', fontWeight: '600' }],
        'kpi-label': ['11.5px', { lineHeight: '16px', fontWeight: '500' }],
        micro: ['10.5px', { lineHeight: '14px' }],
        'micro-caps': ['10px', { lineHeight: '14px', letterSpacing: '1px', fontWeight: '600' }],
        'group-caps': ['10px', { lineHeight: '14px', letterSpacing: '1.1px', fontWeight: '600' }],
        cell: ['12.5px', { lineHeight: '18px' }],
        amount: ['13px', { lineHeight: '18px', fontWeight: '600' }],
        nav: ['13.5px', { lineHeight: '20px', fontWeight: '500' }],
        pill: ['11px', { lineHeight: '14px', fontWeight: '500' }],
        axis: ['10px', { lineHeight: '12px' }],
        'inv-figure': ['14px', { lineHeight: '18px', fontWeight: '600' }],
        brand: ['14px', { lineHeight: '20px', letterSpacing: '0.3px', fontWeight: '600' }],
        'ctl-sm': ['12px', { lineHeight: '16px' }],
        'ctl-md': ['12.5px', { lineHeight: '18px' }],
      },
```

Note the merged `pos` entry replaces the old `pos: colors.pos` line — legacy classes like `bg-pos-cash` keep working via the spread.

- [ ] **Step 5: Rewire `src/index.css`** — replace the four `@fontsource/roboto` imports with:

```css
@import '@fontsource/ibm-plex-sans/400.css';
@import '@fontsource/ibm-plex-sans/500.css';
@import '@fontsource/ibm-plex-sans/600.css';
@import '@fontsource/ibm-plex-sans/700.css';
@import '@fontsource/ibm-plex-mono/400.css';
@import '@fontsource/ibm-plex-mono/500.css';
@import '@fontsource/ibm-plex-mono/600.css';
@import './core/theme/theme.css';
```

and change the base body rule to `body { @apply font-sans text-ink bg-bg; }`. **Keep the `@media print` block byte-for-byte.**

- [ ] **Step 6: `index.html`** — change the body tag to `<body class="antialiased">` (colors now come from CSS), and add this pre-paint theme script as the FIRST child of `<head>` so a dark-mode user never sees a light flash:

```html
<script>
  try { if (localStorage.getItem('maki-pos-theme') === 'dark') document.documentElement.setAttribute('data-theme', 'dark'); } catch (e) {}
</script>
```

- [ ] **Step 7: Verify**

Run: `npm run typecheck && npm run test && npm run build`
Expected: all pass (no component uses the new classes yet; legacy tests unaffected — if any legacy test asserted the Roboto font or `bg-light-background` on body, fix that test to the new expectation and note it in the commit).

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat(web): design tokens, IBM Plex fonts, semantic Tailwind mapping"
```

---

### Task 2: ThemeProvider

**Files:**
- Create: `src/core/theme/ThemeProvider.tsx`
- Test: `src/core/theme/ThemeProvider.test.tsx`
- Modify: `src/main.tsx` (wrap `<App />`)

**Interfaces:**
- Produces: `ThemeProvider({ children })`, `useTheme(): { theme: 'light' | 'dark'; toggleTheme: () => void }`. Storage key `maki-pos-theme`. Attribute `data-theme` on `document.documentElement` (absent = light).

- [ ] **Step 1: Write the failing test**

```tsx
import { afterEach, describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ThemeProvider, useTheme } from './ThemeProvider';

function Probe() {
  const { theme, toggleTheme } = useTheme();
  return <button onClick={toggleTheme}>{theme}</button>;
}

afterEach(() => {
  localStorage.clear();
  document.documentElement.removeAttribute('data-theme');
});

describe('ThemeProvider', () => {
  it('defaults to light with no attribute', () => {
    render(<ThemeProvider><Probe /></ThemeProvider>);
    expect(screen.getByRole('button')).toHaveTextContent('light');
    expect(document.documentElement.getAttribute('data-theme')).toBeNull();
  });

  it('toggle flips to dark, sets the attribute inside the handler, persists', async () => {
    render(<ThemeProvider><Probe /></ThemeProvider>);
    await userEvent.click(screen.getByRole('button'));
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
    expect(localStorage.getItem('maki-pos-theme')).toBe('dark');
    await userEvent.click(screen.getByRole('button'));
    expect(document.documentElement.getAttribute('data-theme')).toBeNull();
    expect(localStorage.getItem('maki-pos-theme')).toBe('light');
  });

  it('initializes from a stored dark preference', () => {
    localStorage.setItem('maki-pos-theme', 'dark');
    render(<ThemeProvider><Probe /></ThemeProvider>);
    expect(screen.getByRole('button')).toHaveTextContent('dark');
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
  });
});
```

- [ ] **Step 2: Run to verify failure** — `npm run test -- ThemeProvider` → FAIL (module not found).

- [ ] **Step 3: Implement `src/core/theme/ThemeProvider.tsx`**

```tsx
// Owns data-theme on <html> and the localStorage round trip (spec §4).
// The attribute is applied INSIDE the state setter, never in an effect —
// the spec calls update-lifecycle application unreliable in this runtime.
import { createContext, useCallback, useContext, useState, type ReactNode } from 'react';

export type Theme = 'light' | 'dark';

const STORAGE_KEY = 'maki-pos-theme';

function readStoredTheme(): Theme {
  try {
    return localStorage.getItem(STORAGE_KEY) === 'dark' ? 'dark' : 'light';
  } catch {
    return 'light';
  }
}

function applyTheme(theme: Theme): void {
  if (theme === 'dark') document.documentElement.setAttribute('data-theme', 'dark');
  else document.documentElement.removeAttribute('data-theme');
}

const ThemeContext = createContext<{ theme: Theme; toggleTheme: () => void } | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<Theme>(() => {
    const initial = readStoredTheme();
    applyTheme(initial);
    return initial;
  });

  const toggleTheme = useCallback(() => {
    setTheme((prev) => {
      const next: Theme = prev === 'dark' ? 'light' : 'dark';
      applyTheme(next);
      try {
        localStorage.setItem(STORAGE_KEY, next);
      } catch {
        // Private mode — theme still flips for this session.
      }
      return next;
    });
  }, []);

  return <ThemeContext.Provider value={{ theme, toggleTheme }}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used inside ThemeProvider');
  return ctx;
}
```

In `src/main.tsx`, wrap: `<ThemeProvider><DiProvider>…</DiProvider></ThemeProvider>` (import from `@/core/theme/ThemeProvider`).

- [ ] **Step 4: Run** — `npm run test -- ThemeProvider` → PASS; `npm run typecheck` → clean.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): ThemeProvider with persisted data-theme switching"`

---

### Task 3: Button + IconButton

**Files:**
- Create: `src/presentation/components/ui/Button.tsx`, `src/presentation/components/ui/IconButton.tsx`
- Test: `src/presentation/components/ui/Button.test.tsx`

**Interfaces:**
- Produces: `Button({ variant?: 'primary'|'secondary'|'ghost'|'danger', size?: 'sm'|'md', icon?: ReactNode, loading?: boolean, ...ButtonHTMLAttributes })` (no className/style); `IconButton({ title: string, size?: 22|28, ...ButtonHTMLAttributes })` — `title` required, renders `aria-label` too.

- [ ] **Step 1: Write the failing test**

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Button } from './Button';
import { IconButton } from './IconButton';

describe('Button', () => {
  it('fires onClick', async () => {
    const onClick = vi.fn();
    render(<Button variant="primary" onClick={onClick}>New sale</Button>);
    await userEvent.click(screen.getByRole('button', { name: 'New sale' }));
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('is disabled while loading and shows no icon slot content', () => {
    render(<Button loading icon={<svg data-testid="icon" />}>Save</Button>);
    const btn = screen.getByRole('button');
    expect(btn).toBeDisabled();
    expect(screen.queryByTestId('icon')).not.toBeInTheDocument();
  });

  it('disabled blocks clicks', async () => {
    const onClick = vi.fn();
    render(<Button disabled onClick={onClick}>Save</Button>);
    await userEvent.click(screen.getByRole('button')).catch(() => {});
    expect(onClick).not.toHaveBeenCalled();
  });
});

describe('IconButton', () => {
  it('always exposes its title as accessible name', () => {
    render(<IconButton title="Copy sale number"><svg /></IconButton>);
    expect(screen.getByRole('button', { name: 'Copy sale number' })).toHaveAttribute('title', 'Copy sale number');
  });
});
```

- [ ] **Step 2: Run to fail** — `npm run test -- ui/Button` → FAIL.

- [ ] **Step 3: Implement**

`src/presentation/components/ui/Button.tsx`:

```tsx
import { clsx } from 'clsx';
import type { ButtonHTMLAttributes, ReactNode } from 'react';
import { Spinner } from '../common/LoadingView';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
export type ButtonSize = 'sm' | 'md';

const variantCls: Record<ButtonVariant, string> = {
  primary: 'bg-accent text-accent-ink font-semibold hover:brightness-95',
  secondary: 'border border-line bg-surface text-ink-2 hover:text-ink',
  ghost: 'bg-transparent text-ink-2 hover:bg-surface-2',
  danger: 'bg-neg-soft font-medium text-neg hover:brightness-95',
};

const sizeCls: Record<ButtonSize, string> = {
  sm: 'px-3 py-[7px] text-ctl-sm',
  md: 'px-3.5 py-[9px] text-ctl-md',
};

export interface ButtonProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className' | 'style'> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  icon?: ReactNode;
  loading?: boolean;
}

export function Button({
  variant = 'secondary',
  size = 'md',
  icon,
  loading = false,
  disabled,
  children,
  type = 'button',
  ...rest
}: ButtonProps) {
  return (
    <button
      type={type}
      disabled={disabled || loading}
      className={clsx(
        'inline-flex items-center justify-center gap-1.5 whitespace-nowrap rounded-ctl font-medium transition-opacity',
        variantCls[variant],
        sizeCls[size],
        (disabled || loading) && 'pointer-events-none opacity-50',
      )}
      {...rest}
    >
      {loading ? <Spinner className="h-3.5 w-3.5" /> : icon}
      {children}
    </button>
  );
}
```

`src/presentation/components/ui/IconButton.tsx`:

```tsx
import { clsx } from 'clsx';
import type { ButtonHTMLAttributes } from 'react';

export interface IconButtonProps
  extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className' | 'style' | 'title'> {
  /** Required — becomes both tooltip and accessible name. */
  title: string;
  size?: 22 | 28;
}

export function IconButton({ title, size = 22, children, type = 'button', ...rest }: IconButtonProps) {
  return (
    <button
      type={type}
      title={title}
      aria-label={title}
      className={clsx(
        'inline-flex shrink-0 items-center justify-center rounded-chip text-ink-3 transition-[color] hover:bg-surface-3 hover:text-ink-2',
        size === 22 ? 'h-[22px] w-[22px]' : 'h-7 w-7',
      )}
      {...rest}
    >
      {children}
    </button>
  );
}
```

- [ ] **Step 4: Run** — `npm run test -- ui/Button` → PASS; `npm run typecheck` → clean.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): Button and IconButton primitives"`

---

### Task 4: Badge + statusTone

**Files:**
- Create: `src/presentation/components/ui/Badge.tsx`, `src/presentation/components/ui/statusTone.ts`
- Test: `src/presentation/components/ui/Badge.test.tsx`, `src/presentation/components/ui/statusTone.test.ts`

**Interfaces:**
- Produces: `type Tone = 'positive'|'warning'|'negative'|'neutral'`; `Badge({ tone?, shape?: 'pill'|'chip', children })`; `statusTone(status: string): Tone` — the single domain-status→tone mapping for the whole admin.

- [ ] **Step 1: Write the failing tests**

`statusTone.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { statusTone } from './statusTone';

describe('statusTone', () => {
  it('maps sale statuses per spec §5.6', () => {
    expect(statusTone('completed')).toBe('positive');
    expect(statusTone('Completed')).toBe('positive');
    expect(statusTone('pending')).toBe('warning');
    expect(statusTone('refunded')).toBe('negative');
    expect(statusTone('voided')).toBe('neutral');
  });
  it('falls back to neutral for unknown statuses', () => {
    expect(statusTone('sideways')).toBe('neutral');
  });
});
```

`Badge.test.tsx`:

```tsx
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Badge } from './Badge';

describe('Badge', () => {
  it('renders its content', () => {
    render(<Badge tone="positive">Completed</Badge>);
    expect(screen.getByText('Completed')).toBeInTheDocument();
  });
  it('chip shape renders mono for counts and deltas', () => {
    render(<Badge tone="neutral" shape="chip">+8.2%</Badge>);
    expect(screen.getByText('+8.2%').className).toContain('font-mono');
  });
});
```

- [ ] **Step 2: Run to fail** — `npm run test -- ui/Badge ui/statusTone` → FAIL.

- [ ] **Step 3: Implement**

`Badge.tsx`:

```tsx
import { clsx } from 'clsx';
import type { ReactNode } from 'react';

export type Tone = 'positive' | 'warning' | 'negative' | 'neutral';
export type BadgeShape = 'pill' | 'chip';

const toneCls: Record<Tone, string> = {
  positive: 'bg-pos-soft text-pos',
  warning: 'bg-accent-soft text-accent-text',
  negative: 'bg-neg-soft text-neg',
  neutral: 'bg-surface-3 text-ink-3',
};

export function Badge({
  tone = 'neutral',
  shape = 'pill',
  children,
}: {
  tone?: Tone;
  shape?: BadgeShape;
  children: ReactNode;
}) {
  return (
    <span
      className={clsx(
        'inline-flex items-center whitespace-nowrap',
        shape === 'pill'
          ? 'rounded-pill px-2.5 py-0.5 text-pill'
          : 'rounded-chip px-1.5 py-0.5 font-mono text-micro font-semibold',
        toneCls[tone],
      )}
    >
      {children}
    </span>
  );
}
```

`statusTone.ts`:

```ts
// The ONE domain-status → tone mapping (spec §7 Badge). "Completed" is the
// same green in the sales table, job order list and drawer because every
// screen routes through this function.
import type { Tone } from './Badge';

const TONE_BY_STATUS: Record<string, Tone> = {
  completed: 'positive',
  approved: 'positive',
  received: 'positive',
  pending: 'warning',
  open: 'warning',
  partial: 'warning',
  refunded: 'negative',
  rejected: 'negative',
  cancelled: 'negative',
  voided: 'neutral',
  draft: 'neutral',
};

export function statusTone(status: string): Tone {
  return TONE_BY_STATUS[status.toLowerCase()] ?? 'neutral';
}
```

- [ ] **Step 4: Run** — PASS + typecheck clean.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): Badge primitive and the statusTone mapping"`

---

### Task 5: Toast system

**Files:**
- Create: `src/presentation/components/ui/toast.ts`, `src/presentation/components/ui/Toaster.tsx`
- Test: `src/presentation/components/ui/Toaster.test.tsx`

**Interfaces:**
- Produces: imperative singleton `toast.success(message, detail?)`, `toast.error(message, detail?)`, `toast.info(message, detail?)`; `<Toaster />` (mounted once in AppShell, Task 15). One toast at a time; ~1.9s auto-dismiss; a second toast replaces content and resets the timer.

- [ ] **Step 1: Write the failing test**

```tsx
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, render, screen } from '@testing-library/react';
import { toast } from './toast';
import { Toaster } from './Toaster';

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

describe('Toaster', () => {
  it('shows a success toast with mono detail, then auto-dismisses', () => {
    render(<Toaster />);
    act(() => toast.success('Copied to clipboard', 'SALE-20260831-027'));
    expect(screen.getByRole('status')).toHaveTextContent('Copied to clipboard');
    expect(screen.getByText('SALE-20260831-027')).toBeInTheDocument();
    act(() => vi.advanceTimersByTime(2000));
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
  });

  it('a second toast replaces the first and resets the timer', () => {
    render(<Toaster />);
    act(() => toast.success('Copied to clipboard', 'A'));
    act(() => vi.advanceTimersByTime(1500));
    act(() => toast.success('Copied to clipboard', 'B'));
    act(() => vi.advanceTimersByTime(1500));
    // 3s after the first, but only 1.5s after the second — still visible, showing B.
    expect(screen.getByText('B')).toBeInTheDocument();
    expect(screen.queryByText('A')).not.toBeInTheDocument();
    act(() => vi.advanceTimersByTime(500));
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run to fail** — `npm run test -- ui/Toaster` → FAIL.

- [ ] **Step 3: Implement**

`toast.ts`:

```ts
// Imperative toast singleton (spec §7 Toast). The Toaster component
// subscribes; anything in the app may fire.
export type ToastTone = 'success' | 'error' | 'info';

export interface ToastPayload {
  tone: ToastTone;
  message: string;
  detail?: string;
}

type Listener = (payload: ToastPayload) => void;

let listener: Listener | null = null;

function emit(tone: ToastTone, message: string, detail?: string): void {
  listener?.({ tone, message, detail });
}

export const toast = {
  success: (message: string, detail?: string) => emit('success', message, detail),
  error: (message: string, detail?: string) => emit('error', message, detail),
  info: (message: string, detail?: string) => emit('info', message, detail),
  /** @internal Toaster only. */
  _subscribe(next: Listener): () => void {
    listener = next;
    return () => {
      if (listener === next) listener = null;
    };
  },
};
```

`Toaster.tsx`:

```tsx
import { useEffect, useRef, useState } from 'react';
import { CheckCircleIcon, InformationCircleIcon, XCircleIcon } from '@heroicons/react/24/outline';
import { toast, type ToastPayload } from './toast';

const DISMISS_MS = 1900;

const toneIcon = {
  success: <CheckCircleIcon className="h-4 w-4 shrink-0 text-pos" />,
  error: <XCircleIcon className="h-4 w-4 shrink-0 text-neg" />,
  info: <InformationCircleIcon className="h-4 w-4 shrink-0 text-ink-2" />,
} as const;

export function Toaster() {
  const [current, setCurrent] = useState<ToastPayload | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const unsubscribe = toast._subscribe((payload) => {
      setCurrent(payload);
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(() => setCurrent(null), DISMISS_MS);
    });
    return () => {
      unsubscribe();
      if (timer.current) clearTimeout(timer.current);
    };
  }, []);

  if (!current) return null;
  return (
    <div
      role="status"
      className="fixed bottom-6 left-1/2 z-50 flex -translate-x-1/2 items-center gap-2 rounded-[12px] border border-line bg-surface px-4 py-2.5 shadow-card"
    >
      {toneIcon[current.tone]}
      <span className="text-ctl-md font-medium text-ink">{current.message}</span>
      {current.detail && <span className="font-mono text-ctl-md text-ink-3">{current.detail}</span>}
    </div>
  );
}
```

- [ ] **Step 4: Run** — PASS + typecheck.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): global toast singleton and Toaster"`

---

### Task 6: CopyButton

**Files:**
- Create: `src/presentation/components/ui/CopyButton.tsx`
- Test: `src/presentation/components/ui/CopyButton.test.tsx`

**Interfaces:**
- Consumes: `IconButton` (Task 3), `toast` (Task 5).
- Produces: `CopyButton({ value: string, label: string })` — title `Copy {label}`, clipboard write in try/catch, `stopPropagation`, success toast with the value as mono detail. Goes beside every machine identifier on the site.

- [ ] **Step 1: Write the failing test**

```tsx
import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { CopyButton } from './CopyButton';
import { Toaster } from './Toaster';

afterEach(() => vi.restoreAllMocks());

function mockClipboard(impl: (v: string) => Promise<void>) {
  Object.assign(navigator, { clipboard: { writeText: vi.fn(impl) } });
  return navigator.clipboard.writeText as ReturnType<typeof vi.fn>;
}

describe('CopyButton', () => {
  it('copies the value and toasts with it', async () => {
    const write = mockClipboard(() => Promise.resolve());
    render(<><CopyButton value="SALE-20260831-027" label="sale number" /><Toaster /></>);
    await userEvent.click(screen.getByRole('button', { name: 'Copy sale number' }));
    expect(write).toHaveBeenCalledWith('SALE-20260831-027');
    expect(await screen.findByRole('status')).toHaveTextContent('Copied to clipboard');
    expect(screen.getByText('SALE-20260831-027')).toBeInTheDocument();
  });

  it('does not trigger the row click around it', async () => {
    mockClipboard(() => Promise.resolve());
    const rowClick = vi.fn();
    render(<div onClick={rowClick}><CopyButton value="X" label="SKU" /></div>);
    await userEvent.click(screen.getByRole('button', { name: 'Copy SKU' }));
    expect(rowClick).not.toHaveBeenCalled();
  });

  it('survives a clipboard failure (insecure origin) with an error toast', async () => {
    mockClipboard(() => Promise.reject(new Error('denied')));
    render(<><CopyButton value="X" label="SKU" /><Toaster /></>);
    await userEvent.click(screen.getByRole('button', { name: 'Copy SKU' }));
    expect(await screen.findByRole('status')).toHaveTextContent('Copy failed');
  });
});
```

- [ ] **Step 2: Run to fail** — FAIL.

- [ ] **Step 3: Implement `CopyButton.tsx`**

```tsx
// Copy affordance for machine identifiers (spec §5.7). Sits beside every
// sale no., JO no., SKU, supplier code and batch/serial across the admin.
import type { MouseEvent } from 'react';
import { Square2StackIcon } from '@heroicons/react/24/outline';
import { IconButton } from './IconButton';
import { toast } from './toast';

export function CopyButton({ value, label }: { value: string; label: string }) {
  async function handleClick(event: MouseEvent<HTMLButtonElement>) {
    event.stopPropagation();
    try {
      await navigator.clipboard.writeText(value);
      toast.success('Copied to clipboard', value);
    } catch {
      toast.error('Copy failed', value);
    }
  }

  return (
    <IconButton title={`Copy ${label}`} onClick={handleClick}>
      <Square2StackIcon className="h-[13px] w-[13px]" />
    </IconButton>
  );
}
```

- [ ] **Step 4: Run** — PASS + typecheck.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): CopyButton with clipboard + toast"`

---

### Task 7: EmptyState, Skeleton, ErrorState (ui)

**Files:**
- Create: `src/presentation/components/ui/EmptyState.tsx`, `src/presentation/components/ui/Skeleton.tsx`, `src/presentation/components/ui/ErrorState.tsx`
- Test: `src/presentation/components/ui/states.test.tsx`

**Interfaces:**
- Produces: `EmptyState({ message: string, action?: ReactNode })`; `Skeleton({ width?: string, height?: string })` (CSS length strings, defaults `100%`/`14px`); `ErrorState({ message?: string, onRetry?: () => void })`.
- Note: legacy `common/EmptyState` & `common/ErrorView` stay for legacy screens; these ui/ versions are the go-forward set and replace them screen-by-screen during rollout.

- [ ] **Step 1: Write the failing test**

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { EmptyState } from './EmptyState';
import { ErrorState } from './ErrorState';
import { Skeleton } from './Skeleton';

describe('ui states', () => {
  it('EmptyState shows message and optional action', () => {
    render(<EmptyState message="No sales yet" action={<button>New sale</button>} />);
    expect(screen.getByText('No sales yet')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'New sale' })).toBeInTheDocument();
  });
  it('ErrorState wires Retry', async () => {
    const onRetry = vi.fn();
    render(<ErrorState message="Load failed" onRetry={onRetry} />);
    await userEvent.click(screen.getByRole('button', { name: 'Retry' }));
    expect(onRetry).toHaveBeenCalledOnce();
  });
  it('Skeleton takes explicit dimensions', () => {
    const { container } = render(<Skeleton width="120px" height="23px" />);
    const el = container.firstElementChild as HTMLElement;
    expect(el.style.width).toBe('120px');
    expect(el.style.height).toBe('23px');
  });
});
```

- [ ] **Step 2: Run to fail** — FAIL.

- [ ] **Step 3: Implement**

`EmptyState.tsx`:

```tsx
import type { ReactNode } from 'react';

export function EmptyState({ message, action }: { message: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-11 text-center">
      <p className="text-cell text-ink-3">{message}</p>
      {action}
    </div>
  );
}
```

`Skeleton.tsx`:

```tsx
// Loading placeholder at the real content's dimensions — never a spinner
// inside a card (spec §7).
export function Skeleton({ width = '100%', height = '14px' }: { width?: string; height?: string }) {
  return <div aria-hidden className="animate-pulse rounded-chip bg-surface-3" style={{ width, height }} />;
}
```

`ErrorState.tsx`:

```tsx
import { Button } from './Button';

export function ErrorState({
  message = 'Something went wrong.',
  onRetry,
}: {
  message?: string;
  onRetry?: () => void;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-11 text-center">
      <p className="text-cell text-neg">{message}</p>
      {onRetry && (
        <Button variant="secondary" size="sm" onClick={onRetry}>
          Retry
        </Button>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Run** — PASS + typecheck.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): ui EmptyState, Skeleton, ErrorState"`

---

### Task 8: Card + StatCard

**Files:**
- Create: `src/presentation/components/ui/Card.tsx`, `src/presentation/components/ui/StatCard.tsx`
- Test: `src/presentation/components/ui/StatCard.test.tsx`

**Interfaces:**
- Consumes: `Badge`/`Tone` (Task 4), `Skeleton` (Task 7), `formatMoney`.
- Produces:
  - `Card({ title?, subtitle?, headerAction?, padding?: 'sm'|'md', children })` — surface, `border-line`, `rounded-card`, `shadow-card`.
  - `StatCard({ label, value, format: 'currency'|'number'|'percent', delta?: number|null, chip?: { label: string; tone: Tone }, note?, loading? })`. `delta` is a signed fraction (0.082 → `+8.2%` chip, tone by sign); an explicit `chip` (e.g. `{label:'58.7% of gross', tone:'neutral'}`) wins over `delta`. This adapts the spec's `delta`/`deltaTone` pair into one honest contract.

- [ ] **Step 1: Write the failing test**

```tsx
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { StatCard } from './StatCard';

describe('StatCard', () => {
  it('formats currency in mono with the peso sign', () => {
    render(<StatCard label="Gross Sales" value={8945} format="currency" />);
    expect(screen.getByText('Gross Sales')).toBeInTheDocument();
    const figure = screen.getByText('₱8,945.00');
    expect(figure.className).toContain('font-mono');
  });

  it('renders a signed positive delta chip', () => {
    render(<StatCard label="Sales today" value={27} format="number" delta={0.082} />);
    expect(screen.getByText('+8.2%')).toBeInTheDocument();
  });

  it('renders a negative delta chip', () => {
    render(<StatCard label="Avg order" value={370.37} format="currency" delta={-0.041} />);
    expect(screen.getByText('-4.1%')).toBeInTheDocument();
  });

  it('an explicit neutral ratio chip wins over delta', () => {
    render(
      <StatCard label="Total COGS" value={5246} format="currency" delta={0.5} chip={{ label: '58.7% of gross', tone: 'neutral' }} />,
    );
    expect(screen.getByText('58.7% of gross')).toBeInTheDocument();
    expect(screen.queryByText('+50.0%')).not.toBeInTheDocument();
  });

  it('shows a skeleton while loading', () => {
    render(<StatCard label="Gross Sales" value={0} format="currency" loading />);
    expect(screen.queryByText('₱0.00')).not.toBeInTheDocument();
  });

  it('hides the chip when there is no prior-day baseline', () => {
    render(<StatCard label="Sales today" value={27} format="number" delta={null} />);
    expect(screen.queryByText(/%/)).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run to fail** — FAIL.

- [ ] **Step 3: Implement**

`Card.tsx`:

```tsx
import { clsx } from 'clsx';
import type { ReactNode } from 'react';

export interface CardProps {
  title?: string;
  subtitle?: string;
  headerAction?: ReactNode;
  padding?: 'sm' | 'md';
  children: ReactNode;
}

export function Card({ title, subtitle, headerAction, padding = 'md', children }: CardProps) {
  const pad = padding === 'sm' ? 'p-4' : 'p-5';
  return (
    <section className="flex min-w-0 flex-col rounded-card border border-line bg-surface shadow-card">
      {(title || headerAction) && (
        <header className={clsx('flex items-start justify-between gap-3', pad, 'pb-0')}>
          <div className="min-w-0">
            {title && <h2 className="text-card-title text-ink">{title}</h2>}
            {subtitle && <p className="mt-0.5 text-kpi-label font-normal text-ink-3">{subtitle}</p>}
          </div>
          {headerAction && <div className="flex shrink-0 items-center gap-2">{headerAction}</div>}
        </header>
      )}
      <div className={clsx('min-w-0 flex-1', pad)}>{children}</div>
    </section>
  );
}
```

`StatCard.tsx`:

```tsx
import { formatMoney } from '@/core/utils/money';
import { Badge, type Tone } from './Badge';
import { Skeleton } from './Skeleton';

export type StatFormat = 'currency' | 'number' | 'percent';

export interface StatCardProps {
  label: string;
  value: number;
  format: StatFormat;
  /** Signed fraction vs the prior business day; null/undefined hides the chip. */
  delta?: number | null;
  /** Explicit chip (neutral ratios like "58.7% of gross") — overrides delta. */
  chip?: { label: string; tone: Tone };
  note?: string;
  loading?: boolean;
}

function formatValue(value: number, format: StatFormat): string {
  if (format === 'currency') return formatMoney(value);
  if (format === 'percent') return `${(value * 100).toFixed(1)}%`;
  return value.toLocaleString('en-PH');
}

function deltaChip(delta: number): { label: string; tone: Tone } {
  const pct = (delta * 100).toFixed(1);
  if (delta > 0) return { label: `+${pct}%`, tone: 'positive' };
  if (delta < 0) return { label: `${pct}%`, tone: 'negative' };
  return { label: '0.0%', tone: 'neutral' };
}

export function StatCard({ label, value, format, delta, chip, note, loading = false }: StatCardProps) {
  const resolvedChip = chip ?? (delta != null ? deltaChip(delta) : null);
  return (
    <section className="rounded-card border border-line bg-surface p-4 shadow-card">
      <div className="flex items-start justify-between gap-2">
        <span className="text-kpi-label text-ink-2">{label}</span>
        {!loading && resolvedChip && (
          <Badge tone={resolvedChip.tone} shape="chip">
            {resolvedChip.label}
          </Badge>
        )}
      </div>
      <div className="tnum mt-1.5 font-mono text-kpi text-ink">
        {loading ? <Skeleton width="90px" height="23px" /> : formatValue(value, format)}
      </div>
      {note && !loading && <p className="mt-1 text-micro text-ink-3">{note}</p>}
    </section>
  );
}
```

- [ ] **Step 4: Run** — PASS + typecheck.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): Card and StatCard primitives"`

---

### Task 9: SearchInput

**Files:**
- Create: `src/presentation/components/ui/SearchInput.tsx`
- Test: `src/presentation/components/ui/SearchInput.test.tsx`

**Interfaces:**
- Produces: `SearchInput({ value: string, onChange: (v: string) => void, placeholder?, debounce?: number /* default 250 */ })` — controlled from outside, emits debounced; shows a clear (×) button when non-empty which emits `''` immediately.

- [ ] **Step 1: Write the failing test**

```tsx
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, fireEvent, render, screen } from '@testing-library/react';
import { SearchInput } from './SearchInput';

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

describe('SearchInput', () => {
  it('debounces onChange by 250ms', () => {
    const onChange = vi.fn();
    render(<SearchInput value="" onChange={onChange} placeholder="Search sale no." />);
    fireEvent.change(screen.getByPlaceholderText('Search sale no.'), { target: { value: 'SALE' } });
    expect(onChange).not.toHaveBeenCalled();
    act(() => vi.advanceTimersByTime(250));
    expect(onChange).toHaveBeenCalledWith('SALE');
  });

  it('clear emits empty immediately', () => {
    const onChange = vi.fn();
    render(<SearchInput value="SALE" onChange={onChange} />);
    fireEvent.click(screen.getByRole('button', { name: 'Clear search' }));
    expect(onChange).toHaveBeenCalledWith('');
  });
});
```

- [ ] **Step 2: Run to fail** — FAIL.

- [ ] **Step 3: Implement `SearchInput.tsx`**

```tsx
import { useEffect, useRef, useState } from 'react';
import { MagnifyingGlassIcon, XMarkIcon } from '@heroicons/react/24/outline';

export interface SearchInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  debounce?: number;
}

export function SearchInput({ value, onChange, placeholder = 'Search', debounce = 250 }: SearchInputProps) {
  const [text, setText] = useState(value);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => setText(value), [value]);
  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);

  function handleInput(next: string) {
    setText(next);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => onChange(next), debounce);
  }

  function handleClear() {
    if (timer.current) clearTimeout(timer.current);
    setText('');
    onChange('');
  }

  return (
    <div className="flex items-center gap-1.5 rounded-field border border-line bg-surface-2 px-2.5 py-1.5">
      <MagnifyingGlassIcon className="h-3.5 w-3.5 shrink-0 text-ink-3" />
      <input
        value={text}
        onChange={(e) => handleInput(e.target.value)}
        placeholder={placeholder}
        className="w-40 bg-transparent text-ctl-sm text-ink outline-none placeholder:text-ink-3"
      />
      {text && (
        <button type="button" aria-label="Clear search" onClick={handleClear} className="text-ink-3 hover:text-ink-2">
          <XMarkIcon className="h-3.5 w-3.5" />
        </button>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Run** — PASS + typecheck.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): debounced SearchInput"`

---

### Task 10: DataTable

**Files:**
- Create: `src/presentation/components/ui/DataTable.tsx`
- Test: `src/presentation/components/ui/DataTable.test.tsx`

**Interfaces:**
- Consumes: `EmptyState`, `Skeleton` (Task 7).
- Produces:

```ts
export interface Column<T> {
  key: string;
  header: string;
  align?: 'left' | 'right' | 'center';
  width?: string;          // CSS width, e.g. '160px'
  mono?: boolean;          // IBM Plex Mono cell
  render: (row: T) => ReactNode;
}
export interface DataTableProps<T> {
  columns: Array<Column<T>>;
  rows: T[];
  rowKey: (row: T) => string;
  onRowClick?: (row: T) => void;
  loading?: boolean;
  skeletonRows?: number;   // default 8
  empty?: ReactNode;       // default <EmptyState message="Nothing here yet" />
}
export function DataTable<T>(props: DataTableProps<T>): JSX.Element
```

  (Sorting, pagination, selection are Phase-2 additions to this same component — the props land when the first rollout screen needs them.)

- [ ] **Step 1: Write the failing test**

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DataTable, type Column } from './DataTable';

interface Row { id: string; name: string; total: number }
const columns: Array<Column<Row>> = [
  { key: 'name', header: 'Name', render: (r) => r.name },
  { key: 'total', header: 'Total', align: 'right', mono: true, render: (r) => `₱${r.total}` },
];
const rows: Row[] = [
  { id: 'a', name: 'Brake shoe', total: 450 },
  { id: 'b', name: 'Bulb', total: 60 },
];

describe('DataTable', () => {
  it('renders headers and cells; numeric column is right-aligned mono', () => {
    render(<DataTable columns={columns} rows={rows} rowKey={(r) => r.id} />);
    expect(screen.getByText('Name')).toBeInTheDocument();
    const cell = screen.getByText('₱450');
    expect(cell.className).toContain('font-mono');
    expect(cell.className).toContain('text-right');
  });

  it('fires onRowClick with the row', async () => {
    const onRowClick = vi.fn();
    render(<DataTable columns={columns} rows={rows} rowKey={(r) => r.id} onRowClick={onRowClick} />);
    await userEvent.click(screen.getByText('Bulb'));
    expect(onRowClick).toHaveBeenCalledWith(rows[1]);
  });

  it('renders the empty state when there are no rows', () => {
    render(<DataTable columns={columns} rows={[]} rowKey={(r) => r.id} />);
    expect(screen.getByText('Nothing here yet')).toBeInTheDocument();
  });

  it('renders skeleton rows while loading, not the empty state', () => {
    const { container } = render(<DataTable columns={columns} rows={[]} rowKey={(r) => r.id} loading />);
    expect(screen.queryByText('Nothing here yet')).not.toBeInTheDocument();
    expect(container.querySelectorAll('tbody tr').length).toBe(8);
  });
});
```

- [ ] **Step 2: Run to fail** — FAIL.

- [ ] **Step 3: Implement `DataTable.tsx`**

```tsx
// The one table for the whole admin (spec §7). Never write a bare <table>
// in a screen again — extend this instead.
import { clsx } from 'clsx';
import type { ReactNode } from 'react';
import { EmptyState } from './EmptyState';
import { Skeleton } from './Skeleton';

export interface Column<T> {
  key: string;
  header: string;
  align?: 'left' | 'right' | 'center';
  width?: string;
  mono?: boolean;
  render: (row: T) => ReactNode;
}

export interface DataTableProps<T> {
  columns: Array<Column<T>>;
  rows: T[];
  rowKey: (row: T) => string;
  onRowClick?: (row: T) => void;
  loading?: boolean;
  skeletonRows?: number;
  empty?: ReactNode;
}

const alignCls = { left: 'text-left', right: 'text-right', center: 'text-center' } as const;

export function DataTable<T>({
  columns,
  rows,
  rowKey,
  onRowClick,
  loading = false,
  skeletonRows = 8,
  empty,
}: DataTableProps<T>) {
  if (!loading && rows.length === 0) {
    return <>{empty ?? <EmptyState message="Nothing here yet" />}</>;
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse">
        <thead>
          <tr className="border-y border-line bg-surface-2">
            {columns.map((col) => (
              <th
                key={col.key}
                style={col.width ? { width: col.width } : undefined}
                className={clsx('px-4 py-2 text-micro-caps uppercase text-ink-3', alignCls[col.align ?? 'left'])}
              >
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading
            ? Array.from({ length: skeletonRows }, (_, i) => (
                <tr key={i} className="border-b border-line-2 last:border-b-0">
                  {columns.map((col) => (
                    <td key={col.key} className="px-4 py-2.5">
                      <Skeleton height="12px" />
                    </td>
                  ))}
                </tr>
              ))
            : rows.map((row) => (
                <tr
                  key={rowKey(row)}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                  className={clsx(
                    'border-b border-line-2 last:border-b-0',
                    onRowClick && 'cursor-pointer hover:bg-surface-2',
                  )}
                >
                  {columns.map((col) => (
                    <td
                      key={col.key}
                      className={clsx(
                        'px-4 py-2.5 text-cell text-ink',
                        col.mono && 'font-mono',
                        col.align === 'right' && 'text-amount',
                        alignCls[col.align ?? 'left'],
                      )}
                    >
                      {col.render(row)}
                    </td>
                  ))}
                </tr>
              ))}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 4: Run** — PASS + typecheck.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): shared DataTable with loading/empty states"`

---

### Task 11: BarChart + SegmentedBar

**Files:**
- Create: `src/presentation/components/ui/charts/BarChart.tsx`, `src/presentation/components/ui/charts/SegmentedBar.tsx`
- Test: `src/presentation/components/ui/charts/charts.test.tsx`

**Interfaces:**
- Produces:
  - `BarChart({ data: Array<{ label: string; value: number }>, highlight?: number, height?: number /* px, default 110 */, empty?: ReactNode })` — tallest-bar logic lives with the CALLER via `highlight` (index); bars `--surface-3`, highlighted bar `--accent`; value above each bar (mono, omitted when 0); label below (10px mono `--text-3`); bar radius `var(--radius-bar)`. When every value is 0 renders `empty`.
  - `SegmentedBar({ segments: Array<{ label: string; value: number; color: 'pos' | 'accent' | 'neg' | 'surface-3' }> })` — one 10px strip, 2px gaps, zero-value segments skipped; colors strictly from the token set.

- [ ] **Step 1: Write the failing test**

```tsx
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BarChart } from './BarChart';
import { SegmentedBar } from './SegmentedBar';

describe('BarChart', () => {
  const data = [
    { label: '8 AM', value: 0 },
    { label: '9 AM', value: 3 },
    { label: '12 PM', value: 7 },
  ];

  it('renders a labeled bar per datum and omits zero counts', () => {
    render(<BarChart data={data} highlight={2} />);
    expect(screen.getByText('12 PM')).toBeInTheDocument();
    expect(screen.getByText('7')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument();
    // the 8 AM bucket shows no "0" count label
    expect(screen.queryByText('0')).not.toBeInTheDocument();
  });

  it('gives the highlighted bar the accent fill', () => {
    const { container } = render(<BarChart data={data} highlight={2} />);
    const bars = container.querySelectorAll('[data-bar]');
    expect(bars[2].className).toContain('bg-accent');
    expect(bars[1].className).toContain('bg-surface-3');
  });

  it('renders empty when every value is zero', () => {
    render(<BarChart data={[{ label: '8 AM', value: 0 }]} empty={<p>No sales yet today</p>} />);
    expect(screen.getByText('No sales yet today')).toBeInTheDocument();
  });
});

describe('SegmentedBar', () => {
  it('renders non-zero segments with proportional grow and skips zeros', () => {
    const { container } = render(
      <SegmentedBar
        segments={[
          { label: 'In stock', value: 3, color: 'pos' },
          { label: 'Low', value: 1, color: 'accent' },
          { label: 'Out', value: 0, color: 'neg' },
        ]}
      />,
    );
    const segs = container.querySelectorAll('[data-segment]');
    expect(segs.length).toBe(2);
    expect((segs[0] as HTMLElement).style.flexGrow).toBe('3');
    expect(segs[0].className).toContain('bg-pos');
  });
});
```

- [ ] **Step 2: Run to fail** — FAIL.

- [ ] **Step 3: Implement**

`BarChart.tsx`:

```tsx
import { clsx } from 'clsx';
import type { ReactNode } from 'react';

export interface BarDatum {
  label: string;
  value: number;
}

export interface BarChartProps {
  data: BarDatum[];
  highlight?: number;
  height?: number;
  empty?: ReactNode;
}

export function BarChart({ data, highlight, height = 110, empty = null }: BarChartProps) {
  const max = Math.max(...data.map((d) => d.value), 0);
  if (max === 0) return <>{empty}</>;

  return (
    <div className="flex items-end gap-1.5">
      {data.map((datum, index) => (
        <div key={datum.label} className="flex min-w-0 flex-1 flex-col items-center gap-1">
          <span className="font-mono text-axis text-ink-3">{datum.value > 0 ? datum.value : ' '}</span>
          <div className="flex w-full items-end" style={{ height }}>
            <div
              data-bar
              className={clsx('w-full', index === highlight ? 'bg-accent' : 'bg-surface-3')}
              style={{ height: `${(datum.value / max) * 100}%`, borderRadius: 'var(--radius-bar)' }}
            />
          </div>
          <span className="truncate font-mono text-axis text-ink-3">{datum.label}</span>
        </div>
      ))}
    </div>
  );
}
```

`SegmentedBar.tsx`:

```tsx
export interface Segment {
  label: string;
  value: number;
  color: 'pos' | 'accent' | 'neg' | 'surface-3';
}

const colorCls: Record<Segment['color'], string> = {
  pos: 'bg-pos',
  accent: 'bg-accent',
  neg: 'bg-neg',
  'surface-3': 'bg-surface-3',
};

export function SegmentedBar({ segments }: { segments: Segment[] }) {
  const visible = segments.filter((s) => s.value > 0);
  if (visible.length === 0) return <div className="h-2.5 rounded bg-surface-3" />;
  return (
    <div className="flex h-2.5 gap-[2px]">
      {visible.map((segment) => (
        <div
          key={segment.label}
          data-segment
          title={segment.label}
          className={`min-w-[6px] rounded ${colorCls[segment.color]}`}
          style={{ flexGrow: segment.value }}
        />
      ))}
    </div>
  );
}
```

- [ ] **Step 4: Run** — PASS + typecheck.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): BarChart and SegmentedBar chart primitives"`

---

### Task 12: Domain functions — hourly buckets, inventory summary, deltas

**Files:**
- Create: `src/domain/sales/hourlySales.ts`, `src/domain/products/inventoryStatus.ts`, `src/domain/reports/compare.ts`
- Test: `src/domain/sales/hourlySales.test.ts`, `src/domain/products/inventoryStatus.test.ts`, `src/domain/reports/compare.test.ts`

**Interfaces:**
- Consumes: `shopTimeOf` (`@/domain/time/shopTime`), `saleIsVoided`, `saleGrandTotal`, `getStockStatus`, entity types.
- Produces:

```ts
// hourlySales.ts
export interface HourBucket { hour: number; count: number; gross: number }
export const DEFAULT_OPEN_HOUR = 8;   // display window floor
export const DEFAULT_CLOSE_HOUR = 20; // display window ceiling
export function bucketSalesByHour(sales: Sale[]): HourBucket[]   // contiguous hours, voided excluded
export function peakHour(buckets: HourBucket[]): number | null    // argmax count, null when no sales
export function formatHourLabel(hour: number, withMinutes?: boolean): string // '12 PM' / '12:00 PM'

// inventoryStatus.ts
export interface InventorySummary { total: number; inStock: number; lowStock: number; outOfStock: number }
export function summarizeInventory(products: Product[]): InventorySummary // inactive products skipped
export function sharePercent(part: number, total: number): number         // one decimal, 0 when total is 0

// compare.ts
export function percentDelta(current: number, previous: number): number | null // null when previous <= 0
```

- [ ] **Step 1: Write the failing tests**

`hourlySales.test.ts` (build fake sales with a local factory as the codebase convention; only the consumed fields need real values — `createdAt`, `status`, `items`, `laborLines`, `feeLines`, `discountType`):

```ts
import { describe, expect, it } from 'vitest';
import { bucketSalesByHour, formatHourLabel, peakHour, DEFAULT_OPEN_HOUR, DEFAULT_CLOSE_HOUR } from './hourlySales';
import { DiscountType, SaleStatus } from '../enums';
import type { Sale } from '../entities';
import { instantOf } from '../time/shopTime';

// Minimal sale: one ₱100 item, created at the given shop-wall hour.
function fakeSale(hour: number, overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's', saleNumber: 'SALE-1', laborLines: [], feeLines: [], mechanicId: null,
    mechanicName: null, motorcycleModel: null, tenders: {}, discountType: DiscountType.fixed,
    paymentMethod: 'cash', amountReceived: 100, changeGiven: 0, status: SaleStatus.completed,
    cashierId: 'c', cashierName: 'C', updatedAt: null, jobOrderId: null, notes: null,
    voidedAt: null, voidedBy: null, voidedByName: null, voidReason: null,
    createdAt: instantOf(new Date(Date.UTC(2026, 7, 31, hour, 15))),
    items: [{
      productId: 'p', productName: 'Part', sku: 'SKU-1', quantity: 1, unitPrice: 100,
      unitCost: 60, discount: 0, unit: 'pcs', sellingOptionId: null, sellingOptionLabel: null,
    } as Sale['items'][number]],
    ...overrides,
  } as Sale;
}

describe('bucketSalesByHour', () => {
  it('buckets counts and gross by shop-wall hour', () => {
    const buckets = bucketSalesByHour([fakeSale(9), fakeSale(9), fakeSale(14)]);
    const nine = buckets.find((b) => b.hour === 9)!;
    expect(nine.count).toBe(2);
    expect(nine.gross).toBe(200);
    expect(buckets.find((b) => b.hour === 14)!.count).toBe(1);
  });

  it('excludes voided sales', () => {
    const voided = fakeSale(9, { status: SaleStatus.voided, voidedAt: new Date() });
    const nine = bucketSalesByHour([voided]).find((b) => b.hour === 9);
    expect(nine?.count ?? 0).toBe(0);
  });

  it('always spans at least the default open hours, extended by outliers', () => {
    const buckets = bucketSalesByHour([fakeSale(22)]);
    expect(buckets[0].hour).toBe(DEFAULT_OPEN_HOUR);
    expect(buckets[buckets.length - 1].hour).toBe(22);
    expect(buckets.length).toBe(22 - DEFAULT_OPEN_HOUR + 1);
  });

  it('spans exactly the default window when there are no sales', () => {
    const buckets = bucketSalesByHour([]);
    expect(buckets[0].hour).toBe(DEFAULT_OPEN_HOUR);
    expect(buckets[buckets.length - 1].hour).toBe(DEFAULT_CLOSE_HOUR);
  });
});

describe('peakHour', () => {
  it('is the argmax-count hour', () => {
    expect(peakHour(bucketSalesByHour([fakeSale(9), fakeSale(12), fakeSale(12)]))).toBe(12);
  });
  it('is null with no sales', () => {
    expect(peakHour(bucketSalesByHour([]))).toBeNull();
  });
});

describe('formatHourLabel', () => {
  it('formats 12-hour labels', () => {
    expect(formatHourLabel(0)).toBe('12 AM');
    expect(formatHourLabel(8)).toBe('8 AM');
    expect(formatHourLabel(12)).toBe('12 PM');
    expect(formatHourLabel(13)).toBe('1 PM');
    expect(formatHourLabel(12, true)).toBe('12:00 PM');
  });
});
```

(If the `SaleItem` fields above don't compile, open `src/domain/entities/SaleItem.ts` and fill the factory with the real required fields — the test's intent is fixed, the fixture shape follows the entity.)

`inventoryStatus.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { sharePercent, summarizeInventory } from './inventoryStatus';
import type { Product } from '../entities';

function fakeProduct(overrides: Partial<Product>): Product {
  return {
    id: 'p', sku: 'S', name: 'N', costCode: '', cost: 0, price: 0, quantity: 10,
    reorderLevel: 2, unit: 'pcs', supplierId: null, supplierName: null, isActive: true,
    createdAt: new Date(), updatedAt: null, createdBy: null, updatedBy: null,
    createdByName: null, updatedByName: null, searchKeywords: [], baseSku: null,
    variationNumber: null, barcodes: [], sellingOptions: [], category: null,
    imageUrl: null, notes: null, ...overrides,
  };
}

describe('summarizeInventory', () => {
  it('counts stock statuses and skips inactive products', () => {
    const summary = summarizeInventory([
      fakeProduct({ quantity: 10, reorderLevel: 2 }),   // in stock
      fakeProduct({ quantity: 2, reorderLevel: 2 }),    // low (qty <= reorder, > 0)
      fakeProduct({ quantity: 0 }),                     // out
      fakeProduct({ quantity: 0, isActive: false }),    // skipped
    ]);
    expect(summary).toEqual({ total: 3, inStock: 1, lowStock: 1, outOfStock: 1 });
  });
});

describe('sharePercent', () => {
  it('rounds to one decimal', () => expect(sharePercent(1, 3)).toBe(33.3));
  it('is 0 for an empty total', () => expect(sharePercent(1, 0)).toBe(0));
});
```

`compare.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { percentDelta } from './compare';

describe('percentDelta', () => {
  it('signed fraction vs prior day', () => {
    expect(percentDelta(27, 25)).toBeCloseTo(0.08);
    expect(percentDelta(20, 25)).toBeCloseTo(-0.2);
  });
  it('null when there is no baseline', () => {
    expect(percentDelta(27, 0)).toBeNull();
  });
});
```

- [ ] **Step 2: Run to fail** — `npm run test -- hourlySales inventoryStatus compare` → FAIL.

- [ ] **Step 3: Implement**

`src/domain/sales/hourlySales.ts`:

```ts
// Hourly sales bucketing for the dashboard chart (spec §5.2). Pure; hours
// are SHOP-WALL hours via shopTimeOf, so a shift's buckets don't drift with
// the viewer's device timezone.
import { saleGrandTotal, saleIsVoided, type Sale } from '../entities';
import { shopTimeOf } from '../time/shopTime';

export interface HourBucket {
  hour: number; // 0–23, shop wall clock
  count: number;
  gross: number;
}

export const DEFAULT_OPEN_HOUR = 8;
export const DEFAULT_CLOSE_HOUR = 20;

export function bucketSalesByHour(sales: Sale[]): HourBucket[] {
  const byHour = new Map<number, { count: number; gross: number }>();
  for (const sale of sales) {
    if (saleIsVoided(sale)) continue;
    const hour = shopTimeOf(sale.createdAt).getUTCHours();
    const bucket = byHour.get(hour) ?? { count: 0, gross: 0 };
    bucket.count += 1;
    bucket.gross += saleGrandTotal(sale);
    byHour.set(hour, bucket);
  }
  const hours = [...byHour.keys()];
  const first = Math.min(DEFAULT_OPEN_HOUR, ...hours);
  const last = Math.max(DEFAULT_CLOSE_HOUR, ...hours);
  const buckets: HourBucket[] = [];
  for (let hour = first; hour <= last; hour++) {
    buckets.push({ hour, ...(byHour.get(hour) ?? { count: 0, gross: 0 }) });
  }
  return buckets;
}

export function peakHour(buckets: HourBucket[]): number | null {
  let best: HourBucket | null = null;
  for (const bucket of buckets) {
    if (bucket.count > 0 && (best === null || bucket.count > best.count)) best = bucket;
  }
  return best ? best.hour : null;
}

export function formatHourLabel(hour: number, withMinutes = false): string {
  const h12 = hour % 12 === 0 ? 12 : hour % 12;
  const suffix = hour < 12 ? 'AM' : 'PM';
  return withMinutes ? `${h12}:00 ${suffix}` : `${h12} ${suffix}`;
}
```

`src/domain/products/inventoryStatus.ts`:

```ts
// Inventory status aggregation (spec §5.4) — extracted from the old
// dashboard InventoryStatus component so screens share one definition.
import { getStockStatus, StockStatus, type Product } from '../entities';

export interface InventorySummary {
  total: number;
  inStock: number;
  lowStock: number;
  outOfStock: number;
}

export function summarizeInventory(products: Product[]): InventorySummary {
  const summary: InventorySummary = { total: 0, inStock: 0, lowStock: 0, outOfStock: 0 };
  for (const product of products) {
    if (!product.isActive) continue;
    summary.total += 1;
    const status = getStockStatus(product);
    if (status === StockStatus.inStock) summary.inStock += 1;
    else if (status === StockStatus.lowStock) summary.lowStock += 1;
    else summary.outOfStock += 1;
  }
  return summary;
}

export function sharePercent(part: number, total: number): number {
  if (total <= 0) return 0;
  return Math.round((part / total) * 1000) / 10;
}
```

`src/domain/reports/compare.ts`:

```ts
// Prior-period comparison math for KPI delta chips (spec §5.1).
export function percentDelta(current: number, previous: number): number | null {
  if (!Number.isFinite(previous) || previous <= 0) return null;
  return (current - previous) / previous;
}
```

- [ ] **Step 4: Run** — PASS + typecheck.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): hourly buckets, inventory summary, delta math (pure domain)"`

---

### Task 13: Register status — DrawerState read path

**Files:**
- Create: `src/domain/entities/DrawerState.ts`, `src/domain/repositories/DrawerStateRepository.ts`, `src/data/repositories/FirestoreDrawerStateRepository.ts`, `src/presentation/hooks/useRegisterStatus.ts`
- Modify: `src/domain/entities/index.ts` (add `export * from './DrawerState';`), `src/infrastructure/di/container.tsx` (add `drawerStateRepo` + `useDrawerStateRepo()`, following the exact pattern of the existing 18 entries)
- Test: `src/domain/entities/DrawerState.test.ts`

**Interfaces:**
- Consumes: `shopDayInt` (`@/domain/time/shopTime`), `useFirestoreSubscription`, `FirestoreCollections.drawerState` (`'drawer_state'`, doc id `'state'` — read-only here; the write path in `FirestoreSaleRepository` is untouched).
- Produces:

```ts
export interface DrawerState { lastSaleDay: number | null; lastClosedDay: number | null } // yyyymmdd ints
export function isRegisterOpen(state: DrawerState): boolean
export function businessDayFor(state: DrawerState | null, now: Date): number // yyyymmdd — an open past-midnight shift still reports its opening day (spec §5.9)
export function formatDayInt(dayInt: number): string // "Sunday, Aug 31, 2026"
export interface DrawerStateRepository { watch(onChange: (s: DrawerState) => void, onError?: (e: Error) => void): () => void }
export function useRegisterStatus(): { open: boolean; businessDayInt: number; isLoading: boolean }
```

- [ ] **Step 1: Write the failing test** — `DrawerState.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { businessDayFor, formatDayInt, isRegisterOpen } from './DrawerState';
import { instantOf } from '../time/shopTime';

describe('isRegisterOpen', () => {
  it('open when sales exist past the last close', () => {
    expect(isRegisterOpen({ lastSaleDay: 20260831, lastClosedDay: 20260830 })).toBe(true);
    expect(isRegisterOpen({ lastSaleDay: 20260831, lastClosedDay: null })).toBe(true);
  });
  it('closed when the day is sealed or nothing was ever sold', () => {
    expect(isRegisterOpen({ lastSaleDay: 20260831, lastClosedDay: 20260831 })).toBe(false);
    expect(isRegisterOpen({ lastSaleDay: null, lastClosedDay: null })).toBe(false);
  });
});

describe('businessDayFor', () => {
  const pastMidnight = instantOf(new Date(Date.UTC(2026, 8, 1, 0, 30))); // Sep 1, 00:30 shop wall
  it('an open shift past midnight still reports its opening day', () => {
    expect(businessDayFor({ lastSaleDay: 20260831, lastClosedDay: 20260830 }, pastMidnight)).toBe(20260831);
  });
  it('falls back to the shop calendar day otherwise', () => {
    expect(businessDayFor({ lastSaleDay: 20260831, lastClosedDay: 20260831 }, pastMidnight)).toBe(20260901);
    expect(businessDayFor(null, pastMidnight)).toBe(20260901);
  });
});

describe('formatDayInt', () => {
  it('renders "dddd, MMM D, YYYY"', () => {
    expect(formatDayInt(20260831)).toBe('Monday, Aug 31, 2026');
  });
});
```

(2026-08-31 is a Monday; adjust the expected literal only if `date --date` proves otherwise, not to make the test pass.)

- [ ] **Step 2: Run to fail** — FAIL.

- [ ] **Step 3: Implement**

`src/domain/entities/DrawerState.ts`:

```ts
// Read-model of the drawer_state/state doc — written by sale creation and
// day closing (mobile + FirestoreSaleRepository). Web only READS it.
import { shopDayInt } from '../time/shopTime';

export interface DrawerState {
  lastSaleDay: number | null; // yyyymmdd of the newest sale
  lastClosedDay: number | null; // yyyymmdd of the newest sealed day
}

export function isRegisterOpen(state: DrawerState): boolean {
  if (state.lastSaleDay == null) return false;
  return state.lastClosedDay == null || state.lastSaleDay > state.lastClosedDay;
}

/** The business date the header reports: an open shift that ran past
 *  midnight still belongs to its opening day (spec §5.9). */
export function businessDayFor(state: DrawerState | null, now: Date): number {
  const today = shopDayInt(now);
  if (state && isRegisterOpen(state) && state.lastSaleDay != null && state.lastSaleDay < today) {
    return state.lastSaleDay;
  }
  return today;
}

export function formatDayInt(dayInt: number): string {
  const year = Math.floor(dayInt / 10000);
  const month = Math.floor((dayInt % 10000) / 100);
  const day = dayInt % 100;
  return new Intl.DateTimeFormat('en-PH', {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(Date.UTC(year, month - 1, day)));
}
```

`src/domain/repositories/DrawerStateRepository.ts`:

```ts
import type { DrawerState } from '../entities/DrawerState';

export interface DrawerStateRepository {
  watch(onChange: (state: DrawerState) => void, onError?: (error: Error) => void): () => void;
}
```

`src/data/repositories/FirestoreDrawerStateRepository.ts` (mirror the import style of `FirestoreSaleRepository.ts` — `db` comes from `@/infrastructure/firebase/firestore`):

```ts
import { doc, onSnapshot } from 'firebase/firestore';
import { db } from '@/infrastructure/firebase/firestore';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import type { DrawerState } from '@/domain/entities/DrawerState';
import type { DrawerStateRepository } from '@/domain/repositories/DrawerStateRepository';

export class FirestoreDrawerStateRepository implements DrawerStateRepository {
  watch(onChange: (state: DrawerState) => void, onError?: (error: Error) => void): () => void {
    const ref = doc(db, FirestoreCollections.drawerState, 'state');
    return onSnapshot(
      ref,
      (snapshot) => {
        const data = snapshot.data();
        onChange({
          lastSaleDay: typeof data?.lastSaleDay === 'number' ? data.lastSaleDay : null,
          lastClosedDay: typeof data?.lastClosedDay === 'number' ? data.lastClosedDay : null,
        });
      },
      (error) => onError?.(error),
    );
  }
}
```

DI: in `container.tsx`, add `drawerStateRepo: DrawerStateRepository;` to the `Container` interface, `drawerStateRepo: new FirestoreDrawerStateRepository(),` to `buildDefaultContainer()`, and `export function useDrawerStateRepo() { return useContainer().drawerStateRepo; }` — copy the surrounding pattern exactly.

`src/presentation/hooks/useRegisterStatus.ts`:

```ts
import { businessDayFor, isRegisterOpen, type DrawerState } from '@/domain/entities';
import { useDrawerStateRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';

export function useRegisterStatus(): { open: boolean; businessDayInt: number; isLoading: boolean } {
  const repo = useDrawerStateRepo();
  const { data, isLoading } = useFirestoreSubscription<DrawerState>(
    (onData, onError) => repo.watch(onData, onError),
    [repo],
  );
  return {
    open: data ? isRegisterOpen(data) : false,
    businessDayInt: businessDayFor(data, new Date()),
    isLoading,
  };
}
```

- [ ] **Step 4: Verify the rules allow the read.** Check `firestore.rules` (repo root) for `drawer_state`: authenticated web admin/cashier reads must be permitted. If reads are NOT allowed for web roles, STOP and flag it in the task report — do not edit `firestore.rules` (production-affecting; needs explicit user sign-off). The header must then render the closed state on error rather than crashing (the hook already degrades: `data` stays null → `open: false`).

- [ ] **Step 5: Run** — `npm run test -- DrawerState` → PASS; `npm run typecheck` → clean.
- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(web): drawer_state read path — register status + business day"`

---

### Task 14: Sidebar reskin

**Files:**
- Modify: `src/presentation/components/common/Sidebar.tsx` (in place — keep all behavior: permission filtering, collapse, groups, badges, account popover)
- Test: existing `src/presentation/components/common/Sidebar.test.tsx` must keep passing (it is behavioral); extend it with one new badge case.

**Interfaces:**
- Consumes: tokens (Task 1), `useJobOrders` (`@/presentation/hooks/useJobOrders`), existing `useVoidRequests`, `canAccess`.
- Produces: no API change — visual retokening plus a Job Orders open-count badge.

- [ ] **Step 1: Write the failing test** — add to `Sidebar.test.tsx`, following the file's existing harness and its void-request badge tests verbatim (same DiProvider override pattern, admin user):

```tsx
describe('Sidebar — Job Orders badge', () => {
  it('badges Job Orders with the open (unconverted) count', async () => {
    // fake jobOrderRepo.watchAll -> two open JOs (isConverted: false) and one
    // converted (isConverted: true), using the harness's fake-repo style
    // …render…
    const badge = await screen.findByText('2');
    expect(badge).toBeInTheDocument();
  });
});
```

Model the fake `jobOrderRepo` on how the harness already fakes `voidRequestRepo`; a minimal `JobOrder` fixture needs `id` and `isConverted` plus whatever the type requires (copy required fields from `src/domain/entities/JobOrder.ts`).

- [ ] **Step 2: Run to fail** — `npm run test -- Sidebar` → the new case FAILS, existing cases PASS.

- [ ] **Step 3: Implement.** Two changes:

**(a) Job Orders badge.** Mirror the existing pendingVoids gating: subscribe via `useJobOrders()` only when `canAccess(RoutePaths.jobOrders, user)` (use the same gate mechanism the file already uses for void requests — read the file, copy the pattern). Open count = `(jobOrders ?? []).filter((jo) => !jo.isConverted).length`. Pass to the Job Orders item the way `pendingVoids` reaches Void Requests. Badge rendering: keep the void badge's *shape* but retone — Void Requests badge becomes `bg-neg text-surface` (attention), Job Orders badge is informational: `bg-surface-3 text-ink-2 font-mono`. Render nothing when the count is 0 (already the existing behavior — keep it).

**(b) Retoken every class in the file** (do not restructure the component tree or touch any logic):
- Sidebar root: `bg-surface border-r border-line`, width `w-sidebar` (248px) expanded / keep `w-14` collapsed. Remove any `transition` that includes background (spec §2 rule 2); `transition-[width]` is fine.
- Brand block: wordmark `text-brand text-ink`.
- Group labels: `text-group-caps uppercase text-ink-3`.
- Nav items: `text-nav text-ink-2 hover:bg-surface-2 hover:text-ink rounded-ctl`; active: `bg-surface-3 font-semibold text-ink`. No background transitions.
- Account block: `border-t border-line`; avatar circle `bg-accent text-accent-ink`; email `text-cell text-ink`; role `text-micro-caps uppercase text-ink-3`; popover `bg-surface border-line shadow-card rounded-ctl`.
- Every remaining `light-*`/`primary-dark` class in this file gets a token equivalent (`bg-light-subtle`→`bg-surface-2`, `text-light-text-secondary`→`text-ink-2`, `border-light-hairline`→`border-line`, etc.).

- [ ] **Step 4: Run** — `npm run test -- Sidebar` → ALL PASS (old + new); `npm run typecheck` → clean.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): sidebar reskin + Job Orders open-count badge"`

---

### Task 15: AppShell — sticky header, shell swap

**Files:**
- Create: `src/presentation/layouts/AppShell.tsx`, `src/presentation/layouts/HeaderBar.tsx`
- Modify: `src/presentation/router/routes.tsx` (swap `AdminShell`→`AppShell`; add `handle` to the dashboard route)
- Delete: `src/presentation/layouts/AdminShell.tsx` (after confirming nothing else imports it)
- Test: `src/presentation/layouts/HeaderBar.test.tsx`

**Interfaces:**
- Consumes: `useRegisterStatus` + `formatDayInt` (Task 13), `useTheme` (Task 2), `Button`/`IconButton` (Task 3), `Toaster` (Task 5), existing `Sidebar`, `OfflineBanner`, `AccountDeactivationGuard`.
- Produces: route `handle` contract — screens opt into the shared header via:

```ts
export interface PageChrome {
  title: string;
  subtitle?: string;
  primaryAction?: { label: string; to: string };
}
```

  (declare in `HeaderBar.tsx`, export it). Routes without a `handle` render no shell header and no shell padding — legacy pages keep their own headers untouched.

- [ ] **Step 1: Write the failing test** — `HeaderBar.test.tsx`. Harness: DiProvider override with a fake `drawerStateRepo` (`watch: (cb) => { cb(state); return () => {}; }`), ThemeProvider, QueryClientProvider, and a `createMemoryRouter` whose dashboard route has `handle: { title: 'Dashboard', subtitle: 'x', primaryAction: { label: 'New sale', to: '/pos' } }` and renders `<AppShell />` with a stub child. Cases:

```tsx
it('renders title, subtitle and the primary action from the route handle', …);
it('shows "Register open" with an open drawer state', …);   // lastSaleDay 20260831, lastClosedDay 20260830
it('shows "Register closed" when the day is sealed', …);    // lastClosedDay === lastSaleDay
it('renders no header at all for a route without a handle', …);
it('theme toggle flips data-theme on <html>', …);
```

Assert with `screen.getByText('Register open')`, `screen.queryByRole('banner')` etc.

- [ ] **Step 2: Run to fail** — FAIL.

- [ ] **Step 3: Implement**

`HeaderBar.tsx`:

```tsx
import { Link, useMatches } from 'react-router-dom';
import { MoonIcon, SunIcon } from '@heroicons/react/24/outline';
import { useTheme } from '@/core/theme/ThemeProvider';
import { formatDayInt } from '@/domain/entities';
import { useRegisterStatus } from '@/presentation/hooks/useRegisterStatus';
import { Button } from '@/presentation/components/ui/Button';
import { IconButton } from '@/presentation/components/ui/IconButton';

export interface PageChrome {
  title: string;
  subtitle?: string;
  primaryAction?: { label: string; to: string };
}

export function usePageChrome(): PageChrome | null {
  const matches = useMatches();
  const match = [...matches].reverse().find((m) => m.handle != null);
  return (match?.handle as PageChrome | undefined) ?? null;
}

export function HeaderBar({ chrome }: { chrome: PageChrome }) {
  const { theme, toggleTheme } = useTheme();
  const { open, businessDayInt } = useRegisterStatus();

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between gap-4 border-b border-line bg-surface px-7 py-[18px]">
      <div className="min-w-0">
        <h1 className="text-page-title text-ink">{chrome.title}</h1>
        {chrome.subtitle && <p className="text-page-sub text-ink-2">{chrome.subtitle}</p>}
      </div>
      <div className="flex shrink-0 items-center gap-4">
        <span className="font-mono text-cell text-ink-2">{formatDayInt(businessDayInt)}</span>
        <span className="flex items-center gap-1.5 text-cell text-ink-2">
          <span aria-hidden className={`h-2 w-2 rounded-full ${open ? 'bg-pos' : 'bg-ink-3'}`} />
          {open ? 'Register open' : 'Register closed'}
        </span>
        <IconButton title={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'} size={28} onClick={toggleTheme}>
          {theme === 'dark' ? <SunIcon className="h-4 w-4" /> : <MoonIcon className="h-4 w-4" />}
        </IconButton>
        {chrome.primaryAction && (
          <Link to={chrome.primaryAction.to}>
            <Button variant="primary">{chrome.primaryAction.label}</Button>
          </Link>
        )}
      </div>
    </header>
  );
}
```

`AppShell.tsx` (port `AdminShell`'s exact structure — Sidebar + OfflineBanner + scroll container + Outlet + AccountDeactivationGuard — then add the header and Toaster):

```tsx
import { Outlet } from 'react-router-dom';
import { Sidebar } from '@/presentation/components/common/Sidebar';
import { OfflineBanner } from '@/presentation/components/common/OfflineBanner';
import { AccountDeactivationGuard } from '@/presentation/components/common/AccountDeactivationGuard';
import { Toaster } from '@/presentation/components/ui/Toaster';
import { HeaderBar, usePageChrome } from './HeaderBar';

export function AppShell() {
  const chrome = usePageChrome();
  return (
    <div className="flex h-full w-full bg-bg">
      <Sidebar />
      <main className="flex min-w-0 flex-1 flex-col overflow-hidden">
        <OfflineBanner />
        {chrome && <HeaderBar chrome={chrome} />}
        <div className="flex-1 overflow-y-auto">
          <div className={chrome ? 'px-7 pb-10 pt-[22px]' : undefined}>
            <Outlet />
          </div>
        </div>
      </main>
      <Toaster />
      <AccountDeactivationGuard />
    </div>
  );
}
```

`routes.tsx`: replace the `<AdminShell />` element with `<AppShell />` (update import), and give ONLY the dashboard route a handle:

```ts
{
  index: true,
  element: <DashboardPage />,
  handle: {
    title: 'Dashboard',
    subtitle: 'Store performance at a glance',
    primaryAction: { label: 'New sale', to: RoutePaths.pos },
  } satisfies PageChrome,
},
```

(match the actual dashboard route node shape in the file — it may be `path: RoutePaths.dashboard` rather than `index`). Then `grep -rn "AdminShell" src` — when only the deleted file matches, delete `AdminShell.tsx` and any colocated test, porting any of its test cases that still apply to a new `AppShell.test.tsx` only if they test behavior (not classes).

- [ ] **Step 4: Run** — `npm run test -- HeaderBar && npm run test && npm run typecheck` → PASS (full suite catches legacy screens that broke under the shell swap).
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): AppShell with sticky header, register status, theme toggle"`

---

### Task 16: Dashboard rebuild

**Files:**
- Create: `src/presentation/hooks/useYesterdaySales.ts`, `src/presentation/features/dashboard/KpiRow.tsx`, `src/presentation/features/dashboard/SalesThroughDay.tsx`, `src/presentation/features/dashboard/InventoryStatusCard.tsx`, `src/presentation/features/dashboard/NeedsAttentionCard.tsx`, `src/presentation/features/dashboard/RecentSalesTable.tsx`
- Rewrite: `src/presentation/features/dashboard/DashboardPage.tsx`, `src/presentation/features/dashboard/DashboardPage.test.tsx`
- Delete: `src/presentation/features/dashboard/RecentSales.tsx`, `RecentSales.test.tsx`, `InventoryStatus.tsx` (keep `SummaryCard.tsx` — receiving/reports still import it)

**Interfaces:**
- Consumes: everything from Tasks 3–13, `useTodaysSales`, `useProducts`, `useVoidRequests`, `summarizeSales`, `hasPermission(user.role, Permission.viewProductCost)`, `canAccess(RoutePaths.voidRequests, user)`, `formatInShopZone`, `paymentMethodDisplayName`, `saleStatusDisplayName`, `RoutePaths.daySales` / `RoutePaths.pos` / `RoutePaths.inventory` / `RoutePaths.voidRequests`, sale detail path `'/reports/sale/' + sale.id`.
- Produces: `useYesterdaySales(): { summary: SalesSummary | null; isLoading: boolean }`.

- [ ] **Step 1: Write the failing page test** — rewrite `DashboardPage.test.tsx` from scratch on the existing harness pattern (DiProvider override + QueryClientProvider + MemoryRouter at `/` + seeded `useAuthStore`), asserting SEMANTICS only, never class names. Fake repos: `saleRepo: { watchToday: cb => { cb(sales); return () => {}; }, list: async () => yesterdaySales }`, `productRepo: { watchAll: … }`, `voidRequestRepo` (copy Sidebar.test's fake), `drawerStateRepo: { watch: cb => { cb({lastSaleDay: null, lastClosedDay: null}); return () => {}; } }`, `jobOrderRepo: { watchAll: cb => { cb([]); return () => {}; } }` (the sidebar mounts in some routes — if the page test renders DashboardPage directly outside the shell, sidebar fakes are unnecessary; do that). Test cases:

```
it('renders all five KPI labels for an admin')                    // Sales today, Gross Sales, Total COGS, Gross profit, Avg order
it('hides COGS and Gross profit from a cashier')
it('renders a delta chip vs yesterday on Sales today')            // 27 today vs 25 yesterday → +8.0%
it('lists recent sales with sale number, tender, status and total')
it('filters the recent list by sale number via search')           // type into search, advance debounce, other rows gone
it('hides needs-attention rows whose count is zero')              // 0 out-of-stock → no "Out of stock" row
it('shows an out-of-stock row linking to inventory when count > 0')
it('renders the empty chart state when there are no sales')       // "No sales yet today"
```

Build `fakeSale`/`fakeProduct` factories as in Task 12's tests (share by copy, per codebase convention).

- [ ] **Step 2: Run to fail** — `npm run test -- DashboardPage` → FAIL.

- [ ] **Step 3: Implement**

`useYesterdaySales.ts`:

```ts
// Prior business day's summary for the KPI delta chips (spec §5.1).
// Range is computed in SHOP time — not the browser's calendar.
import { useQuery } from '@tanstack/react-query';
import { summarizeSales, type SalesSummary } from '@/domain/sales/summarizeSales';
import { shopDateKey, shopEndOfDay, shopStartOfDay } from '@/domain/time/shopTime';
import { useSaleRepo } from '@/infrastructure/di/container';

const DAY_MS = 24 * 60 * 60 * 1000;

export function useYesterdaySales(): { summary: SalesSummary | null; isLoading: boolean } {
  const repo = useSaleRepo();
  const yesterday = new Date(Date.now() - DAY_MS);
  const { data, isLoading } = useQuery({
    queryKey: ['sales', 'yesterday', shopDateKey(yesterday)],
    queryFn: () => repo.list({ start: shopStartOfDay(yesterday), end: shopEndOfDay(yesterday) }),
  });
  return { summary: data ? summarizeSales(data) : null, isLoading };
}
```

`KpiRow.tsx`:

```tsx
import { percentDelta } from '@/domain/reports/compare';
import type { SalesSummary } from '@/domain/sales/summarizeSales';
import { StatCard } from '@/presentation/components/ui/StatCard';

export interface KpiRowProps {
  summary: SalesSummary;
  yesterday: SalesSummary | null;
  canSeeCost: boolean;
  loading: boolean;
}

export function KpiRow({ summary, yesterday, canSeeCost, loading }: KpiRowProps) {
  const revenue = summary.netAmount + summary.laborRevenue + summary.feesRevenue;
  const count = summary.totalSalesCount;
  const avgOrder = count === 0 ? 0 : revenue / count;
  const yRevenue = yesterday ? yesterday.netAmount + yesterday.laborRevenue + yesterday.feesRevenue : 0;
  const yAvg = yesterday && yesterday.totalSalesCount > 0 ? yRevenue / yesterday.totalSalesCount : 0;
  const cogsShare = summary.grossAmount > 0 ? ((summary.totalCost / summary.grossAmount) * 100).toFixed(1) : null;
  const margin = (summary.profitMargin * 100).toFixed(1);

  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
      <StatCard label="Sales today" value={count} format="number" loading={loading}
        delta={yesterday ? percentDelta(count, yesterday.totalSalesCount) : null} note="vs prior business day" />
      <StatCard label="Gross Sales" value={summary.grossAmount} format="currency" loading={loading}
        delta={yesterday ? percentDelta(summary.grossAmount, yesterday.grossAmount) : null} note="vs prior business day" />
      {canSeeCost && (
        <StatCard label="Total COGS" value={summary.totalCost} format="currency" loading={loading}
          chip={cogsShare ? { label: `${cogsShare}% of gross`, tone: 'neutral' } : undefined} />
      )}
      {canSeeCost && (
        <StatCard label="Gross profit" value={summary.totalProfit} format="currency" loading={loading}
          chip={{ label: `${margin}% margin`, tone: 'neutral' }} />
      )}
      <StatCard label="Avg order" value={avgOrder} format="currency" loading={loading}
        delta={yesterday ? percentDelta(avgOrder, yAvg) : null} note="vs prior business day" />
    </div>
  );
}
```

`SalesThroughDay.tsx`:

```tsx
import { useMemo } from 'react';
import { bucketSalesByHour, formatHourLabel, peakHour } from '@/domain/sales/hourlySales';
import type { Sale } from '@/domain/entities';
import type { SalesSummary } from '@/domain/sales/summarizeSales';
import { Card } from '@/presentation/components/ui/Card';
import { EmptyState } from '@/presentation/components/ui/EmptyState';
import { Skeleton } from '@/presentation/components/ui/Skeleton';
import { BarChart } from '@/presentation/components/ui/charts/BarChart';
import { SegmentedBar } from '@/presentation/components/ui/charts/SegmentedBar';

export function SalesThroughDay({
  sales,
  summary,
  canSeeCost,
  loading,
}: {
  sales: Sale[];
  summary: SalesSummary;
  canSeeCost: boolean;
  loading: boolean;
}) {
  const buckets = useMemo(() => bucketSalesByHour(sales), [sales]);
  const peak = peakHour(buckets);
  const highlight = peak == null ? undefined : buckets.findIndex((b) => b.hour === peak);
  const cogs = summary.totalCost;
  const profit = summary.totalProfit;

  return (
    <Card
      title="Sales through the day"
      subtitle={peak != null ? `Peak ${formatHourLabel(peak, true)}` : undefined}
    >
      {loading ? (
        <Skeleton height="110px" />
      ) : (
        <BarChart
          data={buckets.map((b) => ({ label: formatHourLabel(b.hour), value: b.count }))}
          highlight={highlight}
          empty={<EmptyState message="No sales yet today" />}
        />
      )}
      {canSeeCost && !loading && (cogs > 0 || profit > 0) && (
        <div className="mt-5 border-t border-line-2 pt-4">
          <div className="mb-2 flex items-center justify-between">
            <span className="text-micro-caps uppercase text-ink-3">Margin</span>
            <span className="font-mono text-micro text-ink-2">{(summary.profitMargin * 100).toFixed(1)}% profit</span>
          </div>
          <SegmentedBar
            segments={[
              { label: 'COGS', value: cogs, color: 'surface-3' },
              { label: 'Profit', value: profit, color: 'accent' },
            ]}
          />
        </div>
      )}
    </Card>
  );
}
```

`InventoryStatusCard.tsx`:

```tsx
import { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { sharePercent, summarizeInventory } from '@/domain/products/inventoryStatus';
import { useProducts } from '@/presentation/hooks/useProducts';
import { RoutePaths } from '@/presentation/router/routePaths';
import { Card } from '@/presentation/components/ui/Card';
import { Skeleton } from '@/presentation/components/ui/Skeleton';
import { SegmentedBar, type Segment } from '@/presentation/components/ui/charts/SegmentedBar';

const ROWS: Array<{ key: 'inStock' | 'lowStock' | 'outOfStock'; label: string; color: Segment['color']; dot: string }> = [
  { key: 'inStock', label: 'In stock', color: 'pos', dot: 'bg-pos' },
  { key: 'lowStock', label: 'Low stock', color: 'accent', dot: 'bg-accent' },
  { key: 'outOfStock', label: 'Out of stock', color: 'neg', dot: 'bg-neg' },
];

export function InventoryStatusCard() {
  const { data: products, isLoading } = useProducts();
  const summary = useMemo(() => summarizeInventory(products ?? []), [products]);

  return (
    <Card
      title="Inventory status"
      headerAction={<Link to={RoutePaths.inventory} className="text-ctl-sm font-medium text-ink-2 hover:text-ink">View all</Link>}
    >
      {isLoading ? (
        <div className="space-y-3"><Skeleton height="18px" /><Skeleton height="10px" /><Skeleton height="54px" /></div>
      ) : (
        <>
          <div className="mb-3 flex items-baseline gap-1.5">
            <span className="tnum font-mono text-inv-figure text-ink">{summary.total.toLocaleString('en-PH')}</span>
            <span className="text-micro text-ink-3">active SKUs</span>
          </div>
          <SegmentedBar segments={ROWS.map((r) => ({ label: r.label, value: summary[r.key], color: r.color }))} />
          <ul className="mt-3 space-y-2">
            {ROWS.map((row) => (
              <li key={row.key} className="flex items-center justify-between text-cell">
                <span className="flex items-center gap-2 text-ink-2">
                  <span aria-hidden className={`h-1.5 w-1.5 rounded-full ${row.dot}`} />
                  {row.label}
                </span>
                <span className="font-mono text-ink">
                  {summary[row.key].toLocaleString('en-PH')}
                  <span className="ml-1.5 text-ink-3">{sharePercent(summary[row.key], summary.total).toFixed(1)}%</span>
                </span>
              </li>
            ))}
          </ul>
        </>
      )}
    </Card>
  );
}
```

`NeedsAttentionCard.tsx` — stock rows from the same `summarizeInventory` result (passed as a prop to avoid a second subscription), void row as a nested component so its hook only runs for users who may approve:

```tsx
import { Link } from 'react-router-dom';
import type { InventorySummary } from '@/domain/products/inventoryStatus';
import { useVoidRequests } from '@/presentation/hooks/useVoidRequests';
import { RoutePaths } from '@/presentation/router/routePaths';
import { Card } from '@/presentation/components/ui/Card';
import { EmptyState } from '@/presentation/components/ui/EmptyState';
import { Button } from '@/presentation/components/ui/Button';

function AttentionRow({ label, detail, action, to }: { label: string; detail: string; action: string; to: string }) {
  return (
    <li className="flex items-center justify-between gap-3 py-2.5">
      <div className="min-w-0">
        <p className="text-cell font-medium text-ink">{label}</p>
        <p className="text-micro text-ink-3">{detail}</p>
      </div>
      <Link to={to} className="shrink-0"><Button size="sm">{action}</Button></Link>
    </li>
  );
}

function VoidRequestsRow() {
  const { pending } = useVoidRequests();
  if (pending.length === 0) return null;
  return (
    <AttentionRow
      label="Void requests"
      detail={`${pending.length} pending manager approval`}
      action="Approve"
      to={RoutePaths.voidRequests}
    />
  );
}

export function NeedsAttentionCard({ inventory, canApproveVoids }: { inventory: InventorySummary; canApproveVoids: boolean }) {
  const allClear = inventory.outOfStock === 0 && inventory.lowStock === 0 && !canApproveVoids;
  return (
    <Card title="Needs attention">
      <ul className="divide-y divide-line-2">
        {inventory.outOfStock > 0 && (
          <AttentionRow label="Out of stock" detail={`${inventory.outOfStock} SKUs unavailable at register`} action="Reorder" to={RoutePaths.inventory} />
        )}
        {inventory.lowStock > 0 && (
          <AttentionRow label="Low stock" detail={`${inventory.lowStock} SKUs below reorder point`} action="Review" to={RoutePaths.inventory} />
        )}
        {canApproveVoids && <VoidRequestsRow />}
      </ul>
      {allClear && <EmptyState message="All clear — nothing needs attention" />}
    </Card>
  );
}
```

(The spec's `?filter=out` / `?filter=low` deep links land with the Inventory rollout; until then both stock rows go to `/inventory`. Note: when `canApproveVoids` with zero pending and zero stock issues, the list renders empty — acceptable; refine in review if it looks bare.)

`RecentSalesTable.tsx`:

```tsx
import { useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  saleGrandTotal, saleTotalItemCount, type Sale,
} from '@/domain/entities';
import { saleStatusDisplayName } from '@/domain/enums';
import { paymentMethodDisplayName } from '@/domain/enums';
import { formatInShopZone } from '@/domain/time/shopTime';
import { formatMoney } from '@/core/utils/money';
import { Badge } from '@/presentation/components/ui/Badge';
import { Card } from '@/presentation/components/ui/Card';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { EmptyState } from '@/presentation/components/ui/EmptyState';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { statusTone } from '@/presentation/components/ui/statusTone';
import { RoutePaths } from '@/presentation/router/routePaths';

const LIMIT = 8;

export function RecentSalesTable({ sales, loading }: { sales: Sale[]; loading: boolean }) {
  const navigate = useNavigate();
  const [query, setQuery] = useState('');

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase();
    const filtered = q ? sales.filter((s) => s.saleNumber.toLowerCase().includes(q)) : sales;
    return filtered.slice(0, LIMIT);
  }, [sales, query]);

  const columns: Array<Column<Sale>> = [
    {
      key: 'saleNo', header: 'Sale no.', mono: true,
      render: (sale) => (
        <span className="flex items-center gap-[7px]">
          {sale.saleNumber}
          <CopyButton value={sale.saleNumber} label="sale number" />
        </span>
      ),
    },
    {
      key: 'time', header: 'Time', mono: true,
      render: (sale) => formatInShopZone(sale.createdAt, { hour: 'numeric', minute: '2-digit', hour12: true }),
    },
    {
      key: 'items', header: 'Items',
      render: (sale) => {
        const n = saleTotalItemCount(sale);
        return `${n} ${n === 1 ? 'item' : 'items'}`;
      },
    },
    { key: 'tender', header: 'Tender', render: (sale) => paymentMethodDisplayName[sale.paymentMethod] },
    {
      key: 'status', header: 'Status',
      render: (sale) => <Badge tone={statusTone(sale.status)}>{saleStatusDisplayName[sale.status]}</Badge>,
    },
    {
      key: 'total', header: 'Total', align: 'right', mono: true,
      render: (sale) => formatMoney(saleGrandTotal(sale)),
    },
  ];

  return (
    <Card
      title="Recent sales"
      headerAction={
        <>
          <SearchInput value={query} onChange={setQuery} placeholder="Search sale no." />
          <Link to={RoutePaths.daySales} className="text-ctl-sm font-medium text-ink-2 hover:text-ink">View all</Link>
        </>
      }
      padding="sm"
    >
      <DataTable
        columns={columns}
        rows={rows}
        rowKey={(sale) => sale.id}
        onRowClick={(sale) => navigate(`/reports/sale/${sale.id}`)}
        loading={loading}
        empty={<EmptyState message={query ? `No sales matching “${query}”` : 'No sales yet today'} />}
      />
    </Card>
  );
}
```

(If `saleStatusDisplayName`/`paymentMethodDisplayName` aren't re-exported from `@/domain/enums`' index, import from their actual modules.)

`DashboardPage.tsx` (full rewrite):

```tsx
import { useEffect, useMemo } from 'react';
import { summarizeSales } from '@/domain/sales/summarizeSales';
import { summarizeInventory } from '@/domain/products/inventoryStatus';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useTodaysSales } from '@/presentation/hooks/useTodaysSales';
import { useYesterdaySales } from '@/presentation/hooks/useYesterdaySales';
import { useProducts } from '@/presentation/hooks/useProducts';
import { canAccess } from '@/presentation/router/routeGuards';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ErrorState } from '@/presentation/components/ui/ErrorState';
import { KpiRow } from './KpiRow';
import { SalesThroughDay } from './SalesThroughDay';
import { InventoryStatusCard } from './InventoryStatusCard';
import { NeedsAttentionCard } from './NeedsAttentionCard';
import { RecentSalesTable } from './RecentSalesTable';

export function DashboardPage() {
  const user = useAuthStore((s) => s.user);
  const { data: sales, isLoading, error } = useTodaysSales();
  const { summary: yesterday } = useYesterdaySales();
  const { data: products } = useProducts();

  const summary = useMemo(() => summarizeSales(sales ?? []), [sales]);
  const inventory = useMemo(() => summarizeInventory(products ?? []), [products]);
  const canSeeCost = user != null && hasPermission(user.role, Permission.viewProductCost);
  const canApproveVoids = user != null && canAccess(RoutePaths.voidRequests, user);

  useEffect(() => {
    document.title = 'Dashboard · MAKI POS Admin';
  }, []);

  if (error) {
    return <ErrorState message="Couldn't load today's sales." onRetry={() => window.location.reload()} />;
  }

  return (
    <div className="grid gap-4">
      <KpiRow summary={summary} yesterday={yesterday} canSeeCost={canSeeCost} loading={isLoading} />
      <div className="grid gap-4 lg:grid-cols-[1.6fr_1fr]">
        <SalesThroughDay sales={sales ?? []} summary={summary} canSeeCost={canSeeCost} loading={isLoading} />
        <div className="grid content-start gap-4">
          <InventoryStatusCard />
          <NeedsAttentionCard inventory={inventory} canApproveVoids={canApproveVoids} />
        </div>
      </div>
      <RecentSalesTable sales={sales ?? []} loading={isLoading} />
    </div>
  );
}
```

Check `hasPermission`'s actual import path/signature in the old `DashboardPage.tsx` before deleting it and mirror exactly. Verify the auth store selector shape (`useAuthStore((s) => s.user)`) against existing pages. Then delete `RecentSales.tsx`, `RecentSales.test.tsx`, `InventoryStatus.tsx` and fix any dangling imports (`grep -rn "RecentSales\|features/dashboard/InventoryStatus" src`).

- [ ] **Step 4: Run** — `npm run test -- dashboard && npm run test && npm run typecheck` → ALL PASS.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(web): dashboard rebuilt on the shared component library"`

---

### Task 17: Full verification + docs

- [ ] **Step 1:** `npm run typecheck && npm run test && npm run build` — all clean. Paste outputs into the task report.
- [ ] **Step 2:** Fix `web_admin/README.md`'s stale stack claims (it says lucide-react and TanStack Table are used; state the truth: heroicons, hand-rolled shared DataTable, IBM Plex via fontsource, CSS-variable theming with light/dark).
- [ ] **Step 3:** `npm run dev` and eyeball BOTH themes by hand (or via the `run` skill with screenshots): Dashboard light, Dashboard dark (toggle), sidebar badges, copy toast, search filter, cashier view if a test cashier login exists. Legacy screens: spot-check Inventory and Reports still render legibly on the new fonts/background in LIGHT mode. Known accepted gap: legacy screens are not dark-mode aware until their rollout phase — they stay light-styled cards on the dark page background.
- [ ] **Step 4:** Update `design/MAKI POS Dashboard - Spec.md` §8 with a dated note: Phase 1 shipped (tokens, primitives minus FilterBar/TableViews/Drawer/LineChart/MiniBar, Dashboard); rollout order unchanged.
- [ ] **Step 5:** Commit — `git add -A && git commit -m "docs(web): reskin phase-1 verification + stack notes"`. Do NOT merge or push — finishing the branch is a user decision (finishing-a-development-branch skill).

---

## Self-review notes (spec coverage)

- §1 typography → Task 1 (scale) + mono rule enforced in every component. §2 palette + both color rules → Task 1 (tokens), constraints (no `--accent-line` as text, no bg transitions). §3 geometry → Task 1 radii/shadow/width + AppShell paddings. §4 theme switching → Task 2 (attribute set inside the handler). §5.1 → Tasks 12/16 (KpiRow + useYesterdaySales). §5.2 → Tasks 11/12/16. §5.3 → Task 16 (SalesThroughDay margin strip). §5.4 → Tasks 12/16. §5.5 → Task 16 (NeedsAttentionCard; `?filter=` deep links deferred to Inventory rollout). §5.6 → Task 16 (RecentSalesTable; drawer deferred per §8 — row click navigates to the existing sale detail). §5.7 → Task 6. §5.8 → Task 14. §5.9 → Tasks 13/15. §5.10 → shop-time helpers + `formatMoney` throughout; money stays in pesos as the whole existing codebase does (centavo storage is a server-side concern outside this phase). §7 → Tasks 3–11, 15; FilterBar/TableViews/Drawer/LineChart/MiniBar + DataTable sort/pagination/selection explicitly deferred (Global Constraints). §8 → Task 17 step 4.
- Known deviations, all deliberate: heroicons not lucide (user decision); StatCard `chip` prop replaces `delta`+`deltaTone` pair; KPI endpoint shapes are Firestore hooks, not REST; admin-only COGS/profit tiles preserved from production behavior though the spec's screenshot shows five tiles.
