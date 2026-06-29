import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
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
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final primary = theme.colorScheme.primary;

    // Brand tile: light = rgba(40,62,70,.07), dark = rgba(232,184,76,.14)
    final brandTileBg =
        dark ? const Color(0x24E8B84C) : const Color(0x12283E46);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
        children: [
          // Brand mark + app name + version + build
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Column(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: brandTileBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    LucideIcons.shoppingCart,
                    size: 36,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  'MAKI Mobile POS',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Version ${_packageInfo?.version ?? '1.0.0'}',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  'Build ${_packageInfo?.buildNumber ?? '2'}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9AA0A3)),
                ),
              ],
            ),
          ),

          // About This App
          _AboutCard(
            title: 'About This App',
            titleMarginBottom: 7,
            margin: const EdgeInsets.only(top: 8),
            child: Text(
              'A comprehensive mobile Point of Sale system designed for '
              'Philippine businesses — inventory management, sales tracking, '
              'supplier management, and detailed reporting.',
              style: TextStyle(fontSize: 13, height: 1.55, color: muted),
            ),
          ),

          // Key Features
          _AboutCard(
            title: 'Key Features',
            titleMarginBottom: 10,
            margin: const EdgeInsets.only(top: 12),
            child: Column(
              children: const [
                _FeatureRow(
                  icon: LucideIcons.shoppingCart,
                  title: 'Point of Sale',
                  subtitle: 'Fast checkout with barcode scanning',
                ),
                SizedBox(height: 13),
                _FeatureRow(
                  icon: LucideIcons.package,
                  title: 'Inventory Management',
                  subtitle: 'Track stock levels and variations',
                ),
                SizedBox(height: 13),
                _FeatureRow(
                  icon: LucideIcons.briefcase,
                  title: 'Supplier Management',
                  subtitle: 'Manage vendors and receiving',
                ),
                SizedBox(height: 13),
                _FeatureRow(
                  icon: LucideIcons.barChart3,
                  title: 'Reports & Analytics',
                  subtitle: 'Sales, profit, and inventory reports',
                ),
              ],
            ),
          ),

          // Technical Information
          _AboutCard(
            title: 'Technical Information',
            titleMarginBottom: 8,
            margin: const EdgeInsets.only(top: 12),
            child: Column(
              children: const [
                _InfoRow(label: 'Platform', value: 'Flutter'),
                _InfoRow(label: 'Backend', value: 'Firebase'),
                _InfoRow(label: 'Currency', value: 'Philippine Peso (₱)'),
                _InfoRow(label: 'Barcode', value: 'Code 128'),
              ],
            ),
          ),

          // Footer
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 18, 0, 4),
            child: Center(
              child: Text(
                '© 2026 All rights reserved',
                style: TextStyle(fontSize: 12, color: Color(0xFF9AA0A3)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.title,
    required this.child,
    this.titleMarginBottom = 8.0,
    this.margin,
  });

  final String title;
  final Widget child;
  final double titleMarginBottom;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: titleMarginBottom),
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
    final dark = theme.brightness == Brightness.dark;
    final tileBg = dark ? const Color(0x1F93A0A3) : const Color(0x0F283E46);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ],
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
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: muted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
