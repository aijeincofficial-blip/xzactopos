import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/theme.dart';
import '../data/staff_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_engine.dart' show AuthExpired;

/// Why the server refused a staff call, in words for the owner.
String staffErrorText(AppLocalizations t, Object e) {
  if (e is StaffOffline) return t.staffOffline;
  if (e is StaffException) {
    return switch (e.hint) {
      'duplicate' || 'username_taken' => t.staffErrDuplicate,
      'invalid_argument' || 'invalid_value' => t.staffErrInvalid,
      'create_denied' || 'manage_denied' || 'forbidden' || 'location_denied' || 'not_allowed' => t.staffErrDenied,
      'self_deactivate' => t.staffErrSelf,
      'limit_users' => t.staffErrLimit,
      _ => t.errGeneric,
    };
  }
  return t.errGeneric;
}

String _roleName(AppLocalizations t, String role) => switch (role) {
      'superadmin' => t.staffRoleSuperadmin,
      'admin' => t.staffRoleAdmin,
      'warehouse' => t.staffRoleWarehouse,
      _ => t.staffRoleCashier,
    };

typedef _StaffData = ({List<StaffMember> people, String slug});

/// Staff list: who works here, add a cashier, switch a person off or on. Online only (More > Staff).
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key, required this.backend});
  final Backend backend;

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late Future<_StaffData> _load = _fetch();
  String? _message;

  StaffApi? get _api => widget.backend is StaffApi ? widget.backend as StaffApi : null;

  Future<_StaffData> _fetch() async {
    final api = _api;
    if (api == null) throw const StaffOffline();
    final people = await api.listStaff();
    final access = await widget.backend.myAccess();
    final slug = ((access?['tenant'] as Map?)?['slug'] as String?) ?? '';
    return (people: people, slug: slug);
  }

  void _reload() {
    setState(() {
      _load = _fetch();
    });
  }

  Future<void> _run(Future<void> Function() act, {String? done}) async {
    final t = AppLocalizations.of(context);
    try {
      await act();
      if (!mounted) return;
      setState(() => _message = done);
      _reload();
    } on AuthExpired {
      rethrow;
    } catch (e) {
      if (mounted) setState(() => _message = staffErrorText(t, e));
    }
  }

  Future<void> _add(String slug) async {
    final api = _api!;
    final t = AppLocalizations.of(context);
    List<StaffStore> stores;
    try {
      stores = await api.listStores();
    } catch (e) {
      if (mounted) setState(() => _message = staffErrorText(t, e));
      return;
    }
    if (!mounted) return;
    final made = await showModalBottomSheet<({String username, String name})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSheet(api: api, stores: stores),
    );
    if (made == null || !mounted) return;
    setState(() => _message = t.staffCreated(made.name, staffLogin(made.username, slug)));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final me = widget.backend.userId;
    final isOwner = CatalogScope.maybeOf(context)?.role != 'admin';
    return Scaffold(
      appBar: AppBar(title: Text(t.staffTitle)),
      body: FutureBuilder<_StaffData>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.xl),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(staffErrorText(t, snap.error!), key: const Key('staff-error'), textAlign: TextAlign.center),
                  TextButton(key: const Key('staff-retry'), onPressed: _reload, child: const Icon(Icons.refresh)),
                ]),
              ),
            );
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(Gap.l),
            children: [
              FilledButton.icon(
                key: const Key('staff-add'),
                onPressed: () => _add(data.slug),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(t.staffAdd),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.m),
                  child: Text(_message!, key: const Key('staff-message')),
                ),
              const SizedBox(height: Gap.m),
              if (data.people.isEmpty) Text(t.staffNone, key: const Key('staff-none')),
              for (final p in data.people)
                Card(
                  key: Key('staff-${p.username}'),
                  child: ListTile(
                    title: Text(p.shownName),
                    subtitle: Text([
                      _roleName(t, p.role),
                      if (!p.active) t.staffInactive,
                      if (p.stores.isNotEmpty) p.stores.join(', '),
                      if (p.role == 'cashier') t.staffSignIn(staffLogin(p.username, data.slug)),
                    ].join(' · ')),
                    leading: Icon(p.active ? Icons.person_rounded : Icons.person_off_rounded),
                    trailing: p.userId == me
                        ? null
                        : PopupMenuButton<String>(
                            key: Key('staff-menu-${p.username}'),
                            onSelected: (v) => _run(
                              () => v == 'pin' ? _api!.clearPin(p.userId) : _api!.setActive(p.userId, !p.active),
                              done: v == 'pin' ? t.staffPinCleared : null,
                            ),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                key: Key('staff-toggle-${p.username}'),
                                value: 'active',
                                child: Text(p.active ? t.staffDeactivate : t.staffActivate),
                              ),
                              if (isOwner) PopupMenuItem(key: Key('staff-pin-${p.username}'), value: 'pin', child: Text(t.staffResetPin)),
                            ],
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AddSheet extends StatefulWidget {
  const _AddSheet({required this.api, required this.stores});
  final StaffApi api;
  final List<StaffStore> stores;

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _user = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  late String? _store = widget.stores.isEmpty ? null : widget.stores.first.id;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    _name.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final t = AppLocalizations.of(context);
    final username = _user.text.trim().toLowerCase();
    if (!usernamePattern.hasMatch(username) || _pass.text.length < 8 || _store == null) {
      setState(() => _error = t.staffErrInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = _name.text.trim().isEmpty ? username : _name.text.trim();
      await widget.api.createCashier(username: username, fullName: _name.text.trim(), password: _pass.text, locationId: _store!);
      if (mounted) Navigator.pop(context, (username: username, name: name));
    } on AuthExpired {
      rethrow;
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = staffErrorText(t, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.l + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.staffAdd, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Gap.m),
          TextField(key: const Key('staff-username'), controller: _user, decoration: InputDecoration(labelText: t.staffUsername)),
          const SizedBox(height: Gap.s),
          TextField(key: const Key('staff-fullname'), controller: _name, decoration: InputDecoration(labelText: t.staffFullName)),
          const SizedBox(height: Gap.s),
          TextField(key: const Key('staff-password'), controller: _pass, obscureText: true, decoration: InputDecoration(labelText: t.staffPassword)),
          if (widget.stores.length > 1) ...[
            const SizedBox(height: Gap.s),
            DropdownButtonFormField<String>(
              key: const Key('staff-store'),
              initialValue: _store,
              decoration: InputDecoration(labelText: t.staffStore),
              items: [for (final s in widget.stores) DropdownMenuItem(value: s.id, child: Text(s.name))],
              onChanged: (v) => setState(() => _store = v),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.s),
              child: Text(_error!, key: const Key('staff-add-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: Gap.m),
          FilledButton(key: const Key('staff-create'), onPressed: _busy ? null : _create, child: Text(t.staffCreate)),
        ]),
      ),
    );
  }
}
