import 'package:flutter/services.dart';

/// Native IO Implementation for QR Scanner Bridge (Android 32-bit ARMv7 / 64-bit)
class WebQrScannerBridge {
  static const MethodChannel _channel = MethodChannel('com.cardano.airgap/qr_scanner');
  static bool _initialized = false;
  static void Function(String text)? _activeCallback;
  static void Function(String error)? _errorCallback;
  static void Function()? _closeCallback;
  static bool _isCameraSessionActive = false;

  static bool get isCameraSessionActive => _isCameraSessionActive;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onQrScanned':
          final text = call.arguments?.toString();
          if (text != null && text.isNotEmpty) {
            _activeCallback?.call(text);
          }
          break;
        case 'onCameraClosed':
          _isCameraSessionActive = false;
          _closeCallback?.call();
          break;
        case 'onCameraError':
          _isCameraSessionActive = false;
          final err = call.arguments?.toString() ?? 'Không thể khởi động Camera.';
          _errorCallback?.call(err);
          break;
      }
    });
  }

  static void startLiveCamera(
    void Function(String text) onScanned, {
    void Function(String error)? onError,
    void Function()? onClosed,
  }) {
    _ensureInitialized();
    _activeCallback = onScanned;
    _errorCallback = onError;
    _closeCallback = onClosed;
    _isCameraSessionActive = true;

    _channel.invokeMethod('startCamera').catchError((e) {
      _isCameraSessionActive = false;
      if (e is MissingPluginException) {
        return;
      }
      _errorCallback?.call(e.toString());
    });
  }

  static void stopLiveCamera() {
    _isCameraSessionActive = false;
    _activeCallback = null;
    if (_initialized) {
      _channel.invokeMethod('stopCamera').catchError((_) {});
    }
  }

  static void updateMultipartProgress(int received, int total) {
    if (_initialized && _isCameraSessionActive) {
      _channel.invokeMethod('updateMultipartProgress', {
        'received': received,
        'total': total,
      }).catchError((_) {});
    }
  }

  static bool get isSupported => true;
}
