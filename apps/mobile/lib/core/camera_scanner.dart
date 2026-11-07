import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/app_localizations.dart';

/// What the camera screen shows after a code was read, and whether to close it.
class ScanFeedback {
  const ScanFeedback(this.message, {this.ok = true});
  final String message;

  /// false = something to notice (unknown barcode): shown in the warning colour.
  final bool ok;
}

/// The phone camera as a barcode reader. Screens use this interface only, so tests can fake it
/// and the web build (which has no camera plugin support) simply reports it is not available.
abstract class CameraScanner {
  bool get available;

  /// Opens the camera until one code is read; returns it (null if the user went back).
  Future<String?> scanOne(BuildContext context);

  /// Keeps the camera open (continuous mode): [onCode] runs for each new code and returns what to show.
  /// The same code is ignored for 1.5 s so one barcode does not add twice. Returns when the user taps Done.
  Future<void> scanMany(BuildContext context, Future<ScanFeedback> Function(String code) onCode);
}

/// Replaced in tests.
CameraScanner cameraScanner = const MobileCameraScanner();

class MobileCameraScanner implements CameraScanner {
  const MobileCameraScanner();

  @override
  bool get available => !kIsWeb;

  @override
  Future<String?> scanOne(BuildContext context) => Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const CameraScanScreen()),
      );

  @override
  Future<void> scanMany(BuildContext context, Future<ScanFeedback> Function(String code) onCode) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => CameraScanScreen(onCode: onCode)));
}

const _formats = [
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
  BarcodeFormat.code128,
  BarcodeFormat.code39,
  BarcodeFormat.qrCode,
];

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key, this.onCode});

  /// null = single scan: the first code closes the screen and is returned.
  final Future<ScanFeedback> Function(String code)? onCode;

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final _controller = MobileScannerController(formats: _formats, detectionSpeed: DetectionSpeed.normal);
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;
  ScanFeedback? _feedback;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (code == null || code.isEmpty) return;
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt) < const Duration(milliseconds: 1500)) return;
    _lastCode = code;
    _lastAt = now;
    if (widget.onCode == null) {
      Navigator.of(context).pop(code);
      return;
    }
    _busy = true;
    try {
      final fb = await widget.onCode!(code);
      if (mounted) setState(() => _feedback = fb);
    } finally {
      _busy = false;
      _lastAt = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.scanTitle),
        actions: [
          IconButton(
            key: const Key('scan-torch'),
            tooltip: t.scanLight,
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => Center(
            child: Padding(padding: const EdgeInsets.all(24), child: Text(t.scanCameraDenied, textAlign: TextAlign.center)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  _feedback?.message ?? t.scanHint,
                  key: const Key('scan-message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: (_feedback?.ok ?? true) ? Colors.white : scheme.errorContainer, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                if (widget.onCode != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(key: const Key('scan-done'), onPressed: () => Navigator.of(context).pop(), child: Text(t.scanDone)),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
