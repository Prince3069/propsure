import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

enum LegalKind { privacy, terms }

class _Sec {
  final String h, b;
  const _Sec(this.h, this.b);
}

// Plain-language drafts. Have a Nigerian lawyer review before launch
// (NDPA 2023 compliance, consumer-protection wording). See DEPLOY.md.
const _terms = [
  _Sec('What Propsure is', 'Propsure is a marketplace that helps renters find homes in Abuja and helps landlords and agents list them. We are not a party to any tenancy and we do not collect rent or deposits.'),
  _Sec('Your account', 'You must give accurate details. You are responsible for activity on your account. Do not share one-time codes with anyone.'),
  _Sec('Listings', 'Agents and landlords are responsible for the accuracy of what they list, including prices, fees and availability. Propsure may remove or hide a listing that is inaccurate, out of date, under review or reported.'),
  _Sec('What our checks mean', 'An identity check confirms who a person is. An authority check relates to one listing only. Neither proves ownership or title, and neither guarantees a home’s condition. Always inspect in person and get agreements in writing.'),
  _Sec('Paid tools and promotion', 'Agent Pro is a fixed 30-day access pass. It does not renew automatically. Promoted placement is labelled Sponsored. Payment does not buy verification and does not guarantee enquiries or a tenant.'),
  _Sec('Payments and refunds', 'Payments are processed by Paystack for agent tools and promotion only, never for rent or deposits. Access starts after Paystack confirms payment. If you were charged and access did not start, contact support with your reference.'),
  _Sec('Acceptable use', 'Do not post false or misleading listings, impersonate others, harass users, or use Propsure to collect payments outside the app under false pretences.'),
  _Sec('Contact', 'Questions about these terms: use Help & support in the app.'),
];

const _privacy = [
  _Sec('What we collect', 'Your name, phone number, email (optional), profile photo (optional), the listings you save, your messages with agents, and details you give for verification. For agents we also store listing content and videos you upload.'),
  _Sec('How we use it', 'To run your account, show listings, connect you with agents, review reports, review verification requests, process payments for agent tools and keep the marketplace safe.'),
  _Sec('What others can see', 'Your name and photo appear to people you message. Agents’ public profiles show name, agency, bio, and whether an identity check was completed. Your phone number and email are not shown publicly by default.'),
  _Sec('Verification documents', 'ID photos, selfies and authority documents are stored privately and are only viewed by Propsure reviewers through short-lived links.'),
  _Sec('Payments', 'Card and bank details are handled by Paystack. We receive the payment status and reference, not your card number.'),
  _Sec('Your choices', 'You can edit your profile and notification settings in the app. To delete your account or ask what we hold about you, use Help & support.'),
  _Sec('Contact', 'Privacy questions: use Help & support in the app.'),
];

class LegalScreen extends StatelessWidget {
  final LegalKind kind;
  const LegalScreen({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final terms = kind == LegalKind.terms;
    final secs = terms ? _terms : _privacy;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PsTopBar(title: terms ? 'Terms' : 'Privacy'),
      body: ListView(padding: kPagePadding, children: [
        Text(terms ? 'Terms of use' : 'Privacy policy', style: AppText.h1),
        const SizedBox(height: 16),
        for (final s in secs) Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.h, style: AppText.h3), const SizedBox(height: 4), Text(s.b, style: AppText.body)])),
        const SizedBox(height: 16),
      ]),
    );
  }
}
