import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:xzactopos_mobile/core/camera_scanner.dart';

/// No real camera in tests: every test starts with the camera reported as not available
/// (like the web build); camera tests install their own fake.
class NoCamera implements CameraScanner {
  const NoCamera();
  @override
  bool get available => false;
  @override
  Future<String?> scanOne(BuildContext context) async => null;
  @override
  Future<void> scanMany(BuildContext context, Future<ScanFeedback> Function(String code) onCode) async {}
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  cameraScanner = const NoCamera();
  await testMain();
}
