/**
 * Propsure Functions — shared configuration.
 *
 * THIS FILE IS THE SINGLE SOURCE OF TRUTH FOR EVERY PRICE, LIMIT AND
 * FRESHNESS WINDOW. The Flutter app fetches display values from the
 * `getPricing` callable; it never decides an amount or an entitlement.
 *
 * Items marked CONFIRM are proposals from the design brief that you must
 * approve before treating them as final commercial policy.
 */

const kobo = (naira) => Math.round(naira * 100);

// ── Boost catalogs ────────────────────────────────────────────────────────
// CONFIRM: the brief says do not mix catalogs. Pick ONE by setting
// BOOST_CATALOG in functions/.env  ("pilot" is the default and matches
// mockup 30; "standard" is the catalog that shipped in the old source).
const BOOST_CATALOGS = {
  pilot: {
    boost_7: { amountKobo: kobo(3000), type: 'boost', boostDays: 7, label: '7 days' },
    boost_14: { amountKobo: kobo(5000), type: 'boost', boostDays: 14, label: '14 days' },
  },
  standard: {
    boost_7: { amountKobo: kobo(5000), type: 'boost', boostDays: 7, label: '7 days' },
    boost_14: { amountKobo: kobo(10000), type: 'boost', boostDays: 14, label: '14 days' },
    boost_30: { amountKobo: kobo(20000), type: 'boost', boostDays: 30, label: '30 days' },
  },
};

// ── Agent plan ────────────────────────────────────────────────────────────
// A FIXED-DURATION ACCESS PASS, not an auto-renewing subscription. The
// app copy says "30-day access". If you later want real recurring billing
// you must add Paystack plan/authorization handling, explicit consent,
// renewal-failure/cancellation flows and reconciliation first.
// CONFIRM: the annual price below is carried over from the old source
// (10 months for 12) and is NOT shown in the app until you confirm it.
const PLANS = {
  agent_pro_monthly: {
    amountKobo: kobo(10000), type: 'premium', planId: 'agent_pro', durationDays: 30, label: '30-day access',
  },
  agent_pro_yearly: {
    amountKobo: kobo(100000), type: 'premium', planId: 'agent_pro', durationDays: 365, label: '365-day access',
    hiddenUntilConfirmed: true,
  },
};

function boostCatalogName() {
  const n = (process.env.BOOST_CATALOG || 'pilot').toLowerCase();
  return BOOST_CATALOGS[n] ? n : 'pilot';
}

function planCatalog() {
  const catalog = { ...BOOST_CATALOGS[boostCatalogName()], ...PLANS };
  return catalog;
}

// ── Listing limits ────────────────────────────────────────────────────────
// CONFIRM: proposals from the brief (free 3 / Pro 20).
function activeListingLimit(isPremium) {
  const free = parseInt(process.env.FREE_ACTIVE_LISTINGS || '3', 10);
  const pro = parseInt(process.env.PRO_ACTIVE_LISTINGS || '20', 10);
  return isPremium ? pro : free;
}

// ── Freshness windows (days) ──────────────────────────────────────────────
// A home whose availability was last confirmed longer ago than
// REFRESH_AFTER_DAYS is flagged "needs refresh" (and de-ranked in the app).
// After HIDE_AFTER_DAYS it is moved to status "stale" and disappears from
// public search until the agent re-confirms it.
const REFRESH_AFTER_DAYS = parseInt(process.env.REFRESH_AFTER_DAYS || '7', 10);
const HIDE_AFTER_DAYS = parseInt(process.env.HIDE_AFTER_DAYS || '21', 10);

// ── Payments ──────────────────────────────────────────────────────────────
// The ONLY callback URL Paystack is given. A client-supplied value is ignored.
const PAYSTACK_CALLBACK_URL = process.env.PAYSTACK_CALLBACK_URL || 'https://propsure.africa/payment/callback';

// ── Media limits (enforced server-side) ───────────────────────────────────
const MEDIA = {
  maxVideoBytes: 300 * 1024 * 1024,
  maxVideoSeconds: 180,
  minVideoSeconds: 5,
  maxImageBytes: 12 * 1024 * 1024,
  maxStills: 20,
  allowedVideoTypes: ['video/mp4', 'video/quicktime', 'video/x-m4v', 'video/3gpp', 'video/webm'],
};

// ── Founder programme ─────────────────────────────────────────────────────
// DISABLED BY DEFAULT. Do not advertise a free year or a cap until you have
// tested the claim path and set FOUNDER_PROMO_ENABLED=true in .env.
const FOUNDER = {
  enabled: () => String(process.env.FOUNDER_PROMO_ENABLED || 'false').toLowerCase() === 'true',
  slots: () => parseInt(process.env.FOUNDER_SLOTS || '100', 10),
  grantDays: () => parseInt(process.env.FOUNDER_GRANT_DAYS || '365', 10),
};

// Report reasons that put a listing under a safety hold (paid placement is
// ignored while a hold exists, and the report is prioritised).
const SERIOUS_REPORT_REASONS = ['suspicious_payment', 'authority_concern'];

module.exports = {
  kobo,
  BOOST_CATALOGS,
  PLANS,
  boostCatalogName,
  planCatalog,
  activeListingLimit,
  REFRESH_AFTER_DAYS,
  HIDE_AFTER_DAYS,
  PAYSTACK_CALLBACK_URL,
  MEDIA,
  FOUNDER,
  SERIOUS_REPORT_REASONS,
};
