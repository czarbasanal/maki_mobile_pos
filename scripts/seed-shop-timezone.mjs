// Seeds the shop timezone into settings/general — the doc the mobile app, the
// web admin and the Firestore rules all read to decide what "today" is.
//
// Idempotent: it MERGES the two timezone keys, so re-running is safe and any
// other keys in the shared general doc are left alone. With the doc absent,
// every surface already falls back to Asia/Manila +480, so seeding the default
// changes no behaviour — it just makes the value explicit and editable.
//
// Dry run:  node seed-shop-timezone.mjs                 (prints, writes nothing)
// Execute:  node seed-shop-timezone.mjs --execute
// Custom:   node seed-shop-timezone.mjs --timezone=Asia/Tokyo --offset=540 --execute
// Emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node seed-shop-timezone.mjs --execute
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { buildSeedPayload, DEFAULT_SEED } from './seed-shop-timezone-lib.mjs';

const PROJECT_ID = 'maki-mobile-pos';

const execute = process.argv.includes('--execute');
const argValue = (name) => {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : undefined;
};

const timezoneId = argValue('timezone') ?? DEFAULT_SEED.timezoneId;
const rawOffset = argValue('offset');
const offsetMinutes =
  rawOffset === undefined ? DEFAULT_SEED.tzOffsetMinutes : Number(rawOffset);

let payload;
try {
  payload = buildSeedPayload({ timezoneId, offsetMinutes });
} catch (e) {
  console.error(`invalid arguments: ${e.message}`);
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR
  ? `TARGET: emulator (${EMULATOR})`
  : `TARGET: PRODUCTION (${PROJECT_ID})`);

const ref = db.collection('settings').doc('general');

try {
  const before = await ref.get();
  console.log('\n--- settings/general before ---');
  console.log(before.exists ? JSON.stringify(before.data(), null, 2) : '(document does not exist)');

  console.log('\n--- would merge ---');
  console.log(JSON.stringify(payload, null, 2));

  if (!execute) {
    console.log('\nDRY RUN — nothing written. Re-run with --execute to apply.');
    process.exit(0);
  }

  await ref.set(payload, { merge: true });

  const after = await ref.get();
  console.log('\n--- settings/general after ---');
  console.log(JSON.stringify(after.data(), null, 2));
  console.log('\nSeed complete.');
} catch (e) {
  console.error(`\nSeed failed: ${e.message}`);
  process.exit(1);
}
