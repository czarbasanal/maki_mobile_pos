import {
  browserLocalPersistence,
  connectAuthEmulator,
  getAuth,
  setPersistence,
  type Auth,
} from 'firebase/auth';
import { firebaseApp } from './firebaseApp';

// Mirrors lib/services/firebase_service.dart: web uses LOCAL persistence so
// the auth session survives reloads and is shared with the Flutter web build.
const auth: Auth = getAuth(firebaseApp);

const useEmulator = import.meta.env.VITE_USE_FIREBASE_EMULATOR === 'true';
const emulatorHost = import.meta.env.VITE_FIREBASE_EMULATOR_HOST ?? 'localhost';

let initPromise: Promise<void> | null = null;

export function ensureAuthReady(): Promise<void> {
  if (!initPromise) {
    initPromise = (async () => {
      if (useEmulator) {
        connectAuthEmulator(auth, `http://${emulatorHost}:9099`, {
          disableWarnings: true,
        });
      }
      await setPersistence(auth, browserLocalPersistence);
      await auth.authStateReady();
    })();
  }
  return initPromise;
}

export { auth };
