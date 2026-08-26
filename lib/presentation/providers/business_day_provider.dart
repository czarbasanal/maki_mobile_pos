import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';

export 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart'
    show nowProvider;

/// The current business day (midnight-truncated), used as the single
/// source of "today" across the app.
///
/// Rolls over on a timer armed for the next local midnight, and can be
/// force-rechecked (e.g. from an app-lifecycle resume hook) to catch the
/// case where the device was asleep and missed the timer firing exactly
/// at midnight.
class BusinessDayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final now = ref.read(nowProvider)();
    _arm(now);
    ref.onDispose(() => _timer?.cancel());
    return businessDateOf(now);
  }

  void _arm(DateTime now) {
    _timer?.cancel();
    _timer = Timer(
      nextMidnightAfter(now).difference(now) + const Duration(seconds: 1),
      _tick,
    );
  }

  void _tick() {
    final now = ref.read(nowProvider)();
    final day = businessDateOf(now);
    if (day != state) state = day;
    _arm(now);
  }

  /// Called from the app-lifecycle observer on resume.
  void recheck() => _tick();
}

final businessDayProvider =
    NotifierProvider<BusinessDayNotifier, DateTime>(BusinessDayNotifier.new);
