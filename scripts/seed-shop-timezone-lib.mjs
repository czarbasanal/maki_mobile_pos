/**
 * Pure helpers for the settings/general shop-timezone seed.
 *
 * The offset written here is read by the Firestore rules (phDay()), by the
 * mobile app and by the web admin — all three must agree, so the value is
 * validated in exactly the same way the rules validate it: an integer in
 * [-720, 840] minutes east of UTC.
 */

/** Asia/Manila, UTC+8, no DST — what the system falls back to everywhere. */
export const DEFAULT_SEED = { timezoneId: 'Asia/Manila', tzOffsetMinutes: 480 };

const MIN_OFFSET = -720;
const MAX_OFFSET = 840;

/**
 * Validates and shapes the settings/general timezone keys.
 *
 * @param {{timezoneId: string, offsetMinutes: number}} input
 * @returns {{timezoneId: string, tzOffsetMinutes: number}}
 * @throws {Error} when the id is empty or the offset is not an in-range integer
 */
export function buildSeedPayload({ timezoneId, offsetMinutes }) {
  if (typeof timezoneId !== 'string' || timezoneId.trim() === '') {
    throw new Error('timezoneId must be a non-empty string (an IANA name, e.g. Asia/Manila)');
  }
  if (!Number.isInteger(offsetMinutes)) {
    throw new Error(`offsetMinutes must be a whole number of minutes, got: ${offsetMinutes}`);
  }
  if (offsetMinutes < MIN_OFFSET || offsetMinutes > MAX_OFFSET) {
    throw new Error(
      `offsetMinutes must be between ${MIN_OFFSET} and ${MAX_OFFSET}, got: ${offsetMinutes}`,
    );
  }
  return { timezoneId: timezoneId.trim(), tzOffsetMinutes: offsetMinutes };
}
