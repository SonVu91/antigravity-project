package com.cardano.airgap.mobile_online

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val QR_CHANNEL = "com.cardano.airgap/qr_scanner"
    private var qrScannerOverlay: NativeQrScannerOverlay? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val qrChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QR_CHANNEL)
        qrScannerOverlay = NativeQrScannerOverlay(this, qrChannel)

        qrChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCamera" -> {
                    qrScannerOverlay?.startScannerWithPermissionCheck()
                    result.success(true)
                }
                "stopCamera" -> {
                    qrScannerOverlay?.stopScanner(notifyFlutterClosed = false)
                    result.success(true)
                }
                "updateMultipartProgress" -> {
                    val args = call.arguments as? Map<*, *>
                    val received = (args?.get("received") as? Number)?.toInt() ?: 0
                    val total = (args?.get("total") as? Number)?.toInt() ?: 0
                    qrScannerOverlay?.updateMultipartProgress(received, total)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (qrScannerOverlay?.onRequestPermissionsResult(requestCode, grantResults) == true) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        if (qrScannerOverlay?.isShowing == true) {
            qrScannerOverlay?.stopScanner(notifyFlutterClosed = true)
            return
        }
        super.onBackPressed()
    }

    override fun onStop() {
        if (qrScannerOverlay?.isShowing == true) {
            qrScannerOverlay?.stopScanner(notifyFlutterClosed = true)
        }
        super.onStop()
    }

    override fun onDestroy() {
        qrScannerOverlay?.stopScanner(notifyFlutterClosed = false)
        super.onDestroy()
    }
}
