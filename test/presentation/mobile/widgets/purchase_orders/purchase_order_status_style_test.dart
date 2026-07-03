import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart';

void main() {
  test('status styles resolve to the AppColors PO tokens in both themes', () {
    for (final dark in [false, true]) {
      final draft =
          PurchaseOrderStatusStyle.of(PurchaseOrderStatus.draft, dark: dark);
      expect(draft.textColor, AppColors.poDraftFg(dark), reason: 'dark=$dark');
      expect(draft.tint, AppColors.poDraftBg(dark));

      final ordered =
          PurchaseOrderStatusStyle.of(PurchaseOrderStatus.ordered, dark: dark);
      expect(ordered.textColor, AppColors.poOrderedFg(dark));
      expect(ordered.tint, AppColors.poOrderedBg(dark));

      final received =
          PurchaseOrderStatusStyle.of(PurchaseOrderStatus.received, dark: dark);
      expect(received.textColor, AppColors.poReceivedFg(dark));
      expect(received.tint, AppColors.poReceivedBg(dark));

      final cancelled = PurchaseOrderStatusStyle.of(
          PurchaseOrderStatus.cancelled,
          dark: dark);
      expect(cancelled.textColor, AppColors.poCancelledFg(dark));
      expect(cancelled.tint, AppColors.poCancelledBg(dark));
    }
  });

  test('token values match the handoff table (light)', () {
    expect(AppColors.poOrderedFg(false), const Color(0xFFC8881A));
    expect(AppColors.poDraftBg(false), const Color(0x14000000));
    expect(AppColors.poCancelledBg(false), const Color(0x1AF44336));
  });
}
