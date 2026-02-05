import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for Sale operations.
///
/// This interface defines all data access methods for sales.
/// Implementations handle the actual data source (Firestore, etc.)
///
/// Key responsibilities:
/// - CRUD operations for sales
/// - Querying sales by various criteria
/// - Voiding sales
/// - Generating sale numbers
/// - Retrieving sale items
abstract class SaleRepository {
  // ==================== CREATE ====================

  /// Creates a new sale and returns it with the generated ID.
  ///
  /// [sale] - The sale entity to create (id will be ignored/replaced)
  /// [items] - The sale items to create in subcollection
  ///
  /// Returns the created sale with populated ID and server timestamps.
  /// Throws [SaleException] if creation fails.
  Future<SaleEntity> createSale(SaleEntity sale);

  // ==================== READ ====================

  /// Retrieves a sale by its ID.
  ///
  /// [saleId] - The unique identifier of the sale
  ///
  /// Returns the sale entity with items loaded.
  /// Returns null if not found.
  Future<SaleEntity?> getSaleById(String saleId);

  /// Retrieves a sale by its sale number.
  ///
  /// [saleNumber] - The human-readable sale number (e.g., "SALE-20250205-001")
  ///
  /// Returns the sale entity with items loaded.
  /// Returns null if not found.
  Future<SaleEntity?> getSaleBySaleNumber(String saleNumber);

  /// Retrieves sales within a date range.
  ///
  /// [startDate] - Start of the date range (inclusive)
  /// [endDate] - End of the date range (inclusive)
  /// [status] - Optional filter by sale status
  /// [cashierId] - Optional filter by cashier
  /// [limit] - Maximum number of results (default: 100)
  ///
  /// Returns list of sales ordered by createdAt descending.
  Future<List<SaleEntity>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    SaleStatus? status,
    String? cashierId,
    int limit = 100,
  });

  /// Retrieves sales for a specific day.
  ///
  /// [date] - The date to query
  /// [status] - Optional filter by sale status
  /// [cashierId] - Optional filter by cashier
  ///
  /// Returns list of sales for that day.
  Future<List<SaleEntity>> getSalesForDay({
    required DateTime date,
    SaleStatus? status,
    String? cashierId,
  });

  /// Retrieves today's sales.
  ///
  /// [status] - Optional filter by sale status
  /// [cashierId] - Optional filter by cashier
  ///
  /// Returns list of today's sales.
  Future<List<SaleEntity>> getTodaysSales({
    SaleStatus? status,
    String? cashierId,
  });

  /// Retrieves recent sales with pagination.
  ///
  /// [limit] - Number of sales to retrieve
  /// [startAfterSaleId] - For pagination, start after this sale ID
  /// [status] - Optional filter by sale status
  ///
  /// Returns list of recent sales.
  Future<List<SaleEntity>> getRecentSales({
    int limit = 20,
    String? startAfterSaleId,
    SaleStatus? status,
  });

  /// Streams sales for real-time updates.
  ///
  /// [date] - The date to stream sales for
  /// [status] - Optional filter by sale status
  ///
  /// Returns a stream of sale lists.
  Stream<List<SaleEntity>> watchSalesForDay({
    required DateTime date,
    SaleStatus? status,
  });

  /// Streams today's sales for real-time updates.
  ///
  /// [status] - Optional filter by sale status
  ///
  /// Returns a stream of today's sales.
  Stream<List<SaleEntity>> watchTodaysSales({SaleStatus? status});

  // ==================== UPDATE ====================

  /// Voids a sale.
  ///
  /// [saleId] - The ID of the sale to void
  /// [voidedBy] - The ID of the user voiding the sale
  /// [voidedByName] - The name of the user voiding the sale
  /// [reason] - The reason for voiding
  ///
  /// Returns the updated sale entity.
  /// Throws [SaleException] if void fails.
  Future<SaleEntity> voidSale({
    required String saleId,
    required String voidedBy,
    required String voidedByName,
    required String reason,
  });

  /// Updates sale notes.
  ///
  /// [saleId] - The ID of the sale
  /// [notes] - The new notes
  ///
  /// Returns the updated sale entity.
  Future<SaleEntity> updateSaleNotes({
    required String saleId,
    required String notes,
  });

  // ==================== SALE NUMBER GENERATION ====================

  /// Generates the next sale number for a given date.
  ///
  /// [date] - The date to generate sale number for
  ///
  /// Returns a unique sale number (e.g., "SALE-20250205-001").
  /// Handles concurrent access to prevent duplicates.
  Future<String> generateSaleNumber(DateTime date);

  /// Gets the current sequence number for a date.
  ///
  /// [date] - The date to query
  ///
  /// Returns the last used sequence number for that date.
  Future<int> getSaleSequenceForDate(DateTime date);

  // ==================== REPORTING QUERIES ====================

  /// Gets total sales amount for a date range.
  ///
  /// [startDate] - Start of the date range
  /// [endDate] - End of the date range
  /// [excludeVoided] - Whether to exclude voided sales (default: true)
  ///
  /// Returns total sales amount.
  Future<double> getTotalSalesAmount({
    required DateTime startDate,
    required DateTime endDate,
    bool excludeVoided = true,
  });

  /// Gets total sales count for a date range.
  ///
  /// [startDate] - Start of the date range
  /// [endDate] - End of the date range
  /// [excludeVoided] - Whether to exclude voided sales (default: true)
  ///
  /// Returns total number of sales.
  Future<int> getTotalSalesCount({
    required DateTime startDate,
    required DateTime endDate,
    bool excludeVoided = true,
  });

  /// Gets sales grouped by payment method for a date range.
  ///
  /// [startDate] - Start of the date range
  /// [endDate] - End of the date range
  ///
  /// Returns map of payment method to total amount.
  Future<Map<PaymentMethod, double>> getSalesByPaymentMethod({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Gets sales summary for a date range.
  ///
  /// [startDate] - Start of the date range
  /// [endDate] - End of the date range
  ///
  /// Returns a summary containing totals, counts, and breakdowns.
  Future<SalesSummary> getSalesSummary({
    required DateTime startDate,
    required DateTime endDate,
  });

  // ==================== ITEM QUERIES ====================

  /// Gets all items for a sale.
  ///
  /// [saleId] - The sale ID
  ///
  /// Returns list of sale items.
  Future<List<SaleItemEntity>> getSaleItems(String saleId);

  /// Gets top-selling products for a date range.
  ///
  /// [startDate] - Start of the date range
  /// [endDate] - End of the date range
  /// [limit] - Number of top products to return
  ///
  /// Returns list of product sales data sorted by quantity sold.
  Future<List<ProductSalesData>> getTopSellingProducts({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
  });
}

// ==================== SUPPORTING CLASSES ====================

/// Summary of sales for a date range.
class SalesSummary {
  /// Total number of completed sales
  final int totalSalesCount;

  /// Total number of voided sales
  final int voidedSalesCount;

  /// Total gross amount (before discounts)
  final double grossAmount;

  /// Total discount amount
  final double totalDiscounts;

  /// Total net amount (after discounts)
  final double netAmount;

  /// Total cost of goods sold
  final double totalCost;

  /// Total profit
  final double totalProfit;

  /// Breakdown by payment method
  final Map<PaymentMethod, double> byPaymentMethod;

  /// Average sale amount
  double get averageSaleAmount =>
      totalSalesCount > 0 ? netAmount / totalSalesCount : 0;

  /// Profit margin percentage
  double get profitMargin =>
      netAmount > 0 ? (totalProfit / netAmount) * 100 : 0;

  const SalesSummary({
    required this.totalSalesCount,
    required this.voidedSalesCount,
    required this.grossAmount,
    required this.totalDiscounts,
    required this.netAmount,
    required this.totalCost,
    required this.totalProfit,
    required this.byPaymentMethod,
  });

  /// Creates an empty summary.
  factory SalesSummary.empty() {
    return const SalesSummary(
      totalSalesCount: 0,
      voidedSalesCount: 0,
      grossAmount: 0,
      totalDiscounts: 0,
      netAmount: 0,
      totalCost: 0,
      totalProfit: 0,
      byPaymentMethod: {},
    );
  }
}

/// Sales data for a single product (used in top-selling reports).
class ProductSalesData {
  /// Product ID
  final String productId;

  /// Product SKU
  final String sku;

  /// Product name
  final String name;

  /// Total quantity sold
  final int quantitySold;

  /// Total revenue from this product
  final double totalRevenue;

  /// Total cost for this product
  final double totalCost;

  /// Total profit from this product
  double get totalProfit => totalRevenue - totalCost;

  /// Profit margin percentage
  double get profitMargin =>
      totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0;

  const ProductSalesData({
    required this.productId,
    required this.sku,
    required this.name,
    required this.quantitySold,
    required this.totalRevenue,
    required this.totalCost,
  });
}
