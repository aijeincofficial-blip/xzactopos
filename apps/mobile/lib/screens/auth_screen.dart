import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart' show LanguageButton;
import '../backend.dart';
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
        title: Text(t.forgotTitle),
        content: TextField(
          key: const Key('forgot-email'),
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: t.email),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(key: const Key('forgot-send'), onPressed: () => Navigator.pop(ctx, true), child: Text(t.forgotSend)),
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
        final hasSession =
            await widget.backend.signUp(_email.text.trim(), _password.text);
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
    return Scaffold(
      appBar: AppBar(title: Text(t.appTitle), actions: const [LanguageButton()]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: t.email),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? t.errRequired : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: t.password),
                    validator: (v) =>
                        (v == null || v.length < 6) ? t.errPasswordShort : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_newUser ? t.signUp : t.signIn),
                  ),
                  TextButton(
                    onPressed:
                        _busy ? null : () => setState(() => _newUser = !_newUser),
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
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_message!, textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
