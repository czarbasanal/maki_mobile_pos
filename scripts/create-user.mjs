// Creates an app user: Firebase Auth account + users/{uid} doc, mirroring the
// exact doc shape the mobile app writes (UserModel.toCreateMap).
//
// Run:
//   cd scripts && npm install
//   gcloud auth application-default login   # OR export GOOGLE_APPLICATION_CREDENTIALS=<sa.json>
//   node create-user.mjs <email> <password> "<display name>" <admin|staff|cashier>          # dry-run
//   node create-user.mjs <email> <password> "<display name>" <admin|staff|cashier> --apply  # create
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';
const CREATED_BY = 'setup-script';

const [email, password, displayName, role, applyFlag] = process.argv.slice(2);
const ROLES = ['admin', 'staff', 'cashier'];
if (!email || !password || !displayName || !ROLES.includes(role)) {
  console.error('Usage: node create-user.mjs <email> <password> "<display name>" <admin|staff|cashier> [--apply]');
  process.exit(1);
}
const apply = applyFlag === '--apply';

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const auth = getAuth();
const db = getFirestore();

async function main() {
  let existing = null;
  try {
    existing = await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
  }
  if (existing) {
    const doc = await db.collection('users').doc(existing.uid).get();
    console.error(`ABORT: auth account already exists for ${email} (uid ${existing.uid}); users doc ${doc.exists ? 'EXISTS' : 'missing'}.`);
    process.exit(1);
  }

  const dupDoc = await db.collection('users').where('email', '==', email).get();
  if (!dupDoc.empty) {
    console.error(`ABORT: a users doc already carries ${email} (${dupDoc.docs.map((d) => d.id).join(', ')}).`);
    process.exit(1);
  }

  console.log(`OK to create: ${email} / "${displayName}" / role=${role} / isActive=true`);
  if (!apply) {
    console.log('Dry run only — re-run with --apply to create.');
    return;
  }

  const rec = await auth.createUser({ email, password, displayName });
  await db.collection('users').doc(rec.uid).set({
    email,
    displayName,
    role,
    isActive: true,
    phoneNumber: null,
    photoUrl: null,
    createdBy: CREATED_BY,
    updatedBy: CREATED_BY,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log(`Created ${role} ${email} (uid ${rec.uid}) + users doc.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
