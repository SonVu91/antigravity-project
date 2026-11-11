import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/hot_theme.dart';
import '../providers/hot_wallet_provider.dart';
import 'tx_raw_export_screen.dart';

class WithdrawRewardScreen extends ConsumerStatefulWidget {
  const WithdrawRewardScreen({super.key});

  @override
  ConsumerState<WithdrawRewardScreen> createState() => _WithdrawRewardScreenState();
}

class _WithdrawRewardScreenState extends ConsumerState<WithdrawRewardScreen> {
  final TextEditingController _customAddressController = TextEditingController();
  bool _useCustomAddress = false;
  String? _errorMessage;

  @override
  void dispose() {
    _customAddressController.dispose();
    super.dispose();
  }

  void _onBuildWithdrawTxPressed() async {
    setState(() => _errorMessage = null);

    final state = ref.read(hotWalletProvider);
    final targetDestination = _useCustomAddress
        ? _customAddressController.text.trim()
        : state.watchedAddress;

    if (_useCustomAddress && (targetDestination == null || targetDestination.isEmpty)) {
      setState(() => _errorMessage = "Vui lòng nhập địa chỉ nhận thưởng.");
      return;
    }

    const estimatedFeeLovelace = 195000;
    if (state.withdrawableRewardLovelace <= estimatedFeeLovelace) {
      setState(() {
        _errorMessage = "Số phần thưởng (${state.withdrawableRewardAda.toStringAsFixed(6)} ADA) không đủ chi trả phí rút (${(estimatedFeeLovelace / 1000000).toStringAsFixed(6)} ADA)!";
      });
      return;
    }

    try {
      final builtTx = await ref.read(hotWalletProvider.notifier).prepareRewardWithdrawalTransaction(
        destinationAddress: _useCustomAddress ? targetDestination : null,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TxRawExportScreen(builtTx: builtTx),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hotWalletProvider);
    const int estimatedFeeLovelace = 195000;
    const double estimatedFeeAda = estimatedFeeLovelace / 1000000.0;
    final int netReceiveLovelace = (state.withdrawableRewardLovelace > estimatedFeeLovelace)
        ? (state.withdrawableRewardLovelace - estimatedFeeLovelace)
        : 0;
    final double netReceiveAda = netReceiveLovelace / 1000000.0;
    final bool canWithdraw = state.withdrawableRewardLovelace > estimatedFeeLovelace;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rút Thưởng Staking"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: HotTheme.buildLiveNetworkBadge(
              networkName: state.network.name.toUpperCase(),
            ),
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
              stepTitle: "Bước 1/3: Khởi Tạo Lệnh Rút Thưởng Staking",
              subtitle: "Đóng gói giao dịch rút thưởng để ký kép ngoại tuyến trên Ví Lạnh.",
            ),
            // Thẻ Card Tổng Thưởng Khả Dụng
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.savings_outlined, color: HotTheme.accent, size: 28),
                        SizedBox(width: 8),
                        Text(
                          "PHẦN THƯỞNG KHẢ DỤNG",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "${state.withdrawableRewardAda.toStringAsFixed(6)} ADA",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: HotTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "(${state.withdrawableRewardLovelace} Lovelace)",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Stake Pool:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Flexible(
                          child: Text(
                            state.stakedPoolId != null
                                ? "${state.stakedPoolId!.substring(0, 14)}...${state.stakedPoolId!.substring(state.stakedPoolId!.length - 8)}"
                                : "Chưa xác định",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Stake Address:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Flexible(
                          child: Text(
                            state.stakeAddress != null
                                ? "${state.stakeAddress!.substring(0, 14)}...${state.stakeAddress!.substring(state.stakeAddress!.length - 8)}"
                                : "Chưa có",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Thẻ Chọn Địa Chỉ Nhận Thưởng
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Địa Chỉ Nhận Thưởng",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Chính địa chỉ ví hiện tại (Khuyến nghị)"),
                      subtitle: Text(
                        state.watchedAddress ?? "Chưa thiết lập",
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      value: false,
                      groupValue: _useCustomAddress,
                      onChanged: (val) => setState(() => _useCustomAddress = val!),
                    ),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Chuyển đến địa chỉ nhận khác"),
                      value: true,
                      groupValue: _useCustomAddress,
                      onChanged: (val) => setState(() => _useCustomAddress = val!),
                    ),
                    if (_useCustomAddress) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customAddressController,
                        decoration: InputDecoration(
                          labelText: "Địa chỉ người nhận",
                          hintText: "addr1... hoặc addr_test1...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste),
                            tooltip: "Dán từ bộ nhớ tạm",
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data != null && data.text != null) {
                                _customAddressController.text = data.text!.trim();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Thẻ Tự Động Tính Phí Rút & Số Nhận Thực
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: HotTheme.accent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Bóc Tách Phí Rút Tự Động",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Tổng thưởng rút:", style: TextStyle(color: Colors.grey)),
                        Text("${state.withdrawableRewardAda.toStringAsFixed(6)} ADA", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Phí mạng ước tính (Conway):", style: TextStyle(color: Colors.grey)),
                        Text("~0.195000 ADA", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Cơ chế khấu trừ:", style: TextStyle(color: Colors.grey)),
                        Text("Trừ trực tiếp vào tiền thưởng", style: TextStyle(fontSize: 12, color: HotTheme.accent)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("UTXO mồi khởi tạo giao dịch:", style: TextStyle(color: Colors.grey)),
                        Text(
                          state.utxos.isNotEmpty ? "1 UTXO (${(int.parse(state.utxos.first['amount'][0]['quantity']) / 1000000).toStringAsFixed(2)} ADA)" : "Không có",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Số ADA Thưởng Thực Nhận:",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          "${netReceiveAda.toStringAsFixed(6)} ADA",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: canWithdraw ? Colors.greenAccent : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cảnh báo nếu không đủ phí
            if (!canWithdraw) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.withdrawableRewardLovelace == 0
                            ? "Hiện tại không có phần thưởng Staking nào khả dụng để rút."
                            : "Số thưởng (${state.withdrawableRewardAda.toStringAsFixed(6)} ADA) nhỏ hơn phí rút mạng (~0.195 ADA). Vui lòng tích lũy thêm thưởng trước khi rút.",
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              ),
              const SizedBox(height: 16),
            ],

            // Nút bấm Tạo giao dịch rút thưởng
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: canWithdraw ? HotTheme.primary : Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.qr_code),
              label: const Text(
                "TẠO GIAO DỊCH RÚT THƯỞNG",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: canWithdraw ? _onBuildWithdrawTxPressed : null,
            ),
          ],
        ),
      ),
    );
  }
}
