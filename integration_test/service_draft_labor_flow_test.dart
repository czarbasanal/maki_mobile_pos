// Service-draft end-to-end flow: add a part, add labor, assign a mechanic,
// save as draft, reload into a fresh cart, check out, and assert the sale
// carries labor inline + mechanic, while the REAL parts-only getSalesSummary
// is unchanged and laborRevenue reflects the labor (decision #9 invariant).
//
// Backend persistence uses FakeFirebaseFirestore + the real SaleRepositoryImpl
// (no Firebase, no network), matching the in-memory-fake style of
// sku_edit_flow_test.dart. See README.md.
//
// Run on a connected device/emulator:
//   flutter test integration_test/service_draft_labor_flow_test.dart -d <device-id>

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/sale_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';

ProductEntity _part() => ProductEntity(
      id: 'prod-1',
      sku: 'SKU-001',
      name: 'Spark Plug',
      costCode: 'NBF',
      cost: 60,
      price: 100,
      quantity: 100,
      reorderLevel: 10,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('service draft round-trips labor + mechanic, then checks out '
      'with a real parts-only sales summary', (tester) async {
    // 1. Build a service draft in the cart: one part + two labor lines + mechanic.
    final cart = CartNotifier();
    cart.addProduct(_part()); // partsSubtotal = 100
    cart.addLaborLine(description: 'Engine tune-up', fee: 450);
    cart.addLaborLine(description: 'Brake bleed', fee: 300);
    cart.setMechanic('mech-1', 'Juan Dela Cruz');

    expect(cart.state.partsSubtotal, 100);
    expect(cart.state.laborSubtotal, 750);
    expect(cart.state.grandTotal, 850);
    expect(cart.state.mechanicName, 'Juan Dela Cruz');

    // 2. Save as draft.
    final draft = cart.toDraft(
      name: 'Plate ABC-123',
      createdBy: 'cashier-1',
      createdByName: 'Cashier',
    );
    expect(draft.laborLines.length, 2);
    expect(draft.mechanicId, 'mech-1');
    expect(draft.mechanicName, 'Juan Dela Cruz');
    expect(draft.laborSubtotal, 750);
    expect(draft.grandTotal, 850);

    // 3. Reload the draft into a FRESH cart — labor + mechanic must survive.
    final reloaded = CartNotifier();
    reloaded.loadFromDraft(draft);
    expect(reloaded.state.laborLines.length, 2);
    expect(reloaded.state.mechanicId, 'mech-1');
    expect(reloaded.state.mechanicName, 'Juan Dela Cruz');
    expect(reloaded.state.grandTotal, 850);

    // 4. Check out: pay the full grand total in cash.
    reloaded.setPaymentMethod(PaymentMethod.cash);
    reloaded.setAmountReceived(850);
    expect(reloaded.state.isPaymentValid, true);

    final sale = reloaded.toSale(
      saleNumber: 'SALE-0001',
      cashierId: 'cashier-1',
      cashierName: 'Cashier',
    );

    // 5. Receipt-facing data: labor lines + mechanic carried on the sale.
    expect(sale.laborLines.map((l) => l.description),
        containsAll(<String>['Engine tune-up', 'Brake bleed']));
    expect(sale.laborSubtotal, 750);
    expect(sale.mechanicName, 'Juan Dela Cruz');
    expect(sale.grandTotal, 850); // labor-inclusive true total on the receipt

    // 6. Persist via the REAL repository + read back the REAL summary.
    final firestore = FakeFirebaseFirestore();
    final repository = SaleRepositoryImpl(firestore: firestore);
    final created = await repository.createSale(sale);

    // Round-trip: labor persisted inline on the sale doc.
    final reloadedSale = await repository.getSaleById(created.id);
    expect(reloadedSale!.laborLines.length, 2);
    expect(reloadedSale.mechanicName, 'Juan Dela Cruz');

    final today = DateTime.now();
    final summary = await repository.getSalesSummary(
      startDate: today,
      endDate: today,
    );

    // Parts-only top-line unchanged; labor on its own track (decision #9).
    expect(summary.grossAmount, 100); // parts only
    expect(summary.netAmount, 100); // parts only — NOT 850
    expect(summary.totalProfit, 40); // parts profit (100 - 60 cost)
    expect(summary.laborRevenue, 750); // labor track
    expect(summary.laborProfit, 750); // zero-cost labor
    // Cash bucket is labor-inclusive.
    expect(summary.byPaymentMethod[PaymentMethod.cash], 850);
    // Reconciliation identity: Σ byPaymentMethod == net(parts) + laborRevenue.
    final tenderTotal =
        summary.byPaymentMethod.values.fold<double>(0, (a, b) => a + b);
    expect(tenderTotal, summary.netAmount + summary.laborRevenue); // 850
  });
}
