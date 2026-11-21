import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/hot_theme.dart';
import '../providers/hot_wallet_provider.dart';
import 'tx_raw_export_screen.dart';

class DeregisterStakeScreen extends ConsumerStatefulWidget {
  const DeregisterStakeScreen({super.key});

  @override
  ConsumerState<DeregisterStakeScreen> createState() => _DeregisterStakeScreenState();
}

class _DeregisterStakeScreenState extends ConsumerState<DeregisterStakeScreen> {
  final TextEditingController _customAddressController = TextEditingController();
  bool _useCustomAddress = false;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _customAddressController.dispose();
    super.dispose();
  }

  void _onBuildDeregisterTxPressed() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final state = ref.read(hotWalletProvider);
    final targetDestination = _useCustomAddress
        ? _customAddressController.text.trim()
        : state.watchedAddress;

    if (_useCustomAddress && (targetDestination == null || targetDestination.isEmpty)) {
      setState(() {
        _errorMessage = "Vui lòng nhập địa chỉ nhận tiền hoàn cọc.";
        _isLoading = false;
      });
      return;
    }

    try {
      final builtTx = await ref.read(hotWalletProvider.notifier).prepareStakeDeregistrationTransaction(
        destinationAddress: _useCustomAddress ? targetDestination : null,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TxRawExportScreen(builtTx: builtTx),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hotWalletProvider);
    const int depositLovelace = 2000000;
    const double depositAda = 2.0;
    const int estimatedFeeLovelace = 195000;
    const double estimatedFeeAda = estimatedFeeLovelace / 1000000.0;
    final int totalReclaimLovelace = depositLovelace + state.withdrawableRewardLovelace;
    final int netReclaimLovelace = totalReclaimLovelace > estimatedFeeLovelace
        ? totalReclaimLovelace - estimatedFeeLovelace
        : 0;
    final double netReclaimAda = netReclaimLovelace / 1000000.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hủy Stake & Hoàn Cọc"),
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
              stepTitle: "Bước 1/3: Khởi Tạo Lệnh Hủy Stake & Thu Hồi Cọc",
              subtitle: "Đóng gói giao dịch thu hồi cọc 2 ADA và rút sạch thưởng để ký ngoại tuyến trên Ví Lạnh.",
            ),

            // Thẻ Cảnh báo Rủi ro
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                      SizedBox(width: 8),
                      Text(
                        "CẢNH BÁO QUAN TRỌNG VỀ HỦY STAKE",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "• Stake Key của bạn sẽ bị hủy đăng ký (Deregister) trên mạng Cardano.\n"
                    "• Bạn sẽ NGỪNG NHẬN THƯỞNG Staking kể từ epoch tiếp theo.\n"
                    "• Toàn bộ 2.00 ADA tiền cọc ban đầu + số dư thưởng chưa rút sẽ được hoàn trả.\n"
                    "• Nếu muốn tham gia Staking trở lại sau này, bạn sẽ cần nộp lại 2.00 ADA tiền cọc mới.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Thẻ Chi Tiết Tài Chính Hoàn Trả
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_return_outlined, color: HotTheme.safeGreen, size: 26),
                        SizedBox(width: 8),
                        Text(
                          "TỔNG DỰ KIẾN NHẬN VỀ",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "+${netReclaimAda.toStringAsFixed(6)} ADA",
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: HotTheme.safeGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "(Bao gồm tiền hoàn cọc và toàn bộ tiền thưởng sau khi trừ phí mạng)",
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 24),

                    // Chi tiết từng khoản
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Tiền cọc thế chấp hoàn lại:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text(
                          "+${depositAda.toStringAsFixed(6)} ADA",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: HotTheme.safeGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Thưởng Staking rút sạch:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text(
                          state.withdrawableRewardAda > 0
                              ? "+${state.withdrawableRewardAda.toStringAsFixed(6)} ADA"
                              : "0.000000 ADA",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: state.withdrawableRewardAda > 0 ? HotTheme.accent : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Phí mạng ước tính (Conway):", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text(
                          "-$estimatedFeeAda ADA",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Stake Address:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Flexible(
                          child: Text(
                            state.stakeAddress != null
                                ? "${state.stakeAddress!.substring(0, 14)}...${state.stakeAddress!.substring(state.stakeAddress!.length - 8)}"
                                : "Chưa xác định",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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

            // Tùy chọn địa chỉ nhận tùy chỉnh
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _useCustomAddress,
                          activeColor: HotTheme.accent,
                          onChanged: (val) {
                            setState(() {
                              _useCustomAddress = val ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            "Gửi tiền thu hồi sang địa chỉ khác (Tùy chọn)",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (_useCustomAddress) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customAddressController,
                        decoration: InputDecoration(
                          hintText: "Nhập địa chỉ Cardano đích (addr1... / addr_test1...)",
                          hintStyle: const TextStyle(fontSize: 12),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste, size: 20),
                            onPressed: () async {
                              final data = await Clipboard.getData('text/plain');
                              if (data?.text != null) {
                                _customAddressController.text = data!.text!.trim();
                              }
                            },
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        minLines: 1,
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                        child: Text(
                          "Mặc định hoàn tiền trực tiếp về địa chỉ ví hiện tại:\n${state.watchedAddress ?? ''}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cancel_outlined, size: 22),
              label: Text(
                _isLoading ? "ĐANG ĐÓNG GÓI GIAO DỊCH..." : "TẠO LỆNH HỦY STAKE & THU HỒI CỌC",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _isLoading ? null : _onBuildDeregisterTxPressed,
            ),
          ],
        ),
      ),
    );
  }
}
