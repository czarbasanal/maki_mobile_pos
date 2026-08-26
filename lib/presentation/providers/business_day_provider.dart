import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';

export 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart'
    show nowProvider;

/// The current business day as a **shop wall-clock** midnight, used as the
/// single source of "today" across the app.
///
/// Rolls over on a timer armed for the next SHOP midnight, and can be
/// force-rechecked (e.g. from an app-lifecycle resume hook) to catch the
/// case where the device was asleep and missed the timer firing exactly at
/// midnight. Re-arms whenever the shop timezone changes, so switching zones
/// in settings takes effect without a restart.
class BusinessDayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    // Watching the offset rebuilds this notifier when the shop timezone
    // changes — the day and the pending rollover both need recomputing.
    final offset = ref.watch(shopOffsetProvider);
    final now = ref.read(nowProvider)();
    _arm(now, offset);
    ref.onDispose(() => _timer?.cancel());
    return businessDateOf(now, offset);
  }

  void _arm(DateTime now, int offset) {
    _timer?.cancel();
    _timer = Timer(
      nextShopMidnightAfter(now, offset).difference(now) +
          const Duration(seconds: 1),
      _tick,
    );
  }

  void _tick() {
    final offset = ref.read(shopOffsetProvider);
    final now = ref.read(nowProvider)();
    final day = businessDateOf(now, offset);
    if (day != state) state = day;
    _arm(now, offset);
  }

  /// Called from the app-lifecycle observer on resume.
  void recheck() => _tick();
}

final businessDayProvider =
    NotifierProvider<BusinessDayNotifier, DateTime>(BusinessDayNotifier.new);
