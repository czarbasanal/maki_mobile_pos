import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/expense_provider.dart';

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
  String _selectedCategory = 'General';
  bool _isSaving = false;

  final _categories = [
    'General',
    'Utilities',
    'Rent',
    'Supplies',
    'Transportation',
    'Food',
    'Maintenance',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Expense' : 'Add Expense'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.expenses),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  prefixIcon: Icon(CupertinoIcons.doc_text),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Description is required' : null,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  prefixIcon: Icon(CupertinoIcons.money_dollar),
                  prefixText: '₱ ',
                  border: OutlineInputBorder(),
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

              // Category
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(CupertinoIcons.square_grid_2x2),
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date *',
                    prefixIcon: Icon(CupertinoIcons.calendar),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(CupertinoIcons.list_bullet),
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
                      : Text(
                          widget.isEditing ? 'Update Expense' : 'Add Expense'),
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
        final updated = existing.copyWith(
          description: _descriptionController.text.trim(),
          amount: amount,
          category: _selectedCategory,
          date: _selectedDate,
          notes: notes.isEmpty ? null : notes,
          clearNotes: notes.isEmpty,
        );
        final saved = await notifier.updateExpense(expense: updated);
        if (saved == null) throw _readOperationError();
      } else {
        final draft = ExpenseEntity(
          id: '',
          description: _descriptionController.text.trim(),
          amount: amount,
          category: _selectedCategory,
          date: _selectedDate,
          notes: notes.isEmpty ? null : notes,
          createdAt: now,
          createdBy: '',
          createdByName: '',
        );
        final saved = await notifier.createExpense(expense: draft);
        if (saved == null) throw _readOperationError();
      }

      if (mounted) {
        context.showSuccessSnackBar(
          widget.isEditing ? 'Expense updated' : 'Expense added',
        );
        context.go(RoutePaths.expenses);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Object _readOperationError() {
    final state = ref.read(expenseOperationsProvider);
    return state.hasError
        ? state.error ?? 'Operation failed'
        : 'Operation failed';
  }
}
