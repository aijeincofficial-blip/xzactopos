import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../core/search.dart';
import '../data/local_store.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';

typedef PickedCustomer = ({String id, String name});

/// Asks for a name and creates the customer on the device (sent to the server later). Null if cancelled.
Future<PickedCustomer?> showNewCustomerDialog(BuildContext context, LocalStore store) async {
  final t = AppLocalizations.of(context);
  final c = TextEditingController();
  final phone = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.customerNew),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          key: const Key('customer-name'),
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: t.customerName),
        ),
        TextField(
          key: const Key('customer-phone'),
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: t.customerPhone),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
        FilledButton(key: const Key('customer-save'), onPressed: () => Navigator.pop(ctx, true), child: Text(t.save)),
      ],
    ),
  );
  final name = c.text.trim();
  if (ok != true || name.isEmpty) return null;
  final id = const Uuid().v7();
  await store.saveCustomer(id: id, name: name, phone: phone.text, opId: const Uuid().v7());
  return (id: id, name: name);
}

/// Bottom sheet: search the customers or add a new one. Returns the chosen customer.
Future<PickedCustomer?> pickCustomer(BuildContext context, LocalStore store) {
  return showModalBottomSheet<PickedCustomer>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _Picker(store: store),
  );
}

class _Picker extends StatefulWidget {
  const _Picker({required this.store});
  final LocalStore store;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('customer-search'),
              onChanged: (v) => setState(() => _q = searchKey(v)),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: t.customerSearch,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          ListTile(
            key: const Key('customer-add'),
            leading: const Icon(Icons.person_add_alt_1),
            title: Text(t.customerNew),
            onTap: () async {
              final made = await showNewCustomerDialog(context, widget.store);
              if (made != null && context.mounted) Navigator.pop(context, made);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<CustomerView>>(
              stream: widget.store.watchCustomers(),
              builder: (context, snap) {
                final all = snap.data ?? const <CustomerView>[];
                final list = _q.isEmpty ? all : all.where((c) => searchKey(c.name).contains(_q)).toList();
                return ListView(children: [
                  for (final c in list)
                    ListTile(
                      key: Key('customer-${c.id}'),
                      title: Text(c.name, style: const TextStyle(fontSize: 18)),
                      trailing: c.balance == 0
                          ? null
                          : Text(Money(c.balance, widget.store.baseCurrency).format(locale)),
                      onTap: () => Navigator.pop(context, (id: c.id, name: c.name)),
                    ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
