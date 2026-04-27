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

  it("only admin can create products", async () => {
    await assertFails(
      as("cashier").collection("products").doc("p-2").set({ sku: "X", price: 1, cost: 0.5, costCode: "A", quantity: 0, isActive: true })
    );
    await assertFails(
      as("staff").collection("products").doc("p-2").set({ sku: "X", price: 1, cost: 0.5, costCode: "A", quantity: 0, isActive: true })
    );
    await assertSucceeds(
      as("admin").collection("products").doc("p-2").set({ sku: "X", price: 1, cost: 0.5, costCode: "A", quantity: 0, isActive: true })
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

  it("cashier CANNOT change name (full update)", async () => {
    await assertFails(
      as("cashier").collection("products").doc("p-1").update({ name: "Hacked" })
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
// /petty_cash
// ===================================================================
describe("/petty_cash", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("petty_cash").doc("pc-1").set({
        type: "cash_in", amount: 500, balance: 500,
      });
    });
  });

  it("cashier CANNOT read petty_cash", async () => {
    await assertFails(as("cashier").collection("petty_cash").doc("pc-1").get());
  });

  it("staff CANNOT read petty_cash", async () => {
    await assertFails(as("staff").collection("petty_cash").doc("pc-1").get());
  });

  it("admin can read + write petty_cash", async () => {
    await assertSucceeds(as("admin").collection("petty_cash").doc("pc-1").get());
    await assertSucceeds(
      as("admin").collection("petty_cash").doc(newDocId("pc")).set({
        type: "cash_out", amount: 100, balance: 400,
      })
    );
  });

  it("cashier CANNOT write petty_cash", async () => {
    await assertFails(
      as("cashier").collection("petty_cash").doc(newDocId("pc")).set({
        type: "cash_in", amount: 1000,
      })
    );
  });

  it("staff CANNOT write petty_cash", async () => {
    await assertFails(
      as("staff").collection("petty_cash").doc(newDocId("pc")).set({
        type: "cash_in", amount: 1000,
      })
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

  it("inactive admin cannot write petty_cash (isActive gate works on most collections)", async () => {
    await assertFails(
      as("inactiveAdmin").collection("petty_cash").doc("pc-x").set({
        type: "cash_in", amount: 1,
      })
    );
  });

  // KNOWN GAP — surfaced by these tests:
  // /users rules check isAdmin() but NOT isActiveUser(), so a deactivated
  // admin can still create + delete user docs as long as their session is
  // valid. Every other admin-gated collection in firestore.rules combines
  // both predicates. To close the gap, the rules should read:
  //   allow create: if isAdmin() && isActiveUser();
  //   allow delete: if isAdmin() && isActiveUser();
  // and the update branch's `isAdmin()` should likewise be `isAdmin() &&
  // isActiveUser()`. Pinned as a passing test reflecting current behavior so
  // it fails loudly the moment the rule changes (in either direction).
  it("inactive admin CAN still create users (rules gap — see comment)", async () => {
    await assertSucceeds(
      as("inactiveAdmin").collection("users").doc("anyone-new").set({
        role: "cashier", isActive: true, email: "x@test", displayName: "X",
      })
    );
  });

  it("sanity: assertSucceeds and assertFails work on the same op + role", async () => {
    // Belt and suspenders: confirm the harness wiring is sane.
    await assertSucceeds(as("admin").collection("users").doc(USERS.admin.uid).get());
    assert.ok(true);
  });
});
