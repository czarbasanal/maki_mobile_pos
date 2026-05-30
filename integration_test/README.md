# Integration / e2e tests

End-to-end tests that drive real screens via the official
[`integration_test`](https://docs.flutter.dev/testing/integration-tests)
harness. They live here (not under `test/`) so the default `flutter test` unit
run does **not** pick them up.

## Running

Integration tests require a **mobile device or emulator** — web is rejected
("Web devices are not supported for integration tests yet") and the desktop
platforms have been dropped from this project.

```bash
# Android emulator or attached device:
flutter test integration_test/                       # all e2e tests
flutter test integration_test/sku_edit_flow_test.dart  # one file
flutter test integration_test/ -d <device-id>        # pick a device
```

## What's here

- **`sku_edit_flow_test.dart`** — drives the admin SKU-edit happy path on the
  real `ProductFormScreen`: load product → edit SKU → confirm dialog → save,
  asserting the product is written with the new SKU and the old SKU kept as a
  scan alias.

  It overrides the backend providers (`productRepository`,
  `activityLogRepository`, `currentUser`, `costCodeMapping`) with in-memory
  fakes, so the flow is deterministic and needs **no Firebase and no network**.
  Overriding backend providers is the recommended way to keep integration tests
  fast and reliable while still exercising the real widget tree, navigation,
  and gestures on a device.

## Growing this into full-app e2e

`sku_edit_flow_test.dart` mounts a single screen inside a minimal `GoRouter`.
To drive the **whole app** from the login screen (real navigation across
features), the next steps are:

1. **Firebase emulator wiring.** The app boots through
   `FirebaseService.instance.initialize()` (see `lib/main.dart`). Add an
   emulator path — e.g. gated by `--dart-define=USE_FIREBASE_EMULATOR=true` —
   that calls `FirebaseFirestore.instance.useFirestoreEmulator(...)` and
   `FirebaseAuth.instance.useAuthEmulator(...)` before the app runs.
2. **Seed + auth.** Start the Firestore/Auth emulators, seed an admin user and
   a product, and sign in through the real login screen (or seed an auth token).
3. **Drive the app entrypoint.** Pump `MAKIPOSMobileApp` (the real root) instead
   of a single screen, then navigate Inventory → product → edit → save.
4. **CI.** Run under `flutter test integration_test/` on an Android emulator
   (e.g. via `reactivecircus/android-emulator-runner` on GitHub Actions),
   booting the Firebase emulators alongside (the
   `tools/firestore-rules-test/` setup already shows the emulator pattern).
