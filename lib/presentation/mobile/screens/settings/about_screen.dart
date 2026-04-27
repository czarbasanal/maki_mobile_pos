import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App logo and name
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.point_of_sale,
                    size: 50,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${_packageInfo?.version ?? AppConstants.appVersion}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (_packageInfo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Build ${_packageInfo!.buildNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Description
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About This App',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A comprehensive mobile Point of Sale system designed for '
                    'Philippine businesses. Features include inventory management, '
                    'sales tracking, supplier management, and detailed reporting.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Features
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Features',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.point_of_sale,
                    'Point of Sale',
                    'Fast checkout with barcode scanning',
                  ),
                  _buildFeatureItem(
                    Icons.inventory_2,
                    'Inventory Management',
                    'Track stock levels and variations',
                  ),
                  _buildFeatureItem(
                    Icons.business,
                    'Supplier Management',
                    'Manage vendors and receiving',
                  ),
                  _buildFeatureItem(
                    Icons.analytics,
                    'Reports & Analytics',
                    'Sales, profit, and inventory reports',
                  ),
                  _buildFeatureItem(
                    Icons.security,
                    'Role-Based Access',
                    'Secure multi-user system',
                  ),
                  _buildFeatureItem(
                    Icons.code,
                    'Cost Protection',
                    'Hidden cost codes for security',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Technical info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Technical Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Platform', 'Flutter'),
                  _buildInfoRow('Backend', 'Firebase'),
                  _buildInfoRow('Currency', 'Philippine Peso (₱)'),
                  _buildInfoRow('Barcode', 'Code 128'),
                  if (_packageInfo != null) ...[
                    _buildInfoRow('Package', _packageInfo!.packageName),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Support
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Contact Support'),
                    subtitle: const Text('support@example.com'),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      // Open email
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.help),
                    title: const Text('Help Center'),
                    subtitle: const Text('View documentation'),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      // Open help
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Copyright
          Center(
            child: Text(
              '© ${DateTime.now().year} All rights reserved',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
