import 'package:flutter/material.dart';

/// Chip colors for one tag token: soft tint background + readable foreground.
class TagChipStyle {
  final Color bg;
  final Color fg;
  const TagChipStyle(this.bg, this.fg);
}

/// The eight tag color tokens, stored verbatim in `product_tags.color`.
/// Keep in lockstep with web_admin/src/domain/tags/tagColors.ts — the same
/// token must render as the same hue on both surfaces.
abstract class TagColors {
  static const List<String> tokens = [
    'gray', 'red', 'amber', 'green', 'teal', 'blue', 'purple', 'pink',
  ];

  static String normalize(String? value) =>
      tokens.contains(value) ? value! : 'gray';

  static const Map<String, TagChipStyle> _light = {
    'gray':   TagChipStyle(Color(0xFFECEFF1), Color(0xFF455A64)),
    'red':    TagChipStyle(Color(0xFFFDE8E8), Color(0xFFB03A34)),
    'amber':  TagChipStyle(Color(0xFFFBF0DC), Color(0xFF8A6116)),
    'green':  TagChipStyle(Color(0xFFE5F2E5), Color(0xFF2E7D32)),
    'teal':   TagChipStyle(Color(0xFFE0F0EF), Color(0xFF1F6E66)),
    'blue':   TagChipStyle(Color(0xFFE3EDF8), Color(0xFF2A5D8F)),
    'purple': TagChipStyle(Color(0xFFEEE8F7), Color(0xFF6A4FA3)),
    'pink':   TagChipStyle(Color(0xFFF9E7F0), Color(0xFFA34D77)),
  };

  // Dark theme: dim tint (low-alpha fg over surface), brighter foreground.
  static const Map<String, TagChipStyle> _dark = {
    'gray':   TagChipStyle(Color(0x2690A4AE), Color(0xFFB0BEC5)),
    'red':    TagChipStyle(Color(0x26E57373), Color(0xFFEF9A9A)),
    'amber':  TagChipStyle(Color(0x26D9A54A), Color(0xFFE6C07B)),
    'green':  TagChipStyle(Color(0x2681C784), Color(0xFF8FE39A)),
    'teal':   TagChipStyle(Color(0x264DB6AC), Color(0xFF80CBC4)),
    'blue':   TagChipStyle(Color(0x2664B5F6), Color(0xFF90CAF9)),
    'purple': TagChipStyle(Color(0x26B39DDB), Color(0xFFC5AEE8)),
    'pink':   TagChipStyle(Color(0x26F06292), Color(0xFFF48FB1)),
  };

  static TagChipStyle styleFor(String token, bool isDark) {
    final map = isDark ? _dark : _light;
    return map[normalize(token)]!;
  }
}
