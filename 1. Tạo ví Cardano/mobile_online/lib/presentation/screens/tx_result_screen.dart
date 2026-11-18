import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/hot_theme.dart';
import '../../core/utils/cardanoscan_helper.dart';
import '../providers/hot_wallet_provider.dart';

class TxResultScreen extends ConsumerWidget {
  final String txId;

  const TxResultScreen({super.key, required this.txId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(hotWalletProvider).network;
    final explorerUrl = CardanoscanHelper.getTxUrl(network, txId);

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
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.travel_explore_rounded, color: HotTheme.accent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "ĐỐI CHIẾU TRÊN CARDANOSCAN (${network.name.toUpperCase()}):",
                          style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Bạn có thể mở hoặc sao chép liên kết bên dưới để theo dõi trạng thái khối được xác nhận trên Cardanoscan:",
                      style: TextStyle(color: HotTheme.textMuted, fontSize: 11.5),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      explorerUrl,
                      style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16, color: HotTheme.accent),
                      label: const Text("Sao Chép Link Cardanoscan"),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: explorerUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Đã sao chép liên kết Cardanoscan vào Clipboard!")),
                        );
                      },
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
