// Bootstrap rules used by the Firebase emulator at startup.
// The actual rules under test (../../firestore.rules) are loaded into the
// test environment by initializeTestEnvironment() in test/rules.test.js, so
// this file just needs to be a valid rules document. It is intentionally
// permissive — no production traffic ever sees it.
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
