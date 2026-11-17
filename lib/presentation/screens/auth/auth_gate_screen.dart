import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

enum _Step { method, code, setup, emailCreate, reset }

/// Sign in / create account, with the phone-code and account-setup states
/// from the mockups. Browsing never requires an account; [reason] explains
/// why sign-in is being asked for ("Sign in to save this home").
class AuthGateScreen extends ConsumerStatefulWidget {
  final String? redirectAfter;
  final String? reason;
  const AuthGateScreen({super.key, this.redirectAfter, this.reason});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  _Step _step = _Step.method;
  int _method = 0; // 0 phone, 1 email
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _city = TextEditingController(text: 'Abuja');
  final _code = TextEditingController();
  String _role = 'tenant';
  bool _alerts = false;
  bool _busy = false;
  String? _error;
  String? _verificationId;
  String _fullPhone = '';
  int _resend = 0;

  @override
  void dispose() {
    for (final c in [_phone, _email, _password, _name, _city, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _contextLine {
    switch (widget.reason) {
      case 'save':
        return 'Sign in to save this home.';
      case 'list':
        return 'Sign in to list your property.';
      case 'message':
        return 'Sign in to message the agent.';
      default:
        return 'Save homes and speak with agents.';
    }
  }

  String _normalisePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('234')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return '+234$d';
  }

  String _masked(String p) => p.length > 8 ? '${p.substring(0, 8)} *** ${p.substring(p.length - 4)}' : p;

  void _tick() async {
    _resend = 30;
    while (mounted && _resend > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _resend--);
    }
  }

  Future<void> _sendCode() async {
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      setState(() => _error = 'Enter your 10-digit Nigerian mobile number.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    _fullPhone = _normalisePhone(_phone.text);
    await ref.read(authServiceProvider).sendOTP(
      phoneNumber: _fullPhone,
      onCodeSent: (id) {
        if (!mounted) return;
        setState(() { _verificationId = id; _step = _Step.code; _busy = false; _code.clear(); });
        _tick();
      },
      onError: (e) {
        if (!mounted) return;
        setState(() { _busy = false; _error = e; });
      },
    );
  }

  Future<void> _verifyCode() async {
    if (_code.text.length != 6 || _verificationId == null) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final auth = ref.read(authServiceProvider);
    final r = await auth.verifyOTP(verificationId: _verificationId!, otp: _code.text);
    if (!mounted) return;
    if (!r.success) {
      setState(() { _busy = false; _error = r.error; });
      return;
    }
    await _afterSignIn(r.uid!);
  }

  Future<void> _emailSubmit({required bool create}) async {
    if (!_email.text.contains('@') || _password.text.length < 8) {
      setState(() => _error = 'Enter a valid email and a password of at least 8 characters.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final auth = ref.read(authServiceProvider);
    final r = create
        ? await auth.createAccountWithEmail(email: _email.text, password: _password.text)
        : await auth.signInWithEmail(email: _email.text, password: _password.text);
    if (!mounted) return;
    if (!r.success) {
      setState(() { _busy = false; _error = r.error; });
      return;
    }
    await _afterSignIn(r.uid!);
  }

  Future<void> _afterSignIn(String uid) async {
    final exists = await ref.read(authServiceProvider).userProfileExists(uid);
    if (!mounted) return;
    if (exists) {
      _done();
    } else {
      setState(() { _busy = false; _step = _Step.setup; });
    }
  }

  Future<void> _finishSetup() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final uid = ref.read(authServiceProvider).currentUser!.uid;
      await ref.read(authServiceProvider).createUserProfile(uid: uid, name: _name.text.trim(), role: _role);
      if (mounted) _done();
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'We could not save your details. Check your connection and try again.'; });
    }
  }

  void _done() {
    final to = widget.redirectAfter;
    context.go(to != null && to.isNotEmpty ? to : (_role == 'tenant' ? '/home' : '/workspace'));
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.code:
        return _codeView();
      case _Step.setup:
        return _setupView();
      case _Step.reset:
        return _resetView();
      default:
        return _methodView();
    }
  }

  Widget _errorLine() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(liveRegion: true, child: Text(_error!, style: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600))),
        );

  Widget _legal() => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('By continuing you agree to the ', style: AppText.caption),
          PsLink('Terms', onTap: () => context.push('/legal/terms'), underline: true),
          Text(' and ', style: AppText.caption),
          PsLink('Privacy Policy', onTap: () => context.push('/legal/privacy'), underline: true),
        ]),
      );

  Widget _methodView() {
    final creating = _step == _Step.emailCreate;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(padding: EdgeInsets.zero, children: [
        PsGreenHeader(
          padding: const EdgeInsets.fromLTRB(12, 0, 24, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PsTopBar(dark: true, onBack: () => context.canPop() ? context.pop() : context.go('/home')),
            const Padding(padding: EdgeInsets.only(left: 12, top: 4), child: PropsureLogo(light: true, size: 32)),
          ]),
        ),
        Padding(
          padding: kPagePadding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 28),
            Text(creating ? 'Create account' : 'Welcome back', textAlign: TextAlign.center, style: AppText.display.copyWith(color: AppColors.primary)),
            const SizedBox(height: 8),
            Text(_contextLine, textAlign: TextAlign.center, style: AppText.bodyMuted),
            const SizedBox(height: 24),
            if (!creating) PsSegmented(labels: const ['Phone', 'Email'], index: _method, onChanged: (i) => setState(() { _method = i; _error = null; })),
            const SizedBox(height: 20),
            if (_method == 0 && !creating) ...[
              PsField(
                label: 'Phone number',
                controller: _phone,
                keyboardType: TextInputType.phone,
                hint: '812 345 6789',
                autofillHints: const [AutofillHints.telephoneNumberNational],
                formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(13)],
                prefix: const Padding(padding: EdgeInsets.only(left: 14, right: 8), child: Center(widthFactor: 1, child: Text('🇳🇬  +234', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
                helper: 'Used for account security. Marketing is optional.',
              ),
              _errorLine(),
              const SizedBox(height: 16),
              PsButton('Send verification code', trailingIcon: Icons.arrow_forward_rounded, loading: _busy, onPressed: _sendCode),
              const SizedBox(height: 16),
              const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or')), Expanded(child: Divider())]),
              const SizedBox(height: 16),
              PsButton('Continue with email', kind: PsButtonKind.outline, icon: Icons.mail_outline_rounded, onPressed: () => setState(() { _method = 1; _error = null; })),
            ] else ...[
              PsField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, hint: 'you@example.com', autofillHints: const [AutofillHints.email]),
              const SizedBox(height: 16),
              PsField(label: 'Password', controller: _password, obscure: true, hint: 'At least 8 characters', autofillHints: const [AutofillHints.password]),
              _errorLine(),
              const SizedBox(height: 16),
              PsButton(creating ? 'Create account' : 'Sign in', loading: _busy, onPressed: () => _emailSubmit(create: creating)),
              if (!creating) Align(alignment: Alignment.centerRight, child: PsLink('Forgot password?', onTap: () => setState(() { _step = _Step.reset; _error = null; }))),
            ],
            const SizedBox(height: 16),
            Center(
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(creating ? 'Already registered? ' : 'New here? ', style: AppText.small),
                PsLink(creating ? 'Sign in' : 'Create account', underline: false, onTap: () => setState(() { _step = creating ? _Step.method : _Step.emailCreate; _method = 1; _error = null; })),
              ]),
            ),
            Center(child: PsLink('Continue browsing', chevron: true, underline: false, onTap: () => context.go('/home'))),
            _legal(),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }

  Widget _codeView() {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
          PsTopBar(dark: true, onBack: () => setState(() { _step = _Step.method; _error = null; })),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.shield_outlined, size: 34, color: AppColors.primary),
              const SizedBox(height: 12),
              Text('Check your messages', style: AppText.h1),
              const SizedBox(height: 8),
              Text('Enter the code sent to ${_masked(_fullPhone)}', style: AppText.bodyMuted),
              PsLink('Change number', onTap: () => setState(() { _step = _Step.method; _error = null; })),
              const SizedBox(height: 16),
              _CodeBoxes(controller: _code, onComplete: _verifyCode),
              _errorLine(),
              const SizedBox(height: 20),
              PsButton('Verify & continue', loading: _busy, onPressed: _verifyCode),
              const SizedBox(height: 8),
              Center(
                child: _resend > 0
                    ? Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text('Resend code in ${_resend}s', style: AppText.small))
                    : PsLink('Resend code', onTap: _sendCode),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Center(child: Text('Never share this code with an agent or anyone else.', textAlign: TextAlign.center, style: AppText.caption)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _setupView() {
    const roles = [
      ('tenant', Icons.home_outlined, 'Find a home', 'Search and discover properties'),
      ('landlord', Icons.description_outlined, 'List my property', 'Reach serious buyers and tenants'),
      ('agent', Icons.groups_outlined, 'Manage listings for clients', 'Tools for agents and professionals'),
    ];
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PsTopBar(onBack: () => ref.read(authServiceProvider).signOut().then((_) { if (mounted) setState(() => _step = _Step.method); }), action: Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('Setup', style: AppText.small)))),
      body: ListView(padding: kPagePadding, children: [
        Text('Make Propsure yours', style: AppText.display),
        const SizedBox(height: 8),
        Text('A few details help us show you the right properties and tools.', style: AppText.bodyMuted),
        const SizedBox(height: 24),
        PsField(label: 'Your name', controller: _name, hint: 'Your name', autofillHints: const [AutofillHints.givenName]),
        const SizedBox(height: 20),
        Text("I'm here to", style: AppText.label),
        const SizedBox(height: 10),
        Column(children: [
          for (final r in roles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                button: true,
                selected: _role == r.$1,
                label: '${r.$3}. ${r.$4}',
                excludeSemantics: true,
                child: PsCard(
                  onTap: () => setState(() => _role = r.$1),
                  color: _role == r.$1 ? AppColors.primaryPale : AppColors.card,
                  borderColor: _role == r.$1 ? AppColors.primary : AppColors.border,
                  child: Row(children: [
                    Icon(r.$2, size: 30, color: AppColors.primary),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.$3, style: AppText.title), Text(r.$4, style: AppText.small)])),
                    if (_role == r.$1) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                  ]),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text('Listing a property and managing client listings are different permissions. Neither gives you a verified status; checks are separate.', style: AppText.caption),
        const SizedBox(height: 20),
        PsField(label: 'Your location', controller: _city, prefix: const Icon(Icons.location_on_outlined)),
        const SizedBox(height: 8),
        PsToggleRow(title: 'Send useful property alerts', subtitle: 'You can change this later.', value: _alerts, onChanged: (v) => setState(() => _alerts = v)),
        _errorLine(),
        const SizedBox(height: 16),
        PsButton('Continue', loading: _busy, onPressed: _finishSetup),
        Center(child: PsLink('Skip for now', underline: false, onTap: () { if (_name.text.trim().length < 2) { _name.text = 'Propsure user'; } _finishSetup(); })),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _resetView() {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PsTopBar(title: 'Reset password', onBack: () => setState(() => _step = _Step.method)),
      body: ListView(padding: kPagePadding, children: [
        Text('Enter the email you registered with. If an account exists we will send a reset link.', style: AppText.bodyMuted),
        const SizedBox(height: 20),
        PsField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 20),
        PsButton('Send reset link', loading: _busy, onPressed: () async {
          setState(() => _busy = true);
          await ref.read(authServiceProvider).sendPasswordReset(email: _email.text);
          if (!mounted) return;
          setState(() { _busy = false; _step = _Step.method; });
          showPsSnack(context, 'If an account exists for that email, a reset link is on its way.');
        }),
      ]),
    );
  }
}

/// Six accessible code boxes backed by one hidden text field so paste,
/// autofill (SMS one-tap) and the numeric keypad all work.
class _CodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onComplete;
  const _CodeBoxes({required this.controller, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Six digit verification code',
      textField: true,
      child: Stack(children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, v, __) => Row(children: [
            for (var i = 0; i < 6; i++) ...[
              Expanded(
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: i == v.text.length ? AppColors.primary : AppColors.border, width: i == v.text.length ? 2 : 1),
                  ),
                  child: Text(i < v.text.length ? v.text[i] : '', style: AppText.h2),
                ),
              ),
              if (i < 5) const SizedBox(width: 8),
            ],
          ]),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) { if (v.length == 6) onComplete(); },
            ),
          ),
        ),
      ]),
    );
  }
}
