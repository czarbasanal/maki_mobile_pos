# reset-db

Resets the MAKI Firestore database to a clean operational state.

> ⚠️ **This permanently deletes data and cannot be undone.** Run `reset:dry` first.

## What it does

**Wipes** (and their subcollections): `sales` (+`items`), `drafts`, `receivings`,
`expenses`, `daily_closings`, `void_requests`, `user_logs`, `products` (+`price_history`),
`suppliers`.

**Keeps** (never touched): `users`, `settings`, `product_categories`,
`expense_categories`, `units`, `void_reasons`.

## Setup

```bash
cd tools/reset-db
npm install
```

Get a service-account key: Firebase console → Project settings → Service accounts →
**Generate new private key**. Save it OUTSIDE the repo (or it's git-ignored here), then:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/key.json
# If the project id isn't picked up from the key:
export GOOGLE_CLOUD_PROJECT=maki-mobile-pos
```

## Usage

```bash
npm run reset:dry     # counts what WOULD be deleted; deletes nothing
npm run reset         # prompts: type the project id to confirm, then deletes
```

`--yes` skips the prompt (automation only — dangerous).

## Tests

```bash
npm run test:config   # pure unit tests (no emulator)
npm test              # runs all tests against the Firestore emulator
```

The emulator needs **Java 11+** (21+ recommended). If `java -version` reports 1.8, point
`JAVA_HOME` at a newer JDK, e.g.:

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 19)
```
