import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/expenses/receipt_image_field.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/services/expense_receipt_storage_service.dart';

/// Screen for creating or editing an expense.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  final String? expenseId;

  const ExpenseFormScreen({super.key, this.expenseId});

  bool get isEditing => expenseId != null;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  PaymentMethod _paidVia = PaymentMethod.cash;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  Uint8List? _pendingReceiptBytes;
  bool _receiptMarkedForRemoval = false;
  String? _existingReceiptUrl;

  /// Snapshot of the form's values at load. The Update button stays disabled
  /// until the current values diverge from this (edit mode only).
  String _initialSig = '';

  String _sig() => [
        _descriptionController.text.trim(),
        _amountController.text.trim(),
        _selectedCategory ?? '',
        _paidVia.name,
        _selectedDate.toIso8601String(),
        _notesController.text.trim(),
        (_pendingReceiptBytes != null || _receiptMarkedForRemoval).toString(),
      ].join('|');

  bool get _isDirty => _sig() != _initialSig;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _descriptionController,
      _amountController,
      _notesController
    ]) {
      c.addListener(_onFormChanged);
    }
    if (widget.isEditing) {
      _loadExpense();
    } else {
      _initialSig = _sig();
    }
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadExpense() async {
    setState(() => _isLoading = true);
    try {
      final expense =
          await ref.read(expenseByIdProvider(widget.expenseId!).future);
      if (expense == null) {
        if (mounted) {
          context.showErrorSnackBar('Expense not found');
          context.goBackOr(RoutePaths.expenses);
        }
        return;
      }
      _descriptionController.text = expense.description;
      _amountController.text = expense.amount.toString();
      _notesController.text = expense.notes ?? '';
      _selectedCategory = expense.category;
      _paidVia = expense.paidVia;
      _selectedDate = expense.date;
      _existingReceiptUrl = expense.receiptImageUrl;
      _initialSig = _sig();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final userRole = currentUser?.role ?? UserRole.cashier;
    final canDelete =
        RolePermissions.hasPermission(userRole, Permission.deleteExpense);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Expense' : 'Add Expense'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.expenses),
        ),
        actions: [
          if (widget.isEditing && canDelete)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              tooltip: 'Delete expense',
              color: AppColors.error,
              onPressed: (_isLoading || _isSaving || _isDeleting)
                  ? null
                  : _handleDelete,
            ),
        ],
      ),
      body: _isLoading
          ? const FormSkeleton()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    TextFormField(
                      style: AppTextStyles.fieldInput,
                      controller: _descriptionController,
                      autofocus: !widget.isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                      ),
                      validator: (value) => value?.isEmpty == true
                          ? 'Description is required'
                          : null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      style: AppTextStyles.fieldInput,
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount *',
                        prefixText: '₱ ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Amount is required';
                        final amount = double.tryParse(value!);
                        if (amount == null || amount <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category — admin-managed dropdown.
                    _ExpenseCategoryDropdown(
                      selected: _selectedCategory,
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Paid via — which payment method funded this expense.
                    AppDropdown<PaymentMethod>(
                      initialValue: _paidVia,
                      decoration: const InputDecoration(
                        labelText: 'Paid via *',
                      ),
                      items: PaymentMethod.values
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _paidVia = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date *',
                          suffixIcon: Icon(LucideIcons.calendar),
                        ),
                        child: Text(
                          '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      style: AppTextStyles.fieldInput,
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Optional details…',
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Optional receipt photo — bytes held in memory, uploaded on
                    // save (before create for non-admin roles; see _handleSubmit).
                    Text(
                      'Receipt (optional)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ReceiptImageField(
                      existingUrl:
                          _receiptMarkedForRemoval ? null : _existingReceiptUrl,
                      pendingBytes: _pendingReceiptBytes,
                      onChanged: (bytes, {required removed}) {
                        setState(() {
                          if (removed) {
                            _pendingReceiptBytes = null;
                            _receiptMarkedForRemoval = true;
                          } else {
                            _pendingReceiptBytes = bytes;
                            _receiptMarkedForRemoval = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            (_isSaving || (widget.isEditing && !_isDirty))
                                ? null
                                : _handleSubmit,
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
                                ? 'Update Expense'
                                : 'Add Expense'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final notifier = ref.read(expenseOperationsProvider.notifier);
    final amount = double.parse(_amountController.text);
    final notes = _notesController.text.trim();
    final now = DateTime.now();

    try {
      if (widget.isEditing) {
        final existing =
            await ref.read(expenseByIdProvider(widget.expenseId!).future);
        if (existing == null) {
          if (mounted) {
            context.showErrorSnackBar('Expense not found');
          }
          return;
        }
        if (!mounted) return;
        var receiptFailed = false;
        final saved = await context.runWithWaiting(
          () async {
            String? newUrl;
            if (_pendingReceiptBytes != null) {
              try {
                newUrl = await ref
                    .read(expenseReceiptStorageServiceProvider)
                    .upload(
                        expenseId: existing.id, bytes: _pendingReceiptBytes!);
              } catch (_) {
                receiptFailed = true; // keep whatever URL was there before
              }
            }
            final clearReceipt =
                _receiptMarkedForRemoval && _pendingReceiptBytes == null;
            final updated = existing.copyWith(
              description: _descriptionController.text.trim(),
              amount: amount,
              category: _selectedCategory!,
              date: _selectedDate,
              paidVia: _paidVia,
              notes: notes.isEmpty ? null : notes,
              clearNotes: notes.isEmpty,
              receiptImageUrl: newUrl,
              clearReceiptImageUrl: clearReceipt,
            );
            final result = await notifier.updateExpense(expense: updated);
            if (result != null && clearReceipt) {
              // Best-effort storage cleanup — orphans are harmless.
              try {
                await ref
                    .read(expenseReceiptStorageServiceProvider)
                    .delete(expenseId: existing.id);
              } catch (_) {}
            }
            return result;
          },
          message: 'Updating…',
        );
        if (saved == null) throw _readOperationError();
        if (receiptFailed && mounted) {
          context.showWarningSnackBar(
              'Receipt upload failed — expense saved without new receipt');
        }
      } else {
        // The receipt uploads BEFORE the document is created — pre-allocate
        // the id and carry the URL on the create, so the expense lands in
        // one write with no URL-fixup update racing behind it.
        var receiptFailed = false;
        final saved = await context.runWithWaiting(
          () async {
            var presetId = '';
            String? receiptUrl;
            if (_pendingReceiptBytes != null) {
              presetId = ref.read(expenseRepositoryProvider).newExpenseId();
              try {
                receiptUrl = await ref
                    .read(expenseReceiptStorageServiceProvider)
                    .upload(expenseId: presetId, bytes: _pendingReceiptBytes!);
              } catch (_) {
                receiptFailed = true; // best-effort: save without receipt
              }
            }
            final draft = ExpenseEntity(
              id: receiptUrl != null ? presetId : '',
              description: _descriptionController.text.trim(),
              amount: amount,
              category: _selectedCategory!,
              date: _selectedDate,
              paidVia: _paidVia,
              notes: notes.isEmpty ? null : notes,
              receiptImageUrl: receiptUrl,
              createdAt: now,
              createdBy: '',
              createdByName: '',
            );
            return notifier.createExpense(expense: draft);
          },
          message: 'Saving…',
        );
        if (saved == null) throw _readOperationError();
        if (receiptFailed && mounted) {
          context.showWarningSnackBar(
              'Receipt upload failed — expense saved without receipt');
        }
      }

      if (mounted) {
        context.showSuccessSnackBar(
          widget.isEditing ? 'Expense updated' : 'Expense added',
        );
        // Return to wherever the form was opened from (expense list OR the
        // End-of-Day closing screen) instead of force-resetting to the list.
        context.goBackOr(RoutePaths.expenses);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete() async {
    final desc = _descriptionController.text.trim();
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete expense?',
      message: desc.isEmpty
          ? 'This expense will be permanently deleted.'
          : '"$desc" will be permanently deleted.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed) return;

    if (!mounted) return;
    setState(() => _isDeleting = true);
    try {
      final ok = await context.runWithWaiting(
        () async {
          final deleted = await ref
              .read(expenseOperationsProvider.notifier)
              .deleteExpense(widget.expenseId!);
          if (deleted) {
            // Best-effort receipt cleanup — orphans are harmless.
            try {
              await ref
                  .read(expenseReceiptStorageServiceProvider)
                  .delete(expenseId: widget.expenseId!);
            } catch (_) {}
          }
          return deleted;
        },
        message: 'Deleting…',
      );
      if (!ok) throw _readOperationError();
      if (mounted) {
        context.showSuccessSnackBar('Expense deleted');
        context.go(RoutePaths.expenses);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Failed to delete: $e');
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Object _readOperationError() {
    final state = ref.read(expenseOperationsProvider);
    return state.hasError
        ? state.error ?? 'Operation failed'
        : 'Operation failed';
  }
}

/// Dropdown for expense category. Items = active expense categories ∪
/// {[selected] if it's not in the active list — e.g. a legacy expense whose
/// category was deactivated}. Renders an empty-state row when no categories
/// are defined yet (admin must seed via Settings → Manage Categories).
class _ExpenseCategoryDropdown extends ConsumerWidget {
  const _ExpenseCategoryDropdown({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync =
        ref.watch(activeCategoriesProvider(CategoryKind.expense));

    return categoriesAsync.when(
      data: (categories) {
        final theme = Theme.of(context);
        final activeNames = categories.map((c) => c.name).toList();
        final isOrphan = selected != null && !activeNames.contains(selected);

        if (activeNames.isEmpty && !isOrphan) {
          return InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Category *',
              errorText: 'No categories defined — ask admin to add some.',
            ),
            child: Text(
              'No categories available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return AppDropdown<String>(
          initialValue: selected,
          decoration: const InputDecoration(
            labelText: 'Category *',
          ),
          items: [
            ...activeNames.map(
              (name) => DropdownMenuItem(value: name, child: Text(name)),
            ),
            if (isOrphan)
              DropdownMenuItem(
                value: selected,
                child: Text(
                  '$selected (inactive)',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
          onChanged: onChanged,
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Category is required' : null,
        );
      },
      loading: () => const FieldSkeleton(),
      error: (_, __) => const Text('Could not load categories'),
    );
  }
}
