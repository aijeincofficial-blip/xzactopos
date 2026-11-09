import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../core/export.dart';
import '../core/product_import.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';

/// Where the owner moves data in and out: send sales, utang, stock and products as spreadsheet files, or paste a
/// product list from a spreadsheet to add many products at once.
class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.dataTitle), actions: const [SyncBadge()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.xxl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Section(t.dataExportSection),
          AppCard(
            padding: const EdgeInsets.all(Gap.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CoinBadge(icon: Icons.ios_share_rounded, color: scheme.secondary, size: 36),
                const SizedBox(width: Gap.m),
                Expanded(child: Text(t.exportHint, style: TextStyle(fontSize: 13, color: scheme.outline))),
              ]),
              const SizedBox(height: Gap.m),
              Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
                _ExportButton(key: const Key('export-products'), label: t.exportProducts, kind: _Kind.products),
                _ExportButton(key: const Key('export-sales'), label: t.exportSales, kind: _Kind.sales),
                _ExportButton(key: const Key('export-utang'), label: t.exportUtang, kind: _Kind.utang),
                _ExportButton(key: const Key('export-stock'), label: t.exportStock, kind: _Kind.stock),
              ]),
            ]),
          ),
          const SizedBox(height: Gap.l),
          _Section(t.dataImportSection),
          AppCard(
            padding: const EdgeInsets.all(Gap.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CoinBadge(icon: Icons.upload_file_rounded, color: scheme.primary, size: 36),
                const SizedBox(width: Gap.m),
                Expanded(child: Text(t.dataImportHint, style: TextStyle(fontSize: 13, color: scheme.outline))),
              ]),
              const SizedBox(height: Gap.m),
              Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
                FilledButton(
                  key: const Key('import-open'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => showImportSheet(context, scope),
                  child: Text(t.dataImportOpen),
                ),
                OutlinedButton(
                  key: const Key('import-template'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(const ClipboardData(text: productsCsvHeader));
                    messenger.showSnackBar(SnackBar(content: Text(t.dataTemplateCopied)));
                  },
                  child: Text(t.dataImportTemplate),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.s),
        child: Text(title.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.outline, letterSpacing: 0.6)),
      );
}

enum _Kind { products, sales, utang, stock }

class _ExportButton extends StatelessWidget {
  const _ExportButton({super.key, required this.label, required this.kind});
  final String label;
  final _Kind kind;

  Future<void> _run(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final store = CatalogScope.of(context).store;
    final ccy = store.baseCurrency;
    final day = DateTime.now().toIso8601String().substring(0, 10);
    try {
      switch (kind) {
        case _Kind.products:
          await csvSharer.share(fileName: 'products-$day.csv', csv: productsCsv(await store.watchStockList().first, ccy));
        case _Kind.sales:
          await csvSharer.share(fileName: 'sales-$day.csv', csv: salesCsv(await store.watchSales(limit: 5000).first, ccy));
        case _Kind.utang:
          await csvSharer.share(fileName: 'utang-$day.csv', csv: utangCsv(await store.watchCustomers().first, ccy));
        case _Kind.stock:
          await csvSharer.share(fileName: 'stock-$day.csv', csv: stockCsv(await store.watchStockList().first));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.exportFailed)));
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
        onPressed: () => _run(context),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      );
}

String _problemText(AppLocalizations t, ImportProblem p) => switch (p) {
      ImportProblem.nameMissing => t.dataProbName,
      ImportProblem.priceInvalid => t.dataProbPrice,
      ImportProblem.costInvalid => t.dataProbCost,
      ImportProblem.stockInvalid => t.dataProbStock,
    };

/// Paste rows, see how many are ready and which rows have problems, then add them all.
Future<void> showImportSheet(BuildContext context, CatalogScope scope) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final ccy = scope.store.baseCurrency;
  final text = TextEditingController();
  final go = await showModalBottomSheet<ImportParse>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final parsed = parseProductCsv(text.text, ccy);
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.l, Gap.xl, Gap.l),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t.dataImportSection, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                key: const Key('import-text'),
                controller: text,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: t.dataImportPaste, alignLabelWithHint: true),
              ),
              const SizedBox(height: 12),
              if (parsed.rows.isNotEmpty)
                Text(t.dataImportReady(parsed.rows.length),
                    key: const Key('import-ready'), style: TextStyle(color: scheme.success, fontWeight: FontWeight.w800)),
              if (parsed.errors.isNotEmpty) ...[
                Text(t.dataImportProblems(parsed.errors.length),
                    key: const Key('import-problems'), style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700)),
                for (final e in parsed.errors.take(5))
                  Text(t.dataImportLine(e.line, _problemText(t, e.problem)), style: TextStyle(fontSize: 12, color: scheme.outline)),
              ],
              if (parsed.tooMany) Text(t.dataTooMany, style: TextStyle(fontSize: 12, color: scheme.outline)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel))),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const Key('import-confirm'),
                    onPressed: parsed.rows.isEmpty ? null : () => Navigator.pop(ctx, parsed),
                    child: Text(t.dataImportGo(parsed.rows.length)),
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
    ),
  );
  if (go == null) return;

  var added = 0, skipped = 0;
  final seen = <String>{};
  for (final r in go.rows) {
    final code = r.barcode;
    if (code != null) {
      final taken = seen.contains(code) || await scope.store.findByBarcode(code) != null;
      if (taken) {
        skipped++;
        continue;
      }
      seen.add(code);
    }
    await scope.store.saveProduct(
      ProductDraft(
        id: const Uuid().v7(),
        variantId: const Uuid().v7(),
        name: r.name,
        price: r.price,
        unit: r.unit ?? 'pc',
        barcode: code ?? '',
        cost: r.cost,
        openingQty: r.stock,
      ),
      opId: const Uuid().v7(),
    );
    added++;
  }
  scope.engine.poke();
  messenger.showSnackBar(SnackBar(
    content: Text([t.dataImported(added), if (skipped > 0) t.dataSkipped(skipped)].join(' · ')),
  ));
}
