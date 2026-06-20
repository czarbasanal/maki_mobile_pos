import { deleteObject, getDownloadURL, ref, uploadBytes } from 'firebase/storage';
import { storage } from './storage';

const imagePath = (productId: string) => `products/${productId}/main.jpg`;

/** Uploads (overwriting) a product's single image and returns its download URL. */
export async function uploadProductImage(productId: string, blob: Blob): Promise<string> {
  const r = ref(storage, imagePath(productId));
  await uploadBytes(r, blob, { contentType: 'image/jpeg' });
  return getDownloadURL(r);
}

/** Deletes a product's image; a no-op when it doesn't exist. */
export async function deleteProductImage(productId: string): Promise<void> {
  try {
    await deleteObject(ref(storage, imagePath(productId)));
  } catch (e) {
    if ((e as { code?: string }).code === 'storage/object-not-found') return;
    throw e;
  }
}
