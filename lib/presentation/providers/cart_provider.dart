import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:uuid/uuid.dart';

// ==================== CART STATE ====================

/// Represents the current state of the shopping cart.
class CartState {
  /// Items in the cart
  final List<SaleItemEntity> items;

  /// Type of discount applied (amount or percentage)
  /// All item discounts must be of this type
  final DiscountType discountType;

  /// Selected payment method
  final PaymentMethod paymentMethod;

  /// Amount received from customer
  final double amountReceived;

  /// Secondary method for Mixed (the digital method) or Salmon (the
  /// downpayment method). Null for single-tender sales.
  final PaymentMethod? secondaryMethod;

  /// For Mixed: the digital amount. For Salmon: the downpayment amount.
  final double splitAmount;

  /// Optional notes for the sale
  final String? notes;

  /// If editing an existing draft, its ID
  final String? sourceDraftId;

  /// Name of the draft this cart was loaded from, if any.
  ///
  /// Retained even though [sourceDraftId] is intentionally not — see
  /// [CartNotifier.loadFromDraft]. Carrying just the name lets the
  /// follow-up "Save as Draft" reuse the original title without
  /// re-prompting, while still creating a new draft entry.
  final String? draftName;

  /// Labor/service lines on this ticket. Full price, never discounted.
  final List<LaborLineEntity> laborLines;

  /// Assigned mechanic id (null until a mechanic is picked).
  final String? mechanicId;

  /// Assigned mechanic name snapshot (denormalized, like cashierName).
  final String? mechanicName;

  /// Whether the cart is currently being processed
  final bool isProcessing;

  /// Error message if any
  final String? errorMessage;

  const CartState({
    this.items = const [],
    this.discountType = DiscountType.amount,
    this.paymentMethod = PaymentMethod.cash,
    this.amountReceived = 0,
    this.secondaryMethod,
    this.splitAmount = 0,
    this.notes,
    this.sourceDraftId,
    this.draftName,
    this.laborLines = const [],
    this.mechanicId,
    this.mechanicName,
    this.isProcessing = false,
    this.errorMessage,
  });

  // ==================== COMPUTED PROPERTIES ====================

  /// Whether the cart is empty
  bool get isEmpty => items.isEmpty;

  /// Whether the cart has items
  bool get isNotEmpty => items.isNotEmpty;

  /// Total number of items (sum of quantities)
  int get totalItemCount {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Number of unique products
  int get uniqueProductCount => items.length;

  /// Whether discount type is percentage
  bool get isPercentageDiscount => discountType == DiscountType.percentage;

  /// Subtotal before discounts
  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.grossAmount);
  }

  /// Total discount amount
  double get totalDiscount {
    return items.fold(
      0.0,
      (sum, item) =>
          sum +
          item.calculateDiscountAmount(isPercentage: isPercentageDiscount),
    );
  }

  /// Parts gross subtotal (items only, before discount). Alias of [subtotal].
  double get partsSubtotal => subtotal;

  /// Net merchandise revenue (parts after discount).
  double get partsRevenue => partsSubtotal - totalDiscount;

  /// Labor subtotal (sum of labor fees; never discounted).
  double get laborSubtotal => laborLines.fold(0.0, (s, l) => s + l.fee);

  /// Labor revenue (pure margin — zero cost).
  double get laborRevenue => laborSubtotal;

  /// Grand total after discounts, including labor.
  double get grandTotal => partsRevenue + laborRevenue;

  /// Total cost of all items
  double get totalCost {
    return items.fold(0.0, (sum, item) => sum + item.totalCost);
  }

  /// Merchandise profit (parts revenue minus parts cost).
  double get partsProfit => partsRevenue - totalCost;

  /// Labor profit (equals labor revenue; zero cost).
  double get laborProfit => laborRevenue;

  /// True per-transaction profit (parts + labor).
  double get totalProfit => partsProfit + laborProfit;

  /// Tender breakdown derived from the selected method + entered amounts.
  Map<PaymentMethod, double> get tenders {
    switch (paymentMethod) {
      case PaymentMethod.mixed:
        final digital = secondaryMethod ?? PaymentMethod.gcash;
        return {
          PaymentMethod.cash: grandTotal - splitAmount,
          digital: splitAmount,
        };
      case PaymentMethod.salmon:
        final dp = secondaryMethod ?? PaymentMethod.cash;
        return {
          dp: splitAmount,
          PaymentMethod.salmon: grandTotal - splitAmount,
        };
      default:
        return {paymentMethod: grandTotal};
    }
  }

  /// Amount actually collected today (excludes the Salmon receivable).
  double get collectedToday {
    if (paymentMethod == PaymentMethod.salmon) return splitAmount;
    return grandTotal;
  }

  /// Change to give customer (only meaningful for single cash).
  double get change {
    if (paymentMethod == PaymentMethod.cash &&
        secondaryMethod == null &&
        amountReceived > grandTotal) {
      return amountReceived - grandTotal;
    }
    return 0;
  }

  /// Whether the selected payment is valid for checkout.
  bool get isPaymentValid {
    if (isEmpty) return false;
    switch (paymentMethod) {
      case PaymentMethod.cash:
        return amountReceived >= grandTotal;
      case PaymentMethod.gcash:
      case PaymentMethod.maya:
        return true; // exact, collected in full
      case PaymentMethod.mixed:
        return secondaryMethod != null &&
            splitAmount > 0 &&
            splitAmount < grandTotal;
      case PaymentMethod.salmon:
        return secondaryMethod != null &&
            splitAmount > 0 &&
            splitAmount < grandTotal;
    }
  }

  /// Whether the labor section is internally consistent:
  /// - if any labor line exists, a mechanic must be assigned, and
  /// - every labor fee must be greater than zero.
  /// Empty labor (the normal merchandise sale) is always valid.
  bool get laborValid {
    if (laborLines.isEmpty) return true;
    if (mechanicId == null || mechanicId!.isEmpty) return false;
    return laborLines.every((l) => l.fee > 0);
  }

  /// Human-readable reason labor is invalid, or null when [laborValid].
  String? get laborValidationError {
    if (laborLines.isEmpty) return null;
    if (mechanicId == null || mechanicId!.isEmpty) {
      return 'Assign a mechanic before saving labor.';
    }
    if (laborLines.any((l) => l.fee <= 0)) {
      return 'Each labor fee must be greater than ₱0.';
    }
    return null;
  }

  /// Whether cart can be checked out
  bool get canCheckout =>
      isNotEmpty && isPaymentValid && laborValid && !isProcessing;

  /// Whether cart can be saved as draft
  bool get canSaveAsDraft => isNotEmpty && laborValid && !isProcessing;

  /// Whether any item has a discount
  bool get hasDiscount => totalDiscount > 0;

  /// Whether this cart is from a draft
  bool get isFromDraft => sourceDraftId != null && sourceDraftId!.isNotEmpty;

  // ==================== COPY WITH ====================

  CartState copyWith({
    List<SaleItemEntity>? items,
    DiscountType? discountType,
    PaymentMethod? paymentMethod,
    double? amountReceived,
    PaymentMethod? secondaryMethod,
    double? splitAmount,
    bool clearSecondaryMethod = false,
    String? notes,
    String? sourceDraftId,
    String? draftName,
    List<LaborLineEntity>? laborLines,
    String? mechanicId,
    String? mechanicName,
    bool? isProcessing,
    String? errorMessage,
    bool clearNotes = false,
    bool clearSourceDraftId = false,
    bool clearDraftName = false,
    bool clearMechanic = false,
    bool clearErrorMessage = false,
  }) {
    return CartState(
      items: items ?? this.items,
      discountType: discountType ?? this.discountType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountReceived: amountReceived ?? this.amountReceived,
      secondaryMethod: clearSecondaryMethod
          ? null
          : (secondaryMethod ?? this.secondaryMethod),
      splitAmount: splitAmount ?? this.splitAmount,
      notes: clearNotes ? null : (notes ?? this.notes),
      sourceDraftId:
          clearSourceDraftId ? null : (sourceDraftId ?? this.sourceDraftId),
      draftName: clearDraftName ? null : (draftName ?? this.draftName),
      laborLines: laborLines ?? this.laborLines,
      mechanicId: clearMechanic ? null : (mechanicId ?? this.mechanicId),
      mechanicName: clearMechanic ? null : (mechanicName ?? this.mechanicName),
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ==================== CART NOTIFIER ====================

/// Manages the cart state and operations.
class CartNotifier extends StateNotifier<CartState> {
  final Uuid _uuid = const Uuid();

  CartNotifier() : super(const CartState());

  // ==================== ITEM OPERATIONS ====================

  /// Adds a product to the cart.
  /// If the product already exists, increases quantity.
  void addProduct(ProductEntity product, {int quantity = 1}) {
    final existingIndex =
        state.items.indexWhere((item) => item.productId == product.id);

    if (existingIndex >= 0) {
      // Update existing item
      final existingItem = state.items[existingIndex];
      final updatedItem = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
      final updatedItems = List<SaleItemEntity>.from(state.items);
      updatedItems[existingIndex] = updatedItem;
      state = state.copyWith(items: updatedItems, clearErrorMessage: true);
    } else {
      // Add new item
      final newItem = SaleItemEntity(
        id: _uuid.v4(),
        productId: product.id,
        sku: product.sku,
        name: product.name,
        unitPrice: product.price,
        unitCost: product.cost,
        quantity: quantity,
        unit: product.unit,
      );
      state = state.copyWith(
        items: [...state.items, newItem],
        clearErrorMessage: true,
      );
    }
  }

  /// Adds a SaleItemEntity directly to the cart.
  /// Used when loading from a draft.
  void addItem(SaleItemEntity item) {
    final existingIndex =
        state.items.indexWhere((i) => i.productId == item.productId);

    if (existingIndex >= 0) {
      final existingItem = state.items[existingIndex];
      final updatedItem = existingItem.copyWith(
        quantity: existingItem.quantity + item.quantity,
      );
      final updatedItems = List<SaleItemEntity>.from(state.items);
      updatedItems[existingIndex] = updatedItem;
      state = state.copyWith(items: updatedItems, clearErrorMessage: true);
    } else {
      // Ensure item has a valid ID
      final itemWithId = item.id.isEmpty ? item.copyWith(id: _uuid.v4()) : item;
      state = state.copyWith(
        items: [...state.items, itemWithId],
        clearErrorMessage: true,
      );
    }
  }

  /// Updates the quantity of an item.
  void updateItemQuantity(String itemId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(itemId);
      return;
    }

    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;

    final updatedItems = List<SaleItemEntity>.from(state.items);
    updatedItems[index] = state.items[index].copyWith(quantity: newQuantity);
    state = state.copyWith(items: updatedItems, clearErrorMessage: true);
  }

  /// Increments the quantity of an item.
  void incrementItemQuantity(String itemId) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;

    final item = state.items[index];
    updateItemQuantity(itemId, item.quantity + 1);
  }

  /// Decrements the quantity of an item.
  void decrementItemQuantity(String itemId) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;

    final item = state.items[index];
    updateItemQuantity(itemId, item.quantity - 1);
  }

  /// Removes an item from the cart.
  void removeItem(String itemId) {
    state = state.copyWith(
      items: state.items.where((item) => item.id != itemId).toList(),
      clearErrorMessage: true,
    );
  }

  /// Clears all items from the cart.
  void clearItems() {
    state = state.copyWith(items: [], clearErrorMessage: true);
  }

  // ==================== DISCOUNT OPERATIONS ====================

  /// Sets the discount type for the entire cart.
  /// This resets all item discounts to 0.
  void setDiscountType(DiscountType type) {
    if (type == state.discountType) return;

    // Reset all item discounts when changing type
    final resetItems =
        state.items.map((item) => item.copyWith(discountValue: 0)).toList();

    state = state.copyWith(
      discountType: type,
      items: resetItems,
      clearErrorMessage: true,
    );
  }

  /// Applies a discount to a specific item.
  void applyItemDiscount(String itemId, double discountValue) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;

    final item = state.items[index];

    // Validate discount value
    double validatedDiscount = discountValue;
    if (state.isPercentageDiscount) {
      // Percentage: cap at 100%
      validatedDiscount = discountValue.clamp(0, 100);
    } else {
      // Amount: cap at item's gross amount
      validatedDiscount = discountValue.clamp(0, item.grossAmount);
    }

    final updatedItems = List<SaleItemEntity>.from(state.items);
    updatedItems[index] = item.copyWith(discountValue: validatedDiscount);
    state = state.copyWith(items: updatedItems, clearErrorMessage: true);
  }

  /// Removes discount from a specific item.
  void removeItemDiscount(String itemId) {
    applyItemDiscount(itemId, 0);
  }

  /// Clears all discounts from all items.
  void clearAllDiscounts() {
    final resetItems =
        state.items.map((item) => item.copyWith(discountValue: 0)).toList();
    state = state.copyWith(items: resetItems, clearErrorMessage: true);
  }

  // ==================== LABOR & MECHANIC OPERATIONS ====================

  /// Adds a labor/service line with a generated id.
  void addLaborLine({required String description, required double fee}) {
    final line = LaborLineEntity(
      id: _uuid.v4(),
      description: description,
      fee: fee,
    );
    state = state.copyWith(
      laborLines: [...state.laborLines, line],
      clearErrorMessage: true,
    );
  }

  /// Updates a labor line by id. Only the provided fields change.
  void updateLaborLine(String id, {String? description, double? fee}) {
    final index = state.laborLines.indexWhere((l) => l.id == id);
    if (index < 0) return;

    final updatedLines = List<LaborLineEntity>.from(state.laborLines);
    updatedLines[index] = state.laborLines[index].copyWith(
      description: description,
      fee: fee,
    );
    state = state.copyWith(laborLines: updatedLines, clearErrorMessage: true);
  }

  /// Removes a labor line by id.
  void removeLaborLine(String id) {
    state = state.copyWith(
      laborLines: state.laborLines.where((l) => l.id != id).toList(),
      clearErrorMessage: true,
    );
  }

  /// Assigns the mechanic for this ticket (snapshots the name).
  void setMechanic(String id, String name) {
    state = state.copyWith(
      mechanicId: id,
      mechanicName: name,
      clearErrorMessage: true,
    );
  }

  /// Clears the assigned mechanic.
  void clearMechanic() {
    state = state.copyWith(clearMechanic: true, clearErrorMessage: true);
  }

  // ==================== PAYMENT OPERATIONS ====================

  /// Sets the payment method, resetting the split inputs.
  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(
      paymentMethod: method,
      clearSecondaryMethod: true,
      splitAmount: 0,
      clearErrorMessage: true,
    );
  }

  /// Sets the secondary method (Mixed digital method or Salmon DP method).
  void setSecondaryMethod(PaymentMethod method) {
    state = state.copyWith(secondaryMethod: method, clearErrorMessage: true);
  }

  /// Sets the split amount (Mixed digital amount or Salmon downpayment).
  void setSplitAmount(double amount) {
    state = state.copyWith(splitAmount: amount, clearErrorMessage: true);
  }

  /// Sets the amount received.
  void setAmountReceived(double amount) {
    state = state.copyWith(amountReceived: amount, clearErrorMessage: true);
  }

  /// Sets the exact amount (no change).
  void setExactAmount() {
    state = state.copyWith(
      amountReceived: state.grandTotal,
      clearErrorMessage: true,
    );
  }

  // ==================== NOTES ====================

  /// Sets the sale notes.
  void setNotes(String? notes) {
    state = state.copyWith(
      notes: notes,
      clearNotes: notes == null || notes.isEmpty,
      clearErrorMessage: true,
    );
  }

  // ==================== DRAFT OPERATIONS ====================

  /// Loads a draft into the cart.
  ///
  /// Loading is destructive: the caller is expected to delete the source
  /// draft right after — see [drafts_list_screen]. We deliberately don't
  /// retain `sourceDraftId` so a follow-up "Save as Draft" creates a new
  /// entry rather than trying to update a draft that's already been removed.
  ///
  /// The draft *name* is retained so the follow-up save can reuse the
  /// original title without prompting the user again.
  void loadFromDraft(DraftEntity draft) {
    state = CartState(
      items: List<SaleItemEntity>.from(draft.items),
      discountType: draft.discountType,
      paymentMethod: PaymentMethod.cash,
      amountReceived: 0,
      notes: draft.notes,
      draftName: draft.name,
      laborLines: List<LaborLineEntity>.from(draft.laborLines),
      mechanicId: draft.mechanicId,
      mechanicName: draft.mechanicName,
    );
  }

  /// Creates a DraftEntity from current cart state.
  DraftEntity toDraft({
    required String name,
    required String createdBy,
    required String createdByName,
  }) {
    return DraftEntity(
      id: state.sourceDraftId ?? '',
      name: name,
      items: state.items,
      discountType: state.discountType,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: DateTime.now(),
      notes: state.notes,
      laborLines: state.laborLines,
      mechanicId: state.mechanicId,
      mechanicName: state.mechanicName,
    );
  }

  /// Creates a SaleEntity from current cart state.
  SaleEntity toSale({
    required String saleNumber,
    required String cashierId,
    required String cashierName,
  }) {
    return SaleEntity(
      id: '',
      saleNumber: saleNumber,
      items: state.items,
      discountType: state.discountType,
      paymentMethod: state.paymentMethod,
      tenders: state.tenders,
      amountReceived: state.collectedToday,
      changeGiven: state.change,
      cashierId: cashierId,
      cashierName: cashierName,
      createdAt: DateTime.now(),
      draftId: state.sourceDraftId,
      notes: state.notes,
      laborLines: state.laborLines,
      mechanicId: state.mechanicId,
      mechanicName: state.mechanicName,
    );
  }

  // ==================== STATE MANAGEMENT ====================

  /// Sets processing state.
  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  /// Sets error message.
  void setError(String? error) {
    state = state.copyWith(
      errorMessage: error,
      clearErrorMessage: error == null || error.isEmpty,
      isProcessing: false,
    );
  }

  /// Resets the cart to initial state.
  void reset() {
    state = const CartState();
  }

  /// Resets cart after successful checkout.
  void resetAfterCheckout() {
    state = const CartState();
  }
}

// ==================== CART PROVIDER ====================

/// Main cart provider.
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

// ==================== DERIVED PROVIDERS ====================

/// Whether the cart is empty.
final isCartEmptyProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isEmpty;
});

/// Cart item count.
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalItemCount;
});

/// Cart grand total.
final cartGrandTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).grandTotal;
});

/// Whether cart can be checked out.
final canCheckoutProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).canCheckout;
});

/// Change to give customer.
final cartChangeProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).change;
});

/// Whether payment is sufficient.
final isPaymentSufficientProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isPaymentValid;
});
