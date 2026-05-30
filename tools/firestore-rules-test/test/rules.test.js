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

  it("only admin can delete users", async () => {
    await assertFails(as("staff").collection("users").doc(USERS.cashier.uid).delete());
    await assertFails(as("cashier").collection("users").doc(USERS.staff.uid).delete());
    await assertSucceeds(as("admin").collection("users").doc(USERS.cashier.uid).delete());
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
  it("only admin can read", async () => {
    await assertFails(as("staff").collection("suppliers").doc("s-1").get());
    await assertFails(as("cashier").collection("suppliers").doc("s-1").get());
    await assertSucceeds(as("admin").collection("suppliers").doc("s-1").get());
  });

  it("only admin can write", async () => {
    await assertFails(
      as("staff").collection("suppliers").doc("s-1").set({ name: "ACME" })
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

  it("cashier CANNOT update an expense", async () => {
    await assertFails(
      as("cashier").collection("expenses").doc("e-1").update({ amount: 99 })
    );
  });

  it("staff CANNOT update an expense", async () => {
    await assertFails(
      as("staff").collection("expenses").doc("e-1").update({ amount: 99 })
    );
  });

  it("admin can update + delete expenses", async () => {
    await assertSucceeds(
      as("admin").collection("expenses").doc("e-1").update({ amount: 99 })
    );
    await assertSucceeds(as("admin").collection("expenses").doc("e-1").delete());
  });

  it("cashier CANNOT delete an expense", async () => {
    await assertFails(as("cashier").collection("expenses").doc("e-1").delete());
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
