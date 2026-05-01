import { connectStorageEmulator, getStorage, type FirebaseStorage } from 'firebase/storage';
import { firebaseApp } from './firebaseApp';

const useEmulator = import.meta.env.VITE_USE_FIREBASE_EMULATOR === 'true';
const emulatorHost = import.meta.env.VITE_FIREBASE_EMULATOR_HOST ?? 'localhost';

export const storage: FirebaseStorage = getStorage(firebaseApp);

if (useEmulator) {
  connectStorageEmulator(storage, emulatorHost, 9199);
}
