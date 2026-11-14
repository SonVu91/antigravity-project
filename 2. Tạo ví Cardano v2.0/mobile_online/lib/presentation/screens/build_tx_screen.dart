import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/token_asset.dart';
import '../../core/network/cardano_address_helper.dart';
import '../../core/theme/hot_theme.dart';
import '../../core/tx/tx_builder.dart';
import '../../core/qr/qr_scanner_helper.dart';
import '../../core/utils/clipboard_helper.dart';
import '../providers/hot_wallet_provider.dart';
import 'tx_raw_export_screen.dart';

class SelectedTokenItem {
  final TokenAsset asset;
  final TextEditingController amountController;

  SelectedTokenItem({
    required this.asset,
    required this.amountController,
  });

  BigInt get sendQuantity => asset.parseInputAmount(amountController.text);
}

class BuildTxScreen extends ConsumerStatefulWidget {
  const BuildTxScreen({super.key});

  @override
  ConsumerState<BuildTxScreen> createState() => _BuildTxScreenState();
}

class _BuildTxScreenState extends ConsumerState<BuildTxScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final List<SelectedTokenItem> _selectedTokens = [];
  bool _isSendMax = false;
  String? _error;

  @override
  void dispose() {
    WebQrScannerBridge.stopLiveCamera();
    _recipientController.dispose();
    _amountController.dispose();
    for (final item in _selectedTokens) {
      item.amountController.dispose();
    }
    super.dispose();
  }

  void _onScanRecipientQr() {
    FocusScope.of(context).unfocus();
    WebQrScannerBridge.startLiveCamera((scanned) {
      WebQrScannerBridge.stopLiveCamera();
      String clean = scanned.trim();

      // 1. Nếu là JSON (ví dụ {"address": "addr_test1...", ...})
      try {
        if (clean.startsWith('{') && clean.endsWith('}')) {
          final decoded = jsonDecode(clean);
          if (decoded is Map) {
            final possible = decoded['address'] ?? decoded['addr'] ?? decoded['target'] ?? decoded['recipient'];
            if (possible != null && possible is String) {
              clean = possible.trim();
            }
          }
        }
      } catch (_) {}

      // 2. Loại bỏ tiền tố URI Cardano: web+cardano:, cardano://, cardano:
      if (clean.toLowerCase().startsWith('web+cardano:')) {
        clean = clean.substring('web+cardano:'.length);
      } else if (clean.toLowerCase().startsWith('cardano://')) {
        clean = clean.substring('cardano://'.length);
      } else if (clean.toLowerCase().startsWith('cardano:')) {
        clean = clean.substring('cardano:'.length);
      }

      // 3. Loại bỏ query parameters nếu có (ví dụ: ?amount=10)
      final queryIdx = clean.indexOf('?');
      if (queryIdx != -1) {
        clean = clean.substring(0, queryIdx);
      }
      clean = clean.trim();

      // 4. Bóc tách địa chỉ Cardano Bech32 hợp lệ (addr_test1... hoặc addr1...)
      final match = RegExp(r'(addr_test1[a-z0-9]+|addr1[a-z0-9]+)', caseSensitive: false).firstMatch(clean);
      if (match != null) {
        clean = match.group(0)!;
      }

      final bechDec = CardanoAddressHelper.decodeBech32(clean);
      final bool isValidBech = bechDec != null;

      if (mounted) {
        setState(() {
          _recipientController.text = clean;
          _error = isValidBech ? null : "Cảnh báo: Chuỗi vừa quét có thể không phải là địa chỉ Cardano hợp lệ!";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isValidBech
                  ? "✓ Đã nhận diện địa chỉ ví thành công (${clean.substring(0, 15)}...)!"
                  : "Đã điền nội dung quét được vào ô địa chỉ.",
            ),
            backgroundColor: isValidBech ? HotTheme.safeGreen : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }, onError: (err) {
      if (mounted) {
        setState(() => _error = "Không thể mở camera: $err");
      }
    });
  }

  double get _currentMinAda {
    return TransactionBuilder.calculateMinUtxoAda(_selectedTokens.length);
  }

  void _recalculateMinAdaIfNeeded() {
    if (_selectedTokens.isNotEmpty) {
      final currentInput = double.tryParse(_amountController.text.trim()) ?? 0.0;
      if (currentInput < _currentMinAda) {
        _amountController.text = _currentMinAda.toStringAsFixed(6);
      }
    }
  }

  void _onSendMaxChecked() {
    setState(() {
      _isSendMax = true;
      final state = ref.read(hotWalletProvider);
      final maxAda = (state.totalLovelace - 180000) / 1000000.0;
      if (maxAda > 0) {
        _amountController.text = maxAda.toStringAsFixed(6);
      }
    });
  }

  void _showAddTokenDialog(BuildContext context, List<TokenAsset> walletTokens) {
    // Chỉ hiện lên các token có trong ví (quantity > 0) và chưa được chọn (Yêu cầu 3)
    final availableTokens = walletTokens.where((t) {
      final isAlreadySelected = _selectedTokens.any((st) => st.asset.unit == t.unit);
      return t.quantity > BigInt.zero && !isAlreadySelected;
    }).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Chọn Token Trong Ví Để Gửi",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (availableTokens.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    "Không còn token nào khả dụng trong ví.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: availableTokens.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final token = availableTokens[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: HotTheme.accent.withOpacity(0.15),
                        child: Text(
                          token.displayName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: HotTheme.accent),
                        ),
                      ),
                      title: Text(token.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Khả dụng: ${token.formattedBalance} ${token.ticker ?? ''}"),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedTokens.add(
                            SelectedTokenItem(
                              asset: token,
                              amountController: TextEditingController(),
                            ),
                          );
                          _recalculateMinAdaIfNeeded();
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _buildTx() async {
    final recipient = _recipientController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (recipient.isEmpty) {
      setState(() => _error = "Vui lòng nhập địa chỉ người nhận!");
      return;
    }

    final minAda = _currentMinAda;
    if (_selectedTokens.isNotEmpty && amount < minAda) {
      setState(() => _error = "Giao dịch gửi Token yêu cầu tối thiểu ${minAda.toStringAsFixed(6)} ADA đính kèm!");
      return;
    }

    if (amount <= 0.0 && _selectedTokens.isEmpty) {
      setState(() => _error = "Số ADA gửi phải lớn hơn 0!");
      return;
    }

    final transferItems = <TokenTransferItem>[];
    for (final item in _selectedTokens) {
      final qty = item.sendQuantity;
      if (qty <= BigInt.zero) {
        setState(() => _error = "Vui lòng nhập số lượng hợp lệ cho token '${item.asset.displayName}'!");
        return;
      }
      if (qty > item.asset.quantity) {
        setState(() => _error = "Số lượng '${item.asset.displayName}' vượt quá số dư khả dụng (${item.asset.formattedBalance})!");
        return;
      }
      transferItems.add(TokenTransferItem(asset: item.asset, sendQuantity: qty));
    }

    try {
      final built = await ref.read(hotWalletProvider.notifier).prepareTransaction(
            recipient: recipient,
            amountAda: amount,
            tokensToSend: transferItems,
            sendMax: _isSendMax && transferItems.isEmpty,
          );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TxRawExportScreen(builtTx: built),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hotWalletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Soạn Thảo Giao Dịch"),
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
              stepTitle: "Bước 1/3: Khởi Tạo Giao Dịch Thô (txRaw)",
              subtitle: "Nhập địa chỉ đích và số lượng ADA/Token để đóng gói lệnh gửi sang Ví Lạnh.",
            ),
            // Thẻ số dư khả dụng
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Số dư ADA khả dụng:", style: TextStyle(color: HotTheme.textMuted)),
                    Text(
                      "${state.balanceAda.toStringAsFixed(6)} ADA",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: HotTheme.textPrimary, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Ô nhập người nhận
            TextField(
              controller: _recipientController,
              maxLines: 2,
              enableInteractiveSelection: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: "Địa chỉ người nhận",
                hintText: "Dán hoặc quét mã QR addr_test1... / addr1...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: HotTheme.surface,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_recipientController.text.isNotEmpty)
                      IconButton(
                        tooltip: "Xóa địa chỉ",
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          _recipientController.clear();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      tooltip: "Dán từ bộ nhớ tạm",
                      icon: const Icon(Icons.paste_rounded, color: HotTheme.accent),
                      onPressed: () async {
                        await ClipboardHelper.paste(
                          context,
                          targetController: _recipientController,
                          fieldName: "Địa chỉ người nhận",
                        );
                        setState(() {});
                      },
                    ),
                    IconButton(
                      tooltip: "Bật Camera Quét QR",
                      icon: const Icon(Icons.qr_code_scanner, color: HotTheme.accent),
                      onPressed: _onScanRecipientQr,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Thanh thao tác nhanh cho Mobile (Nút lớn dễ chạm, không bị bàn phím che)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HotTheme.accent,
                      side: BorderSide(color: HotTheme.accent.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.paste_rounded, size: 18),
                    label: const Text("Dán Địa Chỉ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () async {
                      await ClipboardHelper.paste(
                        context,
                        targetController: _recipientController,
                        fieldName: "Địa chỉ người nhận",
                      );
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HotTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 18, color: HotTheme.accent),
                    label: const Text("Quét Mã QR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: _onScanRecipientQr,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Ô nhập số lượng ADA
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _selectedTokens.isNotEmpty ? "Số lượng ADA (Đính kèm cùng Token)" : "Số lượng ADA",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: HotTheme.surface,
                helperText: _selectedTokens.isNotEmpty
                    ? "Tối thiểu: ${_currentMinAda.toStringAsFixed(6)} ADA đính kèm theo chuẩn Conway (Min-UTXO)"
                    : null,
                helperStyle: const TextStyle(color: HotTheme.accent),
                suffixIcon: _selectedTokens.isEmpty
                    ? TextButton(
                        onPressed: _onSendMaxChecked,
                        child: const Text("GỬI TẤT CẢ", style: TextStyle(color: HotTheme.accent, fontWeight: FontWeight.bold)),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            // PHẦN CHỌN VÀ GỬI NHIỀU TOKEN (Yêu cầu 2 & 3)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.toll, size: 20, color: HotTheme.accent),
                    SizedBox(width: 8),
                    Text("Danh Sách Token Gửi Đi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HotTheme.accent,
                    side: const BorderSide(color: HotTheme.accent),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Thêm Token"),
                  onPressed: () => _showAddTokenDialog(context, state.tokens),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_selectedTokens.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Center(
                  child: Text(
                    "Chưa thêm Token nào. Nhấn 'Thêm Token' nếu bạn muốn gửi kèm Token.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (int i = 0; i < _selectedTokens.length; i++) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: HotTheme.accent.withOpacity(0.15),
                                  child: Text(
                                    _selectedTokens[i].asset.displayName.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: HotTheme.accent),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedTokens[i].asset.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                              onPressed: () {
                                setState(() {
                                  _selectedTokens[i].amountController.dispose();
                                  _selectedTokens.removeAt(i);
                                  _recalculateMinAdaIfNeeded();
                                });
                              },
                            ),
                          ],
                        ),
                        Text(
                          "Số dư khả dụng: ${_selectedTokens[i].asset.formattedBalance} ${_selectedTokens[i].asset.ticker ?? ''}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _selectedTokens[i].amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: "Số lượng gửi",
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixIcon: TextButton(
                              onPressed: () {
                                final balClean = _selectedTokens[i].asset.formattedBalance.replaceAll(',', '');
                                _selectedTokens[i].amountController.text = balClean;
                              },
                              child: const Text("TỐI ĐA", style: TextStyle(fontWeight: FontWeight.bold, color: HotTheme.accent)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            ],
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const Icon(Icons.qr_code),
              label: const Text("TẠO GIAO DỊCH THÔ (txRaw) & XUẤT QR"),
              onPressed: _buildTx,
            ),
          ],
        ),
      ),
    );
  }
}
