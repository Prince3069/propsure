import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/ps_widgets.dart';
import '../../data/models/listing_model.dart';
import 'app_providers.dart';

/// IDs the signed-in user has saved (empty when signed out).
final savedIdsProvider = Provider<Set<String>>((ref) {
  final u = ref.watch(currentUserModelProvider).asData?.value;
  return u == null ? <String>{} : u.savedListings.toSet();
});

/// Save / unsave a home. Signed-out users are sent to sign in with context
/// ("Sign in to save this home") and returned here afterwards.
Future<void> toggleSaved(BuildContext context, WidgetRef ref, String listingId) async {
  final uid = ref.read(currentUserIdProvider);
  if (uid == null) {
    context.push('/auth?reason=save&redirect=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}');
    return;
  }
  final repo = ref.read(listingRepositoryProvider);
  final saved = ref.read(savedIdsProvider).contains(listingId);
  try {
    if (saved) {
      await repo.unsaveListing(userId: uid, listingId: listingId);
    } else {
      await repo.saveListing(userId: uid, listingId: listingId);
    }
  } catch (_) {
    if (context.mounted) showPsSnack(context, 'We could not update your saved homes. Try again.', error: true);
  }
}

/// Runs a server action with a loading flag and plain-language errors.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) showPsSnack(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showPsSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    return false;
  }
}

/// Opens (or creates) the conversation about [listing]. Requires sign-in.
/// [prefill] is passed to the chat as the suggested first message.
Future<void> openChatAbout(BuildContext context, WidgetRef ref, ListingModel listing, {String? prefill}) async {
  final user = ref.read(currentUserModelProvider).asData?.value;
  if (user == null) {
    context.push('/auth?reason=message&redirect=${Uri.encodeComponent('/listing/${listing.id}')}');
    return;
  }
  if (user.uid == listing.agentId) {
    showPsSnack(context, 'This is your own listing.');
    return;
  }
  try {
    final id = await ref.read(chatRepositoryProvider).getOrCreateChat(
          userId: user.uid,
          agentId: listing.agentId,
          listingId: listing.id,
          userName: user.displayName,
          agentName: listing.agentName,
          listingTitle: listing.title,
          listingThumbnail: listing.coverUrl,
          userPhoto: user.profilePhoto,
          agentPhoto: listing.agentPhoto,
        );
    if (context.mounted) {
      final q = prefill == null ? '' : '?draft=${Uri.encodeComponent(prefill)}';
      context.push('/chat/$id$q');
    }
  } catch (_) {
    if (context.mounted) showPsSnack(context, 'We could not open the conversation. Try again.', error: true);
  }
}

/// Request an inspection straight from a listing. The agent confirms it;
/// nothing is booked until they do.
Future<void> requestInspection(BuildContext context, WidgetRef ref, ListingModel listing) async {
  final user = ref.read(currentUserModelProvider).asData?.value;
  if (user == null) {
    context.push('/auth?reason=inspection&redirect=${Uri.encodeComponent('/listing/${listing.id}')}');
    return;
  }
  if (listing.agentId == user.uid) {
    showPsSnack(context, 'This is your own listing.');
    return;
  }
  final now = DateTime.now();
  final d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 1)), firstDate: now, lastDate: now.add(const Duration(days: 60)), helpText: 'Choose a day to visit');
  if (d == null || !context.mounted) return;
  final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 11, minute: 0), helpText: 'Choose a time');
  if (t == null || !context.mounted) return;
  final when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
  final ok = await runAction(context, () async {
    await ref.read(bookingRepositoryProvider).createBooking(
          listingId: listing.id,
          agentId: listing.agentId,
          userId: user.uid,
          userName: user.displayName,
          userPhone: user.phone,
          listingTitle: listing.title,
          dateTime: when,
          listingThumbnail: listing.coverUrl,
          agentName: listing.agentName,
          agentPhone: listing.agentPhone,
        );
  }, success: 'Request sent. The agent will confirm the time.');
  if (ok && context.mounted) context.push('/bookings');
}
