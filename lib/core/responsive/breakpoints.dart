import 'package:flutter/widgets.dart';

/// Window-size breakpoints used by the web admin shell.
///
/// Tuned for an admin tool consumed primarily on desktop browsers; the mobile
/// app does not consult these (it ships its own responsive logic per screen).
abstract class Breakpoints {
  /// Below this width: phone-sized.
  static const double compact = 600;

  /// Below this width: sidebar collapses to icons; forms stack to one column.
  static const double medium = 900;

  /// At and above this width: sidebar fully extended with labels.
  static const double expanded = 1280;

  /// Centered max width for content area on very wide screens.
  static const double maxContentWidth = 1440;
}

extension BreakpointX on BuildContext {
  double get _width => MediaQuery.of(this).size.width;

  bool get isCompact => _width < Breakpoints.compact;
  bool get isMedium =>
      _width >= Breakpoints.compact && _width < Breakpoints.expanded;
  bool get isExpanded => _width >= Breakpoints.expanded;

  /// True when the form/grid layout has room for two columns side by side.
  bool get hasTwoColumnRoom => _width >= Breakpoints.medium;
}
