import 'package:flutter/material.dart';

import '../backend.dart';
import '../l10n/app_localizations.dart';

/// Shown after the user opened the reset link in their email: choose a new password.
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key, required this.backend, required this.onDone});
  final Backend backend;
  final VoidCallback onDone;

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _pw = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.backend.updatePassword(_pw.text);
      if (mounted) widget.onDone();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context).errGeneric;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.newPasswordTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  key: const Key('new-password'),
                  controller: _pw,
                  obscureText: true,
                  decoration: InputDecoration(labelText: t.newPassword),
                  validator: (v) => (v == null || v.length < 6) ? t.errPasswordShort : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('new-password-again'),
                  controller: _again,
                  obscureText: true,
                  decoration: InputDecoration(labelText: t.confirmPassword),
                  validator: (v) => v != _pw.text ? t.passwordsDiffer : null,
                ),
                const SizedBox(height: 20),
                FilledButton(key: const Key('save-password'), onPressed: _busy ? null : _save, child: Text(t.save)),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, textAlign: TextAlign.center)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Signed-in user changes their own password.
Future<void> showChangePasswordDialog(BuildContext context, Backend backend) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final pw = TextEditingController();
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(t.changePassword),
        content: TextField(
          key: const Key('change-password-field'),
          controller: pw,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: t.newPassword, errorText: error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('change-password-save'),
            onPressed: () {
              if (pw.text.length < 6) {
                setState(() => error = t.errPasswordShort);
              } else {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(t.save),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  try {
    await backend.updatePassword(pw.text);
    messenger.showSnackBar(SnackBar(content: Text(t.passwordSaved)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(t.errGeneric)));
  }
}
