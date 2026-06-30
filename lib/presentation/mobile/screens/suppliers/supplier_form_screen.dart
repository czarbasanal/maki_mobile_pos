import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/validators.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Screen for creating or editing a supplier.
class SupplierFormScreen extends ConsumerStatefulWidget {
  final String? supplierId;

  const SupplierFormScreen({super.key, this.supplierId});

  bool get isEditing => supplierId != null;

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _alternativeNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  TransactionType _transactionType = TransactionType.cash;
  bool _isLoading = false;
  bool _isSaving = false;
  SupplierEntity? _existingSupplier;

  @override
  void initState() {
    super.initState();
    if (widget.supplierId != null) {
      _loadSupplier();
    }
  }

  Future<void> _loadSupplier() async {
    setState(() => _isLoading = true);
    try {
      final supplier =
          await ref.read(supplierByIdProvider(widget.supplierId!).future);
      if (supplier != null && mounted) {
        _existingSupplier = supplier;
        _nameController.text = supplier.name;
        _addressController.text = supplier.address ?? '';
        _contactPersonController.text = supplier.contactPerson ?? '';
        _contactNumberController.text = supplier.contactNumber ?? '';
        _alternativeNumberController.text = supplier.alternativeNumber ?? '';
        _emailController.text = supplier.email ?? '';
        _notesController.text = supplier.notes ?? '';
        _transactionType = supplier.transactionType;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _alternativeNumberController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Supplier' : 'Add Supplier'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.suppliers),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Name *',
                        prefixIcon: Icon(LucideIcons.briefcase),
                      ),
                      validator: Validators.required,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Contact Person
                    TextFormField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Person',
                        prefixIcon: Icon(LucideIcons.user),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Contact Number
                    TextFormField(
                      controller: _contactNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        prefixIcon: Icon(LucideIcons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: Validators.phoneNumber,
                    ),
                    const SizedBox(height: 16),

                    // Alternative Number
                    TextFormField(
                      controller: _alternativeNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Alternative Number',
                        prefixIcon: Icon(LucideIcons.smartphone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(LucideIcons.mail),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        return Validators.email(value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(LucideIcons.mapPin),
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Transaction Type
                    AppDropdown<TransactionType>(
                      initialValue: _transactionType,
                      decoration: const InputDecoration(
                        labelText: 'Payment Terms *',
                        prefixIcon: Icon(LucideIcons.creditCard),
                      ),
                      items: TransactionType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _transactionType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        prefixIcon: Icon(LucideIcons.list),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _handleSubmit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(widget.isEditing
                                ? 'Update Supplier'
                                : 'Add Supplier'),
                      ),
                    ),
                    _buildActiveToggle(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Deactivate / reactivate control — only when editing an existing supplier
  /// and the current user holds the matching permission. Deactivate requires
  /// [Permission.deleteSupplier] and confirms first; reactivate requires
  /// [Permission.editSupplier] and is applied directly (non-destructive).
  Widget _buildActiveToggle() {
    final supplier = _existingSupplier;
    if (!widget.isEditing || supplier == null) return const SizedBox.shrink();

    final user = ref.read(currentUserProvider).value;
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (supplier.isActive) {
      if (!(user?.hasPermission(Permission.deleteSupplier) ?? false)) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _isSaving ? null : _deactivate,
            icon: const Icon(LucideIcons.archive, size: 18),
            label: const Text('Deactivate supplier'),
            style: TextButton.styleFrom(foregroundColor: AppColors.costUp(dark)),
          ),
        ),
      );
    }

    if (!(user?.hasPermission(Permission.editSupplier) ?? false)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: _isSaving ? null : _reactivate,
          icon: const Icon(LucideIcons.rotateCcw, size: 18),
          label: const Text('Reactivate supplier'),
          style: TextButton.styleFrom(foregroundColor: AppColors.costDown(dark)),
        ),
      ),
    );
  }

  Future<void> _deactivate() async {
    final supplier = _existingSupplier;
    if (supplier == null) return;

    final confirmed = await context.showConfirmDialog(
      title: 'Deactivate supplier?',
      message: '"${supplier.name}" will be hidden from the active list. '
          'Existing records keep their supplier; you can reactivate it later.',
      confirmText: 'Deactivate',
      icon: LucideIcons.archive,
      isDangerous: true,
    );
    if (!confirmed) return;

    await _runSetActive(
      action: () => ref
          .read(supplierOperationsProvider.notifier)
          .deactivateSupplier(supplierId: supplier.id),
      successMessage: 'Supplier deactivated',
    );
  }

  Future<void> _reactivate() async {
    final supplier = _existingSupplier;
    if (supplier == null) return;
    await _runSetActive(
      action: () => ref
          .read(supplierOperationsProvider.notifier)
          .reactivateSupplier(supplierId: supplier.id),
      successMessage: 'Supplier reactivated',
    );
  }

  Future<void> _runSetActive({
    required Future<bool> Function() action,
    required String successMessage,
  }) async {
    setState(() => _isSaving = true);
    try {
      final ok = await action();
      if (!mounted) return;
      if (ok) {
        context.showSuccessSnackBar(successMessage);
        context.go(RoutePaths.suppliers);
      } else {
        context.showErrorSnackBar('Operation failed');
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('Not logged in');

      await context.runWithWaiting(
        () async {
          if (widget.isEditing && _existingSupplier != null) {
        await ref.read(supplierOperationsProvider.notifier).updateSupplier(
              supplier: _existingSupplier!.copyWith(
                name: _nameController.text.trim(),
                address: _addressController.text.trim().isEmpty
                    ? null
                    : _addressController.text.trim(),
                contactPerson: _contactPersonController.text.trim().isEmpty
                    ? null
                    : _contactPersonController.text.trim(),
                contactNumber: _contactNumberController.text.trim().isEmpty
                    ? null
                    : _contactNumberController.text.trim(),
                alternativeNumber:
                    _alternativeNumberController.text.trim().isEmpty
                        ? null
                        : _alternativeNumberController.text.trim(),
                email: _emailController.text.trim().isEmpty
                    ? null
                    : _emailController.text.trim(),
                transactionType: _transactionType,
                notes: _notesController.text.trim().isEmpty
                    ? null
                    : _notesController.text.trim(),
              ),
            );
      } else {
        await ref.read(supplierOperationsProvider.notifier).createSupplier(
              supplier: SupplierEntity(
                id: '',
                name: _nameController.text.trim(),
                address: _addressController.text.trim().isEmpty
                    ? null
                    : _addressController.text.trim(),
                contactPerson: _contactPersonController.text.trim().isEmpty
                    ? null
                    : _contactPersonController.text.trim(),
                contactNumber: _contactNumberController.text.trim().isEmpty
                    ? null
                    : _contactNumberController.text.trim(),
                alternativeNumber:
                    _alternativeNumberController.text.trim().isEmpty
                        ? null
                        : _alternativeNumberController.text.trim(),
                email: _emailController.text.trim().isEmpty
                    ? null
                    : _emailController.text.trim(),
                transactionType: _transactionType,
                notes: _notesController.text.trim().isEmpty
                    ? null
                    : _notesController.text.trim(),
                isActive: true,
                createdBy: currentUser.id,
                createdAt: DateTime.now(),
              ),
            );
          }
        },
        message: widget.isEditing ? 'Updating…' : 'Saving…',
      );

      if (mounted) {
        context.showSuccessSnackBar(
          widget.isEditing ? 'Supplier updated' : 'Supplier added',
        );
        context.go(RoutePaths.suppliers);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
