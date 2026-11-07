import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xzactopos_mobile/core/photo.dart';

/// A noisy photo-like image: noise compresses badly, so it exercises the size loop.
Uint8List noisyPng(int w, int h) {
  final r = Random(7);
  final image = img.Image(width: w, height: h);
  for (final p in image) {
    p.setRgb(r.nextInt(256), r.nextInt(256), r.nextInt(256));
  }
  return img.encodePng(image);
}

void main() {
  test('a big photo becomes a JPEG of at most 640 px and under 100 KB', () {
    final out = compressPhoto(noisyPng(1600, 1200));
    expect(out.length, lessThanOrEqualTo(photoMaxBytes));
    final decoded = img.decodeJpg(out)!;
    expect(max(decoded.width, decoded.height), lessThanOrEqualTo(photoMaxSide));
    expect(decoded.width / decoded.height, closeTo(4 / 3, 0.02), reason: 'keeps the aspect ratio');
  });

  test('portrait photos keep their shape', () {
    final d = img.decodeJpg(compressPhoto(noisyPng(600, 1200)))!;
    expect(d.height, photoMaxSide);
    expect(d.width, 320);
  });

  test('a small image is not enlarged', () {
    final d = img.decodeJpg(compressPhoto(noisyPng(200, 100)))!;
    expect([d.width, d.height], [200, 100]);
  });

  test('a tight budget shrinks further instead of failing', () {
    final out = compressPhoto(noisyPng(1200, 1200), maxBytes: 15 * 1024);
    expect(out.length, lessThanOrEqualTo(15 * 1024));
  });

  test('non-images are refused', () {
    expect(() => compressPhoto(Uint8List.fromList([1, 2, 3, 4])), throwsFormatException);
  });
}
