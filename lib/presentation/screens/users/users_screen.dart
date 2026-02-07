import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';
import 'package:maki_mobile_pos/presentation/screens/users/user_form_screen.dart';
import 'package:maki_mobile_pos/presentation/widgets/users/user_list_tile.dart';

/// Screen displaying list of all users (admin only).
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  UserRole? _roleFilter;
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    // Only admins can access this screen
    if (currentUser?.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Users')),
        body: const Center(
          child: Text('Access denied. Admin privileges required.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          // Filter by role
          PopupMenuButton<UserRole?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by role',
            onSelected: (role) {
              setState(() => _roleFilter = role);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Roles'),
              ),
              ...UserRole.values.map((role) => PopupMenuItem(
                    value: role,
                    child: Text(role.displayName),
                  )),
            ],
          ),
          // Toggle inactive
          IconButton(
            icon: Icon(
              _showInactive ? Icons.visibility : Icons.visibility_off,
            ),
            tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
            onPressed: () {
              setState(() => _showInactive = !_showInactive);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          _buildSummaryCards(usersAsync),

          // Active filters
          if (_roleFilter != null || _showInactive) _buildActiveFilters(),

          // Users list
          Expanded(
            child: usersAsync.when(
              data: (users) => _buildUsersList(users, currentUser!),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreateUser(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
    );
  }

  Widget _buildSummaryCards(AsyncValue<List<UserEntity>> usersAsync) {
    return usersAsync.when(
      data: (users) {
        final activeUsers = users.where((u) => u.isActive).toList();
        final admins =
            activeUsers.where((u) => u.role == UserRole.admin).length;
        final staff = activeUsers.where((u) => u.role == UserRole.staff).length;
        final cashiers =
            activeUsers.where((u) => u.role == UserRole.cashier).length;

        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total',
                  '${activeUsers.length}',
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Admins',
                  '$admins',
                  Icons.admin_panel_settings,
                  Colors.purple,
                  onTap: () => setState(() => _roleFilter = UserRole.admin),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Staff',
                  '$staff',
                  Icons.badge,
                  Colors.green,
                  onTap: () => setState(() => _roleFilter = UserRole.staff),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Cashiers',
                  '$cashiers',
                  Icons.point_of_sale,
                  Colors.orange,
                  onTap: () => setState(() => _roleFilter = UserRole.cashier),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 100),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          if (_roleFilter != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(_roleFilter!.displayName),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() => _roleFilter = null),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (_showInactive)
            Chip(
              label: const Text('Showing inactive'),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => _showInactive = false),
              visualDensity: VisualDensity.compact,
            ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _roleFilter = null;
                _showInactive = false;
              });
            },
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(List<UserEntity> users, UserEntity currentUser) {
    var filteredUsers = users.toList();

    // Apply filters
    if (_roleFilter != null) {
      filteredUsers =
          filteredUsers.where((u) => u.role == _roleFilter).toList();
    }

    if (!_showInactive) {
      filteredUsers = filteredUsers.where((u) => u.isActive).toList();
    }

    // Sort: active first, then by name
    filteredUsers.sort((a, b) {
      if (a.isActive != b.isActive) {
        return a.isActive ? -1 : 1;
      }
      return a.displayName.compareTo(b.displayName);
    });

    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allUsersProvider);
      },
      child: ListView.builder(
        itemCount: filteredUsers.length,
        padding: const EdgeInsets.only(bottom: 80),
        itemBuilder: (context, index) {
          final user = filteredUsers[index];
          return UserListTile(
            user: user,
            isCurrentUser: user.id == currentUser.id,
            onTap: () => _navigateToEditUser(context, user),
            onToggleActive: user.id != currentUser.id
                ? () => _toggleUserActive(user)
                : null,
          );
        },
      ),
    );
  }

  void _navigateToCreateUser(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserFormScreen(),
      ),
    );
  }

  void _navigateToEditUser(BuildContext context, UserEntity user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserFormScreen(user: user),
      ),
    );
  }

  Future<void> _toggleUserActive(UserEntity user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.isActive ? 'Deactivate User?' : 'Reactivate User?'),
        content: Text(
          user.isActive
              ? '${user.displayName} will no longer be able to log in.'
              : '${user.displayName} will be able to log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: user.isActive ? Colors.red : Colors.green,
            ),
            child: Text(user.isActive ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;

      if (user.isActive) {
        await ref.read(userOperationsProvider.notifier).deactivateUser(
              userId: user.id,
              updatedBy: currentUser.id,
            );
      } else {
        await ref.read(userOperationsProvider.notifier).reactivateUser(
              userId: user.id,
              updatedBy: currentUser.id,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.isActive
                  ? '${user.displayName} deactivated'
                  : '${user.displayName} reactivated',
            ),
            backgroundColor: user.isActive ? Colors.orange : Colors.green,
          ),
        );
      }
    }
  }
}
