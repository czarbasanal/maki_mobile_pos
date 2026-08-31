import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/data/repositories/daily_closing_repository_impl.dart';

/// `businessDate` is stored as the shop-day START INSTANT — 16:00Z the
/// previous day at UTC+8 — not as a UTC wall midnight. A range query that
/// compares against wall midnights is a day off at the lower bound: it drops
/// the first day of every range, and a single-day range matches nothing.
void main() {
  const phOffset = 480;
  late FakeFirebaseFirestore firestore;
  late DailyClosingRepositoryImpl repo;

  Future<void> seed(int y, int m, int d) async {
    await firestore.collection('daily_closings').doc('$y-$m-$d').set({
      'businessDate': Timestamp.fromDate(
          shopDayStartInstant(shopWall(y, m, d), phOffset)),
      'closedAt': Timestamp.fromDate(DateTime.utc(y, m, d, 13)),
      'closedBy': 'u',
      'closedByName': 'U',
    });
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repo = DailyClosingRepositoryImpl(firestore: firestore);
    for (final d in [1, 29, 30, 31]) {
      await seed(2026, 8, d);
    }
  });

  test('a single-day range finds that day', () async {
    final got = await repo.getClosingsInRange(
      fromBusinessDate: shopWall(2026, 8, 31),
      toBusinessDate: shopWall(2026, 8, 31),
    );

    expect(got.map((c) => c.id), ['2026-8-31']);
  });

  test('a whole-month range includes BOTH ends', () async {
    // The 1st was silently missing before: its stored instant sits below a
    // wall-midnight lower bound.
    final got = await repo.getClosingsInRange(
      fromBusinessDate: shopWall(2026, 8, 1),
      toBusinessDate: shopWall(2026, 8, 31),
    );

    expect(got.map((c) => c.id), containsAll(['2026-8-1', '2026-8-31']));
    expect(got.length, 4);
  });

  test('excludes a day outside the range', () async {
    final got = await repo.getClosingsInRange(
      fromBusinessDate: shopWall(2026, 8, 30),
      toBusinessDate: shopWall(2026, 8, 31),
    );

    expect(got.map((c) => c.id), ['2026-8-31', '2026-8-30']);
  });
}
