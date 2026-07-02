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
                    value: _JobOrderView.models, label: Text('Models')),
                ButtonSegment(
                    value: _JobOrderView.mechanics, label: Text('Mechanics')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
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
          onRetry: () =>
              ref.invalidate(motorcycleModelReportProvider(_params)),
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
                  _row(m.model, '${m.jobCount} jobs',
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
                  _row(m.mechanicName, '${m.jobCount} jobs',
                      m.totalRevenue.toCurrency()),
              ],
            ),
    );
  }

  Widget _row(String title, String sub, String value) => AppCard(
        radius: AppRadius.md,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

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
