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
          BoxShadow(color: Color(0x0F111C1D), blurRadius: 8, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x0D111C1D), blurRadius: 2, offset: Offset(0, 1)),
        ];

  /// The Gross-Sales hero card.
  static List<BoxShadow> hero({bool dark = false}) => dark
      ? const [
          BoxShadow(color: Color(0x8C000000), blurRadius: 28, spreadRadius: -10, offset: Offset(0, 10)),
        ]
      : const [
          BoxShadow(color: Color(0x29111C1D), blurRadius: 28, spreadRadius: -10, offset: Offset(0, 10)),
          BoxShadow(color: Color(0x0D111C1D), blurRadius: 6, offset: Offset(0, 2)),
        ];

  /// The pinned header surface (app bar + quick actions) — soft bottom shadow.
  static List<BoxShadow> pinnedHeader({bool dark = false}) => dark
      ? const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 2))]
      : const [BoxShadow(color: Color(0x0D111C1D), blurRadius: 10, offset: Offset(0, 2))];

  /// Primary (slate) button — light. Dark uses [primaryButtonGold].
  static const List<BoxShadow> primaryButton = [
    BoxShadow(color: Color(0x8C283E46), blurRadius: 20, spreadRadius: -6, offset: Offset(0, 8)),
  ];

  /// Primary (gold) button — dark theme.
  static const List<BoxShadow> primaryButtonGold = [
    BoxShadow(color: Color(0x80E8B84C), blurRadius: 22, spreadRadius: -6, offset: Offset(0, 8)),
  ];

  /// The New-Sale quick-action pill (a touch tighter than the button).
  static List<BoxShadow> newSalePill({bool dark = false}) => dark
      ? const [BoxShadow(color: Color(0x73E8B84C), blurRadius: 16, spreadRadius: -4, offset: Offset(0, 6))]
      : const [BoxShadow(color: Color(0x80283E46), blurRadius: 16, spreadRadius: -4, offset: Offset(0, 6))];

  /// Focus-ring glow around a focused input.
  static List<BoxShadow> focusRing({bool dark = false}) => dark
      ? const [BoxShadow(color: Color(0x1FE8B84C), spreadRadius: 4)]
      : const [BoxShadow(color: Color(0x14283E46), spreadRadius: 4)];

  /// Pinned bottom action bar — soft shadow cast UPWARD (top edge).
  /// Mirror of [pinnedHeader] with a negative y-offset.
  static List<BoxShadow> pinnedFooter({bool dark = false}) => dark
      ? const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, -4))]
      : const [BoxShadow(color: Color(0x0F111C1D), blurRadius: 16, offset: Offset(0, -4))];

  /// Confirm-Payment (success-green) button glow. Distinct from the
  /// slate/gold [primaryButton]; signals the terminal "commit the sale" action.
  static List<BoxShadow> confirmButton({bool dark = false}) => dark
      ? const [BoxShadow(color: Color(0x734CAF50), blurRadius: 20, spreadRadius: -6, offset: Offset(0, 8))]
      : const [BoxShadow(color: Color(0x804CAF50), blurRadius: 20, spreadRadius: -6, offset: Offset(0, 8))];
}
