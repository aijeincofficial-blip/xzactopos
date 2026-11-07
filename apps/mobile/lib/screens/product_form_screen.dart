import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../core/photo.dart';
import '../data/local_store.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import 'product_thumb.dart';

/// One screen to add or edit a product: name, price, optional barcode and opening stock.
/// Unit and cost hide under "More". Saves to the phone at once; sync sends it later.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product, this.barcode});

  /// Camera/gallery access; tests replace it.
  static PhotoSource Function() photoSource = DevicePhotoSource.new;

  /// Null = new product.
  final ProductView? product;

  /// Prefills the barcode (from a scan of an unknown code).
  final String? barcode;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _price = TextEditingController(
      text: widget.product?.price == null ? '' : Money(widget.product!.price!, widget.product!.currency).toDecimalString());
  late final _barcode = TextEditingController(text: widget.product?.barcode ?? widget.barcode);
  final _stock = TextEditingController();
  late final _unit = TextEditingController(text: widget.product?.unit ?? 'pc');
  final _cost = TextEditingController();
  late final _reorder = TextEditingController(
      text: (widget.product?.reorderPoint ?? 0) > 0 ? widget.product!.reorderPoint.toString().replaceAll(RegExp(r'\.0$'), '') : '');
  bool _busy = false;
  String? _barcodeError;
  Uint8List? _newPhoto;
  bool _photoBusy = false;

  // ids are made once per screen, so saving twice never creates two products
  late final String _productId = widget.product?.id ?? const Uuid().v7();
  late final String _variantId = widget.product?.variantId ?? const Uuid().v7();

  bool get _isNew => widget.product == null;

  @override
  void dispose() {
    for (final c in [_name, _price, _barcode, _stock, _unit, _cost, _reorder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    setState(() => _barcodeError = null);
    if (!_form.currentState!.validate()) return;

    final code = _barcode.text.trim();
    if (code.isNotEmpty) {
      final other = await scope.store.findByBarcode(code);
      if (other != null && other.id != _productId) {
        setState(() => _barcodeError = t.barcodeUsedBy(other.name));
        return;
      }
    }

    setState(() => _busy = true);
    final currency = scope.store.baseCurrency;
    await scope.store.saveProduct(
      ProductDraft(
        id: _productId,
        variantId: _variantId,
        name: _name.text.trim(),
        price: Money.parse(_price.text, currency).amount,
        unit: _unit.text.trim().isEmpty ? 'pc' : _unit.text.trim(),
        barcode: code,
        cost: _cost.text.trim().isEmpty ? null : Money.parse(_cost.text, currency).amount,
        openingQty: _stock.text.trim().isEmpty ? null : double.parse(_stock.text.trim()),
        reorderPoint: _reorder.text.trim().isEmpty ? null : double.parse(_reorder.text.trim().replaceAll(',', '.')),
      ),
      opId: const Uuid().v7(),
    );
    if (_newPhoto != null) {
      await scope.store.setPhoto(_productId, _variantId, _newPhoto!, opId: const Uuid().v7());
    }
    scope.engine.poke();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickPhoto({required bool camera}) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _photoBusy = true);
    try {
      final bytes = await ProductFormScreen.photoSource().pick(camera: camera);
      if (bytes != null && mounted) setState(() => _newPhoto = bytes);
    } catch (e, s) {
      debugPrint('photo pick failed: $e\n$s');
      messenger.showSnackBar(SnackBar(content: Text(t.photoFailed)));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Widget _photoSection(AppLocalizations t) {
    const size = 96.0;
    final Widget current = _newPhoto != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(_newPhoto!, key: const Key('new-photo'), width: size, height: size, fit: BoxFit.cover),
          )
        : ProductThumb(productId: _productId, path: widget.product?.photoPath, size: size);
    return Row(children: [
      current,
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          OutlinedButton.icon(
            key: const Key('photo-camera'),
            onPressed: _photoBusy ? null : () => _pickPhoto(camera: true),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(t.takePhoto),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('photo-gallery'),
            onPressed: _photoBusy ? null : () => _pickPhoto(camera: false),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(t.choosePhoto),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _archive() async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.archiveTitle(widget.product!.name)),
        content: Text(t.archiveBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t.archive)),
        ],
      ),
    );
    if (ok != true) return;
    await scope.store.archiveProduct(_productId, opId: const Uuid().v7());
    scope.engine.poke();
    if (mounted) Navigator.of(context).pop();
  }

  String? _money(String? v, AppLocalizations t, {required bool required}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return required ? t.errRequired : null;
    try {
      final m = Money.parse(s, CatalogScope.of(context).store.baseCurrency);
      if (m.amount < 0) return t.errBadAmount;
    } catch (_) {
      return t.errBadAmount;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final big = Theme.of(context).textTheme.titleLarge;
    final currency = CatalogScope.of(context).store.baseCurrency;
    final symbol = currency == 'PHP' ? '₱' : currency;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? t.addProduct : t.editProduct),
        actions: [
          if (!_isNew)
            IconButton(
              key: const Key('archive-product'),
              tooltip: t.archive,
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _archive,
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _photoSection(t),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('field-name'),
              controller: _name,
              autofocus: _isNew,
              style: big,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: t.productName, hintText: t.productNameHint),
              validator: (v) => (v == null || v.trim().isEmpty) ? t.errRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('field-price'),
              controller: _price,
              style: big,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: t.sellingPrice, prefixText: '$symbol '),
              validator: (v) => _money(v, t, required: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('field-barcode'),
              controller: _barcode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t.barcodeOptional,
                prefixIcon: const Icon(Icons.qr_code_scanner),
                errorText: _barcodeError,
              ),
            ),
            if (_isNew) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('field-stock'),
                controller: _stock,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(labelText: t.openingStockOptional, helperText: t.openingStockHelp),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return null;
                  final q = double.tryParse(s);
                  return (q == null || q < 0) ? t.errBadAmount : null;
                },
              ),
            ],
            const SizedBox(height: 8),
            ExpansionTile(
              key: const Key('more'),
              tilePadding: EdgeInsets.zero,
              title: Text(t.more),
              children: [
                TextFormField(
                  controller: _unit,
                  decoration: InputDecoration(labelText: t.unit, helperText: t.unitHelp),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cost,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t.costOptional, prefixText: '$symbol '),
                  validator: (v) => _money(v, t, required: false),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('field-reorder'),
                  controller: _reorder,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t.reorderPoint, helperText: t.reorderPointHelp),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final q = double.tryParse(v.trim().replaceAll(',', '.'));
                    return (q == null || q < 0) ? t.errBadAmount : null;
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
      // always visible, even on a small phone with the keyboard and error messages showing
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 56,
            child: FilledButton(
              key: const Key('save-product'),
              onPressed: _busy ? null : _save,
              child: Text(t.save, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ),
    );
  }
}
