import 'package:flutter/widgets.dart';

/// App-specific icons that aren't in CupertinoIcons or Material Icons.
class AppIcons {
  AppIcons._();

  /// Peso (₱) glyph rendered as an icon. Uses U+20B1 from the Roboto font,
  /// which Flutter bundles by default on all platforms.
  static const IconData peso = IconData(0x20B1, fontFamily: 'Roboto');
}
