import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Screen displaying app information.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _packageInfo = info);
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          // Hero — outlined glyph, no tinted box
          Center(
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.cart,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${_packageInfo?.version ?? AppConstants.appVersion}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
                if (_packageInfo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Build ${_packageInfo!.buildNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _AboutCard(
            title: 'About This App',
            child: Text(
              'A comprehensive mobile Point of Sale system designed for '
              'Philippine businesses. Features include inventory management, '
              'sales tracking, supplier management, and detailed reporting.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _AboutCard(
            title: 'Key Features',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _FeatureRow(
                  icon: CupertinoIcons.cart,
                  title: 'Point of Sale',
                  subtitle: 'Fast checkout with barcode scanning',
                ),
                _FeatureRow(
                  icon: CupertinoIcons.cube_box,
                  title: 'Inventory Management',
                  subtitle: 'Track stock levels and variations',
                ),
                _FeatureRow(
                  icon: CupertinoIcons.briefcase,
                  title: 'Supplier Management',
                  subtitle: 'Manage vendors and receiving',
                ),
                _FeatureRow(
                  icon: CupertinoIcons.chart_bar,
                  title: 'Reports & Analytics',
                  subtitle: 'Sales, profit, and inventory reports',
                ),
                _FeatureRow(
                  icon: CupertinoIcons.shield,
                  title: 'Role-Based Access',
                  subtitle: 'Secure multi-user system',
                ),
                _FeatureRow(
                  icon: CupertinoIcons.chevron_left_slash_chevron_right,
                  title: 'Cost Protection',
                  subtitle: 'Hidden cost codes for security',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _AboutCard(
            title: 'Technical Information',
            child: Column(
              children: [
                const _InfoRow(label: 'Platform', value: 'Flutter'),
                const _InfoRow(label: 'Backend', value: 'Firebase'),
                const _InfoRow(label: 'Currency', value: 'Philippine Peso (₱)'),
                const _InfoRow(label: 'Barcode', value: 'Code 128'),
                if (_packageInfo != null)
                  _InfoRow(label: 'Package', value: _packageInfo!.packageName),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _AboutCard(
            title: 'Support',
            padContent: false,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(CupertinoIcons.envelope),
                  title: const Text('Contact Support'),
                  subtitle: const Text('support@example.com'),
                  onTap: () {
                    // Open email
                  },
                ),
                const Divider(height: 1, indent: AppSpacing.lg + 22),
                ListTile(
                  leading: const Icon(CupertinoIcons.question_circle),
                  title: const Text('Help Center'),
                  subtitle: const Text('View documentation'),
                  onTap: () {
                    // Open help
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              '© ${DateTime.now().year} All rights reserved',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Section card for the About screen — title above, themed Card body.
class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.title,
    required this.child,
    this.padContent = true,
  });

  final String title;
  final Widget child;

  /// When false, the card holds tappable rows that bring their own
  /// padding (e.g. ListTile) — only the title is padded.
  final bool padContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              padContent ? AppSpacing.sm : AppSpacing.sm,
            ),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (padContent)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: child,
            )
          else
            child,
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
