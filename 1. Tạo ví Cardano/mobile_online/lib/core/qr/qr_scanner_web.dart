import 'dart:js' as js;

/// Web Implementation for QR Scanner Bridge using html5-qrcode
class WebQrScannerBridge {
  static bool _isCameraSessionActive = false;

  static bool get isCameraSessionActive => _isCameraSessionActive;

  static void startLiveCamera(
    void Function(String text) onScanned, {
    void Function(String error)? onError,
    void Function()? onClosed,
  }) {
    _isCameraSessionActive = true;
    js.context['onCardanoQrScanned'] = (dynamic decodedText) {
      if (decodedText != null) {
        onScanned(decodedText.toString());
      }
    };

    final scanner = js.context['CardanoWebQrScanner'];
    if (scanner != null) {
      scanner.callMethod('startCamera', []);
    }
  }

  static void stopLiveCamera() {
    _isCameraSessionActive = false;
    final scanner = js.context['CardanoWebQrScanner'];
    if (scanner != null) {
      scanner.callMethod('stopCamera', []);
    }
  }

  static void updateMultipartProgress(int received, int total) {
    final scanner = js.context['CardanoWebQrScanner'];
    if (scanner != null && scanner.hasProperty('updateProgress')) {
      scanner.callMethod('updateProgress', [received, total]);
    }
  }

  static bool get isSupported => true;
}
