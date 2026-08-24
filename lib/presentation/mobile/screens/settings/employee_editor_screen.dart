// Admin CRUD editor for the payroll employees registry — a mechanic-editor
// clone with dailyRate + weekStartDay. Web-parity behaviors: inactive rows
// stay listed (greyed) for reactivation; hard Delete is offered ONLY on
// inactive rows (deactivate-first); dailyRate must be strictly > 0.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/hr/pay_period.dart';
import 'package:maki_mobile_pos/presentation/providers/hr_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/settings_crud_row.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

class EmployeeEditorScreen extends ConsumerStatefulWidget {
  const EmployeeEditorScreen({super.key});

  @override
  ConsumerState<EmployeeEditorScreen> createState() =>
      _EmployeeEditorScreenState();
}

class _EmployeeEditorScreenState extends ConsumerState<EmployeeEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(allEmployeesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Employees'),
      ),
      body: employeesAsync.when(
        data: (employees) => _buildList(context, employees),
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Failed to load employees: $e',
          onRetry: () => ref.invalidate(allEmployeesProvider),
        ),
      ),
      floatingActionButton: SettingsAddFab(
        onPressed: () => _showEmployeeDialog(context),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<EmployeeEntity> employees) {
    if (employees.isEmpty) {
      return const EmptyStateView(
        icon: LucideIcons.idCard,
        title: 'No employees yet',
        subtitle: 'Tap Add to create one.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      itemCount: employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final employee = employees[index];
        return SettingsCrudRow(
          name: employee.name,
          isActive: employee.isActive,
          leadingIcon: LucideIcons.idCard,
          badge: '${employee.dailyRate.toCurrency()}/day'
              '${employee.weekStartDay != null ? ' · ${weekdayLabel(employee.weekStartDay!)}' : ''}',
          onEdit: () => _showEmployeeDialog(context, existing: employee),
          onToggleActive: () => _toggleActive(employee),
          // Deactivate-first delete: hard delete only once hidden (web parity).
          onDelete: employee.isActive ? null : () => _confirmDelete(employee),
        );
      },
    );
  }

  Future<void> _toggleActive(EmployeeEntity employee) async {
    final ops = ref.read(hrOperationsProvider.notifier);
    final ok = await context.runWithWaiting(
      () => ops.updateEmployee(
        employee.copyWith(isActive: !employee.isActive),
        activeChanged: true,
      ),
      message: 'Updating…',
    );
    if (!mounted) return;
    if (ok) {
      context.showSuccessSnackBar(
        employee.isActive ? 'Employee deactivated' : 'Employee reactivated',
      );
    } else {
      context.showErrorSnackBar('Operation failed');
    }
  }

  Future<void> _confirmDelete(EmployeeEntity employee) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete this employee?',
      message: '"${employee.name}" will be permanently deleted. '
          'Past payslips keep their own copies of everything.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref
        .read(hrOperationsProvider.notifier)
        .deleteEmployee(employee.id, employee.name);
    if (!mounted) return;
    ok
        ? context.showSuccessSnackBar('Deleted')
        : context.showErrorSnackBar('Failed to delete');
  }

  Future<void> _showEmployeeDialog(
    BuildContext context, {
    EmployeeEntity? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor:
          AppDialog.scrimColor(Theme.of(context).brightness == Brightness.dark),
      builder: (dialogContext) => _EmployeeFormDialog(existing: existing),
    );
    if (!context.mounted || saved != true) return;
    context.showSuccessSnackBar(
      existing == null ? 'Employee created' : 'Employee updated',
    );
  }
}

class _EmployeeFormDialog extends ConsumerStatefulWidget {
  const _EmployeeFormDialog({this.existing});

  final EmployeeEntity? existing;

  @override
  ConsumerState<_EmployeeFormDialog> createState() =>
      _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _rateController;
  int? _weekStartDay;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _rateController = TextEditingController(
        text: existing != null ? existing.dailyRate.toString() : '');
    _weekStartDay = existing?.weekStartDay;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: _isEdit ? 'Edit Employee' : 'New Employee',
      leadingIcon: LucideIcons.idCard,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              style: AppTextStyles.fieldInput,
              controller: _nameController,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              style: AppTextStyles.fieldInput,
              controller: _rateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Daily rate (₱)'),
              // Strictly > 0 — web parity: a rate-less employee makes every
              // payslip compute to zero, which reads as a data bug later.
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) {
                  return 'Daily rate must be more than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int?>(
              initialValue: _weekStartDay,
              style: AppTextStyles.fieldInput.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: const InputDecoration(labelText: 'Week starts on'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Default (HR setting)'),
                ),
                for (var d = 1; d <= 7; d++)
                  DropdownMenuItem<int?>(value: d, child: Text(weekdayLabel(d))),
              ],
              onChanged: (v) => setState(() => _weekStartDay = v),
            ),
          ],
        ),
      ),
      actions: [
        appDialogCancel(context, 'Cancel'),
        appDialogPrimary(
          context,
          _isEdit ? 'Save' : 'Add',
          loading: _isSaving,
          onTap: _save,
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final ops = ref.read(hrOperationsProvider.notifier);
    final name = _nameController.text.trim();
    final rate = double.parse(_rateController.text);

    bool ok;
    if (_isEdit) {
      final base = widget.existing!.copyWith(
        name: name,
        dailyRate: rate,
        weekStartDay: _weekStartDay,
        clearWeekStartDay: _weekStartDay == null,
      );
      ok = await ops.updateEmployee(base);
    } else {
      ok = await ops.createEmployee(EmployeeEntity(
            id: '',
            name: name,
            dailyRate: rate,
            isActive: true,
            weekStartDay: _weekStartDay,
          )) !=
          null;
    }

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _isSaving = false);
      context.showErrorSnackBar('Save failed');
    }
  }
}
