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
        info: colors.info,
        'info-light': colors.infoLight,
        'info-dark': colors.infoDark,
        pos: colors.pos,
        role: colors.role,
      },
      spacing: {
        'tk-xs': spacing.xs,
        'tk-sm': spacing.sm,
        'tk-md': spacing.md,
        'tk-lg': spacing.lg,
        'tk-xl': spacing.xl,
        'tk-xxl': spacing.xxl,
      },
      width: {
        'sidebar-extended': layout.sidebarExtended,
        'sidebar-collapsed': layout.sidebarCollapsed,
      },
      height: {
        topbar: layout.topBarHeight,
      },
      maxWidth: {
        content: layout.maxContentWidth,
      },
      fontFamily: {
        sans: ['Roboto', 'system-ui', 'sans-serif'],
        mono: ['ui-monospace', 'SFMono-Regular', 'Menlo', 'monospace'],
      },
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      fontSize: fontSize as any,
    },
  },
  plugins: [animate],
};

export default config;
