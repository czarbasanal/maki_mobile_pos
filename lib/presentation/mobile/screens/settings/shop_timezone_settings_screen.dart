import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/core/utils/shop_timezones.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

const String _mono = AppTextStyles.monoFontFamily;

/// Admin editor for the shop-wide timezone (`settings/general`).
///
/// The stored offset drives the business day on every device *and* the
/// Firestore rules, so this is the single place the shop's clock is defined.
/// Non-admins see the same list read-only.
class ShopTimezoneSettingsScreen extends ConsumerStatefulWidget {
  const ShopTimezoneSettingsScreen({super.key});

  @override
  ConsumerState<ShopTimezoneSettingsScreen> createState() =>
      _ShopTimezoneSettingsScreenState();
}

class _ShopTimezoneSettingsScreenState
    extends ConsumerState<ShopTimezoneSettingsScreen> {
  /// Null until the operator picks a row — then it is the pending selection.
  String? _selectedId;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stored = ref.watch(shopTimezoneProvider).valueOrNull ??
        ShopTimezoneEntity.defaults;
    final selectedId = _selectedId ?? stored.timezoneId;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = user?.role == UserRole.admin;
    final dirty = selectedId != stored.timezoneId;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Time & Timezone'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNowCard(theme, stored),
            _sectionHeading(theme, 'Timezone'),
            _sectionHelper(theme,
                'Only zones without daylight saving are listed — the security '
                'rules compare a fixed offset.'),
            const SizedBox(height: 10),
            _buildZoneList(theme, selectedId, enabled: isAdmin),
            const SizedBox(height: 16),
            _buildWarningCard(theme),
          ],
        ),
      ),
      bottomNavigationBar:
          isAdmin ? _buildBottomBar(theme, enabled: dirty) : null,
    );
  }

  Widget _buildNowCard(ThemeData theme, ShopTimezoneEntity stored) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final shopNow = ref.watch(shopNowProvider)();
    final label = shopTimezoneById(stored.timezoneId)?.label ??
        stored.timezoneId;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.clock, size: 17, color: muted),
              const SizedBox(width: 8),
              Text(
                'Shop time now',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE, MMM d · h:mm a').format(shopNow),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$label · UTC${formatOffset(stored.offsetMinutes)}',
            style: TextStyle(fontSize: 12.5, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneList(ThemeData theme, String selectedId,
      {required bool enabled}) {
    final isDark = theme.brightness == Brightness.dark;
    final hairline = AppColors.hairline(isDark);
    final muted = theme.colorScheme.onSurfaceVariant;

    return AppCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < kShopTimezones.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: hairline)),
              ),
              child: InkWell(
                onTap: enabled
                    ? () => setState(() {
                          _selectedId = kShopTimezones[i].id;
                          _errorMessage = null;
                        })
                    : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                  child: Row(
                    children: [
                      Icon(
                        kShopTimezones[i].id == selectedId
                            ? LucideIcons.circleCheck
                            : LucideIcons.circle,
                        size: 18,
                        color: kShopTimezones[i].id == selectedId
                            ? theme.colorScheme.primary
                            : muted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          kShopTimezones[i].label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: kShopTimezones[i].id == selectedId
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        formatOffset(kShopTimezones[i].offsetMinutes),
                        style: TextStyle(
                          fontFamily: _mono,
                          fontSize: 12.5,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    // Informational, not an error — a neutral tinted block, matching the
    // other settings screens.
    final tileBg = isDark ? const Color(0x24E8B84C) : const Color(0x12283E46);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.info, size: 17, color: muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Changing this affects every device. Phones running an older '
                'app version will stop recording sales correctly until they '
                'update.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, {required bool enabled}) {
    final isDark = theme.brightness == Brightness.dark;
    final hairline = AppColors.hairline(isDark);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (!enabled || _isSaving) ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final id = _selectedId;
    if (id == null) return;
    final tz = shopTimezoneById(id);
    if (tz == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) throw Exception('Not logged in');
      await ref.read(shopTimezoneRepositoryProvider).save(
            ShopTimezoneEntity(
              timezoneId: tz.id,
              offsetMinutes: tz.offsetMinutes,
            ),
            updatedBy: user.id,
          );
      // The stream write-back also updates ShopTimeConfig; setting it here
      // means the summary card is right on the very next frame.
      ShopTimeConfig.apply(
        timezoneId: tz.id,
        offsetMinutes: tz.offsetMinutes,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showSnackBar('Shop timezone set to ${tz.label}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Could not save: $e';
      });
    }
  }

  Widget _sectionHeading(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 3),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _sectionHelper(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
