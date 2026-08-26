import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});
  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  String _search = '';
  final _ctrl = TextEditingController();
  int? _openIndex;

  static const _faqs = [
    // Listing
    ('How do I list my property?', 'Listings',
     'Tap the + button on the bottom navigation bar. You\'ll need to be signed in. Add photos, location details, pricing, and amenities, then submit. Listings are currently FREE.'),
    ('Is it free to list my property?', 'Listings',
     'Yes! Listing on Propsure is completely free right now. Premium features like featured placement, more photos, and video tours are available through our paid plans.'),
    ('How many photos can I add?', 'Listings',
     'You can add up to 10 photos per listing. A minimum of 3 photos is required. Premium plans unlock video tours and 360° walkthroughs.'),
    ('How long does my listing stay active?', 'Listings',
     'Free listings are active for 90 days. Premium listings stay active as long as your subscription is active and can be renewed at any time.'),
    ('Can I edit my listing after posting?', 'Listings',
     'Yes. Go to Profile → My Listings, select the listing, then tap Edit. You can update all details, photos, and pricing.'),
    // Tenants
    ('How do I contact an agent?', 'Tenants',
     'Open any listing and tap "Chat" or "Call" to contact the agent directly. You can also book an inspection through the app.'),
    ('How do I book an inspection?', 'Tenants',
     'On any listing detail page, tap "Book Inspection". Choose your preferred date and time, and the agent will confirm within 24 hours.'),
    ('Are listings on Propsure genuine?', 'Tenants',
     'All agents go through NIN verification before they can list. Verified listings show a green checkmark. We also allow users to report suspicious listings.'),
    ('What is the "Verified" badge?', 'Tenants',
     'The Verified badge means the agent has completed our identity verification process using their National Identification Number (NIN) via our Lumiid integration.'),
    // Payments
    ('What payment methods are accepted?', 'Payments',
     'We accept card payments, bank transfers, and USSD through Paystack. All transactions are 256-bit SSL encrypted.'),
    ('How do I cancel my premium plan?', 'Payments',
     'Go to Profile → Premium Plans. Tap "Manage Subscription" and select "Cancel". Your plan remains active until the end of the billing period.'),
    // Account
    ('How do I verify my identity?', 'Account',
     'Go to Profile → Verification. You can verify with your NIN (free) or upload a passport / driver\'s licence (premium plans). Verification is reviewed within 24 hours.'),
    ('How do I reset my password?', 'Account',
     'On the sign-in screen, tap "Forgot password?" and enter your email. A reset link will be sent within a few minutes.'),
    ('How do I delete my account?', 'Account',
     'Go to Profile → Settings → Account → Delete Account. This action is permanent and all listings will be removed.'),
    // Safety
    ('What should I do if I suspect a scam?', 'Safety',
     'Do not send any money or personal documents. Tap the flag icon on any listing or agent profile to report. Contact our support team at hello@propsure.africa immediately.'),
    ('Is my personal information safe?', 'Safety',
     'Yes. We follow strict data protection standards. We never share your phone number or personal details with third parties without your consent. Read our Privacy Policy for full details.'),
  ];

  List<(String, String, String)> get _filtered {
    if (_search.isEmpty) return _faqs;
    final q = _search.toLowerCase();
    return _faqs.where((f) =>
      f.$1.toLowerCase().contains(q) ||
      f.$3.toLowerCase().contains(q) ||
      f.$2.toLowerCase().contains(q)).toList();
  }

  static const _categories = ['All', 'Listings', 'Tenants', 'Payments', 'Account', 'Safety'];
  String _selectedCat = 'All';

  List<(String, String, String)> get _display {
    final base = _filtered;
    if (_selectedCat == 'All') return base;
    return base.where((f) => f.$2 == _selectedCat).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary])),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.quiz_rounded, color: Colors.white, size: 36),
                      const SizedBox(height: 10),
                      Text('Frequently Asked Questions',
                          style: GoogleFonts.syne(fontSize: 22,
                              fontWeight: FontWeight.w800, color: Colors.white)),
                      const Text('Find answers to common questions',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                )),
              ),
            ),
          ),
          SliverToBoxAdapter(child: Column(children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _ctrl,
                onChanged: (v) => setState(() { _search = v; _openIndex = null; }),
                decoration: InputDecoration(
                  hintText: 'Search questions...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.text3),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.close_rounded),
                          onPressed: () { _ctrl.clear(); setState(() { _search = ''; _openIndex = null; }); })
                      : null,
                ),
              ),
            ),
            // Category chips
            SizedBox(height: 40, child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: _categories.map((c) {
                final on = c == _selectedCat;
                return GestureDetector(
                  onTap: () => setState(() { _selectedCat = c; _openIndex = null; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(right: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: on ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: on ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(c, style: TextStyle(
                      fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? Colors.white : AppColors.text2)),
                  ),
                );
              }).toList(),
            )),
            const SizedBox(height: 8),
          ])),
          _display.isEmpty
            ? SliverToBoxAdapter(child: Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  const Icon(Icons.search_off_rounded, size: 48, color: AppColors.text3),
                  const SizedBox(height: 12),
                  Text('No results for "$_search"',
                      style: const TextStyle(color: AppColors.text2)),
                ]),
              )))
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final faq = _display[i];
                    final isOpen = _openIndex == i;
                    return GestureDetector(
                      onTap: () => setState(() => _openIndex = isOpen ? null : i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: isOpen ? AppColors.primary : AppColors.border,
                            width: isOpen ? 1.5 : 1),
                          boxShadow: isOpen ? [BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 8)] : null,
                        ),
                        child: Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            child: Row(children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: isOpen ? AppColors.primary : AppColors.primaryPale,
                                  borderRadius: BorderRadius.circular(7)),
                                child: Icon(
                                  isOpen ? Icons.remove_rounded : Icons.add_rounded,
                                  size: 16, color: isOpen ? Colors.white : AppColors.primary),
                              ),
                              const SizedBox(width: 11),
                              Expanded(child: Text(faq.$1,
                                style: TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600,
                                  color: isOpen ? AppColors.primary : AppColors.text))),
                            ]),
                          ),
                          if (isOpen) Padding(
                            padding: const EdgeInsets.fromLTRB(52, 0, 14, 14),
                            child: Text(faq.$3,
                              style: const TextStyle(
                                fontSize: 13, color: AppColors.text2, height: 1.6)),
                          ),
                        ]),
                      ),
                    );
                  },
                  childCount: _display.length,
                )),
              ),
        ],
      ),
    );
  }
}
