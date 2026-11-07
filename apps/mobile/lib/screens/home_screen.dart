import 'package:flutter/material.dart';

import '../app.dart' show LanguageButton;
import '../backend.dart';
import '../data/local_store.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'products_screen.dart';

/// Solo home: a few big buttons, nothing else to learn.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(storeName, overflow: TextOverflow.ellipsis),
        actions: [
          const SyncBadge(),
          const LanguageButton(),
          IconButton(tooltip: t.signOut, icon: const Icon(Icons.logout), onPressed: backend.signOut),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            Text(t.welcome(storeName), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            StreamBuilder<List<ProductView>>(
              stream: scope.store.watchProducts(),
              builder: (context, snap) => Text(
                t.productsOnDevice(snap.data?.length ?? 0),
                key: const Key('product-count'),
              ),
            ),
            const SizedBox(height: 20),
            _Tile(
              key: const Key('tile-products'),
              icon: Icons.inventory_2_outlined,
              label: t.products,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => CatalogScope(store: scope.store, engine: scope.engine, child: const ProductsScreen()),
              )),
            ),
            const SizedBox(height: 12),
            _Tile(icon: Icons.point_of_sale, label: t.sell, caption: t.comingSoon),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.icon, required this.label, this.caption, this.onTap});
  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Material(
      color: enabled ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(children: [
            Icon(icon, size: 36, color: enabled ? scheme.onPrimaryContainer : scheme.outline),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: enabled ? scheme.onPrimaryContainer : scheme.outline)),
                if (caption != null) Text(caption!, style: TextStyle(color: scheme.outline)),
              ]),
            ),
            if (enabled) Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
          ]),
        ),
      ),
    );
  }
}
