# Mobile Reports: Hub + Shared Date Filter + CSV Export — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the mobile app a Sales/Profit/Labor reports hub, a shared preset date filter across all three reports, and an Export-as-CSV action on each.

**Architecture:** Extract two shared helpers (`dateRangeForPreset`, `saveReportCsv`) and add pure per-report CSV builders, then wire each report screen. A new `ReportsHubScreen` becomes the `/reports` landing; the transaction list moves to `/reports/history`.

**Tech Stack:** Flutter, Riverpod, go_router, `csv` + `file_picker` packages (already dependencies), `flutter_test`/`mocktail`/`fake_cloud_firestore`.

## Global Constraints

- Mobile app only. No `web_admin/` changes.
- No new packages — reuse `csv: ^6.0.0` and `file_picker`.
- CSV uses LF (`\n`) line endings via `ListToCsvConverter(eol: '\n')`.
- Follow existing patterns: `AppCard` tiles, `context.showSuccessSnackBar`/`showErrorSnackBar`/`showSnackBar`, Lucide icons.
- Default preset across all three reports: `DateRangePreset.today`.
- Daily-only roles (`RolePermissions.isDailyReportsOnly`) stay locked to Today on Sales and Labor; Profit is admin-only via route guard.
- Run `flutter analyze` and `flutter test` after each task; both must be clean before committing.

---

### Task 1: `dateRangeForPreset` helper

**Files:**
- Create: `lib/core/utils/report_date_range.dart`
- Test: `test/core/utils/report_date_range_test.dart`

**Interfaces:**
- Consumes: `DateRangePreset` from `lib/presentation/mobile/widgets/reports/date_range_picker.dart`.
- Produces: `DateTimeRange dateRangeForPreset(DateRangePreset preset, DateTime now)` — start at midnight, end at 23:59:59 of the last day. `custom` returns today (defensive; never selected via the dropdown).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/utils/report_date_range_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';

void main() {
  final now = DateTime(2026, 7, 1, 14, 30); // fixed anchor

  test('today = midnight..23:59:59 same day', () {
    final r = dateRangeForPreset(DateRangePreset.today, now);
    expect(r.start, DateTime(2026, 7, 1));
    expect(r.end, DateTime(2026, 7, 1, 23, 59, 59));
  });

  test('yesterday = the prior day', () {
    final r = dateRangeForPreset(DateRangePreset.yesterday, now);
    expect(r.start, DateTime(2026, 6, 30));
    expect(r.end, DateTime(2026, 6, 30, 23, 59, 59));
  });

  test('thisWeek starts on a Monday on/before now', () {
    final r = dateRangeForPreset(DateRangePreset.thisWeek, now);
    expect(r.start.weekday, DateTime.monday);
    expect(r.start.isAfter(now), isFalse);
    expect(now.difference(r.start).inDays, lessThan(7));
  });

  test('thisMonth starts on the 1st', () {
    final r = dateRangeForPreset(DateRangePreset.thisMonth, now);
    expect(r.start, DateTime(2026, 7, 1));
  });

  test('lastMonth spans the whole previous month', () {
    final r = dateRangeForPreset(DateRangePreset.lastMonth, now);
    expect(r.start, DateTime(2026, 6, 1));
    expect(r.end, DateTime(2026, 6, 30, 23, 59, 59));
  });

  test('thisQuarter: July is Q3 -> starts July 1', () {
    final r = dateRangeForPreset(DateRangePreset.thisQuarter, now);
    expect(r.start, DateTime(2026, 7, 1));
  });

  test('thisYear starts Jan 1', () {
    final r = dateRangeForPreset(DateRangePreset.thisYear, now);
    expect(r.start, DateTime(2026, 1, 1));
  });

  test('custom falls back to today', () {
    final r = dateRangeForPreset(DateRangePreset.custom, now);
    expect(r.start, DateTime(2026, 7, 1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/report_date_range_test.dart`
Expected: FAIL — `report_date_range.dart` / `dateRangeForPreset` does not exist (compile error).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/utils/report_date_range.dart
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';

/// Maps a [DateRangePreset] to a concrete [DateTimeRange] anchored at [now].
/// Start is midnight; end is 23:59:59 of the last day. Callers never pass
/// [DateRangePreset.custom] (the picker routes custom selections to its own
/// date-range picker via onCustomRangeSelected); it falls back to today.
DateTimeRange dateRangeForPreset(DateRangePreset preset, DateTime now) {
  DateTime start;
  DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  switch (preset) {
    case DateRangePreset.today:
      start = DateTime(now.year, now.month, now.day);
      break;
    case DateRangePreset.yesterday:
      final y = now.subtract(const Duration(days: 1));
      start = DateTime(y.year, y.month, y.day);
      end = DateTime(y.year, y.month, y.day, 23, 59, 59);
      break;
    case DateRangePreset.thisWeek:
      final ws = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(ws.year, ws.month, ws.day);
      break;
    case DateRangePreset.lastWeek:
      final lws = now.subtract(Duration(days: now.weekday + 6));
      final lwe = now.subtract(Duration(days: now.weekday));
      start = DateTime(lws.year, lws.month, lws.day);
      end = DateTime(lwe.year, lwe.month, lwe.day, 23, 59, 59);
      break;
    case DateRangePreset.thisMonth:
      start = DateTime(now.year, now.month, 1);
      break;
    case DateRangePreset.lastMonth:
      start = DateTime(now.year, now.month - 1, 1);
      end = DateTime(now.year, now.month, 0, 23, 59, 59);
      break;
    case DateRangePreset.thisQuarter:
      final firstMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      start = DateTime(now.year, firstMonth, 1);
      break;
    case DateRangePreset.thisYear:
      start = DateTime(now.year, 1, 1);
      break;
    case DateRangePreset.custom:
      start = DateTime(now.year, now.month, now.day);
      break;
  }
  return DateTimeRange(start: start, end: end);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/report_date_range_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/report_date_range.dart test/core/utils/report_date_range_test.dart
git commit -m "feat(reports): extract dateRangeForPreset helper"
```

---

### Task 2: Refactor SalesReportScreen to use `dateRangeForPreset`

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/sales_report_screen.dart` (`_handlePresetChange`, ~lines 278–330)

**Interfaces:**
- Consumes: `dateRangeForPreset` (Task 1).
- Produces: nothing new; behavior identical.

- [ ] **Step 1: Replace the inline switch**

Replace the whole body of `_handlePresetChange` with a call to the helper. New method:

```dart
  void _handlePresetChange(DateRangePreset preset) {
    if (preset == DateRangePreset.custom) return; // dropdown never emits custom
    final range = dateRangeForPreset(preset, DateTime.now());
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
      _selectedPreset = preset;
    });
  }
```

Add the import at the top with the other `core/utils` imports:

```dart
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
```

- [ ] **Step 2: Analyze + run existing sales-report tests**

Run: `flutter analyze lib/presentation/mobile/screens/reports/sales_report_screen.dart`
Expected: No issues found.
Run: `flutter test test/presentation/mobile/screens/reports/`
Expected: PASS (behavior unchanged).

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/mobile/screens/reports/sales_report_screen.dart
git commit -m "refactor(reports): SalesReport uses shared dateRangeForPreset"
```

---

### Task 3: Per-report CSV builders

**Files:**
- Create: `lib/core/utils/report_csv.dart`
- Test: `test/core/utils/report_csv_test.dart`

**Interfaces:**
- Consumes: `SaleEntity` (`s.saleNumber`, `s.createdAt`, `s.cashierName`, `s.partsSubtotal`, `s.totalDiscount`, `s.grandTotal`, `s.paymentMethod.displayName`, `s.isVoided`); `ProductSalesData` (`p.name`, `p.sku`, `p.quantitySold`, `p.totalRevenue`, `p.totalCost`, `p.totalProfit`, `p.profitMargin`) from `domain/repositories/repositories.dart`; `LaborReportData`/`LaborByMechanic` from `core/utils/labor_report.dart`.
- Produces:
  - `String buildSalesReportCsv(List<SaleEntity> sales)`
  - `String buildProfitReportCsv(List<ProductSalesData> products)`
  - `String buildLaborReportCsv(LaborReportData report)`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/utils/report_csv_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/utils/labor_report.dart';
import 'package:maki_mobile_pos/core/utils/report_csv.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

SaleEntity _sale({
  required String number,
  required double unitPrice,
  required int qty,
  bool voided = false,
}) =>
    SaleEntity(
      id: number,
      saleNumber: number,
      items: [
        SaleItemEntity(
          id: 'i-$number',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Widget',
          unitPrice: unitPrice,
          unitCost: 5,
          quantity: qty,
        ),
      ],
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      amountReceived: unitPrice * qty,
      changeGiven: 0,
      cashierId: 'c1',
      cashierName: 'Cashier',
      status: voided ? SaleStatus.voided : SaleStatus.completed,
      createdAt: DateTime(2026, 7, 1, 9, 30),
    );

void main() {
  group('buildSalesReportCsv', () {
    test('header + one row per non-voided sale + totals row', () {
      final csv = buildSalesReportCsv([
        _sale(number: 'S-1', unitPrice: 100, qty: 2),
        _sale(number: 'S-2', unitPrice: 50, qty: 1, voided: true),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.first,
          'Sale #,Date,Cashier,Subtotal,Discount,Total,Payment');
      expect(lines.length, 3); // header + 1 completed + totals
      expect(lines[1], contains('S-1'));
      expect(lines.last, startsWith('TOTAL,'));
      expect(lines.last, contains('200.00'));
    });
  });

  group('buildProfitReportCsv', () {
    test('ranks by profit desc, header + rows + totals', () {
      final csv = buildProfitReportCsv(const [
        ProductSalesData(
            productId: 'p1', sku: 'A', name: 'Low',
            quantitySold: 1, totalRevenue: 100, totalCost: 90),
        ProductSalesData(
            productId: 'p2', sku: 'B', name: 'High',
            quantitySold: 2, totalRevenue: 300, totalCost: 100),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.first,
          'Product,SKU,Qty Sold,Revenue,Cost,Profit,Margin %');
      expect(lines[1], startsWith('High,')); // 200 profit ranks first
      expect(lines[2], startsWith('Low,'));
      expect(lines.last, startsWith('TOTAL,'));
    });
  });

  group('buildLaborReportCsv', () {
    test('header + row per mechanic + totals', () {
      const report = LaborReportData(
        totalLabor: 500,
        serviceSaleCount: 3,
        byMechanic: [
          LaborByMechanic(
              mechanicId: 'm1', mechanicName: 'Juan',
              laborTotal: 200, jobCount: 2),
          LaborByMechanic(
              mechanicId: 'm2', mechanicName: 'Pedro',
              laborTotal: 300, jobCount: 1),
        ],
      );
      final csv = buildLaborReportCsv(report);
      final lines = csv.trim().split('\n');
      expect(lines.first, 'Mechanic,Jobs,Labor Total');
      expect(lines.length, 4); // header + 2 + totals
      expect(lines.last, 'TOTAL,3,500.00');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/report_csv_test.dart`
Expected: FAIL — `report_csv.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/utils/report_csv.dart
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/utils/labor_report.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

const _converter = ListToCsvConverter(eol: '\n');
final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

/// One row per completed (non-voided) sale, plus a TOTAL row.
String buildSalesReportCsv(List<SaleEntity> sales) {
  var subtotal = 0.0, discount = 0.0, total = 0.0;
  final rows = <List<dynamic>>[
    ['Sale #', 'Date', 'Cashier', 'Subtotal', 'Discount', 'Total', 'Payment'],
  ];
  for (final s in sales.where((s) => !s.isVoided)) {
    subtotal += s.partsSubtotal;
    discount += s.totalDiscount;
    total += s.grandTotal;
    rows.add([
      s.saleNumber,
      _dateFmt.format(s.createdAt),
      s.cashierName,
      s.partsSubtotal.toStringAsFixed(2),
      s.totalDiscount.toStringAsFixed(2),
      s.grandTotal.toStringAsFixed(2),
      s.paymentMethod.displayName,
    ]);
  }
  rows.add([
    'TOTAL', '', '',
    subtotal.toStringAsFixed(2),
    discount.toStringAsFixed(2),
    total.toStringAsFixed(2),
    '',
  ]);
  return _converter.convert(rows);
}

/// Products ranked by profit desc, plus a TOTAL row.
String buildProfitReportCsv(List<ProductSalesData> products) {
  final ranked = [...products]
    ..sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
  var qty = 0;
  var revenue = 0.0, cost = 0.0, profit = 0.0;
  final rows = <List<dynamic>>[
    ['Product', 'SKU', 'Qty Sold', 'Revenue', 'Cost', 'Profit', 'Margin %'],
  ];
  for (final p in ranked) {
    qty += p.quantitySold;
    revenue += p.totalRevenue;
    cost += p.totalCost;
    profit += p.totalProfit;
    rows.add([
      p.name,
      p.sku,
      p.quantitySold,
      p.totalRevenue.toStringAsFixed(2),
      p.totalCost.toStringAsFixed(2),
      p.totalProfit.toStringAsFixed(2),
      p.profitMargin.toStringAsFixed(1),
    ]);
  }
  final margin = revenue > 0 ? (profit / revenue) * 100 : 0.0;
  rows.add([
    'TOTAL', '', qty,
    revenue.toStringAsFixed(2),
    cost.toStringAsFixed(2),
    profit.toStringAsFixed(2),
    margin.toStringAsFixed(1),
  ]);
  return _converter.convert(rows);
}

/// One row per mechanic, plus a TOTAL row (report totals).
String buildLaborReportCsv(LaborReportData report) {
  final rows = <List<dynamic>>[
    ['Mechanic', 'Jobs', 'Labor Total'],
  ];
  for (final m in report.byMechanic) {
    rows.add([m.mechanicName, m.jobCount, m.laborTotal.toStringAsFixed(2)]);
  }
  rows.add([
    'TOTAL',
    report.serviceSaleCount,
    report.totalLabor.toStringAsFixed(2),
  ]);
  return _converter.convert(rows);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/report_csv_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/report_csv.dart test/core/utils/report_csv_test.dart
git commit -m "feat(reports): pure CSV builders for sales/profit/labor"
```

---

### Task 4: Shared `saveReportCsv` helper (extracted from inventory export)

**Files:**
- Create: `lib/core/utils/report_export.dart`
- Modify: `lib/presentation/mobile/screens/inventory/inventory_screen.dart` (`_handleExport`, ~lines 628–670)

**Interfaces:**
- Produces: `Future<void> saveReportCsv(BuildContext context, String csv, String fileName)`.

- [ ] **Step 1: Create the helper**

```dart
// lib/core/utils/report_export.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';

/// Saves [csv] to a user-chosen `.csv` file named [fileName] using the app's
/// established export mechanism (the file save dialog). Shows a success /
/// cancelled / failed snackbar. Safe to call after awaits (guards mounted).
Future<void> saveReportCsv(
  BuildContext context,
  String csv,
  String fileName,
) async {
  try {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: bytes,
    );
    if (!context.mounted) return;
    if (path == null) {
      context.showSnackBar('Export cancelled');
      return;
    }
    // On mobile, saveFile(bytes:) already wrote the file; on desktop it only
    // returns the chosen path, so write the bytes ourselves.
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(path).writeAsBytes(bytes);
    }
    if (!context.mounted) return;
    context.showSuccessSnackBar('Exported $fileName');
  } catch (e) {
    if (context.mounted) context.showErrorSnackBar('Export failed: $e');
  }
}
```

- [ ] **Step 2: Refactor `inventory_screen._handleExport` to use it**

Replace the body from `final csv = buildInventoryCsv(products);` through the final success snackbar with:

```dart
      final csv = buildInventoryCsv(products);
      final fileName =
          'inventory_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
      if (!mounted) return;
      await saveReportCsv(context, csv, fileName);
```

Add `import 'package:maki_mobile_pos/core/utils/report_export.dart';`. Remove now-unused imports from `inventory_screen.dart` **only if** the analyzer flags them (`dart:convert`, `dart:io`, `dart:typed_data`, `file_picker` may still be used elsewhere in the file — check before removing).

- [ ] **Step 3: Analyze + run inventory tests**

Run: `flutter analyze lib/presentation/mobile/screens/inventory/inventory_screen.dart lib/core/utils/report_export.dart`
Expected: No issues found.
Run: `flutter test test/presentation/mobile/screens/inventory/`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/core/utils/report_export.dart lib/presentation/mobile/screens/inventory/inventory_screen.dart
git commit -m "refactor(reports): extract shared saveReportCsv from inventory export"
```

---

### Task 5: Reports hub screen

**Files:**
- Create: `lib/presentation/mobile/screens/reports/reports_hub_screen.dart`
- Test: `test/presentation/mobile/screens/reports/reports_hub_screen_test.dart`

**Interfaces:**
- Consumes: `currentUserProvider`, `RolePermissions.hasPermission`, `Permission.viewProfitReports`, `RouteNames.salesReport`/`profitReport`/`laborReport`, `AppCard`.
- Produces: `ReportsHubScreen` widget (used by routing in Task 6).

- [ ] **Step 1: Write the failing widget test**

```dart
// test/presentation/mobile/screens/reports/reports_hub_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/reports_hub_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

UserEntity _user(UserRole role) => UserEntity(
      id: 'u1', email: 'a@x.com', displayName: 'U',
      role: role, isActive: true, createdAt: DateTime(2026, 6, 1));

Widget _harness(UserRole role) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
      ],
      child: const MaterialApp(home: ReportsHubScreen()),
    );

void main() {
  testWidgets('admin sees Sales, Profit, Labor', (tester) async {
    await tester.pumpWidget(_harness(UserRole.admin));
    await tester.pumpAndSettle();
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Profit'), findsOneWidget);
    expect(find.text('Labor'), findsOneWidget);
  });

  testWidgets('non-admin does not see Profit', (tester) async {
    await tester.pumpWidget(_harness(UserRole.cashier));
    await tester.pumpAndSettle();
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Profit'), findsNothing);
    expect(find.text('Labor'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/reports/reports_hub_screen_test.dart`
Expected: FAIL — `reports_hub_screen.dart` does not exist.

- [ ] **Step 3: Implement the hub screen**

```dart
// lib/presentation/mobile/screens/reports/reports_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Reports landing: pick Sales, Profit (admin), or Labor.
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canProfit = user != null &&
        RolePermissions.hasPermission(user.role, Permission.viewProfitReports);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _ReportCard(
            icon: LucideIcons.barChart3,
            title: 'Sales',
            subtitle: 'Summary, top products, payment breakdown',
            onTap: () => context.pushNamed(RouteNames.salesReport),
          ),
          if (canProfit) ...[
            const SizedBox(height: 10),
            _ReportCard(
              icon: LucideIcons.trendingUp,
              title: 'Profit',
              subtitle: 'Cost, gross profit, and margin',
              onTap: () => context.pushNamed(RouteNames.profitReport),
            ),
          ],
          const SizedBox(height: 10),
          _ReportCard(
            icon: LucideIcons.wrench,
            title: 'Labor',
            subtitle: 'Service revenue by mechanic',
            onTap: () => context.pushNamed(RouteNames.laborReport),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dark = theme.brightness == Brightness.dark;
    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: dark ? const Color(0x1FE8B84C) : const Color(0x12283E46),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 22, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: muted, fontSize: 12)),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: muted),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/mobile/screens/reports/reports_hub_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/reports/reports_hub_screen.dart test/presentation/mobile/screens/reports/reports_hub_screen_test.dart
git commit -m "feat(reports): reports hub screen (Sales/Profit/Labor)"
```

---

### Task 6: Route the hub at `/reports`; move the transaction list to `/reports/history`

**Files:**
- Modify: `lib/config/router/route_names.dart` (add `salesHistory` name + `/reports/history` path)
- Modify: `lib/config/router/app_routes.dart` (index builder → `ReportsHubScreen`; add `history` child → `SalesListScreen`; add import)
- Modify: `lib/config/router/route_guards.dart` (add `/reports/history` → `viewSalesReports`)
- Modify: `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart` (Recent Transactions "View All", ~line 350: `RoutePaths.reports` → `RoutePaths.salesHistory`)

**Interfaces:**
- Consumes: `ReportsHubScreen` (Task 5).
- Produces: `RouteNames.salesHistory`, `RoutePaths.salesHistory`.

- [ ] **Step 1: Add the route name + path**

In `route_names.dart`, under the report route names add:
```dart
  /// Sales transaction history list route
  static const String salesHistory = 'salesHistory';
```
Under the report paths add (after `salesReport`):
```dart
  static const String salesHistory = '/reports/history';
```

- [ ] **Step 2: Point the index at the hub and add the history child**

In `app_routes.dart`:
- Add import: `import 'package:maki_mobile_pos/presentation/mobile/screens/reports/reports_hub_screen.dart';`
- Change the `/reports` `GoRoute` builder from `const SalesListScreen()` to `const ReportsHubScreen()`.
- Add a child route (alongside `sales`, `profit`, `labor`):
```dart
          GoRoute(
            path: 'history',
            name: RouteNames.salesHistory,
            builder: (context, state) => const SalesListScreen(),
          ),
```

- [ ] **Step 3: Guard the new path**

In `route_guards.dart`, in the reports block add:
```dart
    '/reports/history': Permission.viewSalesReports,
```

- [ ] **Step 4: Re-point the dashboard "Recent Transactions → View All"**

In `dashboard_screen.dart` at the Recent Transactions section (~line 350), change that `onPressed`'s `context.go(RoutePaths.reports)` to `context.go(RoutePaths.salesHistory)`. Leave the Reports quick action (`onReports`, ~line 299) pointing at `RoutePaths.reports` (it now lands on the hub).

- [ ] **Step 5: Analyze + run router/dashboard tests**

Run: `flutter analyze lib/config/router lib/presentation/mobile/screens/dashboard/dashboard_screen.dart`
Expected: No issues found.
Run: `flutter test test/config/router/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/config/router/route_names.dart lib/config/router/app_routes.dart lib/config/router/route_guards.dart lib/presentation/mobile/screens/dashboard/dashboard_screen.dart
git commit -m "feat(reports): hub at /reports; move transaction list to /reports/history"
```

---

### Task 7: SalesReportScreen — drop stopgap tiles, add history link + Export

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/sales_report_screen.dart`

**Interfaces:**
- Consumes: `buildSalesReportCsv` (Task 3), `saveReportCsv` (Task 4), `salesByDateRangeProvider`, `RouteNames.salesHistory`.

- [ ] **Step 1: Remove the "More Reports" Profit/Labor tiles**

Delete the `if (user != null && !dailyOnly) ...[ ... Profit tile ... Labor tile ... ],` block (the hub now provides those). Keep the End-of-Day tile. Also delete the now-unused `_ReportNavTile` class at the bottom of the file **if** nothing else references it (the analyzer will flag it as unused).

- [ ] **Step 2: Add a "View transactions" tile**

Immediately before the End-of-Day tile, add:
```dart
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _EodTile.link(
                  icon: LucideIcons.receipt,
                  title: 'View transactions',
                  subtitle: 'Full sales history list',
                  onTap: () => context.pushNamed(RouteNames.salesHistory),
                ),
              ),
```
If `_EodTile` has no reusable constructor, instead add a plain `AppCard` tile with the same shape as `_EodTile` (icon `LucideIcons.receipt`, title "View transactions", `onTap` → `context.pushNamed(RouteNames.salesHistory)`).

- [ ] **Step 3: Add an Export action to the app bar**

Add an app-bar action:
```dart
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
```
Add the method:
```dart
  Future<void> _exportCsv() async {
    final params = DateRangeParams(startDate: _startDate, endDate: _endDate);
    final sales = await ref.read(salesByDateRangeProvider(params).future);
    if (!mounted) return;
    if (sales.where((s) => !s.isVoided).isEmpty) {
      context.showSnackBar('No sales to export in this range');
      return;
    }
    final d = DateFormat('yyyy-MM-dd');
    final name = 'sales_${d.format(_startDate)}_to_${d.format(_endDate)}.csv';
    if (!mounted) return;
    await saveReportCsv(context, buildSalesReportCsv(sales), name);
  }
```
Add imports: `report_csv.dart`, `report_export.dart`, and `package:intl/intl.dart` (if not already imported).

- [ ] **Step 4: Analyze + run tests**

Run: `flutter analyze lib/presentation/mobile/screens/reports/sales_report_screen.dart`
Expected: No issues found.
Run: `flutter test test/presentation/mobile/screens/reports/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/reports/sales_report_screen.dart
git commit -m "feat(reports): sales report drops stopgap tiles; adds history link + CSV export"
```

---

### Task 8: Profit report — shared preset picker + Export

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/profit_report_screen.dart`

**Interfaces:**
- Consumes: `DateRangePicker`, `DateRangePreset`, `dateRangeForPreset`, `buildProfitReportCsv`, `saveReportCsv`, `topSellingProductsProvider`.

- [ ] **Step 1: Swap the date UI to the shared picker with presets**

Replace the `DateTimeRange _dateRange` state and the app-bar calendar `IconButton` + the `AppCard` date strip with the same pattern SalesReportScreen uses:
- State: `late DateTime _startDate; late DateTime _endDate; DateRangePreset _selectedPreset = DateRangePreset.today;`
- `initState`: set `_startDate`/`_endDate` from `dateRangeForPreset(DateRangePreset.today, DateTime.now())`.
- In `build`, replace the date strip `AppCard` with:
```dart
            DateRangePicker(
              startDate: _startDate,
              endDate: _endDate,
              selectedPreset: _selectedPreset,
              onPresetChanged: (preset) {
                if (preset == DateRangePreset.custom) return;
                final r = dateRangeForPreset(preset, DateTime.now());
                setState(() {
                  _startDate = r.start;
                  _endDate = r.end;
                  _selectedPreset = preset;
                });
              },
              onCustomRangeSelected: (start, end) {
                setState(() {
                  _startDate = start;
                  _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
                  _selectedPreset = DateRangePreset.custom;
                });
              },
            ),
```
- Update `_params`/`_topParams` getters to build from `_startDate`/`_endDate`.
- Remove the now-unused `_ChangeButton` widget and `showDateRangePicker` method if the analyzer flags them.

- [ ] **Step 2: Add the Export action**

Replace the app-bar `actions` (currently the calendar button) with:
```dart
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
```
Add:
```dart
  Future<void> _exportCsv() async {
    final products = await ref.read(topSellingProductsProvider(_topParams).future);
    if (!mounted) return;
    if (products.isEmpty) {
      context.showSnackBar('No profit data to export in this range');
      return;
    }
    final d = DateFormat('yyyy-MM-dd');
    final name = 'profit_${d.format(_startDate)}_to_${d.format(_endDate)}.csv';
    if (!mounted) return;
    await saveReportCsv(context, buildProfitReportCsv(products), name);
  }
```
Add imports: `date_range_picker.dart`, `report_date_range.dart`, `report_csv.dart`, `report_export.dart`.

- [ ] **Step 3: Analyze + run the profit screen test**

Run: `flutter analyze lib/presentation/mobile/screens/reports/profit_report_screen.dart`
Expected: No issues found.
Run: `flutter test test/presentation/mobile/screens/reports/profit_report_screen_test.dart`
Expected: PASS (the provider overrides still resolve; adjust the test only if the date-strip finder changed).

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/mobile/screens/reports/profit_report_screen.dart
git commit -m "feat(reports): profit report uses shared preset picker + CSV export"
```

---

### Task 9: Labor report — shared preset picker + daily-only + Export

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/labor_report_screen.dart`

**Interfaces:**
- Consumes: `DateRangePicker`, `dateRangeForPreset`, `buildLaborReportCsv`, `saveReportCsv`, `laborReportProvider`, `RolePermissions.isDailyReportsOnly`, `currentUserProvider`.

- [ ] **Step 1: Swap to the shared picker with presets (mirror Task 8 Step 1)**

Same conversion as the profit screen: `_startDate`/`_endDate`/`_selectedPreset` state, `initState` defaults to Today, replace the date strip with `DateRangePicker`, update `_params`.

- [ ] **Step 2: Lock daily-only roles to Today**

In `build`, before building `_params`:
```dart
    final user = ref.watch(currentUserProvider).valueOrNull;
    final dailyOnly =
        user != null && RolePermissions.isDailyReportsOnly(user.role);
    if (dailyOnly) {
      final r = dateRangeForPreset(DateRangePreset.today, DateTime.now());
      _startDate = r.start;
      _endDate = r.end;
      _selectedPreset = DateRangePreset.today;
    }
```
When `dailyOnly`, render the existing `ReportsWarningBanner` (as SalesReportScreen does) instead of the `DateRangePicker`.

- [ ] **Step 3: Add the Export action**

```dart
  Future<void> _exportCsv() async {
    final report = await ref.read(laborReportProvider(_params).future);
    if (!mounted) return;
    if (report.byMechanic.isEmpty) {
      context.showSnackBar('No labor to export in this range');
      return;
    }
    final d = DateFormat('yyyy-MM-dd');
    final name = 'labor_${d.format(_startDate)}_to_${d.format(_endDate)}.csv';
    if (!mounted) return;
    await saveReportCsv(context, buildLaborReportCsv(report), name);
  }
```
Add the `download` app-bar action (as in Task 8 Step 2) and imports (`date_range_picker.dart`, `report_date_range.dart`, `report_csv.dart`, `report_export.dart`, `role_permissions.dart`, `reports_widgets.dart` for `ReportsWarningBanner`).

- [ ] **Step 4: Analyze + run the labor screen test**

Run: `flutter analyze lib/presentation/mobile/screens/reports/labor_report_screen.dart`
Expected: No issues found.
Run: `flutter test test/presentation/mobile/screens/reports/labor_report_screen_test.dart`
Expected: PASS (adjust the test only if the date-strip finder changed).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/reports/labor_report_screen.dart
git commit -m "feat(reports): labor report uses shared preset picker + daily-only + CSV export"
```

---

### Task 10: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Whole-project analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: All tests passed (the new report_date_range, report_csv, reports_hub tests plus everything prior).

- [ ] **Step 3: Manual device smoke (user gate)**

On a device/emulator: Dashboard → Reports lands on the hub (Sales/Profit/Labor; Profit hidden for non-admin). Open each report; change the preset (Today/This Week/This Month/This Quarter/This Year/Custom → date picker); tap Export and confirm a `.csv` saves and opens with the expected columns + totals row. Confirm the dashboard "Recent Transactions → View All" still opens the transaction list.

---

## Self-Review

**Spec coverage:**
- Hub (Sales/Profit/Labor) → Tasks 5, 6. ✓
- Preset filter across all reports (today/yesterday/this week/this month/this quarter/this year/custom) → Tasks 1, 2, 8, 9 (Sales already had it; Profit/Labor gain it). ✓
- Custom → existing date-range picker → picker's `onCustomRangeSelected` (Tasks 8, 9). ✓
- Export CSV across all reports → Tasks 3, 4, 7, 8, 9. ✓
- Sales="analytics"; history moved + linked → Tasks 6, 7. ✓
- Daily-only lock on Labor → Task 9 Step 2. ✓
- Reuse inventory save mechanism → Task 4. ✓

**Placeholder scan:** none — every code step shows full code or exact edits with anchors.

**Type consistency:** `dateRangeForPreset(DateRangePreset, DateTime) → DateTimeRange` used identically in Tasks 2/8/9; `buildSalesReportCsv/buildProfitReportCsv/buildLaborReportCsv` and `saveReportCsv(BuildContext, String, String)` used as defined in Tasks 3/4 by Tasks 7/8/9; `RouteNames.salesHistory`/`RoutePaths.salesHistory` defined in Task 6 and used in Tasks 6/7. ✓
