// lib/features/auth/login_screen.dart
// FR-1: Email magic-link + Phone OTP + Google OAuth (all via supabase_flutter).
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../core/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  Future<void> _emailLink() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      _snack('أدخل بريداً إلكترونياً صحيحاً');
      return;
    }
    setState(() => _loading = true);
    try {
      // Magic link (email OTP-like). RLS-protected; anon client only.
      await supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: '$kDeepLinkScheme://$kDeepLinkHost/auth',
      );
      _snack('تم إرسال رابط الدخول إلى بريدك الإلكتروني');
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('تعذّر الإرسال: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _phoneSend() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _snack('أدخل رقم هاتفك (مع رمز الدولة، مثال: +216...)');
      return;
    }
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithOtp(
        phone: phone,
        channel: OtpChannel.sms,
      );
      setState(() => _otpSent = true);
      _snack('أدخل الرمز المرسل إلى هاتفك');
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('تعذّر الإرسال: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _phoneVerify() async {
    final phone = _phoneCtrl.text.trim();
    final token = _otpCtrl.text.trim();
    if (token.length < 4) {
      _snack('أدخل الرمز كاملاً');
      return;
    }
    setState(() => _loading = true);
    try {
      await supabase.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      // Router redirects to onboarding/home automatically.
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('تعذّر التحقق: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      // PKCE/OAuth flow; deep-link callback handled by AndroidManifest intent-filter.
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: '$kDeepLinkScheme://$kDeepLinkHost/auth',
      );
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('تعذّر الدخول عبر Google: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.search_rounded, size: 72, color: AppColors.brand),
              const SizedBox(height: 12),
              const Text('راجع', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const Text('راجع… لأن صاحبها أحق بيها', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 24),
              TabBar(
                controller: _tab,
                labelColor: AppColors.brand,
                tabs: const [Tab(text: 'بريد إلكتروني'), Tab(text: 'رقم هاتف')],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    // EMAIL
                    Column(
                      children: [
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _loading
                            ? const CircularProgressIndicator()
                            : FilledButton(
                                onPressed: _emailLink,
                                child: const Text('إرسال رابط الدخول'),
                              ),
                      ],
                    ),
                    // PHONE
                    Column(
                      children: [
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          enabled: !_otpSent,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف (مثال: +21620123456)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_otpSent) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                              labelText: 'الرمز المكوّن من 6 أرقام',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _loading
                            ? const CircularProgressIndicator()
                            : FilledButton(
                                onPressed: _otpSent ? _phoneVerify : _phoneSend,
                                child: Text(_otpSent ? 'تأكيد الرمز' : 'إرسال الرمز'),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _google,
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('المتابعة عبر Google'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
