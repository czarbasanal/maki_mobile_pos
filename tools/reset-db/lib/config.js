'use strict';

/**
 * The ONLY collections this tool ever deletes. The script never enumerates
 * "all collections", so anything absent here (now or in the future) is safe.
 */
const WIPE_COLLECTIONS = [
  'sales', // includes the `items` subcollection (recursiveDelete)
  'drafts',
  'receivings',
  'expenses',
  'daily_closings',
  'void_requests',
  'user_logs',
];

/** Documented for clarity + guard tests. Never referenced for deletion. */
const KEEP_COLLECTIONS = [
  'users',
  'settings',
  'products', // includes the `price_history` subcollection
  'suppliers',
  'product_categories',
  'expense_categories',
  'units',
  'void_reasons',
];

/** The exact phrase the operator must type to confirm a real run. */
function confirmationToken(projectId) {
  return projectId;
}

function isConfirmed(input, projectId) {
  return typeof input === 'string' && input.trim() === confirmationToken(projectId);
}

module.exports = { WIPE_COLLECTIONS, KEEP_COLLECTIONS, confirmationToken, isConfirmed };
