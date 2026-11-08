import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';

/// Bottom sheet to choose which store this phone sells for. Only offered when the user has more than one store.
Future<void> showStorePicker(BuildContext context, CatalogScope scope, List<StoreRef> stores) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final active = scope.store.activeLocationId;
  final picked = await showModalBottomSheet<StoreRef>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.l, Gap.xl, Gap.s),
          child: Text(t.storePickerTitle, style: Theme.of(ctx).textTheme.titleLarge),
        ),
        for (final s in stores)
          ListTile(
            key: Key('store-${s.id}'),
            leading: const Icon(Icons.storefront_rounded),
            title: Text(s.name),
            trailing: s.id == active ? Icon(Icons.check_circle_rounded, color: Theme.of(ctx).colorScheme.primary) : null,
            onTap: () => Navigator.pop(ctx, s),
          ),
        const SizedBox(height: Gap.s),
      ]),
    ),
  );
  if (picked == null || picked.id == active) return;
  await scope.store.setActiveStore(picked.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t.storeSwitched(picked.name))));
}

/// The current store's name as a small chip; tapping it switches store. Shows nothing for a one-store user.
class StoreChip extends StatefulWidget {
  const StoreChip({super.key});

  @override
  State<StoreChip> createState() => _StoreChipState();
}

class _StoreChipState extends State<StoreChip> {
  List<StoreRef> _stores = const [];
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    CatalogScope.of(context).store.myStores().then((s) {
      if (mounted) setState(() => _stores = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_stores.length < 2) return const SizedBox.shrink();
    final scope = CatalogScope.of(context);
    return StreamBuilder<String?>(
      stream: scope.store.watchActiveStore(),
      builder: (context, snap) {
        final id = snap.data ?? scope.store.activeLocationId;
        final name = _stores.where((s) => s.id == id).map((s) => s.name).firstOrNull ?? _stores.first.name;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ActionChip(
            key: const Key('store-chip'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.storefront_rounded, size: 16),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            onPressed: () => showStorePicker(context, scope, _stores),
          ),
        );
      },
    );
  }
}
