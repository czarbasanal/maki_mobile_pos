import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/report_csv.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/report_export.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

enum _JobOrderView { models, mechanics }

/// Admin-only Job Orders analytics: Motorcycle Models + Top Mechanics for a
/// selected date range, over billed-out (completed) sales.
class JobOrderReportsScreen extends ConsumerStatefulWidget {
  const JobOrderReportsScreen({super.key});

  @override
  ConsumerState<JobOrderReportsScreen> createState() =>
      _JobOrderReportsScreenState();
}

class _JobOrderReportsScreenState extends ConsumerState<JobOrderReportsScreen> {
  late DateTime _start;
  late DateTime _end;
  DateRangePreset _preset = DateRangePreset.today;
  _JobOrderView _view = _JobOrderView.models;

  @override
  void initState() {
    super.initState();
    final r = dateRangeForPreset(DateRangePreset.today, DateTime.now());
    _start = r.start;
    _end = r.end;
  }

  DateRangeParams get _params => DateRangeParams(
        startDate: _start,
        endDate: _end,
        status: SaleStatus.completed,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Orders'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: ListView(
        children: [
          DateRangePicker(
            startDate: _start,
            endDate: _end,
            selectedPreset: _preset,
            onPresetChanged: (p) {
              if (p == DateRangePreset.custom) return;
              final r = dateRangeForPreset(p, DateTime.now());
              setState(() {
                _start = r.start;
                _end = r.end;
                _preset = p;
              });
            },
            onCustomRangeSelected: (s, e) => setState(() {
              _start = s;
              _end = DateTime(e.year, e.month, e.day, 23, 59, 59);
              _preset = DateRangePreset.custom;
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<_JobOrderView>(
              segments: const [
                ButtonSegment(
                  value: _JobOrderView.models,
                  icon: Icon(LucideIcons.bike, size: 16),
                  label: Text('Models'),
                ),
                ButtonSegment(
                  value: _JobOrderView.mechanics,
                  icon: Icon(LucideIcons.wrench, size: 16),
                  label: Text('Mechanics'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
              // Keep the segment glyphs (mock shows bike/wrench, no check).
              showSelectedIcon: false,
              // Per the job-orders handoff mock: this screen's selected
              // segment is primary-tinted (slate@10% light / gold@16% dark).
              // The app-wide green segmented theme is untouched — it remains
              // the selected style on payment/stock/discount dialogs.
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? 0.16
                              : 0.10,
                        ),
                selectedForegroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (_view == _JobOrderView.models)
            _modelsBody()
          else
            _mechanicsBody(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _modelsBody() {
    final async = ref.watch(motorcycleModelReportProvider(_params));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(height: 240, child: ListSkeleton()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorStateView(
          message: 'Failed to load: $e',
          onRetry: () => ref.invalidate(motorcycleModelReportProvider(_params)),
        ),
      ),
      data: (r) => r.byModel.isEmpty
          ? const EmptyStateView(
              icon: LucideIcons.bike,
              title: 'No job orders in this range',
            )
          : Column(
              children: [
                for (final m in r.byModel)
                  _row(LucideIcons.bike, m.model, '${m.jobCount} jobs',
                      m.totalRevenue.toCurrency()),
              ],
            ),
    );
  }

  Widget _mechanicsBody() {
    final async = ref.watch(mechanicPerformanceReportProvider(_params));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(height: 240, child: ListSkeleton()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorStateView(
          message: 'Failed to load: $e',
          onRetry: () =>
              ref.invalidate(mechanicPerformanceReportProvider(_params)),
        ),
      ),
      data: (r) => r.byMechanic.isEmpty
          ? const EmptyStateView(
              icon: LucideIcons.wrench,
              title: 'No mechanic jobs in this range',
            )
          : Column(
              children: [
                for (final m in r.byMechanic)
                  _row(LucideIcons.wrench, m.mechanicName, '${m.jobCount} jobs',
                      m.totalRevenue.toCurrency()),
              ],
            ),
    );
  }

  Widget _row(IconData glyph, String title, String sub, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AppCard(
      radius: AppRadius.field,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.neutralTileFill(isDark),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(glyph,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final d = DateFormat('yyyy-MM-dd');
    final range = '${d.format(_start)}_to_${d.format(_end)}';
    if (_view == _JobOrderView.models) {
      final r = await ref.read(motorcycleModelReportProvider(_params).future);
      if (!mounted) return;
      if (r.byModel.isEmpty) {
        context.showSnackBar('Nothing to export in this range');
        return;
      }
      await saveReportCsv(context, buildMotorcycleModelReportCsv(r),
          'job_orders_models_$range.csv');
    } else {
      final r =
          await ref.read(mechanicPerformanceReportProvider(_params).future);
      if (!mounted) return;
      if (r.byMechanic.isEmpty) {
        context.showSnackBar('Nothing to export in this range');
        return;
      }
      await saveReportCsv(context, buildMechanicPerformanceReportCsv(r),
          'job_orders_mechanics_$range.csv');
    }
  }
}
