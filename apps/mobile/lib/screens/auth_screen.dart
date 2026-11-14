import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart' show LanguageButton;
import '../backend.dart';
import '../core/design_tokens.g.dart';
import '../core/theme.dart';
import '../core/theme_picker.dart';
import '../core/ui.dart';
import '../l10n/app_localizations.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.backend});
  final Backend backend;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _newUser = true;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _forgot() async {
    final t = AppLocalizations.of(context);
    final c = TextEditingController(text: _email.text.trim());
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusL)),
        title: Text(t.forgotTitle),
        content: TextField(
          key: const Key('forgot-email'),
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: t.email,
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('forgot-send'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.forgotSend),
          ),
        ],
      ),
    );
    final email = c.text.trim();
    if (send != true || email.isEmpty) return;
    try {
      await widget.backend.sendPasswordReset(email);
    } catch (_) {
      // same message either way: the screen must not reveal which emails have an account
    }
    if (mounted) setState(() => _message = t.forgotSent);
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_newUser) {
        final hasSession = await widget.backend.signUp(_email.text.trim(), _password.text);
        if (!hasSession && mounted) setState(() => _message = t.checkEmail);
      } else {
        await widget.backend.signIn(_email.text.trim(), _password.text);
      }
    } on AuthException {
      if (mounted) setState(() => _message = t.errBadLogin);
    } catch (_) {
      if (mounted) setState(() => _message = t.errGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: const [ThemeButton(), LanguageButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.l),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AppCard(
              padding: const EdgeInsets.all(Gap.xl),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        key: const Key('app-logo'),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: scheme.nmInk,
                          borderRadius: BorderRadius.circular(Gap.radiusL),
                          border: Border.all(color: scheme.nmLime.withValues(alpha: 0.65), width: Gap.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/brand/logo_squircle.png',
                            width: 56,
                            height: 56,
                            semanticLabel: 'XZACTO POS',
                            errorBuilder: (_, _, _) =>
                                const CoinBadge(icon: Icons.storefront_rounded, color: DesignTokens.lime, size: 52),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.m),
                    Text(
                      'XZACTO',
                      textAlign: TextAlign.center,
                      style: NightMarketText.display(context, size: 26, letterSpacing: -0.6),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: NightMarketDotTag(label: 'POS APP'),
                    ),
                    const SizedBox(height: Gap.l),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t.email,
                        helperText: t.loginHelper,
                        prefixIcon: const Icon(Icons.email_outlined, size: 19),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? t.errRequired : null,
                    ),
                    const SizedBox(height: Gap.m),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: t.password,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                      ),
                      validator: (v) => _newUser
                          ? ((v == null || v.length < 8) ? t.errPasswordShort : null)
                          : ((v == null || v.trim().isEmpty) ? t.errRequired : null),
                    ),
                    const SizedBox(height: Gap.l),
                    LimeButton(
                      label: _newUser ? t.signUp : t.signIn,
                      height: 52,
                      onPressed: _busy ? null : _submit,
                    ),
                    const SizedBox(height: Gap.s),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _newUser = !_newUser),
                      child: Text(_newUser ? t.haveAccount : t.noAccount),
                    ),
                    if (!_newUser)
                      TextButton(
                        key: const Key('forgot-password'),
                        onPressed: _busy ? null : _forgot,
                        child: Text(t.forgotPassword),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.s),
                        child: Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _message == t.errBadLogin || _message == t.errGeneric ? scheme.error : scheme.primary,
                            fontWeight: FontWeight.w600,
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
    );
  }
}
