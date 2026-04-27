# Firestore rules tests

Automated coverage for `firestore.rules`. Runs against a local Firestore
emulator using `@firebase/rules-unit-testing` — the harness is JS rather than
Dart because that's the only setup that actually enforces the rules file.

## Run locally

Prerequisites:
- Node.js 20+ (needed by `firebase-tools`)
- **Java 11+** (needed by the Firebase emulator). On macOS, the easiest
  path is `brew install openjdk@17` — older Java 8 setups will fail with
  "Unsupported java version".

```bash
cd tools/firestore-rules-test
npm install
npm test
```

The test script wraps Mocha in `firebase emulators:exec --only firestore`,
which boots the emulator on port 8080, runs the suite, and tears the
emulator down. Tests fail if any rule allows what it shouldn't or denies
what it should.

## What's covered

Per-role allow/deny on every collection in `firestore.rules`:

- `/users` — self-read, admin all-read, role/isActive can't be self-elevated, admin-only create + delete
- `/products` — admin-only create + delete; staff price/cost/costCode lock; cashier quantity-only update path; price_history admin-only
- `/suppliers` — admin only
- `/sales` — all create/read; admin-only update (void); never-deletable audit trail
- `/drafts` — owner-or-admin update/delete; can't create-as-someone-else
- `/receivings` — staff+admin create/update/read; admin-only delete
- `/expenses` — anyone create; admin-only update + delete
- `/petty_cash` — admin only
- `/user_logs` — admin-only read; auth-only create; immutable (no update/delete)
- `/settings` — anyone read; admin-only write

Plus cross-cutting checks for unauthenticated requests and the `isActive`
gate (an inactive admin loses admin powers).

## Why this lives outside `flutter test`

`fake_cloud_firestore` and `cloud_firestore_mocks` simulate the Firestore
client API but ignore `firestore.rules` entirely — they're useful for
testing application code, not rules. The Firebase emulator is the only
implementation of the rules engine that ships outside production, and
`@firebase/rules-unit-testing` is its officially-maintained test harness.

## CI

Runs in `.github/workflows/ci.yml` as the `firestore-rules` job. Sets up
Node + Java, installs from `package.json`, then runs `npm test`. Failures
block merges to `main`.
