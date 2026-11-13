import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../app.dart' show LanguageButton;
import '../backend.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/app_localizations.dart';

class StoreNameScreen extends StatefulWidget {
  const StoreNameScreen({
    super.key,
    required this.backend,
    required this.locale,
    required this.onDone,
  });
  final Backend backend;
  final String locale;
  final VoidCallback onDone;

  @override
  State<StoreNameScreen> createState() => _StoreNameScreenState();
}

class _StoreNameScreenState extends State<StoreNameScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  // Generated once so a retry after a flaky connection reuses the same ids.
  final _tenantId = const Uuid().v7();
  final _locationId = const Uuid().v7();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.backend.provisionSoloStore(
        tenantId: _tenantId,
        locationId: _locationId,
        storeName: _name.text.trim(),
        locale: widget.locale,
      );
      widget.onDone();
    } on PostgrestException catch (e) {
      if (e.hint == 'user_has_tenant') {
        widget.onDone();
      } else if (mounted) {
        setState(() => _error = t.errGeneric);
      }
    } catch (_) {
      if (mounted) setState(() => _error = t.errGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          const LanguageButton(),
          TextButton(onPressed: widget.backend.signOut, child: Text(t.signOut)),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Gap.l),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AppCard(
              padding: const EdgeInsets.all(Gap.xl),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t.nameYourStore,
                      style: NightMarketText.display(context, size: 24),
                    ),
                    const SizedBox(height: Gap.l),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(hintText: t.storeNameHint),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? t.errRequired : null,
                    ),
                    const SizedBox(height: Gap.l),
                    LimeButton(
                      label: t.startSelling,
                      height: 52,
                      onPressed: _busy ? null : _submit,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.s),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
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
