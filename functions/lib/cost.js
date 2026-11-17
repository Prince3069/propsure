/**
 * Move-in cost maths. Mirrors lib/core/utils/move_in_cost.dart — keep the two
 * in step. Unknown is NEVER treated as zero:
 *   - recurring (monthly) charges are listed separately, not in the subtotal
 *   - a total is only "complete" when the agent attested that every mandatory
 *     charge is listed AND nothing is flagged unconfirmed.
 */
function moveInBreakdown(listing) {
  const rent = Number(listing.price) || 0;
  const charges = Array.isArray(listing.charges) ? listing.charges : [];
  let upfront = 0;
  for (const c of charges) {
    const amount = Number(c.amount) || 0;
    if (c.period === 'one_time' || c.period === 'annual') upfront += amount;
  }
  const unconfirmed = Array.isArray(listing.unconfirmedCharges) ? listing.unconfirmedCharges : [];
  const isRent = listing.category === 'for_rent';
  const complete = isRent ? (listing.chargesComplete === true && unconfirmed.length === 0) : true;
  return { rent, upfront, subtotal: rent + upfront, complete, unconfirmed };
}

module.exports = { moveInBreakdown };
