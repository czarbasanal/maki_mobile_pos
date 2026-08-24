// Shop-wide HR settings (settings/hr): pay-week start day and the two
// holiday percentages the payroll form seeds from. Save is a full overwrite
// of exactly three fields (web parity). Validity: pcts finite and ≥ 0.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/hr/pay_period.dart';
import 'package:maki_mobile_pos/presentation/providers/hr_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

class HrSettingsScreen extends ConsumerStatefulWidget {
  const HrSettingsScreen({super.key});

  @override
  ConsumerState<HrSettingsScreen> createState() => _HrSettingsScreenState();
}

class _HrSettingsScreenState extends ConsumerState<HrSettingsScreen> {
  final _regularController = TextEditingController();
  final _specialController = TextEditingController();
  int _weekStartDay = HrSettingsEntity.defaults.weekStartDay;
  bool _seeded = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _regularController.dispose();
    _specialController.dispose();
    super.dispose();
  }

  void _seedFrom(HrSettingsEntity settings) {
    if (_seeded) return;
    _seeded = true;
    _weekStartDay = settings.weekStartDay;
    _regularController.text = settings.regularHolidayPct.toString();
    _specialController.text = settings.specialHolidayPct.toString();
  }

  bool get _isValid {
    final r = double.tryParse(_regularController.text);
    final s = double.tryParse(_specialController.text);
    return r != null && r >= 0 && s != null && s >= 0;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(hrSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('HR Settings'),
      ),
      body: settingsAsync.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Failed to load HR settings: $e',
          onRetry: () => ref.invalidate(hrSettingsProvider),
        ),
        data: (settings) {
          _seedFrom(settings);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _weekStartDay,
                  style: AppTextStyles.fieldInput.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration:
                      const InputDecoration(labelText: 'Pay week starts on'),
                  items: [
                    for (var d = 1; d <= 7; d++)
                      DropdownMenuItem(value: d, child: Text(weekdayLabel(d))),
                  ],
                  onChanged: (v) =>
                      setState(() => _weekStartDay = v ?? _weekStartDay),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  style: AppTextStyles.fieldInput,
                  controller: _regularController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Regular holiday pay (%)',
                    helperText: '100 = a full extra day of pay',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  style: AppTextStyles.fieldInput,
                  controller: _specialController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Special holiday pay (%)',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isValid && !_isSaving ? _save : null,
                    child: Text(_isSaving ? 'Saving…' : 'Save'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final ok = await context.runWithWaiting(
      () => ref.read(hrOperationsProvider.notifier).saveSettings(
            HrSettingsEntity(
              weekStartDay: _weekStartDay,
              regularHolidayPct: double.parse(_regularController.text),
              specialHolidayPct: double.parse(_specialController.text),
            ),
          ),
      message: 'Saving…',
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ok
        ? context.showSuccessSnackBar('HR settings saved')
        : context.showErrorSnackBar('Save failed');
  }
}
