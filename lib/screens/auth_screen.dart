import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../core/localization.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loginMode = true;
  bool _busy = false;

  Future<void> _submit() async {
    if (_email.text.isEmpty || _pass.text.length < 6) {
      _snack('Enter a valid email and a 6+ character password.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_loginMode) {
        await _auth.signIn(_email.text, _pass.text);
      } else {
        await _auth.signUp(_email.text, _pass.text);
      }
    } catch (e) {
      _snack(_pretty(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      _snack(_pretty(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _pretty(Object e) {
    final s = e.toString();
    final i = s.indexOf(']');
    return i >= 0 ? s.substring(i + 1).trim() : s;
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                decoration: BoxDecoration(
                  gradient: AppColors.authCardGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.travel_explore,
                          size: 54, color: AppColors.primary),
                      const SizedBox(height: 10),
                      Text(context.t('app_name'),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                      const SizedBox(height: 4),
                      Text(context.t('tagline'),
                          style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: context.t('email'),
                          prefixIcon: const Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pass,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: context.t('password'),
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(_loginMode
                                  ? context.t('login')
                                  : context.t('signup')),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _loginMode = !_loginMode),
                        child: Text(_loginMode
                            ? context.t('need_account')
                            : context.t('have_account')),
                      ),
                      const Divider(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _google,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: Text(context.t('sign_in_google')),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
