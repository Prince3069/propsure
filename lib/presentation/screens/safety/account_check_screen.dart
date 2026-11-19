import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../../services/functions_service.dart';
import '../../providers/actions.dart';
import '../../providers/app_providers.dart';

/// Check before you pay: ask the bank who owns the account an agent gave you
/// and compare it with the agent's name on Propsure. It checks a NAME only.
/// It is not a guarantee about the home or the person.
class AccountCheckScreen extends ConsumerStatefulWidget {
  final String? listingId;
  const AccountCheckScreen({super.key, this.listingId});
  @override
  ConsumerState<AccountCheckScreen> createState() => _AccountCheckState();
}

class _AccountCheckState extends ConsumerState<AccountCheckScreen> {
  final _acct = TextEditingController();
  BankOption? _bank;
  bool _busy = false;
  String? _error;
  AccountCheckResult? _result;

  @override
  void dispose() {
    _acct.dispose();
    super.dispose();
  }

  bool get _ready => _bank != null && RegExp(r'^\d{10}$').hasMatch(_acct.text.trim());

  Future<void> _pickBank(List<BankOption> banks) async {
    final picked = await showModalBottomSheet<BankOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      builder: (_) => _BankSheet(banks: banks),
    );
    if (picked != null) setState(() => _bank = picked);
  }

  Future<void> _check() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(functionsServiceProvider).checkAccountName(
            listingId: widget.listingId,
            bankCode: _bank!.code,
            accountNumber: _acct.text.trim(),
          );
      if (!mounted) return;
      setState(() => _result = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listingId == null ? null : ref.watch(listingByIdProvider(widget.listingId!)).asData?.value;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PsTopBar(title: _result == null ? 'Check before you pay' : 'Result'),
      body: _result != null ? _resultView(_result!, listing) : _form(),
    );
  }

  Widget _form() {
    final banks = ref.watch(banksProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 32), children: [
      PsCard(
        color: AppColors.primaryPale,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Who owns this account?', style: AppText.title),
            const SizedBox(height: 4),
            Text('Enter the bank and account number the agent gave you. We ask the bank for the name on the account.', style: AppText.small),
          ])),
        ]),
      ),
      const SizedBox(height: 18),
      Text('Bank', style: AppText.label),
      const SizedBox(height: 8),
      banks.when(
        loading: () => const PsSkeleton(height: 56),
        error: (e, _) => PsError(details: e, onRetry: () => ref.invalidate(banksProvider)),
        data: (list) => Semantics(
          button: true,
          label: 'Choose bank',
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => _pickBank(list),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Expanded(child: Text(_bank?.name ?? 'Choose a bank', style: AppText.body.copyWith(color: _bank == null ? AppColors.text3 : AppColors.text))),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      PsField(
        label: 'Account number',
        controller: _acct,
        hint: '10 digits',
        keyboardType: TextInputType.number,
        maxLength: 10,
        formatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() => _error = null),
        errorText: _error,
      ),
      const SizedBox(height: 20),
      PsButton('Check the name', loading: _busy, onPressed: _ready && !_busy ? _check : null),
      const SizedBox(height: 16),
      const PsNote('We never ask for your PIN, card details or password, and Propsure does not hold your money.', icon: Icons.lock_outline_rounded),
    ]);
  }

  Widget _resultView(AccountCheckResult r, ListingModel? listing) {
    final match = r.verdict == 'match';
    final different = r.verdict == 'different';
    final title = match ? 'The names match' : different ? 'The names are different' : 'Name on the account';
    final tone = match ? PsTone.success : different ? PsTone.warning : PsTone.neutral;
    final icon = match ? Icons.verified_user_outlined : different ? Icons.warning_amber_rounded : Icons.info_outline_rounded;
    final color = match ? AppColors.primary : different ? AppColors.goldDark : AppColors.text2;
    final agentLabel = r.agentIdChecked ? 'Agent’s ID-checked name' : 'Agent’s name on Propsure';
    final advice = match
        ? '${r.matchedOn == 'agency' ? 'The account is in the name of the agent’s agency. ' : ''}Still confirm the amount and what it covers, and ask for a receipt.'
        : different
            ? 'This can be normal, for example a registered business. Ask the agent to explain, and ask for a receipt, before you pay.'
            : 'Make sure this is the name you expect before you pay.';
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 32), children: [
      PsCard(
        color: different ? AppColors.goldLight : AppColors.card,
        borderColor: match ? AppColors.primary : different ? AppColors.gold : AppColors.border,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: color, size: 34), const SizedBox(width: 12), Expanded(child: Text(title, style: AppText.h2))]),
          const Divider(height: 28),
          Text('Name on the account', style: AppText.small),
          const SizedBox(height: 2),
          Text(r.accountName, style: AppText.h2),
          if (r.agentName != null) ...[
            const SizedBox(height: 14),
            Text(agentLabel, style: AppText.small),
            const SizedBox(height: 2),
            Text(r.agentName!, style: AppText.title.copyWith(fontSize: 18)),
            if (r.agencyName != null && r.agencyName!.isNotEmpty) Text(r.agencyName!, style: AppText.small),
          ],
          const SizedBox(height: 14),
          Text(advice, style: AppText.body),
        ]),
      ),
      const SizedBox(height: 12),
      PsPill(match ? 'Names match' : different ? 'Names differ' : 'Bank name only', tone: tone, small: true),
      const SizedBox(height: 12),
      const PsNote('This checks a name only. It is not a guarantee about the home or the person.'),
      const SizedBox(height: 16),
      if (listing != null) ...[
        PsButton('Message the agent', kind: PsButtonKind.outline, icon: Icons.chat_bubble_outline_rounded, onPressed: () => openChatAbout(context, ref, listing, prefill: 'Hello, I checked the account you gave me and the name is ${r.accountName}. Can you confirm it is yours?')),
        const SizedBox(height: 10),
      ],
      if (widget.listingId != null) ...[
        PsButton('Report a concern', kind: PsButtonKind.ghost, icon: Icons.flag_outlined, onPressed: () => context.push('/listing/${widget.listingId}/report')),
        const SizedBox(height: 10),
      ],
      PsButton('Check another account', kind: PsButtonKind.ghost, onPressed: () => setState(() {
            _result = null;
            _acct.clear();
          })),
    ]);
  }
}

class _BankSheet extends StatefulWidget {
  final List<BankOption> banks;
  const _BankSheet({required this.banks});
  @override
  State<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends State<_BankSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.banks.where((b) => b.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: PsField(label: 'Search banks', hint: 'For example GTBank', prefix: const Icon(Icons.search_rounded), onChanged: (v) => setState(() => _q = v)),
            ),
            Flexible(
              child: list.isEmpty
                  ? Padding(padding: const EdgeInsets.all(24), child: Text('No bank matches that name.', style: AppText.bodyMuted))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) => ListTile(minTileHeight: 52, title: Text(list[i].name, style: AppText.body), onTap: () => Navigator.of(context).pop(list[i])),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
