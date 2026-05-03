/// Spacing scale used across the web admin layouts.
///
/// Mobile screens currently hard-code spacing literals; this scale is adopted
/// by web widgets first and can be retrofitted into mobile incrementally.
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner-radius scale.
///
/// Used by [AppTheme] and surface primitives so radii stay consistent across
/// inputs, buttons, cards, and dialogs. The mobile UI leans on `lg` and `xl`
/// for the airy/rounded look; `pill` is reserved for chips and segmented
/// controls.
abstract class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}
