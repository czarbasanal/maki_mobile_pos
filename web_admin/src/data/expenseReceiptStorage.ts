import { deleteObject, getDownloadURL, ref, uploadBytes } from 'firebase/storage';
import { storage } from '@/infrastructure/firebase/storage';

// Mirrors infrastructure/firebase/productImageStorage.ts's idiom (single
// overwritten file per parent doc). Storage rules for expenses/{id}/** are
// already live (mobile's expense_receipt_storage_service.dart feature).
const receiptPath = (expenseId: string) => `expenses/${expenseId}/receipt.jpg`;

/** Uploads (overwriting) an expense's receipt photo and returns its download URL. */
export async function uploadExpenseReceipt(expenseId: string, blob: Blob): Promise<string> {
  const r = ref(storage, receiptPath(expenseId));
  await uploadBytes(r, blob, { contentType: 'image/jpeg' });
  return getDownloadURL(r);
}

/** Deletes an expense's receipt photo; a no-op when it doesn't exist. */
export async function deleteExpenseReceipt(expenseId: string): Promise<void> {
  try {
    await deleteObject(ref(storage, receiptPath(expenseId)));
  } catch (e) {
    if ((e as { code?: string }).code === 'storage/object-not-found') return;
    throw e;
  }
}
