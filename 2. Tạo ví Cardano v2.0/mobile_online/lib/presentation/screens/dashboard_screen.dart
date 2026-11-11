import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/network/blockfrost_client.dart';
import '../../core/theme/hot_theme.dart';
import '../../core/utils/clipboard_helper.dart';
import '../providers/hot_wallet_provider.dart';
import '../widgets/wallet_manager_dialog.dart';
import 'build_tx_screen.dart';
import 'scan_signed_screen.dart';
import 'hot_settings_screen.dart';
import 'withdraw_reward_screen.dart';
import 'delegate_tx_screen.dart';
import '../../core/network/stake_account_info.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _assetTabIndex = 0; // 0: Tài Sản Native Tokens, 1: Danh Sách UTXO

  void _showNetworkDialog(BuildContext context, CardanoNetwork currentNet) async {
    CardanoNetwork selected = currentNet;
    final initialKey = await ref.read(hotWalletProvider.notifier).getSavedApiKeyForNetwork(selected) ??
        ref.read(hotWalletProvider.notifier).activeCustomApiKey ??
        '';
    final apiKeyCtrl = TextEditingController(text: initialKey);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final validationWarning = BlockfrostClient.validateKeyForNetwork(selected, apiKeyCtrl.text);

          return AlertDialog(
            scrollable: true,
            backgroundColor: HotTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            title: const Row(
              children: [
                Icon(Icons.public, color: HotTheme.accent, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Chuyển Môi Trường Mạng",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Chọn mạng Cardano truy vấn qua Blockfrost:",
                    style: TextStyle(color: HotTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HotTheme.border),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<CardanoNetwork>(
                          dense: true,
                          activeColor: HotTheme.accent,
                          title: const Text("Preprod Testnet", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text("cardano-preprod.blockfrost.io", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          value: CardanoNetwork.preprod,
                          groupValue: selected,
                          onChanged: (val) async {
                            if (val == null) return;
                            final k = await ref.read(hotWalletProvider.notifier).getSavedApiKeyForNetwork(val);
                            setDialogState(() {
                              selected = val;
                              apiKeyCtrl.text = k ?? '';
                            });
                          },
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        RadioListTile<CardanoNetwork>(
                          dense: true,
                          activeColor: HotTheme.accent,
                          title: const Text("Preview Testnet", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text("cardano-preview.blockfrost.io", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          value: CardanoNetwork.preview,
                          groupValue: selected,
                          onChanged: (val) async {
                            if (val == null) return;
                            final k = await ref.read(hotWalletProvider.notifier).getSavedApiKeyForNetwork(val);
                            setDialogState(() {
                              selected = val;
                              apiKeyCtrl.text = k ?? '';
                            });
                          },
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        RadioListTile<CardanoNetwork>(
                          dense: true,
                          activeColor: HotTheme.accent,
                          title: const Text("Mainnet (Chính thức)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text("cardano-mainnet.blockfrost.io", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          value: CardanoNetwork.mainnet,
                          groupValue: selected,
                          onChanged: (val) async {
                            if (val == null) return;
                            final k = await ref.read(hotWalletProvider.notifier).getSavedApiKeyForNetwork(val);
                            setDialogState(() {
                              selected = val;
                              apiKeyCtrl.text = k ?? '';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Blockfrost Project ID cho ${selected.name.toUpperCase()}:",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      Text(
                        "(Tùy chọn)",
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: apiKeyCtrl,
                    enableInteractiveSelection: true,
                    onChanged: (_) => setDialogState(() {}),
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: "Dán key '${BlockfrostClient.expectedPrefix(selected)}...' nếu có",
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.black26,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (apiKeyCtrl.text.isNotEmpty)
                            IconButton(
                              tooltip: "Xóa key",
                              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                              onPressed: () {
                                apiKeyCtrl.clear();
                                setDialogState(() {});
                              },
                            ),
                          IconButton(
                            tooltip: "Dán từ bộ nhớ tạm (Paste)",
                            icon: const Icon(Icons.paste_rounded, size: 20, color: HotTheme.accent),
                            onPressed: () async {
                              await ClipboardHelper.paste(
                                ctx,
                                targetController: apiKeyCtrl,
                                fieldName: "Project ID",
                              );
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (validationWarning != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orangeAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            validationWarning,
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HotTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final key = apiKeyCtrl.text.trim();
                  await ref.read(hotWalletProvider.notifier).switchNetwork(
                    selected,
                    apiKey: key,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("✓ Đã chuyển sang mạng ${selected.name.toUpperCase()}!"),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: HotTheme.surface,
                      ),
                    );
                  }
                },
                label: const Text("Áp Dụng", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWalletSwitcherDialog(BuildContext context) {
    WalletManagerDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hotWalletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ví Nóng Cardano"),
        actions: [
          IconButton(
            tooltip: "Quản lý danh sách ví & Portfolio",
            icon: const Icon(Icons.account_balance_wallet, color: HotTheme.accent),
            onPressed: () => WalletManagerDialog.show(context),
          ),
          IconButton(
            tooltip: "Chuyển mạng (Preprod / Preview / Mainnet)",
            icon: const Icon(Icons.public),
            onPressed: () => _showNetworkDialog(context, state.network),
          ),
          IconButton(
            tooltip: "Làm mới số dư",
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(hotWalletProvider.notifier).fetchBalance(),
          ),
          IconButton(
            tooltip: "Cài Đặt & Cập Nhật",
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HotSettingsScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: HotTheme.buildLiveNetworkBadge(
              networkName: state.network.name.toUpperCase(),
              onTap: () => _showNetworkDialog(context, state.network),
            ),
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: HotTheme.accent))
          : RefreshIndicator(
              onRefresh: () => ref.read(hotWalletProvider.notifier).fetchBalance(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Bộ chọn ví (Wallet Selector Pill)
                    InkWell(
                      onTap: () => _showWalletSwitcherDialog(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: HotTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: HotTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: HotTheme.primary.withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet,
                                      size: 18,
                                      color: HotTheme.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                state.activeWallet?.name ?? "VÍ ĐANG THEO DÕI",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: HotTheme.accent,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (state.activeWallet != null) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.white12,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  state.activeWallet!.groupName,
                                                  style: const TextStyle(fontSize: 10, color: HotTheme.accent),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              state.watchedAddress != null
                                                  ? (state.watchedAddress!.length > 20
                                                      ? "${state.watchedAddress!.substring(0, 12)}...${state.watchedAddress!.substring(state.watchedAddress!.length - 8)}"
                                                      : state.watchedAddress!)
                                                  : "Chưa chọn ví",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: HotTheme.textMuted,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                            if (state.watchedAddress != null && state.watchedAddress!.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              InkWell(
                                                borderRadius: BorderRadius.circular(4),
                                                onTap: () {
                                                  ClipboardHelper.copy(
                                                    context,
                                                    state.watchedAddress!,
                                                    message: "Đã sao chép địa chỉ ví!",
                                                  );
                                                },
                                                child: const Padding(
                                                  padding: EdgeInsets.all(2.0),
                                                  child: Icon(Icons.copy_rounded, size: 13, color: HotTheme.accent),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${state.watchedWallets.length} ví",
                                    style: const TextStyle(fontSize: 11, color: HotTheme.textMuted),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down, color: HotTheme.accent),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. HERO BALANCE CARD & CỤM 3 HÀNH ĐỘNG GIAO DỊCH CỐT LÕI
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF281D11), Color(0xFF1C2029)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: HotTheme.accent.withOpacity(0.5), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "TỔNG SỐ DƯ KHẢ DỤNG",
                            style: TextStyle(
                              color: HotTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Số dư màu Trắng sáng (#F8FAFC) rõ ràng, không dùng màu Đỏ cảnh báo
                          Text(
                            "${state.balanceAda.toStringAsFixed(6)} ADA",
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: HotTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "(${state.totalLovelace} Lovelace)",
                            style: const TextStyle(fontSize: 12, color: HotTheme.textMuted),
                          ),
                          const SizedBox(height: 18),
                          // Hàng 1: GỬI TIỀN (Bước 1/3) & NHẬN TIỀN
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: HotTheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                  ),
                                  icon: const Icon(Icons.send_rounded, size: 18),
                                  label: const Text("GỬI TIỀN"),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const BuildTxScreen()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: HotTheme.accent,
                                    side: const BorderSide(color: HotTheme.accent, width: 1.2),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                  ),
                                  icon: const Icon(Icons.call_received_rounded, size: 18),
                                  label: const Text("NHẬN TIỀN"),
                                  onPressed: () {
                                    _showReceiveDialog(context, state.watchedAddress ?? '');
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Hàng 2: QUÉT GIAO DỊCH ĐÃ KÝ (txSigned) & PHÁT SÓNG (Bước 3/3 Air-Gap ngay trên Hero Card)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: HotTheme.accent,
                                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: HotTheme.accent.withOpacity(0.6), width: 1.2),
                                ),
                              ),
                              icon: const Icon(Icons.qr_code_scanner, color: HotTheme.accent, size: 20),
                              label: const Text(
                                "QUÉT GIAO DỊCH ĐÃ KÝ (txSigned) & PHÁT SÓNG",
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ScanSignedScreen()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Thẻ Ủy Thác & Quản Trị Conway Era (Bố cục Bento 2 cột gọn gàng)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.how_to_vote, color: HotTheme.accent, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "ỦY THÁC & QUẢN TRỊ (CONWAY)",
                                      style: TextStyle(
                                        color: HotTheme.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ((state.stakeInfo?.isRegistered ?? state.isStakeActive)
                                            ? HotTheme.safeGreen
                                            : HotTheme.accent)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: ((state.stakeInfo?.isRegistered ?? state.isStakeActive)
                                              ? HotTheme.safeGreen
                                              : HotTheme.accent)
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                  child: Text(
                                    (state.stakeInfo?.isRegistered ?? state.isStakeActive)
                                        ? "STAKE KEY: ĐÃ KÍCH HOẠT"
                                        : "STAKE KEY: CHƯA CỌC",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: (state.stakeInfo?.isRegistered ?? state.isStakeActive)
                                          ? HotTheme.safeGreen
                                          : HotTheme.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Bento Grid 2 Cột: [ Stake Pool | DRep Quản Trị ]
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.pie_chart_outline, size: 15, color: HotTheme.accent),
                                            const SizedBox(width: 5),
                                            const Expanded(
                                              child: Text(
                                                "Stake Pool:",
                                                style: TextStyle(
                                                  color: HotTheme.textMuted,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (state.stakeInfo?.isFimiPool == true ||
                                                state.stakedPoolId == StakeAccountInfo.fimiPoolId)
                                              const Badge(label: Text("FIMI", style: TextStyle(fontSize: 9))),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        SelectableText(
                                          state.stakeInfo?.displayPoolTitle ??
                                              (state.stakedPoolId != null
                                                  ? (state.stakedPoolId!.length > 20
                                                      ? "${state.stakedPoolId!.substring(0, 10)}...${state.stakedPoolId!.substring(state.stakedPoolId!.length - 6)}"
                                                      : state.stakedPoolId!)
                                                  : "Chưa ủy thác Stake Pool"),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.how_to_vote_outlined, size: 15, color: HotTheme.accent),
                                            const SizedBox(width: 5),
                                            const Expanded(
                                              child: Text(
                                                "DRep Quản Trị:",
                                                style: TextStyle(
                                                  color: HotTheme.textMuted,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (state.stakeInfo?.isFimiDRep == true)
                                              const Badge(label: Text("FIMI", style: TextStyle(fontSize: 9))),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        SelectableText(
                                          state.stakeInfo?.displayDRepTitle ?? "Chưa ủy quyền DRep",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Active Stake & Phần thưởng
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Tổng ADA đang Stake:",
                                      style: TextStyle(fontSize: 11, color: HotTheme.textMuted),
                                    ),
                                    Text(
                                      "${(state.stakeInfo?.controlledAda ?? state.balanceAda).toStringAsFixed(2)} ADA",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: HotTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      "Thưởng Khả Dụng:",
                                      style: TextStyle(fontSize: 11, color: HotTheme.textMuted),
                                    ),
                                    Text(
                                      "${state.withdrawableRewardAda.toStringAsFixed(6)} ADA",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: HotTheme.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // Nút hành động: Ủy thác & Rút thưởng
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: HotTheme.accent,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.how_to_vote, size: 18),
                                    label: const Text(
                                      "ỦY THÁC POOL & DREP",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const DelegateTxScreen()),
                                      );
                                    },
                                  ),
                                ),
                                if (state.withdrawableRewardLovelace > 195000) ...[
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: HotTheme.safeGreen,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.savings_outlined, size: 18),
                                    label: const Text(
                                      "RÚT THƯỞNG",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const WithdrawRewardScreen()),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. KHUNG 2 TAB CHUYỂN ĐỔI: [ Tài Sản Native Tokens | Danh Sách UTXO ]
                    Container(
                      decoration: BoxDecoration(
                        color: HotTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: HotTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _assetTabIndex = 0),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: _assetTabIndex == 0
                                            ? HotTheme.primary.withOpacity(0.3)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _assetTabIndex == 0 ? HotTheme.accent : Colors.transparent,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.toll,
                                            size: 17,
                                            color: _assetTabIndex == 0 ? HotTheme.accent : HotTheme.textMuted,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              "Tài Sản Native Tokens (${state.tokens.length})",
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: _assetTabIndex == 0
                                                    ? Colors.white
                                                    : HotTheme.textMuted,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _assetTabIndex = 1),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: _assetTabIndex == 1
                                            ? HotTheme.primary.withOpacity(0.3)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _assetTabIndex == 1 ? HotTheme.accent : Colors.transparent,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.layers_outlined,
                                            size: 17,
                                            color: _assetTabIndex == 1 ? HotTheme.accent : HotTheme.textMuted,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              "Danh Sách UTXO (${state.utxos.length})",
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: _assetTabIndex == 1
                                                    ? Colors.white
                                                    : HotTheme.textMuted,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: _assetTabIndex == 0
                                ? (state.tokens.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 18.0),
                                        child: Center(
                                          child: Text(
                                            "Không có Native Token nào trong ví.",
                                            style: TextStyle(color: HotTheme.textMuted, fontSize: 13),
                                          ),
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          for (final token in state.tokens)
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.black26,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.white10),
                                              ),
                                              child: ListTile(
                                                leading: CircleAvatar(
                                                  backgroundColor: HotTheme.accent.withOpacity(0.18),
                                                  child: Text(
                                                    token.displayName
                                                        .substring(0, token.displayName.length >= 2 ? 2 : 1)
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: HotTheme.accent,
                                                    ),
                                                  ),
                                                ),
                                                title: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        token.displayName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14.5,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (token.ticker != null &&
                                                        token.ticker != token.displayName) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey[800],
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          token.ticker!,
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.white70,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                subtitle: Text(
                                                  "Policy: ${token.policyId.substring(0, 10)}...${token.policyId.substring(token.policyId.length - 6)}",
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: HotTheme.textMuted,
                                                  ),
                                                ),
                                                trailing: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      token.formattedBalance,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    if (token.ticker != null)
                                                      Text(
                                                        token.ticker!,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: HotTheme.accent,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ))
                                : (state.utxos.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 18.0),
                                        child: Center(
                                          child: Text(
                                            "Không có UTXO nào. Hãy nạp ADA vào ví để bắt đầu.",
                                            style: TextStyle(color: HotTheme.textMuted, fontSize: 13),
                                          ),
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          for (final u in state.utxos)
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.black26,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.white10),
                                              ),
                                              child: ListTile(
                                                leading: const Icon(
                                                  Icons.account_balance_wallet_outlined,
                                                  color: HotTheme.accent,
                                                ),
                                                title: Text(
                                                  "${(int.parse(u['amount'][0]['quantity']) / 1000000).toStringAsFixed(6)} ADA",
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                subtitle: Text(
                                                  "${u['tx_hash']}#${u['tx_index']}",
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: HotTheme.textMuted,
                                                    fontFamily: 'monospace',
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                        ],
                                      )),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showReceiveDialog(BuildContext context, String address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HotTheme.surface,
        title: const Text("Địa Chỉ Nhận Của Ví"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(data: address, size: 180),
            ),
            const SizedBox(height: 12),
            HotTheme.buildHighlightedAddress(
              address,
              fontSize: 12,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Đã sao chép địa chỉ ví!")),
              );
            },
            child: const Text("Sao Chép"),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
        ],
      ),
    );
  }
}
