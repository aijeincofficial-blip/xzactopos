import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../sync/store_session.dart';

/// Product photo from the device, downloaded on first display if needed. Shows an icon until (or unless) it is there.
class ProductThumb extends StatefulWidget {
  const ProductThumb({super.key, required this.productId, required this.path, this.size = 48});
  final String productId;
  final String? path;
  final double size;

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
    final dark = scheme.brightness == Brightness.dark;
    // Branded ceramic product tile with ocean blue/cyan box glyph
    final placeholder = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF1E293B), Color(0xFF131D33)]
              : const [Color(0xFFF0F6FE), Color(0xFFE2EEFD)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: dark ? const Color(0xFF38BDF8) : const Color(0xFF1E6FF2),
          size: widget.size * 0.52,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size * 0.30),
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
