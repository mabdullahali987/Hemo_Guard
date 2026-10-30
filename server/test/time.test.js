const test = require('node:test');
const assert = require('node:assert/strict');
const { addDuration, accessState } = require('../src/time');
test('calendar-month subscription clamps to last day of February', () => {
  assert.equal(addDuration('2026-01-31T10:00:00.000Z', 1,'months'),'2026-02-28T10:00:00.000Z');
});
test('trial day increments respect UTC time', () => {
  assert.equal(addDuration('2026-10-17T10:00:00.000Z', 10,'days'),'2026-10-27T10:00:00.000Z');
});
test('ended trial, stopped subscription and disabled statuses', () => {
  const base = { account_type: 'lab', is_active: 1, access_plan: 'trial', plan_started_at: '2026-01-01T00:00:00.000Z', plan_expires_at: '2026-10-01T00:00:00.000Z' };
  assert.equal(accessState(base, new Date('2026-10-17')), 'expired');
  assert.equal(accessState({ ...base, plan_stopped_at: '2026-09-10T00:00:00Z' }), 'stopped');
  assert.equal(accessState({ ...base, is_active: 0 }), 'disabled');
  assert.equal(accessState({ ...base, plan_expires_at: '2026-12-01T00:00:00Z' }, new Date('2026-10-17')), 'active');
});
test('reject zero or excessive durations', () => {
  assert.throws(() => addDuration('2026-01-01T00:00:00Z', 0,'days'));
  assert.throws(() => addDuration('2026-01-01T00:00:00Z', 121,'months'));
});
