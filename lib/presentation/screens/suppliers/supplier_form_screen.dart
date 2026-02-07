import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/utils/validators.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

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
          icon: const Icon(Icons.arrow_back),
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
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
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
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Contact Number
                    TextFormField(
                      controller: _contactNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
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
                        prefixIcon: Icon(Icons.phone_android),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
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
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Transaction Type
                    DropdownButtonFormField<TransactionType>(
                      value: _transactionType,
                      decoration: const InputDecoration(
                        labelText: 'Payment Terms *',
                        prefixIcon: Icon(Icons.payment),
                        border: OutlineInputBorder(),
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
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
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
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('Not logged in');

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
              updatedBy: currentUser.id,
            );
      } else {
        await ref.read(supplierOperationsProvider.notifier).createSupplier(
              createdBy: currentUser.id,
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
