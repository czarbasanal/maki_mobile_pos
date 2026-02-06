import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/common/common_widgets.dart';

/// Dashboard screen showing role-based menu items.
///
/// Features:
/// - Displays logged-in user info
/// - Shows menu items based on user role
/// - Quick access to main features
/// - Sign out functionality
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(RoutePaths.login),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          // Redirect to login if no user
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RoutePaths.login);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _DashboardContent(user: user);
      },
    );
  }
}

class _DashboardContent extends ConsumerStatefulWidget {
  final UserEntity user;

  const _DashboardContent({required this.user});

  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  bool _isLoggingOut = false;

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await ref.read(authActionsProvider).signOut();
      if (mounted) {
        context.go(RoutePaths.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = RouteGuards.getMenuItems(widget.user.role);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;

    return LoadingOverlay(
      isLoading: _isLoggingOut,
      message: 'Signing out...',
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          title: const Text('Dashboard'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleSignOut,
              tooltip: 'Sign Out',
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // User Info Section
              _buildUserSection(),

              const SizedBox(height: 16),

              // Menu Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      return _buildMenuTile(menuItems[index]);
                    },
                  ),
                ),
              ),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: UserInfoCard(user: widget.user),
    );
  }

  Widget _buildMenuTile(MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  size: 32,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.lightText,
                ),
                textAlign: TextAlign.center,
              ),
              if (item.badge != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.badge!,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Logged in as ${widget.user.displayName}',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.lightTextHint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'POS System v1.0.0',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.lightTextHint,
            ),
          ),
        ],
      ),
    );
  }
}
