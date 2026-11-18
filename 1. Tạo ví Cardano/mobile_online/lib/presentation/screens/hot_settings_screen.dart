import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/network/blockfrost_client.dart';
import '../../core/theme/hot_theme.dart';
import '../../core/migration/hot_migration_service.dart';
import '../../core/update/hot_update_service.dart';
import '../../core/utils/cardanoscan_helper.dart';
import '../providers/hot_wallet_provider.dart';
import 'setup_watch_screen.dart';

class HotSettingsScreen extends ConsumerStatefulWidget {
  const HotSettingsScreen({super.key});

  @override
  ConsumerState<HotSettingsScreen> createState() => _HotSettingsScreenState();
}

class _HotSettingsScreenState extends ConsumerState<HotSettingsScreen> {
  final HotMigrationService _migrationService = HotMigrationService();
  final HotUpdateService _updateService = HotUpdateService();

  int _schemaVersion = 2;
  bool _isLoading = true;
  UpdateInfo? _updateInfo;
  bool _isCheckingUpdate = false;
  double? _downloadProgress;
  String? _downloadStatusText;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final v = await _migrationService.getSchemaVersion();
    if (mounted) {
      setState(() {
        _schemaVersion = v;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkUpdate({String? mockVersion}) async {
    setState(() {
      _isCheckingUpdate = true;
      _downloadProgress = null;
      _downloadStatusText = null;
    });

    try {
      final info = await _updateService.checkForUpdate(mockLatestVersion: mockVersion);
      if (mounted) {
        setState(() {
          _updateInfo = info;
          _isCheckingUpdate = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi kiểm tra cập nhật: $e")),
        );
      }
    }
  }

  Future<void> _startDownloadAndInstall() async {
    if (_updateInfo == null) return;

    setState(() {
      _downloadProgress = 0.0;
      _downloadStatusText = "Bắt đầu tải gói APK cập nhật...";
    });

    await _updateService.downloadAndInstallUpdate(
      _updateInfo!,
      onProgress: (progress, status) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            _downloadStatusText = status;
          });
        }
      },
    );

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text("Đã Tải Xong Bản Cập Nhật"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Gói APK phiên bản ${_updateInfo!.latestVersion} đã được tải về thành công."),
              const SizedBox(height: 8),
              const Text(
                "Trình cài đặt hệ thống Android sẽ tự động nâng cấp đè mà KHÔNG làm mất dữ liệu ví theo dõi và cấu hình hiện tại.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: HotTheme.accent),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đang khởi chạy trình cài đặt hệ thống PackageInstaller...")),
                );
              },
              child: const Text("Khởi Chạy Cài Đặt"),
            ),
          ],
        ),
      );
    }
  }

  void _showExportBackupDialog() async {
    final jsonStr = await _migrationService.exportBackup();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.backup, color: HotTheme.accent),
            SizedBox(width: 8),
            Text("Sao Lưu Cấu Hình Ví Nóng"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Mã QR cấu hình Watch-Only & Mạng:", style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: QrImageView(
                    data: jsonStr,
                    size: 160,
                    version: QrVersions.auto,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text("Sao chép tệp .hotbackup"),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Đã sao chép nội dung sao lưu ví nóng!")),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
        ],
      ),
    );
  }

  void _showImportBackupDialog() {
    final payloadCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore, color: HotTheme.accent),
            SizedBox(width: 8),
            Text("Khôi Phục Cấu Hình Ví Nóng"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Dán nội dung sao lưu (.hotbackup hoặc quét từ QR code):", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: payloadCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '{"magic":"CARDANO_HOT_BACKUP"...}',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HotTheme.accent),
            onPressed: () async {
              final raw = payloadCtrl.text.trim();
              if (raw.isEmpty) return;
              try {
                await _migrationService.importBackup(raw);
                await ref.read(hotWalletProvider.notifier).initAndLoad();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Đã khôi phục cấu hình ví thành công!")),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Lỗi khôi phục: $e")),
                );
              }
            },
            child: const Text("Khôi Phục"),
          ),
        ],
      ),
    );
  }

  void _showChangelogDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nhật Ký Thay Đổi (Changelog)"),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Phiên bản v2.0.5 (Hiện tại)", style: TextStyle(fontWeight: FontWeight.bold, color: HotTheme.accent)),
              const SizedBox(height: 6),
              const Text("• Tích hợp Camera Quét QR Nội Tuyến (ZXing Native) cho Android 32-bit/64-bit cùng thanh tiến độ ghép QR Động (Multipart QR).\n• Tinh gọn thao tác quét QR 1-chạm (loại bỏ nút tải ảnh QR)."),
              const Divider(height: 24),
              Text("Phiên bản v2.0.3 - v2.0.4", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
              const SizedBox(height: 6),
              const Text("• Tích hợp đồng bộ chuẩn chuyển đổi 3 môi trường mạng (Mainnet, Preprod, Preview) với Ví Lạnh Air-Gap.\n• Strict Network Guard chặn ký lệch môi trường mạng.\n• Tối ưu hóa UI/UX và cập nhật cơ sở dữ liệu."),
              const Divider(height: 24),
              Text("Phiên bản v2.0.2", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 6),
              const Text("• Hỗ trợ toàn diện 32-bit ARMv7 (Samsung J7 Prime) và 64-bit ARMv8."),
              const Divider(height: 24),
              Text("Phiên bản v1.1.0", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              SizedBox(height: 6),
              Text("• Tính năng Cập nhật In-App & Tải APK tiến trình %.\n• Lưu trữ dữ liệu bền vững và Schema Migration v2.\n• Sao lưu & Khôi phục cấu hình ví theo dõi (.hotbackup).\n• Hỗ trợ mở trang phát hành GitHub trực tiếp."),
              Divider(height: 24),
              Text("Phiên bản v1.0.0 (Gold Release)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              SizedBox(height: 6),
              Text("• Kiến trúc Watch-Only không giữ private key.\n• Kết nối trực tiếp Blockfrost Preprod/Preview/Mainnet.\n• Thuật toán UTXO Largest-First và tính Min-Fee.\n• Bảo toàn địa chỉ Bech32 trong CBOR Conway.\n• Quét nhận và nộp giao dịch đã ký (txSigned)."),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đã Hiểu")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hotWalletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cài Đặt & Phiên Bản"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: HotTheme.buildLiveNetworkBadge(networkName: state.network.name.toUpperCase()),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Card 1: Version & Schema Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Phiên Bản Ứng Dụng", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Chip(
                              label: Text("v2.0.5 (Build 6)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              backgroundColor: HotTheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.storage, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text("Lưu trữ cấu hình: Schema v$_schemaVersion (Bền vững)", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.amberAccent),
                            const SizedBox(width: 6),
                            Text("Chế độ: Watch-Only (Không lưu khóa riêng tư)", style: const TextStyle(fontSize: 13, color: Colors.amberAccent)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Card 2: In-App Updater
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.system_update, color: HotTheme.accent),
                            SizedBox(width: 8),
                            Text("Cập Nhật Ứng Dụng (In-App Update)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Kiểm tra bản cập nhật mới từ GitHub Releases. Hệ thống cập nhật đè giữ nguyên 100% dữ liệu ví theo dõi và cấu hình mạng.",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: HotTheme.primary),
                              icon: _isCheckingUpdate
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.refresh, size: 18),
                              label: const Text("Kiểm Tra Cập Nhật"),
                              onPressed: _isCheckingUpdate ? null : () => _checkUpdate(),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _isCheckingUpdate ? null : () => _checkUpdate(mockVersion: "1.2.0"),
                              child: const Text("Thử Bản Mới (Demo v1.2.0)", style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),

                        if (_updateInfo != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _updateInfo!.hasUpdate ? Colors.green.withOpacity(0.12) : Colors.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _updateInfo!.hasUpdate ? Colors.green : Colors.blue),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _updateInfo!.hasUpdate ? Icons.new_releases : Icons.check_circle,
                                      color: _updateInfo!.hasUpdate ? Colors.green : Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _updateInfo!.hasUpdate
                                          ? "PHÁT HIỆN BẢN MỚI: v${_updateInfo!.latestVersion}"
                                          : "BẠN ĐANG DÙNG BẢN MỚI NHẤT (v1.1.0)",
                                      style: TextStyle(
                                        color: _updateInfo!.hasUpdate ? Colors.green : Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _updateInfo!.releaseNotes,
                                  style: const TextStyle(fontSize: 12, height: 1.4),
                                ),
                                if (_updateInfo!.hasUpdate) ...[
                                  const SizedBox(height: 12),
                                  if (_downloadProgress != null) ...[
                                    LinearProgressIndicator(value: _downloadProgress, color: HotTheme.accent),
                                    const SizedBox(height: 6),
                                    Text(
                                      "$_downloadStatusText (${(_downloadProgress! * 100).toInt()}%)",
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: HotTheme.accent),
                                        icon: const Icon(Icons.download, size: 18),
                                        label: const Text("Tải & Cài Đặt Tự Động"),
                                        onPressed: _downloadProgress != null ? null : _startDownloadAndInstall,
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.open_in_browser, size: 18),
                                        label: const Text("Mở GitHub"),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: _updateInfo!.releasePageUrl));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Đã sao chép liên kết trang GitHub Releases!")),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Card 3: Watch Wallet Configuration
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
                    title: const Text("Thay Đổi Ví Theo Dõi"),
                    subtitle: Text(state.watchedAddress != null ? "Đang theo dõi: ${state.watchedAddress!.substring(0, 15)}..." : "Chưa cấu hình"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SetupWatchScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Card: Cardanoscan On-Chain Explorer Link
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.travel_explore_rounded, color: Colors.blueAccent),
                    title: const Text("Khám Phá On-Chain (Cardanoscan)"),
                    subtitle: Text("Tra cứu ví và dữ liệu chuỗi tại ${CardanoscanHelper.getBaseUrl(state.network)}"),
                    trailing: const Icon(Icons.copy_rounded, size: 18),
                    onTap: () {
                      final url = state.watchedAddress != null
                          ? CardanoscanHelper.getAddressUrl(state.network, state.watchedAddress!)
                          : CardanoscanHelper.getBaseUrl(state.network);
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Đã sao chép liên kết Cardanoscan vào bộ nhớ tạm!")),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Card 4: Backup & Restore Watch Config
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.folder_shared_outlined, color: Colors.purpleAccent),
                            SizedBox(width: 8),
                            Text("Sao Lưu & Khôi Phục Cấu Hình", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Xuất hoặc nhập thông tin ví theo dõi, mạng Cardano và lịch sử giao dịch.",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: HotTheme.primary),
                                icon: const Icon(Icons.file_upload_outlined, size: 18),
                                label: const Text("Xuất Cấu Hình"),
                                onPressed: _showExportBackupDialog,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.file_download_outlined, size: 18),
                                label: const Text("Khôi Phục"),
                                onPressed: _showImportBackupDialog,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Card 5: Changelog
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.history_edu, color: Colors.amberAccent),
                    title: const Text("Nhật Ký Thay Đổi (Changelog)"),
                    subtitle: const Text("Xem chi tiết các tính năng của v1.1.0"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showChangelogDialog,
                  ),
                ),
              ],
            ),
    );
  }
}
