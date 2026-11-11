import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';
import '../../core/theme/hot_theme.dart';
import '../../core/models/watched_wallet_entry.dart';
import '../../core/qr/qr_scanner_helper.dart';
import '../providers/hot_wallet_provider.dart';

class WalletManagerDialog extends ConsumerStatefulWidget {
  const WalletManagerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const WalletManagerDialog(),
    );
  }

  @override
  ConsumerState<WalletManagerDialog> createState() => _WalletManagerDialogState();
}

class _WalletManagerDialogState extends ConsumerState<WalletManagerDialog> {
  void _openAddWalletDialog() {
    final state = ref.read(hotWalletProvider);
    final defaultName = suggestNextWalletName<WatchedWalletEntry>(
      state.watchedWallets,
      (w) => w.name,
    );

    final nameCtrl = TextEditingController(text: defaultName);
    final addrCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: HotTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.add_card, color: HotTheme.accent),
            SizedBox(width: 8),
            Text("Thêm Ví Theo Dõi"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Tự động gom nhóm theo từ trước dấu '-'. Ví dụ: 'Trading-Ví 1' hoặc 'Savings-01'.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: "Tên ví (Preset name)",
                hintText: "Ví dụ: Chung-Ví 1, Trading-01...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addrCtrl,
              decoration: InputDecoration(
                labelText: "Địa chỉ Cardano",
                hintText: "addr1... hoặc addr_test1...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 20, color: HotTheme.accent),
                      tooltip: "Quét Camera QR",
                      onPressed: () {
                        WebQrScannerBridge.startLiveCamera((scanned) {
                          WebQrScannerBridge.stopLiveCamera();
                          addrCtrl.text = scanned.trim();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_paste, size: 20),
                      tooltip: "Dán từ bộ nhớ tạm",
                      onPressed: () async {
                        final clip = await Clipboard.getData('text/plain');
                        if (clip?.text != null) {
                          addrCtrl.text = clip!.text!.trim();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HotTheme.accent),
            onPressed: () {
              final addr = addrCtrl.text.trim();
              final name = nameCtrl.text.trim();
              if (addr.isEmpty) return;

              ref.read(hotWalletProvider.notifier).addWatchedWallet(addr, name: name);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Đã thêm ví '$name' vào danh sách theo dõi!"),
                  backgroundColor: HotTheme.accent,
                ),
              );
            },
            child: const Text("Lưu Ví"),
          ),
        ],
      ),
    );
  }

  void _openRenameDialog(WatchedWalletEntry wallet) {
    final nameCtrl = TextEditingController(text: wallet.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: HotTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.edit, color: HotTheme.accent),
            SizedBox(width: 8),
            Text("Đổi Tên Ví"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Nếu đổi từ trước dấu '-', ví sẽ tự động chuyển sang nhóm tương ứng và sắp xếp A-Z.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Tên ví mới",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HotTheme.accent),
            onPressed: () {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                ref.read(hotWalletProvider.notifier).renameWatchedWallet(wallet.id, newName);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Đã đổi tên thành '$newName'")),
                );
              }
            },
            child: const Text("Cập Nhật"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWallet(WatchedWalletEntry wallet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: HotTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Xóa Ví Theo Dõi"),
          ],
        ),
        content: Text(
          "Bạn có chắc chắn muốn xóa ví '${wallet.name}' khỏi danh sách theo dõi?\n\n(Địa chỉ: ${wallet.address.length > 20 ? '${wallet.address.substring(0, 12)}...${wallet.address.substring(wallet.address.length - 8)}' : wallet.address})",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              ref.read(hotWalletProvider.notifier).removeWatchedWallet(wallet.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Đã xóa ví '${wallet.name}'")),
              );
            },
            child: const Text("Xác Nhận Xóa", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hotWalletProvider);
    final grouped = groupAndSortWallets<WatchedWalletEntry>(
      wallets: state.watchedWallets,
      getName: (w) => w.name,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: HotTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            // Thanh gạt modal
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Tiêu đề & Tổng tài sản (Portfolio Overview)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: HotTheme.accent, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      "Quản Lý Ví & Portfolio",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: state.isRefreshingAll
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: HotTheme.accent),
                        )
                      : const Icon(Icons.refresh, color: HotTheme.accent),
                  tooltip: "Cập nhật số dư tất cả ví",
                  onPressed: () => ref.read(hotWalletProvider.notifier).fetchAllBalances(),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Portfolio Balance Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    HotTheme.accent.withOpacity(0.2),
                    Colors.deepPurple.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HotTheme.accent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TỔNG SỐ DƯ TẤT CẢ VÍ",
                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${state.totalPortfolioAda.toStringAsFixed(2)} ADA",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: HotTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${state.watchedWallets.length} Ví đang theo dõi",
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Danh sách phân nhóm A-Z
            Expanded(
              child: state.watchedWallets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_off, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text("Chưa có ví nào trong danh sách.", style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text("Thêm Ví Đầu Tiên"),
                            style: ElevatedButton.styleFrom(backgroundColor: HotTheme.accent),
                            onPressed: _openAddWalletDialog,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: grouped.length,
                      itemBuilder: (context, groupIdx) {
                        final grp = grouped[groupIdx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              leading: const Icon(Icons.folder, color: Colors.amberAccent, size: 22),
                              title: Row(
                                children: [
                                  Text(
                                    grp.groupName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "${grp.wallets.length}",
                                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ),
                              children: grp.wallets.map((w) {
                                final isCurrent = w.address == state.watchedAddress;
                                final shortAddr = w.address.length > 20
                                    ? "${w.address.substring(0, 10)}...${w.address.substring(w.address.length - 6)}"
                                    : w.address;

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? HotTheme.accent.withOpacity(0.12)
                                        : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCurrent ? HotTheme.accent : Colors.white12,
                                      width: isCurrent ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isCurrent ? Icons.check_circle : Icons.account_balance_wallet_outlined,
                                            size: 18,
                                            color: isCurrent ? HotTheme.accent : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              w.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isCurrent ? HotTheme.accent : Colors.white,
                                              ),
                                            ),
                                          ),
                                          if (isCurrent)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: HotTheme.accent,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                "Đang chọn",
                                                style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                                            tooltip: "Sửa tên ví",
                                            onPressed: () => _openRenameDialog(w),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                            tooltip: "Xóa ví",
                                            onPressed: () => _confirmDeleteWallet(w),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                shortAddr,
                                                style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'monospace'),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.copy, size: 13, color: Colors.grey),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                tooltip: "Sao chép địa chỉ",
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: w.address));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text("Đã sao chép địa chỉ!")),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          Text(
                                            "${w.cachedBalanceAda.toStringAsFixed(2)} ADA",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.amberAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!isCurrent) ...[
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 32,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: HotTheme.accent.withOpacity(0.5)),
                                              padding: EdgeInsets.zero,
                                            ),
                                            onPressed: () {
                                              ref.read(hotWalletProvider.notifier).switchWatchedWallet(w.id);
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text("Chọn Ví Này Để Giao Dịch", style: TextStyle(fontSize: 12)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            // Nút Thêm Ví Mới
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Thêm Ví Theo Dõi Mới", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HotTheme.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _openAddWalletDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
