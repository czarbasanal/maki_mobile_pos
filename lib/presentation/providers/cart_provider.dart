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

  /// Optional notes for the sale
  final String? notes;

  /// If editing an existing draft, its ID
  final String? sourceDraftId;

  /// Whether the cart is currently being processed
  final bool isProcessing;

  /// Error message if any
  final String? errorMessage;

  const CartState({
    this.items = const [],
    this.discountType = DiscountType.amount,
    this.paymentMethod = PaymentMethod.cash,
    this.amountReceived = 0,
    this.notes,
    this.sourceDraftId,
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

  /// Grand total after discounts
  double get grandTotal => subtotal - totalDiscount;

  /// Total cost of all items
  double get totalCost {
    return items.fold(0.0, (sum, item) => sum + item.totalCost);
  }

  /// Total profit
  double get totalProfit => grandTotal - totalCost;

  /// Change to give customer
  double get change {
    if (amountReceived <= grandTotal) return 0;
    return amountReceived - grandTotal;
  }

  /// Whether payment is sufficient
  bool get isPaymentSufficient => amountReceived >= grandTotal;

  /// Whether cart can be checked out
  bool get canCheckout => isNotEmpty && isPaymentSufficient && !isProcessing;

  /// Whether cart can be saved as draft
  bool get canSaveAsDraft => isNotEmpty && !isProcessing;

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
    String? notes,
    String? sourceDraftId,
    bool? isProcessing,
    String? errorMessage,
    bool clearNotes = false,
    bool clearSourceDraftId = false,
    bool clearErrorMessage = false,
  }) {
    return CartState(
      items: items ?? this.items,
      discountType: discountType ?? this.discountType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountReceived: amountReceived ?? this.amountReceived,
      notes: clearNotes ? null : (notes ?? this.notes),
      sourceDraftId:
          clearSourceDraftId ? null : (sourceDraftId ?? this.sourceDraftId),
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

  // ==================== PAYMENT OPERATIONS ====================

  /// Sets the payment method.
  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method, clearErrorMessage: true);
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
  void loadFromDraft(DraftEntity draft) {
    state = CartState(
      items: List<SaleItemEntity>.from(draft.items),
      discountType: draft.discountType,
      paymentMethod: PaymentMethod.cash,
      amountReceived: 0,
      notes: draft.notes,
      sourceDraftId: draft.id,
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
      amountReceived: state.amountReceived,
      changeGiven: state.change,
      cashierId: cashierId,
      cashierName: cashierName,
      createdAt: DateTime.now(),
      draftId: state.sourceDraftId,
      notes: state.notes,
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
  return ref.watch(cartProvider).isPaymentSufficient;
});
