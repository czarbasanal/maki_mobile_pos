/**
 * Firestore security-rules tests for the MAKI POS app.
 *
 * Run with `npm test` from this directory. The script wraps the suite in
 * `firebase emulators:exec`, which boots a local Firestore emulator on port
 * 8080, runs Mocha, and tears the emulator down. The rules file under test is
 * `../../firestore.rules` (referenced via firebase.json).
 *
 * Coverage focus: every per-role allow/deny that the rules file makes a claim
 * about. Negative cases are at least as important as positive ones — they're
 * the ones a hostile client would try.
 */

const fs = require("fs");
const path = require("path");
const assert = require("assert");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

const PROJECT_ID = "demo-maki-pos";

// Test users — one per role plus an inactive admin to verify the isActive gate.
const USERS = {
  admin: { uid: "admin-1", role: "admin", isActive: true },
  staff: { uid: "staff-1", role: "staff", isActive: true },
  cashier: { uid: "cashier-1", role: "cashier", isActive: true },
  inactiveAdmin: { uid: "inactive-admin-1", role: "admin", isActive: false },
  inactiveStaff: { uid: "inactive-staff-1", role: "staff", isActive: false },
};

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "../../../firestore.rules"),
        "utf8"
      ),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();

  // Seed user docs (rules call get(/users/{uid}) — every role check needs a
  // matching user doc to resolve). Done with rules disabled because the rules
  // themselves restrict who can write /users.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const u of Object.values(USERS)) {
      await db.collection("users").doc(u.uid).set({
        email: `${u.uid}@test.local`,
        displayName: `${u.role} user`,
        role: u.role,
        isActive: u.isActive,
        createdAt: new Date(),
      });
    }
  });
});

// Convenience: scoped Firestore client for a given role.
const as = (key) => testEnv.authenticatedContext(USERS[key].uid).firestore();
const unauth = () => testEnv.unauthenticatedContext().firestore();

const newDocId = (prefix) =>
  `${prefix}-${Math.random().toString(36).slice(2, 10)}`;

// PH business day (UTC+8, no DST) as a yyyymmdd int — mirrors the rules'
// phDay() so tests can seed/assert against "today" without a fixed clock.
const phDay = (d = new Date()) => {
  const t = new Date(d.getTime() + 8 * 3600 * 1000);
  return t.getUTCFullYear() * 10000 + (t.getUTCMonth() + 1) * 100 + t.getUTCDate();
};

// ===================================================================
// /users
// ===================================================================
describe("/users", () => {
  it("user reads their own doc", async () => {
    await assertSucceeds(as("cashier").collection("users").doc(USERS.cashier.uid).get());
  });

  it("cashier cannot read another user's doc", async () => {
    await assertFails(as("cashier").collection("users").doc(USERS.staff.uid).get());
  });

  it("admin can read any user doc", async () => {
    await assertSucceeds(as("admin").collection("users").doc(USERS.cashier.uid).get());
  });

  it("unauth cannot read users", async () => {
    await assertFails(unauth().collection("users").doc(USERS.admin.uid).get());
  });

  it("admin can create a user", async () => {
    await assertSucceeds(as("admin").collection("users").doc("new-user").set({
      role: "cashier", isActive: true, email: "new@test", displayName: "New",
    }));
  });

  it("cashier cannot create a user", async () => {
    await assertFails(as("cashier").collection("users").doc("new-user").set({
      role: "cashier", isActive: true, email: "x@test", displayName: "X",
    }));
  });

  it("staff cannot create a user", async () => {
    await assertFails(as("staff").collection("users").doc("new-user").set({
      role: "cashier", isActive: true, email: "x@test", displayName: "X",
    }));
  });

  it("user can update their own non-role fields", async () => {
    await assertSucceeds(
      as("cashier").collection("users").doc(USERS.cashier.uid).update({
        displayName: "New Name",
      })
    );
  });

  it("user CANNOT change their own role", async () => {
    await assertFails(
      as("cashier").collection("users").doc(USERS.cashier.uid).update({
        role: "admin",
      })
    );
  });

  it("user CANNOT change their own isActive", async () => {
    await assertFails(
      as("cashier").collection("users").doc(USERS.cashier.uid).update({
        isActive: false,
      })
    );
  });

  it("admin can change any user's role", async () => {
    await assertSucceeds(
      as("admin").collection("users").doc(USERS.cashier.uid).update({
        role: "staff",
      })
    );
  });

  it("admin cannot delete an ACTIVE user (deactivate-first)", async () => {
    await assertFails(
      as("admin").collection("users").doc(USERS.cashier.uid).delete()
    );
  });

  it("admin cannot delete themselves", async () => {
    await assertFails(
      as("admin").collection("users").doc(USERS.admin.uid).delete()
    );
  });

  it("admin can delete an inactive other user", async () => {
    await assertSucceeds(
      as("admin").collection("users").doc(USERS.inactiveStaff.uid).delete()
    );
  });

  it("staff and cashier cannot delete users, even inactive ones", async () => {
    await assertFails(
      as("staff").collection("users").doc(USERS.inactiveStaff.uid).delete()
    );
    await assertFails(
      as("cashier").collection("users").doc(USERS.inactiveStaff.uid).delete()
    );
  });

  it("inactive admin cannot delete an inactive other user", async () => {
    // Isolates the isActiveUser() conjunct on the actor: the target is
    // already deactivated (satisfies deactivate-first) and the actor role
    // is admin (satisfies the role check), so this can only fail because
    // the acting admin's own isActive is false.
    await assertFails(
      as("inactiveAdmin").collection("users").doc(USERS.inactiveStaff.uid).delete()
    );
  });
});

// ===================================================================
// /products
// ===================================================================
describe("/products", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("products").doc("p-1").set({
        sku: "SKU-001", name: "Coke", price: 25, cost: 12, costCode: "ABF",
        quantity: 100, isActive: true,
      });
    });
  });

  it("any active role can read products", async () => {
    await assertSucceeds(as("cashier").collection("products").doc("p-1").get());
    await assertSucceeds(as("staff").collection("products").doc("p-1").get());
    await assertSucceeds(as("admin").collection("products").doc("p-1").get());
  });

  it("admin and staff can create products; cashier cannot", async () => {
    // Staff create products via cost-code entry (decoded app-side), so the
    // rules allow staff create. Cashier still cannot.
    await assertFails(
      as("cashier").collection("products").doc("p-2").set({ sku: "X", price: 1, cost: 0.5, costCode: "A", quantity: 0, isActive: true })
    );
    await assertSucceeds(
      as("staff").collection("products").doc("p-3").set({ sku: "Y", price: 1, cost: 125, costCode: "NBF", quantity: 0, isActive: true })
    );
    await assertSucceeds(
      as("admin").collection("products").doc("p-4").set({ sku: "Z", price: 1, cost: 0.5, costCode: "A", quantity: 0, isActive: true })
    );
  });

  it("inactive staff cannot create products", async () => {
    await assertFails(
      as("inactiveStaff").collection("products").doc("p-5").set({ sku: "W", price: 1, cost: 1, costCode: "N", quantity: 0, isActive: true })
    );
  });

  it("only admin can delete products", async () => {
    await assertFails(as("staff").collection("products").doc("p-1").delete());
    await assertFails(as("cashier").collection("products").doc("p-1").delete());
    await assertSucceeds(as("admin").collection("products").doc("p-1").delete());
  });

  it("admin can update price + cost + costCode", async () => {
    await assertSucceeds(
      as("admin").collection("products").doc("p-1").update({
        price: 30, cost: 14, costCode: "ABG",
      })
    );
  });

  it("staff CANNOT change price", async () => {
    await assertFails(
      as("staff").collection("products").doc("p-1").update({ price: 30 })
    );
  });

  it("staff CANNOT change cost", async () => {
    await assertFails(
      as("staff").collection("products").doc("p-1").update({ cost: 5 })
    );
  });

  it("staff CANNOT change costCode", async () => {
    await assertFails(
      as("staff").collection("products").doc("p-1").update({ costCode: "ZZZ" })
    );
  });

  it("staff CANNOT change sku", async () => {
    await assertFails(
      as("staff").collection("products").doc("p-1").update({ sku: "NEW-SKU" })
    );
  });

  it("admin CAN change sku", async () => {
    await assertSucceeds(
      as("admin").collection("products").doc("p-1").update({ sku: "NEW-SKU" })
    );
  });

  it("staff CAN update name + reorder level + supplier", async () => {
    await assertSucceeds(
      as("staff").collection("products").doc("p-1").update({
        name: "Coke 1L",
        reorderLevel: 5,
      })
    );
  });

  it("cashier can decrement quantity (sale path)", async () => {
    // Rules allow any active user to update quantity (and updatedAt/By only).
    await assertSucceeds(
      as("cashier").collection("products").doc("p-1").update({
        quantity: 99,
        updatedAt: new Date(),
        updatedBy: USERS.cashier.uid,
      })
    );
  });

  it("cashier can decrement quantity with updatedByName (real checkout sale path)", async () => {
    // ProcessSaleUseCase passes the cashier's display name, so updateStock
    // writes updatedByName alongside quantity. The stock-update rule must
    // tolerate it — otherwise cashier sales complete but never deduct stock.
    await assertSucceeds(
      as("cashier").collection("products").doc("p-1").update({
        quantity: 99,
        updatedAt: new Date(),
        updatedBy: USERS.cashier.uid,
        updatedByName: "cashier user",
      })
    );
  });

  it("cashier CAN update name + imageUrl (minimal write)", async () => {
    await assertSucceeds(
      as("cashier").collection("products").doc("p-1").update({
        name: "Coke 500ml",
        imageUrl: "https://storage.googleapis.com/x/y.jpg",
        searchKeywords: ["coke", "500ml"],
        updatedAt: new Date(),
        updatedBy: USERS.cashier.uid,
        updatedByName: "cashier user",
      })
    );
  });

  it("cashier CAN update name + imageUrl via full toUpdateMap-style write (regression: rules must tolerate nullable fields written as null when missing from existing doc)", async () => {
    // Mirrors what ProductModel.toMap(forUpdate: true) actually sends —
    // every product field on the document, with unchanged values for the
    // preserved ones and explicit nulls for nullable fields that may not
    // exist on the original doc. This matches the real cashier image flow.
    await assertSucceeds(
      as("cashier").collection("products").doc("p-1").update({
        // Preserved fields (same values as seed doc):
        sku: "SKU-001",
        costCode: "ABF",
        cost: 12,
        price: 25,
        quantity: 100,
        reorderLevel: 0,
        unit: "pcs",
        supplierId: null,
        supplierName: null,
        isActive: true,
        baseSku: null,
        variationNumber: null,
        barcodes: [],
        category: null,
        notes: null,
        // Changed fields:
        name: "Coke 500ml",
        imageUrl: "https://storage.googleapis.com/x/y.jpg",
        searchKeywords: ["coke", "500ml"],
        updatedAt: new Date(),
        updatedBy: USERS.cashier.uid,
        updatedByName: "cashier user",
      })
    );
  });

  it("cashier CANNOT change price even if name is also in the update", async () => {
    await assertFails(
      as("cashier").collection("products").doc("p-1").update({
        name: "Coke 500ml",
        price: 1,
      })
    );
  });

  it("cashier CANNOT change price via the quantity-update path", async () => {
    // affectedKeys must be a subset of {quantity, updatedAt, updatedBy}; price
    // breaks that.
    await assertFails(
      as("cashier").collection("products").doc("p-1").update({
        quantity: 50,
        price: 1,
      })
    );
  });

  it("only admin can read price_history", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection("products")
        .doc("p-1")
        .collection("price_history")
        .doc("h-1")
        .set({ price: 25, changedAt: new Date() });
    });
    await assertFails(
      as("staff").collection("products").doc("p-1").collection("price_history").doc("h-1").get()
    );
    await assertSucceeds(
      as("admin").collection("products").doc("p-1").collection("price_history").doc("h-1").get()
    );
  });

  it("inactive admin cannot read products (isActive gate)", async () => {
    await assertFails(as("inactiveAdmin").collection("products").doc("p-1").get());
  });
});

// ===================================================================
// /suppliers
// ===================================================================
describe("/suppliers", () => {
  // Staff can READ suppliers — the Receiving flow's supplier picker streams
  // the list for staff (2026-07-24 fix: read was admin-only since init, which
  // broke "Failed to load suppliers" on the staff bulk-receiving screen).
  it("staff and admin can read; cashier cannot", async () => {
    await assertSucceeds(as("staff").collection("suppliers").doc("s-1").get());
    await assertFails(as("cashier").collection("suppliers").doc("s-1").get());
    await assertSucceeds(as("admin").collection("suppliers").doc("s-1").get());
  });

  it("only admin can write", async () => {
    await assertFails(
      as("staff").collection("suppliers").doc("s-1").set({ name: "ACME" })
    );
    await assertFails(
      as("cashier").collection("suppliers").doc("s-1").set({ name: "ACME" })
    );
    await assertSucceeds(
      as("admin").collection("suppliers").doc("s-1").set({ name: "ACME" })
    );
  });
});

// ===================================================================
// /sales
// ===================================================================
describe("/sales", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("sales").doc("sale-1").set({
        saleNumber: "SALE-001",
        cashierId: USERS.cashier.uid,
        status: "completed",
        grandTotal: 100,
        createdAt: new Date(),
      });
    });
  });

  it("every active role can read sales (app-side daily-only restriction)", async () => {
    await assertSucceeds(as("cashier").collection("sales").doc("sale-1").get());
    await assertSucceeds(as("staff").collection("sales").doc("sale-1").get());
    await assertSucceeds(as("admin").collection("sales").doc("sale-1").get());
  });

  it("every active role can create a sale", async () => {
    await assertSucceeds(
      as("cashier").collection("sales").doc("sale-2").set({
        saleNumber: "SALE-002",
        cashierId: USERS.cashier.uid,
        status: "completed",
        grandTotal: 50,
      })
    );
  });

  it("cashier CANNOT void (update) a sale", async () => {
    await assertFails(
      as("cashier").collection("sales").doc("sale-1").update({
        status: "voided",
        voidedAt: new Date(),
      })
    );
  });

  it("staff CANNOT void (update) a sale", async () => {
    await assertFails(
      as("staff").collection("sales").doc("sale-1").update({ status: "voided" })
    );
  });

  it("admin can void (update) a sale", async () => {
    await assertSucceeds(
      as("admin").collection("sales").doc("sale-1").update({ status: "voided" })
    );
  });

  it("nobody can delete a sale (audit trail)", async () => {
    await assertFails(as("admin").collection("sales").doc("sale-1").delete());
    await assertFails(as("staff").collection("sales").doc("sale-1").delete());
    await assertFails(as("cashier").collection("sales").doc("sale-1").delete());
  });
});

// ===================================================================
// /drafts
// ===================================================================
describe("/drafts", () => {
  it("user can create a draft owned by themselves", async () => {
    await assertSucceeds(
      as("cashier").collection("drafts").doc(newDocId("d")).set({
        createdBy: USERS.cashier.uid,
        items: [],
      })
    );
  });

  it("user CANNOT create a draft owned by someone else", async () => {
    await assertFails(
      as("cashier").collection("drafts").doc(newDocId("d")).set({
        createdBy: USERS.staff.uid,
        items: [],
      })
    );
  });

  it("user can update/delete their own draft", async () => {
    const id = newDocId("d");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("drafts").doc(id).set({
        createdBy: USERS.cashier.uid, items: [],
      });
    });
    await assertSucceeds(as("cashier").collection("drafts").doc(id).update({ items: [{}] }));
    await assertSucceeds(as("cashier").collection("drafts").doc(id).delete());
  });

  it("user CANNOT update/delete another user's draft", async () => {
    const id = newDocId("d");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("drafts").doc(id).set({
        createdBy: USERS.staff.uid, items: [],
      });
    });
    await assertFails(as("cashier").collection("drafts").doc(id).update({ items: [{}] }));
    await assertFails(as("cashier").collection("drafts").doc(id).delete());
  });

  it("admin CAN update/delete any draft", async () => {
    const id = newDocId("d");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("drafts").doc(id).set({
        createdBy: USERS.cashier.uid, items: [],
      });
    });
    await assertSucceeds(as("admin").collection("drafts").doc(id).update({ items: [{}] }));
    await assertSucceeds(as("admin").collection("drafts").doc(id).delete());
  });
});

// ===================================================================
// /receivings
// ===================================================================
describe("/receivings", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("receivings").doc("r-1").set({
        referenceNumber: "RCV-001",
        status: "pending",
        items: [],
        totalCost: 100,
      });
    });
  });

  it("cashier CANNOT read receivings", async () => {
    await assertFails(as("cashier").collection("receivings").doc("r-1").get());
  });

  it("staff and admin can read", async () => {
    await assertSucceeds(as("staff").collection("receivings").doc("r-1").get());
    await assertSucceeds(as("admin").collection("receivings").doc("r-1").get());
  });

  it("cashier CANNOT create receivings", async () => {
    await assertFails(
      as("cashier").collection("receivings").doc(newDocId("r")).set({
        referenceNumber: "X", items: [], totalCost: 0,
      })
    );
  });

  it("staff and admin can create + update", async () => {
    await assertSucceeds(
      as("staff").collection("receivings").doc(newDocId("r")).set({
        referenceNumber: "X", items: [], totalCost: 0,
      })
    );
    await assertSucceeds(
      as("staff").collection("receivings").doc("r-1").update({ status: "completed" })
    );
  });

  it("only admin can delete receivings", async () => {
    await assertFails(as("staff").collection("receivings").doc("r-1").delete());
    await assertSucceeds(as("admin").collection("receivings").doc("r-1").delete());
  });
});

// ===================================================================
// /expenses
// ===================================================================
describe("/expenses", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("expenses").doc("e-1").set({
        description: "Coffee", amount: 50, category: "Office",
        createdBy: USERS.cashier.uid,
      });
    });
  });

  it("every active role can read expenses", async () => {
    await assertSucceeds(as("cashier").collection("expenses").doc("e-1").get());
    await assertSucceeds(as("staff").collection("expenses").doc("e-1").get());
    await assertSucceeds(as("admin").collection("expenses").doc("e-1").get());
  });

  it("every active role can create expenses", async () => {
    await assertSucceeds(
      as("cashier").collection("expenses").doc(newDocId("e")).set({
        description: "Bread", amount: 30, category: "Food",
        createdBy: USERS.cashier.uid,
      })
    );
  });

  // Shop policy 2026-07-04 (rules 45c19d9): cashier/staff fix and remove
  // their own entry mistakes; the activity log keeps the audit trail.
  it("cashier can update an expense", async () => {
    await assertSucceeds(
      as("cashier").collection("expenses").doc("e-1").update({ amount: 99 })
    );
  });

  it("staff can update an expense", async () => {
    await assertSucceeds(
      as("staff").collection("expenses").doc("e-1").update({ amount: 99 })
    );
  });

  it("admin can update + delete expenses", async () => {
    await assertSucceeds(
      as("admin").collection("expenses").doc("e-1").update({ amount: 99 })
    );
    await assertSucceeds(as("admin").collection("expenses").doc("e-1").delete());
  });

  it("cashier can delete an expense", async () => {
    await assertSucceeds(
      as("cashier").collection("expenses").doc("e-1").delete()
    );
  });
});

// ===================================================================
// /user_logs (activity log)
// ===================================================================
describe("/user_logs", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("user_logs").doc("log-1").set({
        action: "Login", userId: USERS.cashier.uid, createdAt: new Date(),
      });
    });
  });

  it("only admin can read logs", async () => {
    await assertFails(as("cashier").collection("user_logs").doc("log-1").get());
    await assertFails(as("staff").collection("user_logs").doc("log-1").get());
    await assertSucceeds(as("admin").collection("user_logs").doc("log-1").get());
  });

  it("any authenticated user can create logs (system-side writes)", async () => {
    await assertSucceeds(
      as("cashier").collection("user_logs").doc(newDocId("log")).set({
        action: "Sale", userId: USERS.cashier.uid,
      })
    );
    await assertSucceeds(
      as("staff").collection("user_logs").doc(newDocId("log")).set({
        action: "Receive", userId: USERS.staff.uid,
      })
    );
  });

  it("nobody can update or delete logs (immutable audit trail)", async () => {
    await assertFails(
      as("admin").collection("user_logs").doc("log-1").update({ action: "Tampered" })
    );
    await assertFails(as("admin").collection("user_logs").doc("log-1").delete());
    await assertFails(
      as("cashier").collection("user_logs").doc("log-1").update({ action: "Tampered" })
    );
    await assertFails(as("cashier").collection("user_logs").doc("log-1").delete());
  });

  it("unauth cannot create logs", async () => {
    await assertFails(
      unauth().collection("user_logs").doc(newDocId("log")).set({
        action: "Hax",
      })
    );
  });
});

// ===================================================================
// /settings
// ===================================================================
describe("/settings", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("settings").doc("cost_codes").set({
        mapping: { 0: "A" },
      });
    });
  });

  it("every active role can read settings", async () => {
    await assertSucceeds(as("cashier").collection("settings").doc("cost_codes").get());
    await assertSucceeds(as("staff").collection("settings").doc("cost_codes").get());
    await assertSucceeds(as("admin").collection("settings").doc("cost_codes").get());
  });

  it("only admin can write settings", async () => {
    await assertFails(
      as("staff").collection("settings").doc("cost_codes").update({ mapping: { 0: "Z" } })
    );
    await assertFails(
      as("cashier").collection("settings").doc("cost_codes").update({ mapping: { 0: "Z" } })
    );
    await assertSucceeds(
      as("admin").collection("settings").doc("cost_codes").update({ mapping: { 0: "Z" } })
    );
  });

  // sale_counters is the one settings doc that non-admins must write:
  // generating a sale number at checkout increments a date-keyed sequence
  // inside the createSale transaction. Without this carve-out, cashier and
  // staff checkouts fail with permission-denied.
  it("every active role can write the sale_counters doc", async () => {
    const dateKey = "2026-05-28";
    await assertSucceeds(
      as("cashier").collection("settings").doc("sale_counters").set({ [dateKey]: 1 }, { merge: true })
    );
    await assertSucceeds(
      as("staff").collection("settings").doc("sale_counters").set({ [dateKey]: 2 }, { merge: true })
    );
    await assertSucceeds(
      as("admin").collection("settings").doc("sale_counters").set({ [dateKey]: 3 }, { merge: true })
    );
  });
});

// ===================================================================
// /void_requests
// ===================================================================
describe("/void_requests", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("void_requests").doc("vr-1").set({
        saleId: "s-1", saleNumber: "SALE-0042", saleGrandTotal: 100,
        requestedBy: USERS.cashier.uid, requestedByName: "cashier user",
        requestedByRole: "cashier", reason: "wrong item", status: "pending",
        read: false, createdAt: new Date(),
      });
    });
  });

  const newReq = (uid) => ({
    saleId: "s-9", saleNumber: "SALE-0099", saleGrandTotal: 50,
    requestedBy: uid, requestedByName: "x", requestedByRole: "cashier",
    reason: "test reason", status: "pending", read: false, createdAt: new Date(),
  });

  it("cashier/staff can create their own pending request", async () => {
    await assertSucceeds(
      as("cashier").collection("void_requests").doc("c-1").set(newReq(USERS.cashier.uid)));
    await assertSucceeds(
      as("staff").collection("void_requests").doc("s-1b").set(newReq(USERS.staff.uid)));
  });

  it("cannot create a request as someone else", async () => {
    await assertFails(
      as("cashier").collection("void_requests").doc("c-2").set(newReq(USERS.staff.uid)));
  });

  it("cannot create a non-pending request", async () => {
    const r = newReq(USERS.cashier.uid);
    r.status = "approved";
    await assertFails(
      as("cashier").collection("void_requests").doc("c-3").set(r));
  });

  it("inactive user cannot create", async () => {
    await assertFails(
      as("inactiveStaff").collection("void_requests").doc("c-4").set(newReq(USERS.inactiveStaff.uid)));
  });

  it("active valid users can read", async () => {
    await assertSucceeds(as("cashier").collection("void_requests").doc("vr-1").get());
    await assertSucceeds(as("admin").collection("void_requests").doc("vr-1").get());
  });

  it("only admin can update (approve/reject/mark-read)", async () => {
    await assertFails(
      as("cashier").collection("void_requests").doc("vr-1").update({ read: true }));
    await assertFails(
      as("staff").collection("void_requests").doc("vr-1").update({ status: "approved" }));
    await assertSucceeds(
      as("admin").collection("void_requests").doc("vr-1").update({ status: "approved", read: true }));
  });

  it("no one can delete", async () => {
    await assertFails(as("admin").collection("void_requests").doc("vr-1").delete());
  });
});

// ===================================================================
// /void_request_pending (R2 — one pending void request per sale, by
// construction; the claim doc's existence IS the lock)
// ===================================================================
describe("/void_request_pending", () => {
  const claim = (uid) => ({
    requestId: "vr-9", requestedBy: uid, createdAt: new Date(),
  });

  it("cashier/staff can create a claim with their own requestedBy", async () => {
    await assertSucceeds(
      as("cashier").collection("void_request_pending").doc("s-1").set(claim(USERS.cashier.uid)));
    await assertSucceeds(
      as("staff").collection("void_request_pending").doc("s-2").set(claim(USERS.staff.uid)));
  });

  it("cannot create a claim as someone else", async () => {
    await assertFails(
      as("cashier").collection("void_request_pending").doc("s-3").set(claim(USERS.staff.uid)));
  });

  it("inactive user cannot create", async () => {
    await assertFails(
      as("inactiveStaff").collection("void_request_pending").doc("s-4")
        .set(claim(USERS.inactiveStaff.uid)));
  });

  it("a second create on an already-claimed saleId fails", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("void_request_pending").doc("s-5")
        .set(claim(USERS.cashier.uid));
    });

    await assertFails(
      as("staff").collection("void_request_pending").doc("s-5").set(claim(USERS.staff.uid)));
  });

  it("active valid users can read", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("void_request_pending").doc("s-6")
        .set(claim(USERS.cashier.uid));
    });
    await assertSucceeds(as("cashier").collection("void_request_pending").doc("s-6").get());
    await assertSucceeds(as("admin").collection("void_request_pending").doc("s-6").get());
  });

  it("cashier/staff cannot delete a claim", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("void_request_pending").doc("s-7")
        .set(claim(USERS.cashier.uid));
    });
    await assertFails(as("cashier").collection("void_request_pending").doc("s-7").delete());
    await assertFails(as("staff").collection("void_request_pending").doc("s-7").delete());
  });

  it("admin can delete a claim (resolve path)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("void_request_pending").doc("s-8")
        .set(claim(USERS.cashier.uid));
    });
    await assertSucceeds(as("admin").collection("void_request_pending").doc("s-8").delete());
  });

  it("update always fails, even for admin", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("void_request_pending").doc("s-9")
        .set(claim(USERS.cashier.uid));
    });
    await assertFails(
      as("admin").collection("void_request_pending").doc("s-9").update({ requestId: "vr-99" }));
  });
});

// ===================================================================
// Cross-cutting: unauthenticated + inactive
// ===================================================================
describe("cross-cutting", () => {
  it("unauthenticated user is denied everything except logs:create (which requires auth too)", async () => {
    await assertFails(unauth().collection("products").doc("p-1").get());
    await assertFails(unauth().collection("sales").doc("s-1").get());
    await assertFails(unauth().collection("drafts").doc("d-1").get());
    await assertFails(unauth().collection("expenses").doc("e-1").get());
    await assertFails(unauth().collection("settings").doc("s-1").get());
  });

  it("inactive admin cannot write petty_cash", async () => {
    await assertFails(
      as("inactiveAdmin").collection("petty_cash").doc("pc-x").set({
        type: "cash_in", amount: 1,
      })
    );
  });

  it("inactive admin cannot create users", async () => {
    await assertFails(
      as("inactiveAdmin").collection("users").doc("anyone-new").set({
        role: "cashier", isActive: true, email: "x@test", displayName: "X",
      })
    );
  });

  it("inactive admin cannot delete users", async () => {
    await assertFails(
      as("inactiveAdmin").collection("users").doc(USERS.cashier.uid).delete()
    );
  });

  it("inactive admin cannot update other users", async () => {
    await assertFails(
      as("inactiveAdmin").collection("users").doc(USERS.cashier.uid).update({
        role: "staff",
      })
    );
  });

  it("sanity: assertSucceeds and assertFails work on the same op + role", async () => {
    // Belt and suspenders: confirm the harness wiring is sane.
    await assertSucceeds(as("admin").collection("users").doc(USERS.admin.uid).get());
    assert.ok(true);
  });
});

// ===================================================================
// Shared list collections (2026-07-24): cashier add/edit, staff full
// ===================================================================
describe("shared list collections (cashier add/edit, staff full)", () => {
  const LISTS = [
    "expense_categories",
    "units",
    "void_reasons",
    "mechanics",
    "shop_fees",
  ];

  const entry = { name: "Test Entry", isActive: true };

  async function seed(coll, id, data) {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().collection(coll).doc(id).set(data)
    );
  }

  for (const coll of LISTS) {
    it(`${coll}: cashier can create`, async () => {
      await assertSucceeds(as("cashier").collection(coll).add(entry));
    });

    it(`${coll}: cashier can edit the name`, async () => {
      await seed(coll, "e1", entry);
      await assertSucceeds(
        as("cashier").collection(coll).doc("e1").update({ name: "Renamed" })
      );
    });

    it(`${coll}: cashier cannot flip isActive`, async () => {
      await seed(coll, "e1", entry);
      await assertFails(
        as("cashier").collection(coll).doc("e1").update({ isActive: false })
      );
    });

    it(`${coll}: staff can flip isActive`, async () => {
      await seed(coll, "e1", entry);
      await assertSucceeds(
        as("staff").collection(coll).doc("e1").update({ isActive: false })
      );
    });

    it(`${coll}: staff can delete`, async () => {
      await seed(coll, "e1", entry);
      await assertSucceeds(as("staff").collection(coll).doc("e1").delete());
    });

    it(`${coll}: admin can delete`, async () => {
      await seed(coll, "e2", entry);
      await assertSucceeds(as("admin").collection(coll).doc("e2").delete());
    });

    it(`${coll}: cashier cannot delete`, async () => {
      await seed(coll, "e9", entry);
      await assertFails(as("cashier").collection(coll).doc("e9").delete());
    });

    it(`${coll}: inactive staff cannot create`, async () => {
      await assertFails(as("inactiveStaff").collection(coll).add(entry));
    });

    it(`${coll}: inactive staff/admin cannot flip isActive`, async () => {
      await seed(coll, "e1", entry);
      await assertFails(
        as("inactiveStaff").collection(coll).doc("e1").update({ isActive: false })
      );
      await assertFails(
        as("inactiveAdmin").collection(coll).doc("e1").update({ isActive: false })
      );
    });

    it(`${coll}: cashier cannot delete`, async () => {
      await seed(coll, "e1", entry);
      await assertFails(as("cashier").collection(coll).doc("e1").delete());
    });
  }

  describe("motorcycle_models", () => {
    const model = (uid) => ({
      name: "Nmax",
      isActive: true,
      createdBy: uid,
    });

    it("cashier create with createdBy=self still allowed", async () => {
      await assertSucceeds(
        as("cashier")
          .collection("motorcycle_models")
          .add(model(USERS.cashier.uid))
      );
    });

    it("cashier can rename but not flip isActive; staff can flip", async () => {
      await seed("motorcycle_models", "m1", model(USERS.admin.uid));
      await assertSucceeds(
        as("cashier")
          .collection("motorcycle_models")
          .doc("m1")
          .update({ name: "Nmax v2" })
      );
      await assertFails(
        as("cashier")
          .collection("motorcycle_models")
          .doc("m1")
          .update({ isActive: false })
      );
      await assertSucceeds(
        as("staff")
          .collection("motorcycle_models")
          .doc("m1")
          .update({ isActive: false })
      );
    });

    it("staff can delete", async () => {
      await seed("motorcycle_models", "m1", model(USERS.admin.uid));
      await assertSucceeds(
        as("staff").collection("motorcycle_models").doc("m1").delete()
      );
    });

    it("admin can delete", async () => {
      await seed("motorcycle_models", "m2", model(USERS.admin.uid));
      await assertSucceeds(
        as("admin").collection("motorcycle_models").doc("m2").delete()
      );
    });

    it("inactive staff/admin cannot flip isActive", async () => {
      await seed("motorcycle_models", "m1", model(USERS.admin.uid));
      await assertFails(
        as("inactiveStaff")
          .collection("motorcycle_models")
          .doc("m1")
          .update({ isActive: false })
      );
      await assertFails(
        as("inactiveAdmin")
          .collection("motorcycle_models")
          .doc("m1")
          .update({ isActive: false })
      );
    });

    it("cashier cannot delete", async () => {
      await seed("motorcycle_models", "m1", model(USERS.admin.uid));
      await assertFails(
        as("cashier").collection("motorcycle_models").doc("m1").delete()
      );
    });
  });

  describe("product_categories (2026-07-25: staff/admin only, not shared-list)", () => {
    it("cashier can no longer create a product category", async () => {
      await assertFails(as("cashier").collection("product_categories").add(entry));
    });

    it("cashier can no longer rename a product category", async () => {
      await seed("product_categories", "e1", entry);
      await assertFails(
        as("cashier").collection("product_categories").doc("e1").update({ name: "New Name" })
      );
    });

    it("staff can still create and rename product categories", async () => {
      await assertSucceeds(as("staff").collection("product_categories").add(entry));
      await seed("product_categories", "e1", entry);
      await assertSucceeds(
        as("staff").collection("product_categories").doc("e1").update({ name: "New Name" })
      );
    });

    it("cashier can still create an expense category (unchanged)", async () => {
      await assertSucceeds(as("cashier").collection("expense_categories").add(entry));
    });

    it("product_categories: admin can create and rename", async () => {
      const docRef = as("admin").collection("product_categories").doc("e1");
      await assertSucceeds(docRef.set(entry));
      await assertSucceeds(docRef.update({ name: "Renamed" }));
    });

    it("product_categories: staff can flip isActive", async () => {
      await seed("product_categories", "e1", entry);
      await assertSucceeds(
        as("staff").collection("product_categories").doc("e1").update({ isActive: false })
      );
    });

    it("product_categories: staff can delete", async () => {
      await seed("product_categories", "e1", entry);
      await assertSucceeds(as("staff").collection("product_categories").doc("e1").delete());
    });

    it("product_categories: admin can delete", async () => {
      await seed("product_categories", "e2", entry);
      await assertSucceeds(as("admin").collection("product_categories").doc("e2").delete());
    });

    it("product_categories: cashier cannot delete", async () => {
      await seed("product_categories", "e3", entry);
      await assertFails(as("cashier").collection("product_categories").doc("e3").delete());
    });

    it("product_categories: inactive staff cannot create", async () => {
      await assertFails(as("inactiveStaff").collection("product_categories").add(entry));
    });

    it("product_categories: inactive staff/admin cannot flip isActive", async () => {
      await seed("product_categories", "e1", entry);
      await assertFails(
        as("inactiveStaff").collection("product_categories").doc("e1").update({ isActive: false })
      );
      await assertFails(
        as("inactiveAdmin").collection("product_categories").doc("e1").update({ isActive: false })
      );
    });
  });
});

// ===================================================================
// /category_codes
// ===================================================================
describe("/category_codes", () => {
  const registryDoc = {
    categoryId: "cat-1",
    nameSnapshot: "Brake Pads",
    assignedAt: new Date(),
    nextSequence: 1,
  };
  const counterDoc = { next: 2 };

  async function seed(id, data) {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().collection("category_codes").doc(id).set(data)
    );
  }

  it("staff can create a registry doc", async () => {
    await assertSucceeds(
      as("staff").collection("category_codes").doc("BRA").set(registryDoc)
    );
  });

  it("staff can create the _counter doc", async () => {
    await assertSucceeds(
      as("staff").collection("category_codes").doc("_counter").set(counterDoc)
    );
  });

  it("cashier cannot create a registry doc", async () => {
    await assertFails(
      as("cashier").collection("category_codes").doc("BRA").set(registryDoc)
    );
  });

  it("cashier cannot create the _counter doc", async () => {
    await assertFails(
      as("cashier").collection("category_codes").doc("_counter").set(counterDoc)
    );
  });

  it("staff can update ONLY nextSequence on a registry doc", async () => {
    await seed("BRA", registryDoc);
    await assertSucceeds(
      as("staff")
        .collection("category_codes")
        .doc("BRA")
        .update({ nextSequence: 2 })
    );
  });

  it("staff cannot update nameSnapshot on a registry doc", async () => {
    await seed("BRA", registryDoc);
    await assertFails(
      as("staff")
        .collection("category_codes")
        .doc("BRA")
        .update({ nameSnapshot: "Renamed" })
    );
  });

  it("staff cannot update nameSnapshot+nextSequence together on a registry doc", async () => {
    await seed("BRA", registryDoc);
    await assertFails(
      as("staff")
        .collection("category_codes")
        .doc("BRA")
        .update({ nameSnapshot: "Renamed", nextSequence: 2 })
    );
  });

  it("staff can update next on the _counter doc", async () => {
    await seed("_counter", counterDoc);
    await assertSucceeds(
      as("staff").collection("category_codes").doc("_counter").update({ next: 3 })
    );
  });

  it("staff cannot update any other key on the _counter doc", async () => {
    await seed("_counter", counterDoc);
    await assertFails(
      as("staff")
        .collection("category_codes")
        .doc("_counter")
        .update({ extra: "nope" })
    );
  });

  it("cashier cannot update nextSequence on a registry doc", async () => {
    await seed("BRA", registryDoc);
    await assertFails(
      as("cashier")
        .collection("category_codes")
        .doc("BRA")
        .update({ nextSequence: 2 })
    );
  });

  it("any active user (cashier) can read a registry doc", async () => {
    await seed("BRA", registryDoc);
    await assertSucceeds(as("cashier").collection("category_codes").doc("BRA").get());
  });

  it("any active user (cashier) can read the _counter doc", async () => {
    await seed("_counter", counterDoc);
    await assertSucceeds(
      as("cashier").collection("category_codes").doc("_counter").get()
    );
  });

  it("delete fails even for admin", async () => {
    await seed("BRA", registryDoc);
    await assertFails(as("admin").collection("category_codes").doc("BRA").delete());
  });

  it("delete fails for the _counter doc even for admin", async () => {
    await seed("_counter", counterDoc);
    await assertFails(
      as("admin").collection("category_codes").doc("_counter").delete()
    );
  });
});

// ===================================================================
// /drawer_state
// ===================================================================
describe("/drawer_state", () => {
  async function seedRaw(data) {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().collection("drawer_state").doc("state").set(data)
    );
  }

  it("active user can read the state doc", async () => {
    await seedRaw({ lastSaleDay: phDay() });
    await assertSucceeds(as("cashier").collection("drawer_state").doc("state").get());
  });

  it("inactive user cannot read the state doc", async () => {
    await seedRaw({ lastSaleDay: phDay() });
    await assertFails(
      as("inactiveStaff").collection("drawer_state").doc("state").get()
    );
  });

  it("cashier can stamp lastSaleDay to today's PH day (create)", async () => {
    await assertSucceeds(
      as("cashier")
        .collection("drawer_state")
        .doc("state")
        .set({ lastSaleDay: phDay() }, { merge: true })
    );
  });

  it("cashier cannot stamp lastSaleDay to a past day (create)", async () => {
    await assertFails(
      as("cashier")
        .collection("drawer_state")
        .doc("state")
        .set({ lastSaleDay: phDay() - 1 }, { merge: true })
    );
  });

  it("cashier cannot stamp lastSaleDay to a future day (create)", async () => {
    await assertFails(
      as("cashier")
        .collection("drawer_state")
        .doc("state")
        .set({ lastSaleDay: phDay() + 1 }, { merge: true })
    );
  });

  it("cashier can set lastClosedDay to a past day (create)", async () => {
    await assertSucceeds(
      as("cashier")
        .collection("drawer_state")
        .doc("state")
        .set({ lastClosedDay: phDay() - 1 }, { merge: true })
    );
  });

  it("cashier can set lastClosedDay to today (create)", async () => {
    await assertSucceeds(
      as("cashier")
        .collection("drawer_state")
        .doc("state")
        .set({ lastClosedDay: phDay() }, { merge: true })
    );
  });

  it("cashier cannot set lastClosedDay to a future day (create)", async () => {
    await assertFails(
      as("cashier")
        .collection("drawer_state")
        .doc("state")
        .set({ lastClosedDay: phDay() + 1 }, { merge: true })
    );
  });

  it("update: lastSaleDay can be advanced to today", async () => {
    await seedRaw({ lastSaleDay: phDay() - 1 });
    await assertSucceeds(
      as("cashier")
        .collection("drawer_state")
        .doc("state")
        .set({ lastSaleDay: phDay() }, { merge: true })
    );
  });

  it("update: lastSaleDay cannot be rewritten to a past day", async () => {
    await seedRaw({ lastSaleDay: phDay() });
    await assertFails(
      as("cashier")
        .collection("drawer_state")
        .doc("state")
        .set({ lastSaleDay: phDay() - 1 }, { merge: true })
    );
  });

  it("update: lastClosedDay can be set to a past day", async () => {
    await seedRaw({ lastSaleDay: phDay() });
    await assertSucceeds(
      as("staff")
        .collection("drawer_state")
        .doc("state")
        .update({ lastClosedDay: phDay() - 1 })
    );
  });

  it("update: lastClosedDay cannot be set to a future day", async () => {
    await seedRaw({ lastSaleDay: phDay() });
    await assertFails(
      as("staff")
        .collection("drawer_state")
        .doc("state")
        .update({ lastClosedDay: phDay() + 1 })
    );
  });

  it("nobody can delete the state doc", async () => {
    await seedRaw({ lastSaleDay: phDay() });
    await assertFails(as("admin").collection("drawer_state").doc("state").delete());
  });
});

// ===================================================================
// /sales create gating (drawerSettled)
// ===================================================================
describe("/sales create gating (drawerSettled)", () => {
  const saleData = (id) => ({
    saleNumber: `SALE-GATE-${id}`,
    cashierId: USERS.cashier.uid,
    status: "completed",
    grandTotal: 10,
  });

  async function seedDrawerState(data) {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().collection("drawer_state").doc("state").set(data)
    );
  }

  it("no drawer_state doc: sale create allowed (fresh DB / pre-rollout)", async () => {
    await assertSucceeds(
      as("cashier")
        .collection("sales")
        .doc(newDocId("sale"))
        .set(saleData("a"))
    );
  });

  it("lastSaleDay == today: sale create allowed (day is live)", async () => {
    await seedDrawerState({ lastSaleDay: phDay() });
    await assertSucceeds(
      as("cashier")
        .collection("sales")
        .doc(newDocId("sale"))
        .set(saleData("b"))
    );
  });

  it("lastSaleDay is a past day with no lastClosedDay: sale create DENIED", async () => {
    await seedDrawerState({ lastSaleDay: phDay() - 1 });
    await assertFails(
      as("cashier")
        .collection("sales")
        .doc(newDocId("sale"))
        .set(saleData("c"))
    );
  });

  it("lastSaleDay is a past day but already closed (lastClosedDay >= lastSaleDay): sale create allowed", async () => {
    await seedDrawerState({ lastSaleDay: phDay() - 1, lastClosedDay: phDay() - 1 });
    await assertSucceeds(
      as("cashier")
        .collection("sales")
        .doc(newDocId("sale"))
        .set(saleData("d"))
    );
  });

  it("drawer_state doc exists with lastClosedDay only (no lastSaleDay): sale create allowed (close-before-first-sale)", async () => {
    await seedDrawerState({ lastClosedDay: phDay() - 1 });
    await assertSucceeds(
      as("cashier")
        .collection("sales")
        .doc(newDocId("sale"))
        .set(saleData("g"))
    );
  });

  it("drawer_state doc exists but empty (neither field set): sale create allowed", async () => {
    await seedDrawerState({});
    await assertSucceeds(
      as("cashier")
        .collection("sales")
        .doc(newDocId("sale"))
        .set(saleData("h"))
    );
  });

  it("gate applies to every active role, not just cashier", async () => {
    await seedDrawerState({ lastSaleDay: phDay() - 1 });
    await assertFails(
      as("staff").collection("sales").doc(newDocId("sale")).set(saleData("e"))
    );
    await assertFails(
      as("admin").collection("sales").doc(newDocId("sale")).set(saleData("f"))
    );
  });
});
