import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/theme.dart';
import '../core/ui.dart';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(t.newPasswordTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.l),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AppCard(
              padding: const EdgeInsets.all(Gap.xxl),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CoinBadge(
                        icon: Icons.lock_reset_rounded,
                        color: scheme.primary,
                        size: 52,
                      ),
                    ),
                    const SizedBox(height: Gap.l),
                    TextFormField(
                      key: const Key('new-password'),
                      controller: _pw,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t.newPassword,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? t.errPasswordShort : null,
                    ),
                    const SizedBox(height: Gap.m),
                    TextFormField(
                      key: const Key('new-password-again'),
                      controller: _again,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: t.confirmPassword,
                        prefixIcon: const Icon(Icons.lock_clock_outlined, size: 20),
                      ),
                      validator: (v) => v != _pw.text ? t.passwordsDiffer : null,
                    ),
                    const SizedBox(height: Gap.xl),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('save-password'),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.obsidian,
                          foregroundColor: dark ? scheme.onPrimary : Colors.white,
                          shape: const StadiumBorder(),
                          elevation: 3,
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        onPressed: _busy ? null : _save,
                        child: Text(t.save),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.m),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusL)),
        title: Text(t.changePassword),
        content: TextField(
          key: const Key('change-password-field'),
          controller: pw,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: t.newPassword,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            errorText: error,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('change-password-save'),
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
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
