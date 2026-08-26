import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../../services/auth_service.dart'; // AuthResult lives here

class AuthGateScreen extends ConsumerStatefulWidget {
  final String? redirectAfter;
  const AuthGateScreen({super.key, this.redirectAfter});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ── Phone state ────────────────────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  final _otpCtrls  = List.generate(6, (_) => TextEditingController());
  final _otpFocus  = List.generate(6, (_) => FocusNode());
  bool    _otpSent        = false;
  String? _verificationId;
  int     _resendTimer    = 60;

  // ── Email state ────────────────────────────────────────────────────────────
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _isRegister = false;
  bool _pwVisible  = false;

  // ── Shared ─────────────────────────────────────────────────────────────────
  bool    _isLoading    = false;
  bool    _needsProfile = false;
  String? _error;

  // ── Profile setup ──────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  String _role = 'tenant';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameCtrl.dispose();
    for (final c in _otpCtrls) { c.dispose(); }
    for (final f in _otpFocus)  { f.dispose(); }
    super.dispose();
  }

  // ── Phone auth ─────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final normalized = raw.startsWith('+234')
        ? raw.substring(4)
        : raw.startsWith('234')
            ? raw.substring(3)
            : raw;
    if (normalized.length != 10 && normalized.length != 11) {
      setState(() => _error = 'Enter a valid Nigerian phone number');
      return;
    }
    final local = normalized.startsWith('0') ? normalized.substring(1) : normalized;
    if (local.length != 10) {
      setState(() => _error = 'Enter a valid Nigerian phone number');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    final phone = '+234$local';
    await ref.read(authServiceProvider).sendOTP(
      phoneNumber: phone,
      onCodeSent: (vid) {
        setState(() {
          _verificationId = vid;
          _otpSent  = true;
          _isLoading = false;
        });
        _startTimer();
      },
      onError: (e) => setState(() { _error = e; _isLoading = false; }),
    );
  }

  void _startTimer() {
    _resendTimer = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendTimer--);
      return _resendTimer > 0;
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length != 6) return;
    setState(() { _isLoading = true; _error = null; });
    final auth   = ref.read(authServiceProvider);
    final result = await auth.verifyOTP(
        verificationId: _verificationId!, otp: otp);
    if (!mounted) return;
    if (result.success) {
      final exists = await auth.userProfileExists(result.uid!);
      if (!exists) {
        setState(() { _needsProfile = true; _isLoading = false; });
      } else {
        _finish();
      }
    } else {
      setState(() { _error = result.error; _isLoading = false; });
    }
  }

  // ── Email auth ─────────────────────────────────────────────────────────────
  Future<void> _emailAuth() async {
    final email = _emailCtrl.text.trim();
    final pw    = _passwordCtrl.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_isRegister && _confirmCtrl.text != pw) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    final auth = ref.read(authServiceProvider);
    final AuthResult result;

    if (_isRegister) {
      result = await auth.createAccountWithEmail(email: email, password: pw);
    } else {
      result = await auth.signInWithEmail(email: email, password: pw);
    }

    if (!mounted) return;
    if (result.success) {
      final exists = await auth.userProfileExists(result.uid!);
      if (!exists) {
        setState(() { _needsProfile = true; _isLoading = false; });
      } else {
        _finish();
      }
    } else {
      setState(() { _error = result.error; _isLoading = false; });
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() =>
          _error = 'Enter your email first, then tap Forgot Password');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    await ref.read(authServiceProvider).sendPasswordReset(email: email);
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Password reset email sent to $email'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Profile setup ──────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    await ref.read(authServiceProvider).createUserProfile(
        uid: uid, name: _nameCtrl.text.trim(), role: _role);
    if (mounted) _finish();
  }

  void _finish() {
    final r = widget.redirectAfter;
    if (r != null && r.isNotEmpty) {
      context.go(r);
    } else {
      context.go('/home');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: _needsProfile
                    ? _ProfileStep(
                        key: const ValueKey('profile'),
                        nameCtrl: _nameCtrl,
                        role: _role,
                        onRoleChanged: (r) => setState(() => _role = r),
                        onSubmit: _saveProfile,
                        isLoading: _isLoading,
                      )
                    : _otpSent
                        ? _OtpStep(
                            key: const ValueKey('otp'),
                            phone: _phoneCtrl.text,
                            ctrls: _otpCtrls,
                            focusNodes: _otpFocus,
                            onChanged: (v, i) {
                              if (v.isNotEmpty && i < 5) {
                                _otpFocus[i + 1].requestFocus();
                              }
                              if (v.isEmpty && i > 0) {
                                _otpFocus[i - 1].requestFocus();
                              }
                              if (i == 5 && v.isNotEmpty) _verifyOtp();
                            },
                            onVerify: _verifyOtp,
                            onResend: _sendOtp,
                            resendTimer: _resendTimer,
                            onChangeNumber: () =>
                                setState(() => _otpSent = false),
                            isLoading: _isLoading,
                            error: _error,
                          )
                        : _MainAuthView(
                            key: const ValueKey('main'),
                            tabCtrl: _tabCtrl,
                            phoneCtrl: _phoneCtrl,
                            onSendOtp: _sendOtp,
                            emailCtrl: _emailCtrl,
                            passwordCtrl: _passwordCtrl,
                            confirmCtrl: _confirmCtrl,
                            isRegister: _isRegister,
                            pwVisible: _pwVisible,
                            onToggleRegister: () => setState(() {
                              _isRegister = !_isRegister;
                              _error = null;
                            }),
                            onTogglePwVisible: () =>
                                setState(() => _pwVisible = !_pwVisible),
                            onEmailAuth: _emailAuth,
                            onForgotPassword: _forgotPassword,
                            isLoading: _isLoading,
                            error: _error,
                            redirectHint: widget.redirectAfter,
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MAIN AUTH VIEW ───────────────────────────────────────────────────────────
class _MainAuthView extends StatelessWidget {
  final TabController tabCtrl;
  final TextEditingController phoneCtrl;
  final VoidCallback onSendOtp;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final bool isRegister;
  final bool pwVisible;
  final VoidCallback onToggleRegister;
  final VoidCallback onTogglePwVisible;
  final VoidCallback onEmailAuth;
  final VoidCallback onForgotPassword;
  final bool isLoading;
  final String? error;
  final String? redirectHint;

  const _MainAuthView({
    super.key,
    required this.tabCtrl,
    required this.phoneCtrl,
    required this.onSendOtp,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.isRegister,
    required this.pwVisible,
    required this.onToggleRegister,
    required this.onTogglePwVisible,
    required this.onEmailAuth,
    required this.onForgotPassword,
    required this.isLoading,
    this.error,
    this.redirectHint,
  });

  String get _title {
    if (redirectHint?.contains('post') == true)    return 'Sign in to\nlist a property';
    if (redirectHint?.contains('chat') == true)    return 'Sign in to\nchat with agent';
    if (redirectHint?.contains('booking') == true) return 'Sign in to\nbook a tour';
    return 'Sign in or\ncreate account';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo row
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Center(
                child: Text('🏡', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 10),
          Text('Propsure',
              style: GoogleFonts.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 28),
        Text(_title,
            style: Theme.of(context)
                .textTheme
                .headlineLarge
                ?.copyWith(height: 1.2)),
        const SizedBox(height: 8),
        Text('No password needed for phone. Or use email & password.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),

        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: tabCtrl,
            indicator: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(9),
              boxShadow: AppShadows.sm,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.text3,
            labelStyle:
                GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(icon: Icon(Icons.phone_outlined, size: 16), text: 'Phone'),
              Tab(icon: Icon(Icons.email_outlined,  size: 16), text: 'Email'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tab content
        SizedBox(
          height: isRegister ? 360 : 300,
          child: TabBarView(
            controller: tabCtrl,
            children: [
              _PhoneTabContent(
                ctrl: phoneCtrl,
                onSend: onSendOtp,
                isLoading: isLoading,
                error: tabCtrl.index == 0 ? error : null,
              ),
              _EmailTabContent(
                emailCtrl: emailCtrl,
                passwordCtrl: passwordCtrl,
                confirmCtrl: confirmCtrl,
                isRegister: isRegister,
                pwVisible: pwVisible,
                onToggleRegister: onToggleRegister,
                onTogglePwVisible: onTogglePwVisible,
                onSubmit: onEmailAuth,
                onForgotPassword: onForgotPassword,
                isLoading: isLoading,
                error: tabCtrl.index == 1 ? error : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'By continuing you agree to our Terms & Privacy Policy',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ─── PHONE TAB ────────────────────────────────────────────────────────────────
class _PhoneTabContent extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final bool isLoading;
  final String? error;
  const _PhoneTabContent({
    required this.ctrl,
    required this.onSend,
    required this.isLoading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Text('+234',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.text)),
          ),
          Container(width: 1, height: 24, color: AppColors.border),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0812 345 6789',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                filled: false,
              ),
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
            ),
          ),
        ]),
      ),
      if (error != null) ...[const SizedBox(height: 10), _ErrorBox(error!)],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onSend,
          icon: isLoading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sms_outlined, size: 18),
          label: Text(isLoading ? 'Sending…' : 'Send Verification Code'),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Icons.shield_outlined, size: 13, color: AppColors.text3),
        const SizedBox(width: 5),
        Text('Your number is never shared with third parties.',
            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
      ]),
    ]);
  }
}

// ─── EMAIL TAB ────────────────────────────────────────────────────────────────
class _EmailTabContent extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final bool isRegister;
  final bool pwVisible;
  final VoidCallback onToggleRegister;
  final VoidCallback onTogglePwVisible;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final bool isLoading;
  final String? error;

  const _EmailTabContent({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.isRegister,
    required this.pwVisible,
    required this.onToggleRegister,
    required this.onTogglePwVisible,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.isLoading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Toggle: Sign In / Create Account
        Row(children: [
          _AuthToggleChip(
            label: 'Sign In',
            selected: !isRegister,
            onTap: isRegister ? onToggleRegister : null,
          ),
          const SizedBox(width: 8),
          _AuthToggleChip(
            label: 'Create Account',
            selected: isRegister,
            onTap: !isRegister ? onToggleRegister : null,
          ),
        ]),
        const SizedBox(height: 14),

        // Email
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'you@example.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
        ),
        const SizedBox(height: 10),

        // Password
        TextField(
          controller: passwordCtrl,
          obscureText: !pwVisible,
          textInputAction:
              isRegister ? TextInputAction.next : TextInputAction.done,
          onSubmitted: isRegister ? null : (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: isRegister ? 'Min. 6 characters' : '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(pwVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: onTogglePwVisible,
            ),
          ),
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
        ),

        // Confirm password
        if (isRegister) ...[
          const SizedBox(height: 10),
          TextField(
            controller: confirmCtrl,
            obscureText: !pwVisible,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              hintText: 'Re-enter password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
          ),
        ],

        if (error != null) ...[
          const SizedBox(height: 10),
          _ErrorBox(error!),
        ],

        const SizedBox(height: 16),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(isRegister ? 'Create Account →' : 'Sign In →'),
          ),
        ),

        // Forgot password
        if (!isRegister) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgotPassword,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('Forgot password?',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.primary)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _AuthToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _AuthToggleChip(
      {required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.text2,
            )),
      ),
    );
  }
}

// ─── OTP STEP ─────────────────────────────────────────────────────────────────
class _OtpStep extends StatelessWidget {
  final String phone;
  final List<TextEditingController> ctrls;
  final List<FocusNode> focusNodes;
  final void Function(String, int) onChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final int resendTimer;
  final VoidCallback onChangeNumber;
  final bool isLoading;
  final String? error;

  const _OtpStep({
    super.key,
    required this.phone,
    required this.ctrls,
    required this.focusNodes,
    required this.onChanged,
    required this.onVerify,
    required this.onResend,
    required this.resendTimer,
    required this.onChangeNumber,
    required this.isLoading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryPale,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryPale2),
        ),
        child: Row(children: [
          const Icon(Icons.sms_outlined,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text('Code sent to +234 $phone',
                  style: GoogleFonts.outfit(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12))),
          GestureDetector(
            onTap: onChangeNumber,
            child: Text('Change',
                style: GoogleFonts.outfit(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      Text('Enter your code',
          style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 6),
      Text('6-digit SMS code',
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
            6,
            (i) => _OtpBox(
                  ctrl: ctrls[i],
                  focus: focusNodes[i],
                  onChanged: (v) => onChanged(v, i),
                )),
      ),
      if (error != null) ...[
        const SizedBox(height: 12),
        _ErrorBox(error!),
      ],
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: isLoading ? null : onVerify,
          child: isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Verify & Continue'),
        ),
      ),
      const SizedBox(height: 14),
      Center(
        child: resendTimer > 0
            ? Text('Resend in ${resendTimer}s',
                style: Theme.of(context).textTheme.bodySmall)
            : TextButton(
                onPressed: onResend,
                child: const Text('Resend Code')),
      ),
    ]);
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  const _OtpBox(
      {required this.ctrl,
      required this.focus,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46, height: 58,
      child: TextField(
        controller: ctrl,
        focusNode: focus,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        onChanged: onChanged,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.syne(
            fontSize: 22, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

// ─── PROFILE SETUP STEP ───────────────────────────────────────────────────────
class _ProfileStep extends StatelessWidget {
  final TextEditingController nameCtrl;
  final String role;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSubmit;
  final bool isLoading;

  const _ProfileStep({
    super.key,
    required this.nameCtrl,
    required this.role,
    required this.onRoleChanged,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    const roles = [
      ('tenant',   '🔍', 'Tenant'),
      ('agent',    '🏷', 'Agent'),
      ('landlord', '🏠', 'Landlord'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('👋', style: TextStyle(fontSize: 36)),
      const SizedBox(height: 16),
      Text('Quick setup',
          style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 6),
      Text('One step to personalise your experience.',
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 24),
      TextField(
        controller: nameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Your Name',
          prefixIcon: Icon(Icons.person_outline),
        ),
      ),
      const SizedBox(height: 20),
      Text('I am a…',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      Row(
        children: roles.map((r) {
          final (id, icon, label) = r;
          final sel = role == id;
          return Expanded(
            child: GestureDetector(
              onTap: () => onRoleChanged(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primaryPale
                      : AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel
                        ? AppColors.primary
                        : AppColors.border,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Column(children: [
                  Text(icon,
                      style:
                          const TextStyle(fontSize: 22)),
                  const SizedBox(height: 5),
                  Text(label,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? AppColors.primary
                            : AppColors.text2,
                      )),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: isLoading ? null : onSubmit,
          child: isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white))
              : const Text("Let's Go →"),
        ),
      ),
    ]);
  }
}

// ─── ERROR BOX ────────────────────────────────────────────────────────────────
class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox(this.msg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline,
            color: AppColors.error, size: 15),
        const SizedBox(width: 7),
        Expanded(
            child: Text(msg,
                style: GoogleFonts.outfit(
                    color: AppColors.error, fontSize: 12))),
      ]),
    );
  }
}
