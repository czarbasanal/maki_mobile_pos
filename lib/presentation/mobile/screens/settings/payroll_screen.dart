// The payroll generator — a thin assembly over PayslipDraftController, which
// owns every parity rule (seeding, pick-employee ordering, END-anchored
// re-anchor, positional defaults, isValid). This screen only binds widgets:
// employee dropdown, period arrows, the WeekGrid, numeric fields, dynamic
// other-deduction rows, live totals via computePayslip, Save-as-defaults
// (deliberately unaudited) and Generate (logged use-case) → payslip detail.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/hr/compute_payslip.dart';
import 'package:maki_mobile_pos/domain/hr/pay_period.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/hr_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/payslip_draft_controller.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/hr/week_grid.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  PayslipDraftController? _draft;
  HrSettingsEntity? _settings;
  EmployeeEntity? _employee;
  bool _isBusy = false;

  // One controller per numeric field, kept in sync FROM the draft when an
  // employee pick / defaults application rewrites the form.
  final _controllers = {
    for (final f in DraftField.values) f: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureDraft(HrSettingsEntity settings) {
    if (_draft != null) return;
    _settings = settings;
    _draft = PayslipDraftController(settings: settings, now: DateTime.now());
    _syncControllers();
    _draft!.addListener(() {
      if (mounted) setState(() {});
    });
  }

  /// Pushes the draft's field texts into the TextEditingControllers — called
  /// after pick/defaults, which rewrite many fields at once.
  void _syncControllers() {
    final d = _draft!;
    for (final f in DraftField.values) {
      final text = d.state.text(f);
      if (_controllers[f]!.text != text) _controllers[f]!.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(hrSettingsProvider);
    final employeesAsync = ref.watch(activeEmployeesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Payroll'),
      ),
      body: settingsAsync.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Failed to load HR settings: $e',
          onRetry: () => ref.invalidate(hrSettingsProvider),
        ),
        data: (settings) {
          _ensureDraft(settings);
          return employeesAsync.when(
            loading: () => const ListSkeleton(),
            error: (e, _) => ErrorStateView(
              message: 'Failed to load employees: $e',
              onRetry: () => ref.invalidate(activeEmployeesProvider),
            ),
            data: (employees) => _buildForm(context, employees),
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<EmployeeEntity> employees) {
    final draft = _draft!;
    final computed = computePayslip(draft.inputs);
    final canSubmit = _employee != null && draft.isValid && !_isBusy;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _employee?.id,
            style: AppTextStyles.fieldInput.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: const InputDecoration(labelText: 'Employee'),
            items: [
              for (final e in employees)
                DropdownMenuItem(value: e.id, child: Text(e.name)),
            ],
            onChanged: (id) {
              final picked =
                  employees.where((e) => e.id == id).firstOrNull;
              if (picked == null) return;
              setState(() => _employee = picked);
              draft.pickEmployee(picked, settings: _settings);
              _syncControllers();
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Period navigation
          AppCard(
            radius: 14,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft),
                  tooltip: 'Previous week',
                  onPressed: () => draft.shift(-1),
                ),
                Expanded(
                  child: Text(
                    _periodLabel(draft.state.period),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.fieldInput
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight),
                  tooltip: 'Next week',
                  onPressed: () => draft.shift(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          WeekGrid(days: draft.state.days, onTapDay: draft.cycleDay),
          const SizedBox(height: AppSpacing.lg),

          _sectionHeader('Earnings'),
          _numField(DraftField.hoursWorked, 'Hours worked'),
          _numField(DraftField.dailyRate, 'Daily rate (₱)'),
          _numField(DraftField.overtimeHours, 'Overtime hours'),
          _numField(DraftField.overtimeRatePerHour, 'Overtime rate (₱/hr)'),
          _numField(DraftField.regularHolidayDays, 'Regular holiday days'),
          _numField(DraftField.regularHolidayPct, 'Regular holiday (%)'),
          _numField(DraftField.specialHolidayDays, 'Special holiday days'),
          _numField(DraftField.specialHolidayPct, 'Special holiday (%)'),
          _numField(DraftField.incentives, 'Incentives (₱)'),
          const SizedBox(height: AppSpacing.lg),

          _sectionHeader('Deductions'),
          _numField(DraftField.sss, 'SSS'),
          _numField(DraftField.philhealth, 'PhilHealth'),
          _numField(DraftField.pagibig, 'Pag-IBIG'),
          _numField(DraftField.late, 'Late'),
          _numField(DraftField.absences, 'Absences'),
          _numField(DraftField.cashAdvance, 'Cash advance'),

          for (final row in draft.state.others) _otherRow(draft, row),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.addOther();
                _syncControllers();
              },
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add deduction'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _sectionHeader('Summary'),
          AppCard(
            radius: 14,
            child: Column(
              children: [
                _summaryRow('Base pay', computed.basePay),
                _summaryRow('Overtime pay', computed.overtimePay),
                _summaryRow('Holiday pay', computed.holidayPay),
                _summaryRow('Incentives', draft.inputs.incentives),
                const Divider(height: 20),
                _summaryRow('Gross', computed.gross, bold: true),
                _summaryRow('Total deductions', computed.totalDeductions),
                _summaryRow('Net pay', computed.net, bold: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          OutlinedButton(
            onPressed: canSubmit ? _saveDefaults : null,
            child: const Text('Save as defaults'),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: canSubmit ? _generate : null,
            child: Text(_isBusy ? 'Working…' : 'Generate payslip'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );

  Widget _numField(DraftField field, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        style: AppTextStyles.fieldInput,
        controller: _controllers[field],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: (v) => _draft!.setField(field, v),
      ),
    );
  }

  Widget _otherRow(PayslipDraftController draft, OtherRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              style: AppTextStyles.fieldInput,
              initialValue: row.label,
              decoration: const InputDecoration(labelText: 'Label'),
              onChanged: (v) => draft.setOther(row.id, label: v),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: TextFormField(
              style: AppTextStyles.fieldInput,
              initialValue: row.amountText,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
              onChanged: (v) => draft.setOther(row.id, amountText: v),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 18),
            tooltip: 'Remove',
            onPressed: () => draft.removeOther(row.id),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            value.toCurrency(),
            style: style.copyWith(fontFamily: AppTextStyles.monoFontFamily),
          ),
        ],
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _periodLabel(PayPeriod p) {
    final s = parseIsoLocalDate(p.start);
    final e = parseIsoLocalDate(p.end);
    return '${_months[s.month - 1]} ${s.day} – ${_months[e.month - 1]} ${e.day}, ${e.year}';
  }

  Future<void> _saveDefaults() async {
    setState(() => _isBusy = true);
    final ok = await ref
        .read(hrOperationsProvider.notifier)
        .saveDefaults(_employee!.id, _draft!.snapshotDefaults());
    if (!mounted) return;
    setState(() => _isBusy = false);
    ok
        ? context.showSuccessSnackBar("Saved as this employee's defaults")
        : context.showErrorSnackBar('Save failed');
  }

  Future<void> _generate() async {
    final actor = ref.read(currentUserProvider).valueOrNull;
    final employee = _employee!;
    final draft = _draft!;
    setState(() => _isBusy = true);

    final id = await context.runWithWaiting(
      () => ref.read(hrOperationsProvider.notifier).generatePayslip(
            PayslipEntity(
              id: '',
              employeeId: employee.id,
              employeeName: employee.name,
              periodStart: draft.state.period.start,
              periodEnd: draft.state.period.end,
              days: draft.state.days,
              inputs: draft.inputs,
              computed: computePayslip(draft.inputs),
              createdBy: actor?.id,
              createdByName: actor?.displayName,
            ),
          ),
      message: 'Generating…',
    );

    if (!mounted) return;
    setState(() => _isBusy = false);
    if (id != null) {
      context.showSuccessSnackBar('Payslip generated');
      context.push('${RoutePaths.hrPayslips}/$id');
    } else {
      context.showErrorSnackBar('Generate failed');
    }
  }
}
