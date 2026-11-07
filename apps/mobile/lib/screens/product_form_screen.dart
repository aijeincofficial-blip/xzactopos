import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../core/camera_scanner.dart';
import '../core/money.dart';
import '../core/photo.dart';
import '../core/theme.dart';
import '../core/ui.dart';
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

  Future<void> _scanBarcode() async {
    final code = await cameraScanner.scanOne(context);
    if (code != null && mounted) setState(() => _barcode.text = code);
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

  Widget _photoSection(AppLocalizations t, ColorScheme scheme, bool dark) {
    const size = 92.0;
    final Widget current = _newPhoto != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(Gap.radiusM),
            child: Image.memory(_newPhoto!, key: const Key('new-photo'), width: size, height: size, fit: BoxFit.cover),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(Gap.radiusM),
            child: ProductThumb(productId: _productId, path: widget.product?.photoPath, size: size),
          );

    return AppCard(
      padding: const EdgeInsets.all(Gap.m),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Gap.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: current,
          ),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  key: const Key('photo-camera'),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _photoBusy ? null : () => _pickPhoto(camera: true),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(t.takePhoto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: Gap.s),
                OutlinedButton.icon(
                  key: const Key('photo-gallery'),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _photoBusy ? null : () => _pickPhoto(camera: false),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(t.choosePhoto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _archive() async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusL)),
        title: Text(t.archiveTitle(widget.product!.name)),
        content: Text(t.archiveBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.archive),
          ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final big = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
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
              icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              onPressed: _busy ? null : _archive,
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.m),
          children: [
            _photoSection(t, scheme, dark),
            const SizedBox(height: Gap.m),

            // Main Product Details Card
            AppCard(
              padding: const EdgeInsets.all(Gap.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('field-name'),
                    controller: _name,
                    autofocus: _isNew,
                    style: big,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: t.productName,
                      hintText: t.productNameHint,
                      prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? t.errRequired : null,
                  ),
                  const SizedBox(height: Gap.m),
                  TextFormField(
                    key: const Key('field-price'),
                    controller: _price,
                    style: big,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: t.sellingPrice,
                      prefixText: '$symbol ',
                      prefixIcon: const Icon(Icons.sell_outlined, size: 20),
                    ),
                    validator: (v) => _money(v, t, required: true),
                  ),
                  const SizedBox(height: Gap.m),
                  TextFormField(
                    key: const Key('field-barcode'),
                    controller: _barcode,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: t.barcodeOptional,
                      prefixIcon: cameraScanner.available
                          ? IconButton(
                              key: const Key('barcode-camera'),
                              tooltip: t.scanWithCamera,
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              onPressed: _scanBarcode,
                            )
                          : const Icon(Icons.qr_code_scanner_rounded),
                      errorText: _barcodeError,
                    ),
                  ),
                  if (_isNew) ...[
                    const SizedBox(height: Gap.m),
                    TextFormField(
                      key: const Key('field-stock'),
                      controller: _stock,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: InputDecoration(
                        labelText: t.openingStockOptional,
                        helperText: t.openingStockHelp,
                        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return null;
                        final q = double.tryParse(s);
                        return (q == null || q < 0) ? t.errBadAmount : null;
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Gap.m),

            // More Options (Unit, Cost, Reorder)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.xs),
              child: ExpansionTile(
                key: const Key('more'),
                tilePadding: const EdgeInsets.symmetric(horizontal: Gap.s),
                shape: const Border(),
                title: Text(t.more, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                leading: Icon(Icons.tune_rounded, color: scheme.primary),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.s, 0, Gap.s, Gap.m),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _unit,
                          decoration: InputDecoration(
                            labelText: t.unit,
                            helperText: t.unitHelp,
                            prefixIcon: const Icon(Icons.straighten_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: Gap.m),
                        TextFormField(
                          controller: _cost,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: t.costOptional,
                            prefixText: '$symbol ',
                            prefixIcon: const Icon(Icons.request_quote_outlined, size: 20),
                          ),
                          validator: (v) => _money(v, t, required: false),
                        ),
                        const SizedBox(height: Gap.m),
                        TextFormField(
                          key: const Key('field-reorder'),
                          controller: _reorder,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: t.reorderPoint,
                            helperText: t.reorderPointHelp,
                            prefixIcon: const Icon(Icons.notifications_active_outlined, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final q = double.tryParse(v.trim().replaceAll(',', '.'));
                            return (q == null || q < 0) ? t.errBadAmount : null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.l),
          child: SizedBox(
            height: 56,
            child: FilledButton(
              key: const Key('save-product'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.obsidian,
                foregroundColor: dark ? scheme.onPrimary : Colors.white,
                shape: const StadiumBorder(),
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.3),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.3),
              ),
              onPressed: _busy ? null : _save,
              child: Text(t.save),
            ),
          ),
        ),
      ),
    );
  }
}
