import '../../data/models/listing_model.dart';
import 'format.dart';

/// Move-in cost maths. Mirrors functions/lib/cost.js — keep the two in step.
///
/// Rules (from the product brief):
///  * Annual rent and total known move-in cost are different numbers.
///  * Unknown is NOT zero. A total is only "complete" when the agent has
///    attested that every mandatory charge is listed and nothing is flagged
///    unconfirmed. Otherwise the app says
///    "Known move-in subtotal + unconfirmed charges".
///  * Monthly charges (e.g. a service charge) recur; they are listed beside
///    the total, not inside it.
class MoveInBreakdown {
  final double rent;
  final List<ListingCharge> charges;
  final double upfrontCharges;
  final double subtotal;
  final bool complete;
  final List<String> unconfirmed;
  final List<ListingCharge> recurring;

  const MoveInBreakdown({
    required this.rent,
    required this.charges,
    required this.upfrontCharges,
    required this.subtotal,
    required this.complete,
    required this.unconfirmed,
    required this.recurring,
  });

  factory MoveInBreakdown.of(ListingModel l) {
    final upfront = l.charges.where((c) => c.isUpfront).toList();
    final recurring = l.charges.where((c) => !c.isUpfront).toList();
    final upfrontSum = upfront.fold<double>(0, (a, c) => a + c.amount);
    final isRent = l.categoryEnum.hasMoveInCost;
    return MoveInBreakdown(
      rent: l.price,
      charges: l.charges,
      upfrontCharges: upfrontSum,
      subtotal: l.price + upfrontSum,
      complete: isRent ? (l.chargesComplete && l.unconfirmedCharges.isEmpty) : true,
      unconfirmed: l.unconfirmedCharges,
      recurring: recurring,
    );
  }

  /// Heading for the total line — never calls an incomplete figure "total".
  String get totalLabel => complete ? 'Move-in total' : 'Known move-in subtotal + unconfirmed charges';

  /// Compact form used on cards: "Move-in ₦2.9m" or "Subtotal ₦2.9m + fees TBC".
  String get cardLabel =>
      complete ? 'Move-in ${Money.short(subtotal)}' : 'Subtotal ${Money.short(subtotal)} + unconfirmed';
}

String chargeTypeLabel(String type) {
  switch (type) {
    case 'agency':
      return 'Agency fee';
    case 'legal':
      return 'Legal fee';
    case 'caution':
      return 'Caution deposit';
    case 'service':
      return 'Service charge';
    case 'utilities':
      return 'Utilities';
    default:
      return 'Other charge';
  }
}

String refundableLabel(String r) {
  switch (r) {
    case 'yes':
      return 'Refundable';
    case 'no':
      return 'Not refundable';
    default:
      return 'Refundability to confirm';
  }
}

String recipientLabel(String r) {
  switch (r) {
    case 'landlord':
      return 'Paid to landlord';
    case 'management':
      return 'Paid to management';
    case 'other':
      return 'Paid to other';
    default:
      return 'Paid to agent';
  }
}
