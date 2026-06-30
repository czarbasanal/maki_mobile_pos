import 'package:flutter/material.dart';

/// Soft-shadow elevation for the refreshed theme.
///
/// The defining change of the new theme: surfaces lift off the canvas with
/// low-opacity shadows (Airbnb-style) in light mode. Dark mode leans on a 1px
/// border instead, with a deeper shadow only on the hero/primary surfaces.
///
/// `Material`'s numeric `elevation` does not reproduce these — apply these
/// `BoxShadow` lists to a `Container`'s `BoxDecoration` directly.
abstract class AppShadows {
  /// Resting card (light). Dark uses a 1px border instead (callers add it).
  static List<BoxShadow> card({bool dark = false}) => dark
      ? const []
      : const [
          BoxShadow(color: Color(0x0C111C1D), blurRadius: 4, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x0A111C1D), blurRadius: 1, offset: Offset(0, 1)),
        ];

  /// The Gross-Sales hero card.
  static List<BoxShadow> hero({bool dark = false}) => dark
      ? const [
          BoxShadow(color: Color(0x8C000000), blurRadius: 28, spreadRadius: -10, offset: Offset(0, 10)),
        ]
      : const [
          BoxShadow(color: Color(0x1F111C1D), blurRadius: 20, spreadRadius: -10, offset: Offset(0, 8)),
          BoxShadow(color: Color(0x0A111C1D), blurRadius: 5, offset: Offset(0, 2)),
        ];

  /// The pinned header surface (app bar + quick actions) — soft bottom shadow.
  static List<BoxShadow> pinnedHeader({bool dark = false}) => dark
      ? const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 2))]
      : const [BoxShadow(color: Color(0x0D111C1D), blurRadius: 10, offset: Offset(0, 2))];

  /// Primary (slate) button — light. Dark uses [primaryButtonGold].
  /// Buttons are flat: no drop shadow.
  static const List<BoxShadow> primaryButton = [];

  /// Primary (gold) button — dark theme. Flat: no drop shadow.
  static const List<BoxShadow> primaryButtonGold = [];

  /// The New-Sale quick-action pill. Flat: no drop shadow.
  static List<BoxShadow> newSalePill({bool dark = false}) => const [];

  /// Focus-ring glow around a focused input. Disabled: inputs use only the
  /// border-color change on focus, no glow.
  static List<BoxShadow> focusRing({bool dark = false}) => const [];

  /// Pinned bottom action bar — soft shadow cast UPWARD (top edge).
  /// Mirror of [pinnedHeader] with a negative y-offset.
  static List<BoxShadow> pinnedFooter({bool dark = false}) => dark
      ? const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, -4))]
      : const [BoxShadow(color: Color(0x0F111C1D), blurRadius: 16, offset: Offset(0, -4))];

  /// Confirm-Payment (success-green) button. Flat: no drop shadow.
  static List<BoxShadow> confirmButton({bool dark = false}) => const [];
}
