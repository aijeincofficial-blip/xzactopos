import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Longest side of a stored product photo, and the size budget per photo (the bucket refuses > 200 KB).
const int photoMaxSide = 640;
const int photoMaxBytes = 100 * 1024;

/// Returns a JPEG no larger than [maxSide] px on its longest side and under [maxBytes],
/// lowering quality (then size) until it fits. Throws [FormatException] if the bytes are not an image.
Uint8List compressPhoto(Uint8List input, {int maxSide = photoMaxSide, int maxBytes = photoMaxBytes}) {
  var image = img.decodeImage(input);
  if (image == null) throw const FormatException('Not an image');
  image = img.bakeOrientation(image);
  var side = maxSide;
  while (true) {
    final resized = (image.width > side || image.height > side)
        ? img.copyResize(image,
            width: image.width >= image.height ? side : null,
            height: image.height > image.width ? side : null,
            interpolation: img.Interpolation.average)
        : image;
    for (final quality in const [80, 70, 60, 50, 40]) {
      final out = img.encodeJpg(resized, quality: quality);
      if (out.length <= maxBytes) return out;
    }
    if (side <= 160) return img.encodeJpg(resized, quality: 30);
    side = (side * 0.75).round();
  }
}

/// Where photos come from. The app uses the camera or gallery; tests use a fake.
abstract class PhotoSource {
  /// Null when the user cancels.
  Future<Uint8List?> pick({required bool camera});
}

class DevicePhotoSource implements PhotoSource {
  final _picker = ImagePicker();

  @override
  Future<Uint8List?> pick({required bool camera}) async {
    // let the platform shrink it first (fast, native); compressPhoto then guarantees JPEG and size
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: photoMaxSide.toDouble(),
      maxHeight: photoMaxSide.toDouble(),
      imageQuality: 80,
    );
    if (file == null) return null;
    return compressPhoto(await file.readAsBytes());
  }
}
