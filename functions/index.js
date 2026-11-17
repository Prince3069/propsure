/**
 * Propsure Cloud Functions.
 *
 *   lib/payments.js   Paystack initialise · webhook · verify · reconcile · pricing
 *   lib/listings.js   publish · confirm availability · status · freshness job
 *   lib/trust.js      verification review · property passport · reviewer docs
 *   lib/support.js    support requests + reports (one queue, reference numbers)
 *   lib/media.js      video validation trigger · frame confirmation · cleanup
 *   lib/alerts.js     saved-search alerts
 *   lib/shortlist.js  shared shortlist invites
 *   founder_promo.js  founder programme (disabled unless FOUNDER_PROMO_ENABLED=true)
 *
 * Deploy steps and every setting are in DEPLOY.md.
 */
require('./lib/admin');

Object.assign(
  exports,
  require('./lib/payments'),
  require('./lib/listings'),
  require('./lib/trust'),
  require('./lib/support'),
  require('./lib/media'),
  require('./lib/alerts'),
  require('./lib/shortlist'),
  require('./founder_promo')
);

// Helpers exported for unit tests are not Cloud Functions — remove them.
for (const name of ['chargeMismatch', 'safeEqualHex', 'publishProblems', 'LIMITATIONS', 'TOPICS', 'REPORT_REASONS', 'jobIdFor', 'ORIGINAL_RE', 'matches', '__grant']) {
  delete exports[name];
}
