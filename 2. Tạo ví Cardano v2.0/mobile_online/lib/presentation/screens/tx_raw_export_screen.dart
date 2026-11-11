import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';
import '../../core/theme/hot_theme.dart';
import '../../core/tx/tx_builder.dart';
import 'scan_signed_screen.dart';

class TxRawExportScreen extends StatefulWidget {
  final BuiltTxResult builtTx;

  const TxRawExportScreen({super.key, required this.builtTx});

  @override
  State<TxRawExportScreen> createState() => _TxRawExportScreenState();
}

class _TxRawExportScreenState extends State<TxRawExportScreen> {
  late List<String> _qrFrames;
  int _currentFrame = 0;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    final encoder = MultipartQrEncoder(chunkSize: 180);
    _qrFrames = encoder.encode(widget.builtTx.rawCborHex);

    if (_qrFrames.length > 1) {
      _animationTimer = Timer.periodic(const Duration(milliseconds: 170), (_) {
        if (mounted) {
          setState(() {
            _currentFrame = (_currentFrame + 1) % _qrFrames.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPayload = _qrFrames[_currentFrame];
    final isAnimated = _qrFrames.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mã QR Giao Dịch Thô"),
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
              currentStep: 1,
              stepTitle: "Hoàn Tất Bước 1/3: Xuất Mã QR Giao Dịch Thô (txRaw)",
              subtitle: "Chuyển sang Bước 2/3: Mở Ví Lạnh và bấm 'QUÉT GIAO DỊCH CẦN KÝ (txRaw)'.",
            ),
            const Text(
              "DÙNG VÍ LẠNH (COLD WALLET) QUÉT MÃ QR NÀY ĐỂ KÝ",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: HotTheme.accent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: currentPayload,
                  version: QrVersions.auto,
                  size: 250.0,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (isAnimated) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: HotTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Đang phát QR Động: Mảnh ${_currentFrame + 1} / ${_qrFrames.length} (Tần số: 6 FPS)",
                    style: const TextStyle(color: HotTheme.accent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentFrame + 1) / _qrFrames.length,
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation(HotTheme.accent),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    if (widget.builtTx.isWithdrawal) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Số thưởng rút:"),
                          Text("${widget.builtTx.withdrawAda.toStringAsFixed(6)} ADA", style: const TextStyle(fontWeight: FontWeight.bold, color: HotTheme.accent)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Phí rút mạng (Conway):"),
                          Text("${widget.builtTx.feeAda.toStringAsFixed(6)} ADA", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Số nhận về đích:"),
                          Text("${widget.builtTx.sendAda.toStringAsFixed(6)} ADA", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Số tiền gửi:"),
                          Text("${widget.builtTx.sendAda.toStringAsFixed(6)} ADA", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (widget.builtTx.sentTokens.isNotEmpty) ...[
                        const Divider(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Token gửi kèm (${widget.builtTx.sentTokens.length}):", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        const SizedBox(height: 4),
                        for (final t in widget.builtTx.sentTokens)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("• ${t.displayName}:", style: const TextStyle(fontSize: 13)),
                                Text(
                                  "${t.formattedSendQuantity} ${t.asset.ticker ?? ''}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: HotTheme.accent, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Phí mạng:"),
                          Text("${widget.builtTx.feeAda.toStringAsFixed(6)} ADA", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Tiền thừa về ví:"),
                          Text("${widget.builtTx.changeAda.toStringAsFixed(6)} ADA", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text("Sao Chép Chuỗi txRaw Hex"),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.builtTx.rawCborHex));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đã sao chép chuỗi Hex vào Clipboard!")),
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("TIẾP TỤC: QUÉT txSigned TỪ VÍ LẠNH"),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanSignedScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
