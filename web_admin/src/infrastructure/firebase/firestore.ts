import {
  connectFirestoreEmulator,
  getFirestore,
  initializeFirestore,
  persistentLocalCache,
  persistentMultipleTabManager,
  type Firestore,
} from 'firebase/firestore';
import { firebaseApp } from './firebaseApp';

// Mirror lib/services/firebase_service.dart: persistence enabled, multi-tab.
// `initializeFirestore` must run before any `getFirestore` call, so this
// module is the single entry point for Firestore configuration.
const useEmulator = import.meta.env.VITE_USE_FIREBASE_EMULATOR === 'true';
const emulatorHost = import.meta.env.VITE_FIREBASE_EMULATOR_HOST ?? 'localhost';

let db: Firestore;

try {
  db = initializeFirestore(firebaseApp, {
    localCache: persistentLocalCache({
      tabManager: persistentMultipleTabManager(),
    }),
  });
} catch {
  db = getFirestore(firebaseApp);
}

if (useEmulator) {
  connectFirestoreEmulator(db, emulatorHost, 8080);
}

export { db };
