// Deletes a Firebase AUTH credential for a user whose Firestore doc has
// already been deleted in-app. Client SDKs cannot remove another user's Auth
// account, so in-app "Delete user" removes only users/{uid}; this script
// closes the gap. It ABORTS if users/{uid} still exists — deactivate and
// delete the user in the app first.
//
// Run:
//   cd scripts && npm install
//   gcloud auth application-default login        # OR export GOOGLE_APPLICATION_CREDENTIALS=<sa.json>
//   node delete-auth-user.mjs <email-or-uid>           # dry-run: prints what it found
//   node delete-auth-user.mjs <email-or-uid> --apply   # actually deletes the credential
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';

const [target, applyFlag] = process.argv.slice(2);
if (!target) {
  console.error('Usage: node delete-auth-user.mjs <email-or-uid> [--apply]');
  process.exit(1);
}
const apply = applyFlag === '--apply';

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const auth = getAuth();
const db = getFirestore();

function lookup(target) {
  return target.includes('@') ? auth.getUserByEmail(target) : auth.getUser(target);
}

async function main() {
  let user;
  try {
    user = await lookup(target);
  } catch (e) {
    console.error(`No auth account found for "${target}": ${e.message}`);
    process.exit(1);
  }

  console.log('Found auth account:');
  console.log(`  uid:       ${user.uid}`);
  console.log(`  email:     ${user.email ?? '(none)'}`);
  console.log(`  created:   ${user.metadata.creationTime}`);
  console.log(`  lastLogin: ${user.metadata.lastSignInTime ?? '(never)'}`);

  const docSnap = await db.collection('users').doc(user.uid).get();
  if (docSnap.exists) {
    console.error(
      `\nABORT: users/${user.uid} still exists ` +
        `(displayName: "${docSnap.get('displayName')}", isActive: ${docSnap.get('isActive')}).\n` +
        'Delete the user in the app first (deactivate, then delete), then re-run.'
    );
    process.exit(1);
  }
  console.log(`\nusers/${user.uid} does not exist — safe to delete the auth credential.`);

  if (!apply) {
    console.log('\nDry run only — re-run with --apply to delete the auth credential.');
    return;
  }

  await auth.deleteUser(user.uid);
  console.log(`\nDeleted auth credential for ${user.email ?? user.uid}.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
