import { initializeApp, type FirebaseApp } from 'firebase/app';

const config = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

for (const [key, value] of Object.entries(config)) {
  if (!value) {
    throw new Error(`Missing Firebase env var for ${key}. See web_admin/.env.example.`);
  }
}

export const firebaseApp: FirebaseApp = initializeApp(config);
