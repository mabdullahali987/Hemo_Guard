'use strict';

const DAY_MS = 24 * 60 * 60 * 1000;

function addCalendarMonths(utcIso, months) {
  if (!Number.isInteger(months) || months < 1 || months > 120) throw new Error('Invalid months');
  const d = new Date(utcIso);
  if (Number.isNaN(d.getTime())) throw new Error('Invalid start date');
  const day = d.getUTCDate();
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() + months);
  const finalDay = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  d.setUTCDate(Math.min(day, finalDay));
  return d.toISOString();
}

function addDuration(start, number, unit) {
  if (!Number.isInteger(number) || number < 1 || number > (unit === 'months' ? 120 : 3650)) {
    throw new Error('Duration must be a positive number within allowed limits');
  }
  if (unit === 'days') return new Date(new Date(start).getTime() + number * DAY_MS).toISOString();
  if (unit === 'months') return addCalendarMonths(start, number);
  throw new Error('Duration unit must be days or months');
}

function accessState(user, at = new Date()) {
  if (user.deleted_at) return 'deleted';
  if (!user.is_active) return 'disabled';
  if (user.account_type === 'superadmin') return 'active';
  if (!user.access_plan || !user.plan_expires_at) return 'unassigned';
  if (user.plan_stopped_at) return 'stopped';
  if (new Date(user.plan_started_at).getTime() > at.getTime()) return 'pending';
  if (new Date(user.plan_expires_at).getTime() <= at.getTime()) return 'expired';
  return 'active';
}

module.exports = { addDuration, addCalendarMonths, accessState };
