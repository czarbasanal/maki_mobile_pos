// Theme tokens mirroring lib/core/theme/{app_colors,app_spacing,app_text_styles}.dart.
// Single source of truth for the React app — consumed by tailwind.config.ts and
// any component that needs raw token values. Keep field names aligned with the
// Dart counterparts so visual parity is auditable.

export const colors = {
  // Brand
  primaryDark: '#121C1D',
  primaryAccent: '#E8B84C',
  brandSlate: '#334E58',

  // Light theme
  light: {
    background: '#FFFFFF',
    surface: '#F5F5F5',
    card: '#FFFFFF',
    text: '#000000',
    textSecondary: '#666666',
    textHint: '#999999',
    divider: '#E0E0E0',
    border: '#D0D0D0',
    accent: '#334E58',
    accentText: '#FFFFFF',
  },

  // Dark theme
  dark: {
    background: '#121C1D',
    surface: '#1E2A2B',
    card: '#243334',
    text: '#FFFFFF',
    textSecondary: '#B0B0B0',
    textHint: '#808080',
    divider: '#3A4A4B',
    border: '#4A5A5B',
    accent: '#E8B84C',
    accentText: '#000000',
  },

  // Semantic
  success: '#4CAF50',
  successLight: '#E8F5E9',
  successDark: '#2E7D32',
  warning: '#FFC107',
  warningLight: '#FFF8E1',
  warningDark: '#F57C00',
  error: '#F44336',
  errorLight: '#FFEBEE',
  errorDark: '#C62828',
  info: '#2196F3',
  infoLight: '#E3F2FD',
  infoDark: '#1565C0',

  // POS-specific
  pos: {
    cash: '#4CAF50',
    gcash: '#007DFE',
    voided: '#9E9E9E',
    draft: '#FF9800',
    lowStock: '#FF5722',
    outOfStock: '#F44336',
    inStock: '#4CAF50',
  },

  // Role badges
  role: {
    admin: '#9C27B0',
    staff: '#2196F3',
    cashier: '#4CAF50',
  },
} as const;

export const spacing = {
  xs: '4px',
  sm: '8px',
  md: '16px',
  lg: '24px',
  xl: '32px',
  xxl: '48px',
} as const;

// Type scale mirrors lib/core/theme/app_text_styles.dart. Values are in px.
export const fontSize = {
  headingXL: ['32px', { lineHeight: '1.2', letterSpacing: '-0.5px', fontWeight: '700' }],
  headingLarge: ['28px', { lineHeight: '1.2', letterSpacing: '-0.5px', fontWeight: '700' }],
  headingMedium: ['24px', { lineHeight: '1.3', letterSpacing: '-0.25px', fontWeight: '600' }],
  headingSmall: ['20px', { lineHeight: '1.3', fontWeight: '600' }],
  bodyLarge: ['18px', { lineHeight: '1.5', fontWeight: '400' }],
  bodyMedium: ['16px', { lineHeight: '1.5', fontWeight: '400' }],
  bodySmall: ['14px', { lineHeight: '1.4', fontWeight: '400' }],
  labelLarge: ['16px', { lineHeight: '1.4', letterSpacing: '0.5px', fontWeight: '600' }],
  labelMedium: ['14px', { lineHeight: '1.4', letterSpacing: '0.25px', fontWeight: '500' }],
  labelSmall: ['12px', { lineHeight: '1.4', letterSpacing: '0.25px', fontWeight: '500' }],
  priceXL: ['36px', { lineHeight: '1.1', letterSpacing: '-0.5px', fontWeight: '700' }],
  priceLarge: ['24px', { lineHeight: '1.2', fontWeight: '700' }],
  priceMedium: ['18px', { lineHeight: '1.3', fontWeight: '600' }],
  priceSmall: ['14px', { lineHeight: '1.4', fontWeight: '600' }],
  code: ['14px', { lineHeight: '1.4', letterSpacing: '1px', fontWeight: '500' }],
  costCode: ['16px', { lineHeight: '1.4', letterSpacing: '2px', fontWeight: '700' }],
  badge: ['11px', { lineHeight: '1.4', letterSpacing: '0.5px', fontWeight: '600' }],
} as const;

export const layout = {
  sidebarExtended: '240px',
  sidebarCollapsed: '72px',
  topBarHeight: '64px',
  maxContentWidth: '1280px',
} as const;
