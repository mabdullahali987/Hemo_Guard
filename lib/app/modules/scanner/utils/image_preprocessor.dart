import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Fast preprocessing tuned from a benchmark of 20+ real report photos:
///  * respect EXIF orientation
///  * bring the long edge into a good OCR range — UPSCALE small/low-res images
///    (Tesseract fails on tiny screenshots) and cap huge ones for speed
///  * grayscale + normalise for even lighting
///
/// Binarisation was deliberately dropped — testing showed adaptive thresholding
/// *destroyed* text on real photos; letting Tesseract do its own Otsu is better.
class ImagePreprocessor {
  // Long edge is normalised to ~1600px: big enough for dense reports, small
  // enough that a single OCR pass stays fast on a phone.
  static const int _targetLong = 1600;

  static Future<String> processForOCR(String imagePath) async {
    return _run(imagePath, (bytes) => _process(bytes, 0));
  }

  /// A rotated copy (quarterTurns × 90°) of an already-preprocessed image, used
  /// as a fallback for sideways/upside-down photos.
  static Future<String> rotated(String imagePath, int quarterTurns) async {
    return _run(imagePath, (bytes) => _process(bytes, quarterTurns),
        prefix: 'rot$quarterTurns');
  }

  static Future<String> _run(
      String imagePath, Uint8List? Function(Uint8List) job,
      {String prefix = 'ocr'}) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return imagePath;
      final out = await compute(job, await file.readAsBytes());
      if (out == null) return imagePath;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.png';
      await File(path).writeAsBytes(out);
      return path;
    } catch (e) {
      debugPrint('Preprocess error: $e');
      return imagePath;
    }
  }

  static Uint8List? _process(Uint8List bytes, int quarterTurns) {
    var image = img.decodeImage(bytes);
    if (image == null) return null;

    image = img.bakeOrientation(image);
    if (quarterTurns != 0) {
      image = img.copyRotate(image, angle: 90 * quarterTurns);
    }

    final longEdge = image.width > image.height ? image.width : image.height;
    // Resize toward the target unless already close (avoids needless work).
    if ((longEdge - _targetLong).abs() > 150) {
      final scale = _targetLong / longEdge;
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }

    image = img.grayscale(image);
    image = img.normalize(image, min: 0, max: 255);
    return img.encodePng(image);
  }
}
