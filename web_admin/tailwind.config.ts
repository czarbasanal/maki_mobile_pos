import type { Config } from 'tailwindcss';
import animate from 'tailwindcss-animate';
import { colors, spacing, fontSize, layout } from './src/core/theme/tokens';

const config: Config = {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        'primary-dark': colors.primaryDark,
        'primary-accent': colors.primaryAccent,
        'brand-slate': colors.brandSlate,
        light: {
          background: colors.light.background,
          surface: colors.light.surface,
          card: colors.light.card,
          text: colors.light.text,
          'text-secondary': colors.light.textSecondary,
          'text-hint': colors.light.textHint,
          divider: colors.light.divider,
          border: colors.light.border,
          hairline: colors.light.hairline,
          subtle: colors.light.subtle,
          accent: colors.light.accent,
          'accent-text': colors.light.accentText,
        },
        dark: {
          background: colors.dark.background,
          surface: colors.dark.surface,
          card: colors.dark.card,
          text: colors.dark.text,
          'text-secondary': colors.dark.textSecondary,
          'text-hint': colors.dark.textHint,
          divider: colors.dark.divider,
          border: colors.dark.border,
          accent: colors.dark.accent,
          'accent-text': colors.dark.accentText,
        },
        success: colors.success,
        'success-light': colors.successLight,
        'success-dark': colors.successDark,
        warning: colors.warning,
        'warning-light': colors.warningLight,
        'warning-dark': colors.warningDark,
        error: colors.error,
        'error-light': colors.errorLight,
        'error-dark': colors.errorDark,
        // DEFAULT/soft are the new-skin CSS variables (theme.css); the
        // legacy light/dark literals stay for the old-skin screens.
        info: { DEFAULT: 'var(--info)', soft: 'var(--info-soft)' },
        'info-light': colors.infoLight,
        'info-dark': colors.infoDark,
        role: colors.role,

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
      spacing: {
        'tk-xs': spacing.xs,
        'tk-sm': spacing.sm,
        'tk-md': spacing.md,
        'tk-lg': spacing.lg,
        'tk-xl': spacing.xl,
        'tk-xxl': spacing.xxl,
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
      height: {
        topbar: layout.topBarHeight,
      },
      maxWidth: {
        content: layout.maxContentWidth,
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
        'ctl-lg': ['14px', { lineHeight: '20px' }],
        'ctl-md': ['12.5px', { lineHeight: '18px' }],
      },
    },
  },
  plugins: [animate],
};

export default config;
