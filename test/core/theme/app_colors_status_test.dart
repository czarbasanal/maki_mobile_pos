import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/theme/app_colors.dart';

void main() {
  group('AppColors status helpers — light/dark parity', () {
    test('success icon', () {
      expect(AppColors.successIcon(false), const Color(0xFF4CAF50));
      expect(AppColors.successIcon(true), const Color(0xFF5FC86A));
    });
    test('warning icon + badge text', () {
      expect(AppColors.warningIcon(false), const Color(0xFFF57C00));
      expect(AppColors.warningIcon(true), const Color(0xFFF5B547));
      expect(AppColors.warningBadgeText(false), const Color(0xFF9A6300));
      expect(AppColors.warningBadgeText(true), const Color(0xFFF5B547));
    });
    test('info icon + badge text', () {
      expect(AppColors.infoIcon(false), const Color(0xFF2196F3));
      expect(AppColors.infoIcon(true), const Color(0xFF5AA9F0));
      expect(AppColors.infoBadgeText(false), const Color(0xFF1976D2));
      expect(AppColors.infoBadgeText(true), const Color(0xFF7FB6FF));
    });
    test('cost-diff up/down', () {
      expect(AppColors.costUp(false), const Color(0xFFC62828));
      expect(AppColors.costUp(true), const Color(0xFFFF6B5E));
      expect(AppColors.costDown(false), const Color(0xFF2E7D32));
      expect(AppColors.costDown(true), const Color(0xFF8FE39A));
    });
  });
}
