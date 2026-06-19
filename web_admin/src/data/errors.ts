/**
 * Thrown by the product repository when a SKU's product_skus claim is already
 * taken. Message matches the string InventoryFormPage maps to a field error;
 * the Bulk-Receiving retry catches this type to bump the variation number.
 */
export class DuplicateSkuError extends Error {
  constructor(message = 'A product with this SKU already exists') {
    super(message);
    this.name = 'DuplicateSkuError';
  }
}

/**
 * Thrown by the product repository when a barcode's product_barcodes claim is
 * already taken. Message matches the string InventoryFormPage maps to a field
 * error.
 */
export class DuplicateBarcodeError extends Error {
  constructor(message = 'A product with this barcode already exists') {
    super(message);
    this.name = 'DuplicateBarcodeError';
  }
}
