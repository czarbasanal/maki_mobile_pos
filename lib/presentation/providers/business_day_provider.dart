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
///
/// Neither of those is guaranteed. Android freezes timers in Doze, and a
/// handset left on the app with the screen off may never deliver a `resumed`
/// event to trigger the recheck. When both are missed the app keeps serving
/// YESTERDAY as today — every "today" figure in the app reads this provider,
/// and a cashier's report range is forced from it, so a stale day shows the
/// previous day's totals on the dashboard and the reports screen alike.
/// [heartbeatInterval] bounds how long that can last.
class BusinessDayNotifier extends Notifier<DateTime> {
  /// How often the day is re-checked regardless of timers and lifecycle
  /// events. Cheap: it reads a clock and compares two dates.
  static const heartbeatInterval = Duration(minutes: 5);

  Timer? _timer;
  Timer? _heartbeat;

  @override
  DateTime build() {
    // Watching the offset rebuilds this notifier when the shop timezone
    // changes — the day and the pending rollover both need recomputing.
    final offset = ref.watch(shopOffsetProvider);
    final now = ref.read(nowProvider)();
    _arm(now, offset);
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _verify());
    ref.onDispose(() {
      _timer?.cancel();
      _heartbeat?.cancel();
    });
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

  /// Corrects the day if it has moved on. Unlike [_tick] this does NOT re-arm
  /// the midnight timer — the heartbeat is a safety net beside that timer, not
  /// a replacement for it.
  void _verify() {
    final day = businessDateOf(
        ref.read(nowProvider)(), ref.read(shopOffsetProvider));
    if (day != state) state = day;
  }

  /// Called from the app-lifecycle observer on resume.
  void recheck() => _tick();
}

final businessDayProvider =
    NotifierProvider<BusinessDayNotifier, DateTime>(BusinessDayNotifier.new);
