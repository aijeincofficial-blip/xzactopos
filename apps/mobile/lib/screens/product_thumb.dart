import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../sync/store_session.dart';
import '../core/ui.dart';

/// Product photo from the device, downloaded on first display if needed.
/// Shows a Night Market category color swatch with 2-letter monogram when [name] is supplied,
/// or a neutral paper/ink squircle badge otherwise. Zero gradients.
class ProductThumb extends StatefulWidget {
  const ProductThumb({
    super.key,
    required this.productId,
    required this.path,
    this.size = 48,
    this.name,
    this.category,
  });

  final String productId;
  final String? path;
  final double size;
  final String? name;
  final String? category;

  @override
  State<ProductThumb> createState() => _ProductThumbState();
}

class _ProductThumbState extends State<ProductThumb> {
  Future<Uint8List?>? _bytes;
  String? _loadedPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensure();
  }

  @override
  void didUpdateWidget(ProductThumb old) {
    super.didUpdateWidget(old);
    _ensure();
  }

  void _ensure() {
    final path = widget.path;
    if (path == _loadedPath) return;
    _loadedPath = path;
    _bytes = path == null ? null : CatalogScope.of(context).photos.load(widget.productId, path);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = widget.size * 0.28;
    final label = widget.name?.trim();
    final placeholder = (label != null && label.isNotEmpty)
        ? CategorySwatchTile(name: label, category: widget.category, size: widget.size, radius: radius)
        : CoinBadge(icon: Icons.inventory_2_rounded, color: scheme.primary, size: widget.size);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: _bytes == null
          ? placeholder
          : FutureBuilder<Uint8List?>(
              future: _bytes,
              builder: (context, snap) => snap.data == null
                  ? placeholder
                  : Image.memory(
                      snap.data!,
                      key: const Key('product-photo'),
                      width: widget.size,
                      height: widget.size,
                      cacheWidth: (widget.size * 2.5).round().clamp(64, 300),
                      cacheHeight: (widget.size * 2.5).round().clamp(64, 300),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
    );
  }
}
