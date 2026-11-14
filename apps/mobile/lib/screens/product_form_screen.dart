import 'dart:async';

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
  late bool _tingi = widget.product?.sellsByPiece ?? false;
  late final _pieces = TextEditingController(text: widget.product?.piecesPerPack?.toString() ?? '');
  final _pieceName = TextEditingController();
  final _piecePrice = TextEditingController();
  String? _barcodeError;
  Uint8List? _newPhoto;
  bool _photoBusy = false;

  // ids are made once per screen, so saving twice never creates two products
  late final String _productId = widget.product?.id ?? const Uuid().v7();
  late String _variantId = widget.product?.variantId ?? const Uuid().v7();
  late String _singleVariantName = widget.product?.variantName ?? 'Default';
  final List<_VariantRowState> _variants = [];
  bool _loadedVariants = false;

  bool get _isNew => widget.product == null;
  bool get _multiVariant => _variants.length > 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedVariants && widget.product != null) {
      _loadedVariants = true;
      unawaited(_loadVariants());
    }
  }

  Future<void> _loadVariants() async {
    final rows = await CatalogScope.of(context).store.productVariants(_productId);
    if (!mounted || rows.length <= 1) return;
    setState(() {
      for (final v in _variants) {
        v.dispose();
      }
      _variants.clear();
      for (final r in rows) {
        _variants.add(_VariantRowState(
          id: r.variantId,
          name: r.variantName,
          barcode: r.barcode ?? '',
          price: r.price == null ? '' : Money(r.price!, r.currency).toDecimalString(),
          reorderPoint: r.reorderPoint > 0 ? r.reorderPoint.toString().replaceAll(RegExp(r'\.0$'), '') : '',
          isDefault: r.isDefault,
          isNew: false,
        ));
      }
      if (!_variants.any((v) => v.isDefault) && _variants.isNotEmpty) {
        _variants.first.isDefault = true;
      }
    });
  }

  void _addVariant() {
    setState(() {
      if (_variants.isEmpty) {
        _variants.add(_VariantRowState(
          id: _variantId,
          name: _singleVariantName == 'Default' ? 'Regular' : _singleVariantName,
          barcode: _barcode.text,
          price: _price.text,
          cost: _cost.text,
          reorderPoint: _reorder.text,
          stock: _stock.text,
          isDefault: true,
          isNew: _isNew,
        ));
      }
      _variants.add(_VariantRowState(id: const Uuid().v7(), isDefault: false, isNew: true));
    });
  }

  void _removeVariant(int idx) {
    if (_variants.length <= 1) return;
    setState(() {
      final removed = _variants.removeAt(idx);
      removed.dispose();
      if (_variants.length == 1) {
        final only = _variants.removeAt(0);
        _variantId = only.id;
        _singleVariantName = only.nameCtrl.text.trim().isEmpty ? 'Default' : only.nameCtrl.text.trim();
        _price.text = only.priceCtrl.text;
        _barcode.text = only.barcodeCtrl.text;
        _cost.text = only.costCtrl.text;
        _reorder.text = only.reorderCtrl.text;
        _stock.text = only.stockCtrl.text;
        only.dispose();
      } else if (!_variants.any((v) => v.isDefault)) {
        _variants.first.isDefault = true;
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _barcode, _stock, _unit, _cost, _reorder, _pieces, _pieceName, _piecePrice]) {
      c.dispose();
    }
    for (final v in _variants) {
      v.dispose();
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
    setState(() {
      _barcodeError = null;
      for (final v in _variants) {
        v.barcodeError = null;
      }
    });
    if (!_form.currentState!.validate()) return;

    final currency = scope.store.baseCurrency;
    final unitText = _unit.text.trim().isEmpty ? 'pc' : _unit.text.trim();

    if (_multiVariant) {
      final seenCodes = <String>{};
      var hasBarcodeErr = false;
      for (final v in _variants) {
        final code = v.barcodeCtrl.text.trim();
        if (code.isEmpty) continue;
        if (!seenCodes.add(code)) {
          v.barcodeError = t.barcodeUsedBy(_name.text.trim());
          hasBarcodeErr = true;
          continue;
        }
        final other = await scope.store.findByBarcode(code);
        if (other != null && other.id != _productId) {
          v.barcodeError = t.barcodeUsedBy(other.name);
          hasBarcodeErr = true;
        }
      }
      if (hasBarcodeErr) {
        if (mounted) setState(() {});
        return;
      }
      setState(() => _busy = true);
      final def = _variants.firstWhere((v) => v.isDefault, orElse: () => _variants.first);
      final draftVariants = [
        for (final v in _variants)
          VariantDraft(
            id: v.id,
            name: v.nameCtrl.text.trim().isEmpty ? 'Default' : v.nameCtrl.text.trim(),
            barcode: v.barcodeCtrl.text.trim(),
            price: Money.parse(v.priceCtrl.text, currency).amount,
            cost: v.costCtrl.text.trim().isEmpty ? null : Money.parse(v.costCtrl.text, currency).amount,
            reorderPoint: v.reorderCtrl.text.trim().isEmpty
                ? null
                : double.parse(v.reorderCtrl.text.trim().replaceAll(',', '.')),
            openingQty: v.isNew && v.stockCtrl.text.trim().isNotEmpty
                ? double.parse(v.stockCtrl.text.trim())
                : null,
            isDefault: v.id == def.id,
          ),
      ];
      await scope.store.saveProduct(
        ProductDraft(
          id: _productId,
          variantId: def.id,
          name: _name.text.trim(),
          price: Money.parse(def.priceCtrl.text, currency).amount,
          unit: unitText,
          barcode: def.barcodeCtrl.text.trim(),
          cost: def.costCtrl.text.trim().isEmpty ? null : Money.parse(def.costCtrl.text, currency).amount,
          reorderPoint: def.reorderCtrl.text.trim().isEmpty
              ? null
              : double.parse(def.reorderCtrl.text.trim().replaceAll(',', '.')),
          variants: draftVariants,
        ),
        opId: const Uuid().v7(),
      );
      if (_newPhoto != null) {
        await scope.store.setPhoto(_productId, def.id, _newPhoto!, opId: const Uuid().v7());
      }
      scope.engine.poke();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final code = _barcode.text.trim();
    if (code.isNotEmpty) {
      final other = await scope.store.findByBarcode(code);
      if (other != null && other.id != _productId) {
        setState(() => _barcodeError = t.barcodeUsedBy(other.name));
        return;
      }
    }

    setState(() => _busy = true);
    final singlePrice = Money.parse(_price.text, currency).amount;
    final singleCost = _cost.text.trim().isEmpty ? null : Money.parse(_cost.text, currency).amount;
    final singleOpening = _stock.text.trim().isEmpty ? null : double.parse(_stock.text.trim());
    final singleReorder = _reorder.text.trim().isEmpty ? null : double.parse(_reorder.text.trim().replaceAll(',', '.'));
    await scope.store.saveProduct(
      ProductDraft(
        id: _productId,
        variantId: _variantId,
        name: _name.text.trim(),
        price: singlePrice,
        unit: unitText,
        barcode: code,
        cost: singleCost,
        openingQty: singleOpening,
        reorderPoint: singleReorder,
        variants: _singleVariantName != 'Default'
            ? [
                VariantDraft(
                  id: _variantId,
                  name: _singleVariantName,
                  barcode: code,
                  price: singlePrice,
                  cost: singleCost,
                  reorderPoint: singleReorder,
                  openingQty: _isNew ? singleOpening : null,
                  isDefault: true,
                ),
              ]
            : null,
      ),
      opId: const Uuid().v7(),
    );
    if (_newPhoto != null) {
      await scope.store.setPhoto(_productId, _variantId, _newPhoto!, opId: const Uuid().v7());
    }
    final linked = widget.product?.sellsByPiece ?? false;
    final n = int.tryParse(_pieces.text.trim());
    try {
      if (_tingi && n != null) {
        if (!linked) {
          // the piece is its own product; made first so the server has it before the link
          final pieceId = const Uuid().v7();
          final pieceVariantId = const Uuid().v7();
          final name = _pieceName.text.trim().isEmpty ? t.tingiPieceSuffix(_name.text.trim()) : _pieceName.text.trim();
          await scope.store.saveProduct(
            ProductDraft(id: pieceId, variantId: pieceVariantId, name: name, price: Money.parse(_piecePrice.text, currency).amount),
            opId: const Uuid().v7(),
          );
          await scope.store.setTingiLink(
              variantId: _variantId, pieceVariantId: pieceVariantId, piecesPerPack: n, opId: const Uuid().v7());
        } else if (n != widget.product!.piecesPerPack) {
          await scope.store.setTingiLink(
              variantId: _variantId,
              pieceVariantId: widget.product!.breaksIntoVariantId,
              piecesPerPack: n,
              opId: const Uuid().v7());
        }
      } else if (!_tingi && linked) {
        await scope.store.clearTingiLink(variantId: _variantId, opId: const Uuid().v7());
      }
    } on StateError {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tingiFailed)));
    } on ArgumentError {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tingiFailed)));
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
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: Gap.border),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(Gap.radiusM - 1), child: current),
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
                  if (!_multiVariant) ...[
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
                ],
              ),
            ),
            const SizedBox(height: Gap.m),

            // Sizes & variants section
            AppCard(
              padding: const EdgeInsets.all(Gap.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.variantsSection, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      OutlinedButton.icon(
                        key: const Key('pf-add-variant'),
                        onPressed: _busy ? null : _addVariant,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(t.addVariant),
                      ),
                    ],
                  ),
                  if (_multiVariant) ...[
                    const SizedBox(height: Gap.m),
                    for (var i = 0; i < _variants.length; i++) ...[
                      Container(
                        padding: const EdgeInsets.all(Gap.m),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Gap.radiusM),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                ChoiceChip(
                                  key: Key('pf-variant-default-$i'),
                                  label: Text(t.defaultVariant),
                                  selected: _variants[i].isDefault,
                                  onSelected: (_) => setState(() {
                                    for (var j = 0; j < _variants.length; j++) {
                                      _variants[j].isDefault = j == i;
                                    }
                                  }),
                                ),
                                const Spacer(),
                                IconButton(
                                  key: Key('pf-variant-remove-$i'),
                                  tooltip: t.removeVariant,
                                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                                  onPressed: _busy ? null : () => _removeVariant(i),
                                ),
                              ],
                            ),
                            const SizedBox(height: Gap.s),
                            TextFormField(
                              key: Key('pf-variant-name-$i'),
                              controller: _variants[i].nameCtrl,
                              decoration: InputDecoration(
                                labelText: t.variantLabel,
                                hintText: t.variantLabelHint,
                              ),
                              validator: (val) => (val == null || val.trim().isEmpty) ? t.errRequired : null,
                            ),
                            const SizedBox(height: Gap.s),
                            TextFormField(
                              key: Key('pf-variant-price-$i'),
                              controller: _variants[i].priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              decoration: InputDecoration(
                                labelText: t.sellingPrice,
                                prefixText: '$symbol ',
                              ),
                              validator: (val) => _money(val, t, required: true),
                            ),
                            const SizedBox(height: Gap.s),
                            TextFormField(
                              key: Key('pf-variant-barcode-$i'),
                              controller: _variants[i].barcodeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: t.barcodeOptional,
                                errorText: _variants[i].barcodeError,
                              ),
                            ),
                            if (_variants[i].isNew) ...[
                              const SizedBox(height: Gap.s),
                              TextFormField(
                                key: Key('pf-variant-stock-$i'),
                                controller: _variants[i].stockCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                decoration: InputDecoration(labelText: t.openingStockOptional),
                                validator: (val) {
                                  final s = val?.trim() ?? '';
                                  if (s.isEmpty) return null;
                                  final q = double.tryParse(s);
                                  return (q == null || q < 0) ? t.errBadAmount : null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (i < _variants.length - 1) const SizedBox(height: Gap.m),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: Gap.m),

            // Tingi: sold by piece too (owner / managers)
            if (!_multiVariant && CatalogScope.of(context).canManageStock) ...[
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.xs),
                child: Column(children: [
                  SwitchListTile(
                    key: const Key('tingi-switch'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: Gap.s),
                    title: Text(t.tingiSection, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    subtitle: Text(
                      widget.product?.sellsByPiece == true && widget.product?.pieceName != null
                          ? t.tingiLinkedTo(widget.product!.pieceName!)
                          : t.tingiHelp,
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _tingi,
                    onChanged: (v) => setState(() => _tingi = v),
                  ),
                  if (_tingi)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.s, 0, Gap.s, Gap.m),
                      child: Column(children: [
                        TextFormField(
                          key: const Key('tingi-pieces'),
                          controller: _pieces,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: t.tingiPieces),
                          validator: (v) {
                            if (!_tingi) return null;
                            final n = int.tryParse((v ?? '').trim());
                            return (n == null || n < 1 || n > 10000) ? t.errBadAmount : null;
                          },
                        ),
                        if (widget.product?.sellsByPiece != true) ...[
                          const SizedBox(height: Gap.m),
                          TextFormField(
                            key: const Key('tingi-name'),
                            controller: _pieceName,
                            decoration: InputDecoration(labelText: t.tingiPieceName, hintText: t.tingiPieceSuffix(_name.text.trim())),
                          ),
                          const SizedBox(height: Gap.m),
                          TextFormField(
                            key: const Key('tingi-price'),
                            controller: _piecePrice,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: t.tingiPiecePrice, prefixText: '$symbol '),
                            validator: (v) => _tingi ? _money(v, t, required: true) : null,
                          ),
                        ],
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: Gap.m),
            ],

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
                        if (!_multiVariant) ...[
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
                elevation: 0,
                backgroundColor: scheme.obsidian,
                foregroundColor: scheme.onObsidian,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontFamily: NightMarketFont.sans,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
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

class _VariantRowState {
  _VariantRowState({
    required this.id,
    String name = '',
    String barcode = '',
    String price = '',
    String cost = '',
    String reorderPoint = '',
    String stock = '',
    this.isDefault = false,
    this.isNew = true,
  })  : nameCtrl = TextEditingController(text: name),
        barcodeCtrl = TextEditingController(text: barcode),
        priceCtrl = TextEditingController(text: price),
        costCtrl = TextEditingController(text: cost),
        reorderCtrl = TextEditingController(text: reorderPoint),
        stockCtrl = TextEditingController(text: stock);

  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController costCtrl;
  final TextEditingController reorderCtrl;
  final TextEditingController stockCtrl;
  bool isDefault;
  final bool isNew;
  String? barcodeError;

  void dispose() {
    nameCtrl.dispose();
    barcodeCtrl.dispose();
    priceCtrl.dispose();
    costCtrl.dispose();
    reorderCtrl.dispose();
    stockCtrl.dispose();
  }
}
