import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';
import '../../core/theme/hot_theme.dart';
import '../../core/qr/qr_scanner_helper.dart';
import '../../core/utils/clipboard_helper.dart';
import '../providers/hot_wallet_provider.dart';
import 'tx_result_screen.dart';

class ScanSignedScreen extends ConsumerStatefulWidget {
  const ScanSignedScreen({super.key});

  @override
  ConsumerState<ScanSignedScreen> createState() => _ScanSignedScreenState();
}

class _ScanSignedScreenState extends ConsumerState<ScanSignedScreen> {
  final TextEditingController _signedController = TextEditingController();
  final MultipartQrDecoder _decoder = MultipartQrDecoder();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    WebQrScannerBridge.stopLiveCamera();
    _signedController.dispose();
    super.dispose();
  }

  void _onFeedFrame(String frame) {
    final cleanFrame = frame.trim();
    if (cleanFrame.isEmpty) return;

    final full = _decoder.feed(cleanFrame);
    if (full != null) {
      WebQrScannerBridge.stopLiveCamera();
      _signedController.text = full;
      setState(() {
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✓ Đã tiếp nhận và ghép hoàn chỉnh chữ ký giao dịch!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      if (_decoder.totalCount > 1) {
        WebQrScannerBridge.updateMultipartProgress(
          _decoder.receivedCount,
          _decoder.totalCount,
        );
      }
      setState(() {});
    }
  }

  void _broadcastTx([String? explicitHex]) async {
    final hexToSubmit = (explicitHex ?? _signedController.text).trim();
    if (hexToSubmit.isEmpty) {
      setState(() => _error = "Vui lòng nhập hoặc quét chuỗi giao dịch đã ký!");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final txid = await ref.read(hotWalletProvider.notifier).submitSignedTx(hexToSubmit);
      setState(() => _isSubmitting = false);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TxResultScreen(txId: txid)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = e.toString().replaceAll("Exception: ", "");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tiếp Nhận Giao Dịch Đã Ký"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: HotTheme.buildLiveNetworkBadge(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HotTheme.buildAirGapStepHeader(
              currentStep: 3,
              stepTitle: "Bước 3/3: Quét Giao Dịch Đã Ký (txSigned) & Phát Sóng",
              subtitle: "Quét mã QR từ Ví Lạnh hoặc dán chuỗi CBOR txSigned để gửi lên mạng Cardano.",
            ),
            const Icon(Icons.satellite_alt_rounded, size: 56, color: HotTheme.accent),
            const SizedBox(height: 12),
            const Text(
              "Quét Mã QR hoặc Dán chuỗi txSigned",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              "Đưa camera quét mã QR hiển thị từ Ví Lạnh (Cold Wallet) hoặc dán trực tiếp chuỗi Hex CBOR bên dưới.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Nút Bật Camera Quét 1-Chạm (Hỗ trợ cả QR đơn và QR động nhiều mảnh)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HotTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text("Bật Camera Quét Mã QR txSigned", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  WebQrScannerBridge.startLiveCamera(
                    _onFeedFrame,
                    onError: (err) {
                      if (!mounted) return;
                      setState(() => _error = "Không thể mở Camera: $err");
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            if (_decoder.totalCount > 1) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HotTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: HotTheme.accent.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Tiến độ quét QR Động:",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          "${_decoder.receivedCount} / ${_decoder.totalCount} mảnh (${(_decoder.progress * 100).toInt()}%)",
                          style: const TextStyle(color: HotTheme.accent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _decoder.progress,
                      backgroundColor: Colors.grey[800],
                      color: HotTheme.accent,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _signedController,
              maxLines: 5,
              enableInteractiveSelection: true,
              onChanged: _onFeedFrame,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: "Chuỗi CBOR txSigned đã ký",
                hintText: "Dán chuỗi TxConway:... hoặc 84a4... vào đây",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: HotTheme.surface,
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_signedController.text.isNotEmpty)
                        IconButton(
                          tooltip: "Xóa nội dung",
                          icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                          onPressed: () {
                            _signedController.clear();
                            setState(() {
                              _error = null;
                            });
                          },
                        ),
                      IconButton(
                        tooltip: "Dán từ bộ nhớ tạm (Paste)",
                        icon: const Icon(Icons.paste_rounded, color: HotTheme.accent, size: 22),
                        onPressed: () async {
                          await ClipboardHelper.paste(
                            context,
                            targetController: _signedController,
                            onChanged: _onFeedFrame,
                            fieldName: "txSigned CBOR",
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Thông Báo Lỗi Từ Mạng Cardano",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _error!,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: HotTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(
                _isSubmitting ? "ĐANG PHÁT SÓNG..." : "PHÁT SÓNG GIAO DỊCH LÊN CARDANO (SUBMIT)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: _isSubmitting ? null : () => _broadcastTx(),
            ),
          ],
        ),
      ),
    );
  }
}
