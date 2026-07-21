// Post-import invariant checks. Run against the emulator after the dress
// rehearsal and against prod after the real import.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
console.log(EMULATOR
  ? `TARGET: emulator (${EMULATOR})`
  : `TARGET: PRODUCTION (${PROJECT_ID})`);

let failures = 0;
function check(label, cond, detail = '') {
  if (cond) {
    console.log(`  PASS  ${label}`);
  } else {
    failures += 1;
    console.error(`  FAIL  ${label} ${detail}`);
  }
}

async function byName(name) {
  const snap = await db.collection('products').where('name', '==', name).get();
  return snap.docs;
}

console.log('--- counts ---');
const products = (await db.collection('products').count().get()).data().count;
const claims = (await db.collection('product_skus').count().get()).data().count;
console.log(`products=${products} claims=${claims}`);
check('claims == products', claims === products, `(${claims} vs ${products})`);

console.log('--- variation pair: BELT BANDO SKYDRIVE SPORT 115I ---');
const belts = await byName('BELT BANDO SKYDRIVE SPORT 115I');
check('two docs', belts.length === 2, `(${belts.length})`);
if (belts.length === 2) {
  const base = belts.find((d) => d.get('baseSku') == null);
  const variation = belts.find((d) => d.get('baseSku') != null);
  check('base + variation roles', Boolean(base && variation));
  if (base && variation) {
    check('variation.baseSku == base.sku', variation.get('baseSku') === base.get('sku'));
    check('variationNumber == 1', variation.get('variationNumber') === 1);
    const costs = new Set(belts.map((d) => d.get('cost')));
    check('costs are {550, 570}', costs.has(550) && costs.has(570));
  }
}

console.log('--- corrected cost: CARBURETOR SUNTAL CT150BOXER ---');
const [carb] = await byName('CARBURETOR SUNTAL CT150BOXER');
check('exists', Boolean(carb));
if (carb) {
  check('cost 680 / code ZLS', carb.get('cost') === 680 && carb.get('costCode') === 'ZLS');
}

console.log('--- merged batch: TOP GASKET AMCO W125 ---');
const gaskets = await byName('TOP GASKET AMCO W125');
check('single doc', gaskets.length === 1, `(${gaskets.length})`);
if (gaskets.length === 1) {
  check('qty 15 / price 150 / code QF',
    gaskets[0].get('quantity') === 15 && gaskets[0].get('price') === 150 && gaskets[0].get('costCode') === 'QF');
}

console.log('--- rename: HEADLIGHT RS100 BLK ---');
check('renamed doc exists', (await byName('HEADLIGHT RS100 BLK')).length === 1);
check('old name absent', (await byName('HEADLIGHT RS100')).length === 0);

console.log('--- supplier link: HORN PIAA SNAIL DUAL ---');
const [horn] = await byName('HORN PIAA SNAIL DUAL');
check('exists', Boolean(horn));
if (horn) {
  check('supplier HD linked', horn.get('supplierId') != null && horn.get('supplierName') === 'HD');
}

console.log('--- decimal qty: FUEL HOSE BLK ---');
const [hose] = await byName('FUEL HOSE BLK');
check('exists', Boolean(hose));
if (hose) {
  check('qty 27 + note + unit ruler',
    hose.get('quantity') === 27 && /27\.5/.test(hose.get('notes') ?? '') && hose.get('unit') === 'ruler');
}

console.log('--- merged double-listing: OIL FILTER BAJAJ/CT100 ---');
const filters = await byName('OIL FILTER BAJAJ/CT100');
check('single doc, qty 16, LUBE&FLUIDS',
  filters.length === 1 && filters[0].get('quantity') === 16 && filters[0].get('category') === 'LUBE&FLUIDS');

console.log('--- units vocabulary ---');
const unitNames = (await db.collection('units').get()).docs.map((d) => d.get('name'));
check('set + ruler unit docs exist', unitNames.includes('set') && unitNames.includes('ruler'));

console.log('--- searchKeywords sanity ---');
if (carb) {
  const kw = carb.get('searchKeywords') ?? [];
  check('keywords include name prefixes', kw.includes('carburetor') && kw.includes('c'));
  // Keywords cap at 10 chars per word, so only the first-10 prefix of the SKU
  // is guaranteed present — never the full SKU.
  check('keywords include sku prefix', kw.includes((carb.get('sku') ?? '').toLowerCase().slice(0, 10)));
}

console.log(failures === 0 ? '\nALL CHECKS PASSED' : `\n${failures} CHECK(S) FAILED`);
process.exit(failures === 0 ? 0 : 1);
