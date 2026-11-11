import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/blockfrost_client.dart';
import '../../core/theme/hot_theme.dart';
import '../../core/network/stake_account_info.dart';
import '../../core/network/cardano_address_helper.dart';
import '../providers/hot_wallet_provider.dart';
import 'tx_raw_export_screen.dart';

enum DelegationMode { both, poolOnly, drepOnly }

enum PoolOption { preprod, fimi, custom }

enum DRepOption { alwaysAbstain, alwaysNoConfidence, fimi, custom }

class DelegateTxScreen extends ConsumerStatefulWidget {
  const DelegateTxScreen({super.key});

  @override
  ConsumerState<DelegateTxScreen> createState() => _DelegateTxScreenState();
}

class _DelegateTxScreenState extends ConsumerState<DelegateTxScreen> {
  DelegationMode _mode = DelegationMode.both;
  PoolOption _poolOption = PoolOption.preprod;
  DRepOption _drepOption = DRepOption.alwaysAbstain;

  final TextEditingController _customPoolCtrl = TextEditingController();
  final TextEditingController _customDRepCtrl = TextEditingController();
  bool _isBuilding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final net = ref.read(hotWalletProvider).network;
      if (net == CardanoNetwork.mainnet) {
        setState(() {
          _poolOption = PoolOption.fimi;
          _drepOption = DRepOption.fimi;
        });
      } else {
        setState(() {
          _poolOption = PoolOption.preprod;
          _drepOption = DRepOption.alwaysAbstain;
        });
      }
    });
  }

  @override
  void dispose() {
    _customPoolCtrl.dispose();
    _customDRepCtrl.dispose();
    super.dispose();
  }

  void _onBuildTx() async {
    String? poolId;
    if (_mode == DelegationMode.both || _mode == DelegationMode.poolOnly) {
      if (_poolOption == PoolOption.preprod) {
        poolId = StakeAccountInfo.preprodPoolId;
      } else if (_poolOption == PoolOption.fimi) {
        poolId = StakeAccountInfo.fimiPoolId;
      } else {
        poolId = _customPoolCtrl.text.trim();
        if (poolId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vui lòng nhập Pool ID hợp lệ!"), backgroundColor: Colors.red),
          );
          return;
        }
        final bytes = CardanoAddressHelper.poolIdToBytes(poolId);
        if (bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pool ID không hợp lệ (Phải là pool1... hoặc Hex 56 ký tự)!"), backgroundColor: Colors.red),
          );
          return;
        }
      }
    }

    String? drepId;
    if (_mode == DelegationMode.both || _mode == DelegationMode.drepOnly) {
      switch (_drepOption) {
        case DRepOption.alwaysAbstain:
          drepId = "always_abstain";
          break;
        case DRepOption.alwaysNoConfidence:
          drepId = "always_no_confidence";
          break;
        case DRepOption.fimi:
          drepId = StakeAccountInfo.fimiDRepId;
          break;
        case DRepOption.custom:
          drepId = _customDRepCtrl.text.trim();
          if (drepId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Vui lòng nhập DRep ID hợp lệ!"), backgroundColor: Colors.red),
            );
            return;
          }
          final bytes = CardanoAddressHelper.drepIdToBytes(drepId);
          if (bytes == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("DRep ID không hợp lệ (Phải là drep1... hoặc Hex 56 ký tự)!"), backgroundColor: Colors.red),
            );
            return;
          }
          break;
      }
    }

    setState(() => _isBuilding = true);

    try {
      final tx = await ref.read(hotWalletProvider.notifier).prepareDelegationTransaction(
        poolId: poolId,
        drepId: drepId,
      );

      setState(() => _isBuilding = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TxRawExportScreen(builtTx: tx),
        ),
      );
    } catch (e) {
      setState(() => _isBuilding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi tạo giao dịch: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hotWalletProvider);
    final isRegistered = state.stakeInfo?.isRegistered ?? state.isStakeActive;
    final depositAda = isRegistered ? 0.0 : 2.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ủy Thác Pool & DRep"),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HotTheme.buildAirGapStepHeader(
              currentStep: 1,
              stepTitle: "Bước 1/3: Khởi Tạo Ủy Thác Conway (Pool & DRep)",
              subtitle: "Tạo chứng chỉ ủy thác để gửi sang Ví Lạnh ký kép (Payment + Stake Key).",
            ),
            // Thẻ trạng thái hiện tại của ví
            Card(
              color: HotTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet, size: 20, color: HotTheme.accent),
                        const SizedBox(width: 8),
                        Text(
                          "Ví: ${state.watchedAddress != null ? (state.watchedAddress!.substring(0, 10) + '...' + state.watchedAddress!.substring(state.watchedAddress!.length - 6)) : 'Chưa có'}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isRegistered ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isRegistered ? Colors.green : Colors.orange),
                          ),
                          child: Text(
                            isRegistered ? "Stake Key: ĐÃ KÍCH HOẠT" : "Stake Key: CHƯA KÍCH HOẠT",
                            style: TextStyle(
                              color: isRegistered ? Colors.greenAccent : Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Số dư: ${state.balanceAda.toStringAsFixed(2)} ADA",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Chọn chế độ ủy thác
            const Text("Chọn Phương Thức Ủy Thác:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            SegmentedButton<DelegationMode>(
              segments: const [
                ButtonSegment<DelegationMode>(
                  value: DelegationMode.both,
                  label: Text("Cả Hai (Gộp)", style: TextStyle(fontSize: 12)),
                  icon: Icon(Icons.all_inclusive, size: 16),
                ),
                ButtonSegment<DelegationMode>(
                  value: DelegationMode.poolOnly,
                  label: Text("Chỉ Pool", style: TextStyle(fontSize: 12)),
                  icon: Icon(Icons.pie_chart, size: 16),
                ),
                ButtonSegment<DelegationMode>(
                  value: DelegationMode.drepOnly,
                  label: Text("Chỉ DRep", style: TextStyle(fontSize: 12)),
                  icon: Icon(Icons.how_to_vote, size: 16),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (set) => setState(() => _mode = set.first),
            ),
            const SizedBox(height: 18),

            // PHẦN CHỌN STAKE POOL
            if (_mode == DelegationMode.both || _mode == DelegationMode.poolOnly) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.pie_chart_outline, color: HotTheme.accent, size: 20),
                          SizedBox(width: 8),
                          Text("Ủy Thác Stake Pool", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (state.network != CardanoNetwork.mainnet) ...[
                        RadioListTile<PoolOption>(
                          contentPadding: EdgeInsets.zero,
                          title: const Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text("Preprod Stake Pool (Khuyến nghị) ", style: TextStyle(fontWeight: FontWeight.bold)),
                              Badge(label: Text("PREPROD", style: TextStyle(fontSize: 10))),
                            ],
                          ),
                          subtitle: const SelectableText(
                            StakeAccountInfo.preprodPoolId,
                            style: TextStyle(fontSize: 11, color: Colors.greenAccent),
                          ),
                          value: PoolOption.preprod,
                          groupValue: _poolOption,
                          onChanged: (val) => setState(() => _poolOption = val!),
                        ),
                      ],
                      RadioListTile<PoolOption>(
                        contentPadding: EdgeInsets.zero,
                        title: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text("FIMI Stake Pool ", style: TextStyle(fontWeight: FontWeight.bold)),
                            Badge(
                              label: Text(
                                state.network == CardanoNetwork.mainnet ? "MAINNET" : "MAINNET ONLY",
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          state.network == CardanoNetwork.mainnet
                              ? StakeAccountInfo.fimiPoolId
                              : "⚠️ Pool này đăng ký trên Mainnet: ${StakeAccountInfo.fimiPoolId}",
                          style: TextStyle(
                            fontSize: 11,
                            color: state.network == CardanoNetwork.mainnet ? Colors.grey : Colors.orangeAccent,
                          ),
                        ),
                        value: PoolOption.fimi,
                        groupValue: _poolOption,
                        onChanged: (val) => setState(() => _poolOption = val!),
                      ),
                      RadioListTile<PoolOption>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Nhập Stake Pool ID Khác"),
                        subtitle: const Text("Nhập ID dạng Bech32 (pool1...) hoặc Hex 56 ký tự", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        value: PoolOption.custom,
                        groupValue: _poolOption,
                        onChanged: (val) => setState(() => _poolOption = val!),
                      ),
                      if (_poolOption == PoolOption.custom) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: _customPoolCtrl,
                          decoration: InputDecoration(
                            labelText: "Stake Pool ID",
                            hintText: "pool1...",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.content_paste),
                              onPressed: () async {
                                final clip = await Clipboard.getData('text/plain');
                                if (clip?.text != null) {
                                  _customPoolCtrl.text = clip!.text!.trim();
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
            ],

            // PHẦN CHỌN DREP
            if (_mode == DelegationMode.both || _mode == DelegationMode.drepOnly) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.how_to_vote_outlined, color: HotTheme.accent, size: 20),
                          SizedBox(width: 8),
                          Text("Ủy Quyền DRep (Conway Governance)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<DRepOption>(
                        contentPadding: EdgeInsets.zero,
                        title: const Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text("Bỏ phiếu trắng (Always Abstain) ", style: TextStyle(fontWeight: FontWeight.bold)),
                            Badge(label: Text("CIP-1694", style: TextStyle(fontSize: 10))),
                          ],
                        ),
                        subtitle: const Text("Tùy chọn chuẩn Conway hợp lệ 100% trên mọi mạng Mainnet & Testnet", style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
                        value: DRepOption.alwaysAbstain,
                        groupValue: _drepOption,
                        onChanged: (val) => setState(() => _drepOption = val!),
                      ),
                      RadioListTile<DRepOption>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Luôn bất tín nhiệm (Always No Confidence)"),
                        subtitle: const Text("Luôn bỏ phiếu bất tín nhiệm ủy ban lập hiến (Hợp lệ trên mọi mạng)", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        value: DRepOption.alwaysNoConfidence,
                        groupValue: _drepOption,
                        onChanged: (val) => setState(() => _drepOption = val!),
                      ),
                      RadioListTile<DRepOption>(
                        contentPadding: EdgeInsets.zero,
                        title: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text("FIMI DRep ", style: TextStyle(fontWeight: FontWeight.bold)),
                            Badge(
                              label: Text(
                                state.network == CardanoNetwork.mainnet ? "MAINNET" : "MAINNET ONLY",
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          state.network == CardanoNetwork.mainnet
                              ? StakeAccountInfo.fimiDRepId
                              : "⚠️ DRep này đăng ký trên Mainnet: ${StakeAccountInfo.fimiDRepId}",
                          style: TextStyle(
                            fontSize: 11,
                            color: state.network == CardanoNetwork.mainnet ? Colors.grey : Colors.orangeAccent,
                          ),
                        ),
                        value: DRepOption.fimi,
                        groupValue: _drepOption,
                        onChanged: (val) => setState(() => _drepOption = val!),
                      ),
                      RadioListTile<DRepOption>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Ủy quyền cho DRep ID khác"),
                        subtitle: const Text("Nhập ID dạng Bech32 (drep1...) hoặc Hex", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        value: DRepOption.custom,
                        groupValue: _drepOption,
                        onChanged: (val) => setState(() => _drepOption = val!),
                      ),
                      if (_drepOption == DRepOption.custom) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: _customDRepCtrl,
                          decoration: InputDecoration(
                            labelText: "DRep ID",
                            hintText: "drep1...",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.content_paste),
                              onPressed: () async {
                                final clip = await Clipboard.getData('text/plain');
                                if (clip?.text != null) {
                                  _customDRepCtrl.text = clip!.text!.trim();
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
            ],

            // BẢNG DỰ TOÁN CHI PHÍ & TIỀN CỌC
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Ước tính phí mạng (Conway Fee):", style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const Text("~0.195 ADA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Tiền cọc đăng ký khóa (Key Deposit):", style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(
                        depositAda > 0 ? "$depositAda ADA (Lần đầu)" : "0.00 ADA (Đã cọc)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: depositAda > 0 ? Colors.orangeAccent : Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Tổng chi phí khấu trừ từ ví:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        "${(0.195 + depositAda).toStringAsFixed(3)} ADA",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: HotTheme.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Toàn bộ ADA và Native Token còn lại sẽ tự động trả về ví (Change Guard). Tiền cọc 2 ADA sẽ được hoàn trả nếu bạn hủy đăng ký khóa stake sau này.",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Nút Tạo Giao Dịch Thô
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: HotTheme.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isBuilding
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.qr_code_2),
              label: Text(
                _isBuilding ? "Đang Xây Dựng Giao Dịch..." : "Khởi Tạo Giao Dịch Thô (Xuất QR)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: _isBuilding ? null : _onBuildTx,
            ),
          ],
        ),
      ),
    );
  }
}
