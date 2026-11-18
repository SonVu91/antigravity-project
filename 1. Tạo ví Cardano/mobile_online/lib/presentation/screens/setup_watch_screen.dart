import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/blockfrost_client.dart';
import '../../core/theme/hot_theme.dart';
import '../../core/qr/qr_scanner_helper.dart';
import '../../core/utils/clipboard_helper.dart';
import '../providers/hot_wallet_provider.dart';
import 'dashboard_screen.dart';
import 'hot_settings_screen.dart';

class SetupWatchScreen extends ConsumerStatefulWidget {
  const SetupWatchScreen({super.key});

  @override
  ConsumerState<SetupWatchScreen> createState() => _SetupWatchScreenState();
}

class _SetupWatchScreenState extends ConsumerState<SetupWatchScreen> {
  final TextEditingController _nameController = TextEditingController(text: "Chung-Ví 1");
  final TextEditingController _addrController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  CardanoNetwork _selectedNetwork = CardanoNetwork.preprod;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final saved = await ref.read(hotWalletProvider.notifier).getSavedApiKeyForNetwork(_selectedNetwork);
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() {
          _apiKeyController.text = saved;
        });
      }
    });
  }

  @override
  void dispose() {
    WebQrScannerBridge.stopLiveCamera();
    _nameController.dispose();
    _addrController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final addr = _addrController.text.trim();
    if (addr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập hoặc quét địa chỉ ví công khai từ Ví Lạnh!")),
      );
      return;
    }

    final name = _nameController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    ref.read(hotWalletProvider.notifier).switchNetwork(
      _selectedNetwork,
      apiKey: apiKey.isNotEmpty ? apiKey : null,
    );
    ref.read(hotWalletProvider.notifier).setWatchedAddress(addr, name: name.isNotEmpty ? name : null);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thiết Lập Ví Theo Dõi"),
        actions: [
          IconButton(
            tooltip: "Cài Đặt & Khôi Phục",
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HotSettingsScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: HotTheme.buildLiveNetworkBadge(
              networkName: _selectedNetwork.name.toUpperCase(),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.remove_red_eye_outlined, size: 56, color: HotTheme.accent),
            const SizedBox(height: 12),
            const Text(
              "Thêm Ví Theo Dõi (Watch-Only)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Ví Nóng chỉ quản lý địa chỉ công khai để truy vấn số dư và phát sóng. Tuyệt đối KHÔNG chứa khóa riêng tư.",
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Bộ chọn mạng: Preprod / Preview / Mainnet
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Chọn Môi Trường Mạng Cardano:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 10),
                    SegmentedButton<CardanoNetwork>(
                      segments: const [
                        ButtonSegment<CardanoNetwork>(value: CardanoNetwork.preprod, label: Text("Preprod")),
                        ButtonSegment<CardanoNetwork>(value: CardanoNetwork.preview, label: Text("Preview")),
                        ButtonSegment<CardanoNetwork>(value: CardanoNetwork.mainnet, label: Text("Mainnet")),
                      ],
                      selected: {_selectedNetwork},
                      onSelectionChanged: (Set<CardanoNetwork> newSelection) async {
                        final nextNet = newSelection.first;
                        final savedKey = await ref.read(hotWalletProvider.notifier).getSavedApiKeyForNetwork(nextNet);
                        if (mounted) {
                          setState(() {
                            _selectedNetwork = nextNet;
                            _apiKeyController.text = savedKey ?? '';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Tên ví (Ví dụ: Chung-Ví 1, Trading-01...)",
                hintText: "Đặt tên ví để dễ nhận diện và gom nhóm",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: HotTheme.surface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addrController,
              maxLines: 2,
              enableInteractiveSelection: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: "Địa chỉ ví công khai (payment.addr)",
                hintText: "Dán hoặc quét mã QR addr_test1... / addr1...",
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_addrController.text.isNotEmpty)
                      IconButton(
                        tooltip: "Xóa địa chỉ",
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          _addrController.clear();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      tooltip: "Dán từ bộ nhớ tạm (Paste)",
                      icon: const Icon(Icons.paste_rounded, color: HotTheme.accent),
                      onPressed: () async {
                        await ClipboardHelper.paste(
                          context,
                          targetController: _addrController,
                          fieldName: "Địa chỉ ví",
                        );
                        setState(() {});
                      },
                    ),
                    IconButton(
                      tooltip: "Bật Camera Quét QR",
                      icon: const Icon(Icons.qr_code_scanner, color: HotTheme.accent),
                      onPressed: () {
                        WebQrScannerBridge.startLiveCamera((scanned) {
                          WebQrScannerBridge.stopLiveCamera();
                          setState(() {
                            _addrController.text = scanned.trim();
                          });
                        });
                      },
                    ),
                  ],
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: HotTheme.surface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              enableInteractiveSelection: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: "Blockfrost Project ID cho ${_selectedNetwork.name.toUpperCase()} (Tùy chọn)",
                hintText: "Dán key '${BlockfrostClient.expectedPrefix(_selectedNetwork)}...' hoặc để trống",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: HotTheme.surface,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_apiKeyController.text.isNotEmpty)
                      IconButton(
                        tooltip: "Xóa key",
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          _apiKeyController.clear();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      tooltip: "Dán từ bộ nhớ tạm (Paste)",
                      icon: const Icon(Icons.paste_rounded, color: HotTheme.accent),
                      onPressed: () async {
                        await ClipboardHelper.paste(
                          context,
                          targetController: _apiKeyController,
                          fieldName: "Project ID",
                        );
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (BlockfrostClient.validateKeyForNetwork(_selectedNetwork, _apiKeyController.text) != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 15, color: Colors.orangeAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      BlockfrostClient.validateKeyForNetwork(_selectedNetwork, _apiKeyController.text)!,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: Text("Bắt Đầu Theo Dõi (${_selectedNetwork.name.toUpperCase()})"),
              onPressed: _onConfirm,
            ),
          ],
        ),
      ),
    );
  }
}
