import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/hot_theme.dart';

class TxResultScreen extends StatelessWidget {
  final String txId;

  const TxResultScreen({super.key, required this.txId});

  @override
  Widget build(BuildContext context) {
    final explorerUrl = "https://preprod.cardanoscan.io/transaction/$txId";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kết Quả Giao Dịch"),
        automaticallyImplyLeading: false,
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
              stepTitle: "Hoàn Tất Quy Trình 3/3: Giao Dịch Đã Lên Chuỗi!",
            ),
            const Icon(Icons.check_circle_rounded, size: 72, color: HotTheme.safeGreen),
            const SizedBox(height: 16),
            const Text(
              "GIAO DỊCH ĐÃ ĐƯỢC PHÁT SÓNG THÀNH CÔNG!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HotTheme.safeGreen),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Giao dịch đã được gửi vào Mempool của mạng Cardano và đang chờ được xác nhận vào khối mới.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("MÃ HASH GIAO DỊCH (TXID):", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    SelectableText(
                      txId,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: HotTheme.accent),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text("Sao Chép TxID"),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: txId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Đã sao chép TxID vào Clipboard!")),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("TRA CỨU TRÊN CARDANOSCAN:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    SelectableText(
                      explorerUrl,
                      style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text("VỀ BẢNG ĐIỀU KHIỂN (DASHBOARD)"),
            ),
          ],
        ),
      ),
    );
  }
}
