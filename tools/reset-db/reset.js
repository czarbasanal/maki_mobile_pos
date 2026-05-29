'use strict';

const readline = require('readline');
const admin = require('firebase-admin');
const { WIPE_COLLECTIONS, KEEP_COLLECTIONS, isConfirmed } = require('./lib/config');
const { resetDatabase } = require('./lib/reset');

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const skipPrompt = args.includes('--yes');
const usingEmulator = !!process.env.FIRESTORE_EMULATOR_HOST;

function fail(msg) {
  console.error(`\n✖ ${msg}\n`);
  process.exit(1);
}

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) =>
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer);
    }),
  );
}

async function main() {
  // Credentials / project resolution.
  let projectId;
  if (usingEmulator) {
    projectId = process.env.GCLOUD_PROJECT || 'demo-maki-pos';
    admin.initializeApp({ projectId });
  } else {
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      fail(
        'GOOGLE_APPLICATION_CREDENTIALS is not set.\n' +
          'Download a service-account key (Firebase console → Project settings →\n' +
          'Service accounts → Generate new private key) and:\n' +
          '  export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/key.json',
      );
    }
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
    projectId =
      admin.app().options.projectId ||
      process.env.GOOGLE_CLOUD_PROJECT ||
      process.env.GCLOUD_PROJECT;
    if (!projectId) {
      fail('Could not resolve the project id. Set GOOGLE_CLOUD_PROJECT=<id>.');
    }
  }

  const db = admin.firestore();

  console.log('\n================ Firestore reset ================');
  console.log(`Project : ${projectId}${usingEmulator ? '  (EMULATOR)' : ''}`);
  console.log(`Mode    : ${dryRun ? 'DRY RUN (no deletes)' : 'LIVE DELETE'}`);
  console.log(`WIPE    : ${WIPE_COLLECTIONS.join(', ')}`);
  console.log(`KEEP    : ${KEEP_COLLECTIONS.join(', ')}`);
  console.log('=================================================\n');

  if (dryRun) {
    const results = await resetDatabase(db, { dryRun: true, log: (m) => console.log(m) });
    const total = results.reduce((n, r) => n + (r.count || 0), 0);
    console.log(`\nDry run complete — ${total} docs would be deleted. Nothing changed.\n`);
    process.exit(0);
  }

  if (!skipPrompt) {
    const answer = await ask(
      `This PERMANENTLY deletes the WIPE collections in "${projectId}".\n` +
        `Type the project id to confirm: `,
    );
    if (!isConfirmed(answer, projectId)) {
      fail('Confirmation did not match. Aborted — nothing deleted.');
    }
  }

  console.log('\nDeleting ...');
  await resetDatabase(db, { dryRun: false, log: (m) => console.log(m) });
  console.log('\n✓ Reset complete.\n');
  process.exit(0);
}

main().catch((e) => fail(`Reset failed: ${e.message || e}`));
