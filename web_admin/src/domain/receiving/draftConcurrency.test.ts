import { describe, expect, it } from 'vitest';
import {
  isReceivingConflict,
  nextReceivingVersion,
  receivingVersion,
  RECEIVING_CONFLICT_MESSAGE,
} from './draftConcurrency';

describe('receivingVersion', () => {
  it('reads a stored version', () => {
    expect(receivingVersion(3)).toBe(3);
  });

  it('treats a doc written before versioning as 0, not a conflict with itself', () => {
    // Every legacy draft is missing the field. If these read as anything but a
    // single stable value, every save on an old draft would refuse.
    expect(receivingVersion(undefined)).toBe(0);
    expect(receivingVersion(null)).toBe(0);
    expect(isReceivingConflict(receivingVersion(undefined), receivingVersion(null))).toBe(false);
  });

  it('rejects junk rather than propagating NaN into the comparison', () => {
    expect(receivingVersion('7')).toBe(0);
    expect(receivingVersion(NaN)).toBe(0);
    expect(receivingVersion(-1)).toBe(0);
  });
});

describe('isReceivingConflict', () => {
  it('passes when the doc has not moved', () => {
    expect(isReceivingConflict(4, 4)).toBe(false);
  });

  it('refuses when another client wrote in between', () => {
    expect(isReceivingConflict(4, 5)).toBe(true);
  });

  it('refuses when the client is somehow ahead of the doc', () => {
    // Not expected, but a mismatch either way means the two disagree about
    // what is on the server — never overwrite on a disagreement.
    expect(isReceivingConflict(6, 5)).toBe(true);
  });
});

describe('nextReceivingVersion', () => {
  it('bumps by one', () => {
    expect(nextReceivingVersion(4)).toBe(5);
  });

  it('starts a legacy draft at 1 so the next reader can detect a change', () => {
    expect(nextReceivingVersion(receivingVersion(undefined))).toBe(1);
  });
});

describe('RECEIVING_CONFLICT_MESSAGE', () => {
  it('tells the user what to do, not just that something failed', () => {
    expect(RECEIVING_CONFLICT_MESSAGE).toMatch(/another device/i);
    expect(RECEIVING_CONFLICT_MESSAGE).toMatch(/reload/i);
  });
});
