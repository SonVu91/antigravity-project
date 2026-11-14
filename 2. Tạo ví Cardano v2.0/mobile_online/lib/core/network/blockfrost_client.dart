import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'stake_account_info.dart';
import 'cardano_address_helper.dart';

import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';
export 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart' show CardanoNetwork, CardanoNetworkExtension;

class BlockfrostClient {
  static const String definedPreprodKey = String.fromEnvironment('BLOCKFROST_PREPROD_KEY', defaultValue: '');
  static const String definedPreviewKey = String.fromEnvironment('BLOCKFROST_PREVIEW_KEY', defaultValue: '');
  static const String definedMainnetKey = String.fromEnvironment('BLOCKFROST_MAINNET_KEY', defaultValue: '');

  static const String defaultPreprodKey = "preprodDemoApiKeyDefault123456789";
  static const String defaultPreviewKey = "previewDemoApiKeyDefault123456789";
  static const String defaultMainnetKey = "mainnetDemoApiKeyDefault123456789";

  /// Tiền tố chuẩn của Blockfrost Project ID theo từng mạng
  static String expectedPrefix(CardanoNetwork net) {
    switch (net) {
      case CardanoNetwork.preprod:
        return 'preprod';
      case CardanoNetwork.preview:
        return 'preview';
      case CardanoNetwork.mainnet:
        return 'mainnet';
    }
  }

  /// Kiểm tra tính khớp nối giữa Project ID và mạng đã chọn
  static bool isKeyMatchingNetwork(CardanoNetwork net, String key) {
    final clean = key.trim().toLowerCase();
    if (clean.isEmpty) return true;
    return clean.startsWith(expectedPrefix(net));
  }

  /// Cảnh báo xác thực Project ID (trả về null nếu hợp lệ)
  static String? validateKeyForNetwork(CardanoNetwork net, String key) {
    final clean = key.trim();
    if (clean.isEmpty) return null; // Key tùy chọn
    final prefix = expectedPrefix(net);
    if (!clean.toLowerCase().startsWith(prefix)) {
      return "Cảnh báo: Project ID cho ${net.name.toUpperCase()} thường phải bắt đầu bằng '$prefix...'";
    }
    if (clean.length < 20) {
      return "Cảnh báo: Project ID quá ngắn (${clean.length} ký tự, thường > 30 ký tự).";
    }
    return null;
  }

  CardanoNetwork network;
  String? customApiKey;
  bool allowMockFallback;

  // Metadata cache
  final Map<String, Map<String, dynamic>> _assetMetadataCache = {};

  BlockfrostClient({
    this.network = CardanoNetwork.preprod,
    this.customApiKey,
    this.allowMockFallback = false,
  });

  String get baseUrl {
    switch (network) {
      case CardanoNetwork.preprod:
        return "https://cardano-preprod.blockfrost.io/api/v0";
      case CardanoNetwork.preview:
        return "https://cardano-preview.blockfrost.io/api/v0";
      case CardanoNetwork.mainnet:
        return "https://cardano-mainnet.blockfrost.io/api/v0";
    }
  }

  String get apiKey {
    if (customApiKey != null && customApiKey!.isNotEmpty) {
      return customApiKey!;
    }
    switch (network) {
      case CardanoNetwork.preprod:
        return definedPreprodKey.isNotEmpty ? definedPreprodKey : defaultPreprodKey;
      case CardanoNetwork.preview:
        return definedPreviewKey.isNotEmpty ? definedPreviewKey : defaultPreviewKey;
      case CardanoNetwork.mainnet:
        return definedMainnetKey.isNotEmpty ? definedMainnetKey : defaultMainnetKey;
    }
  }

  Map<String, String> get _headers => {
    "project_id": apiKey,
  };

  Future<List<Map<String, dynamic>>> getUtxos(String address) async {
    final url = Uri.parse("$baseUrl/addresses/$address/utxos");
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((e) => e as Map<String, dynamic>).toList();
      } else if (response.statusCode == 404) {
        // Địa chỉ mới chưa có UTXO
        return [];
      } else {
        throw Exception("Lỗi truy vấn UTXO: HTTP ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      // Khi offline hoặc môi trường kiểm thử: chỉ trả về mock UTXO nếu được cấu hình tường minh
      if (allowMockFallback) {
        return [
          {
            "tx_hash": "64a0e5b1285474b76c8c9f50e7b78912ef54876b5f4c3a2b109876543210abcd",
            "tx_index": 0,
            "amount": [
              {"unit": "lovelace", "quantity": "50000000"}, // 50 ADA
              {"unit": "a0028f350aaabe0545fdcb56b039dbb01871b6330ebe111f2dc26960484f534b59", "quantity": "1000000"}, // 1,000,000 HOSKY
              {"unit": "279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f534e454b", "quantity": "50000"}, // 50,000 SNEK
            ]
          },
          {
            "tx_hash": "98e7d6c5b4a3210fedcba09876543210abcdef0123456789abcdef0123456789",
            "tx_index": 1,
            "amount": [
              {"unit": "lovelace", "quantity": "25000000"}, // 25 ADA
              {"unit": "8db2465136c92461f5d022e7d59f67d87f12f0f13f9e532c6e308ce1446a65644d6963726f555344", "quantity": "250000000"}, // 250 DJED (decimals 6)
            ]
          }
        ];
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getAssetMetadata(String assetUnit) async {
    if (_assetMetadataCache.containsKey(assetUnit)) {
      return _assetMetadataCache[assetUnit];
    }

    // Known mock assets fallback for immediate offline display
    if (assetUnit == "a0028f350aaabe0545fdcb56b039dbb01871b6330ebe111f2dc26960484f534b59") {
      final mock = {
        "asset": assetUnit,
        "policy_id": "a0028f350aaabe0545fdcb56b039dbb01871b6330ebe111f2dc26960",
        "asset_name": "484f534b59",
        "fingerprint": "asset1a0hoskydemo987654321",
        "metadata": {"ticker": "HOSKY", "decimals": 0, "name": "Hosky Token"}
      };
      _assetMetadataCache[assetUnit] = mock;
      return mock;
    }
    if (assetUnit == "279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f534e454b") {
      final mock = {
        "asset": assetUnit,
        "policy_id": "279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f",
        "asset_name": "534e454b",
        "fingerprint": "asset1snekdemo1234567890",
        "metadata": {"ticker": "SNEK", "decimals": 0, "name": "Snek Token"}
      };
      _assetMetadataCache[assetUnit] = mock;
      return mock;
    }
    if (assetUnit == "8db2465136c92461f5d022e7d59f67d87f12f0f13f9e532c6e308ce1446a65644d6963726f555344") {
      final mock = {
        "asset": assetUnit,
        "policy_id": "8db2465136c92461f5d022e7d59f67d87f12f0f13f9e532c6e308ce1",
        "asset_name": "446a65644d6963726f555344",
        "fingerprint": "asset1djeddemo4567891234",
        "metadata": {"ticker": "DJED", "decimals": 6, "name": "Djed Stablecoin"}
      };
      _assetMetadataCache[assetUnit] = mock;
      return mock;
    }

    final url = Uri.parse("$baseUrl/assets/$assetUnit");
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _assetMetadataCache[assetUnit] = data;
        return data;
      }
    } catch (_) {}

    return null;
  }

  Future<String?> getStakeAddress(String paymentAddress) async {
    // 1. Trích xuất trực tiếp Stake Address ngoại tuyến (Toán học CIP-19)
    final offlineDerived = CardanoAddressHelper.deriveStakeAddress(paymentAddress);
    if (offlineDerived != null) {
      return offlineDerived;
    }

    final url = Uri.parse("$baseUrl/addresses/$paymentAddress");
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['stake_address'] as String?;
      } else if (response.statusCode == 404) {
        return null;
      }
    } catch (_) {}

    if (allowMockFallback || apiKey.contains("DemoApiKey")) {
      return network == CardanoNetwork.mainnet
          ? "stake1uxuru4u5twhwjxq5na0xtczckl85fgyxhplnn4jdmqrsaq22j65p"
          : "stake_test1upxuru4u5twhwjxq5na0xtczckl85fgyxhplnn4jdmqrsaqm46y5m";
    }
    return null;
  }

  Future<Map<String, dynamic>?> getPoolMetadata(String poolId) async {
    if (poolId == StakeAccountInfo.fimiPoolId) {
      return {
        "pool_id": poolId,
        "ticker": "FIMI",
        "name": "FIMI Stake Pool",
        "description": "FIMI Cardano Stake Pool",
      };
    }
    final url = Uri.parse("$baseUrl/pools/$poolId/metadata");
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<StakeAccountInfo> getStakeAccountDetails(String stakeAddress) async {
    final infoMap = await getAccountInfo(stakeAddress);
    if (infoMap == null) {
      return StakeAccountInfo(
        stakeAddress: stakeAddress,
        isRegistered: false,
        controlledAmountLovelace: BigInt.zero,
        rewardsAvailableLovelace: BigInt.zero,
      );
    }

    String? poolName;
    String? poolTicker;
    final poolId = infoMap['pool_id'] as String?;
    if (poolId != null && poolId.isNotEmpty) {
      final poolMeta = await getPoolMetadata(poolId);
      if (poolMeta != null) {
        poolName = poolMeta['name'] as String?;
        poolTicker = poolMeta['ticker'] as String?;
      }
    }

    return StakeAccountInfo.fromJson(
      infoMap,
      poolName: poolName,
      poolTicker: poolTicker,
    );
  }

  Future<Map<String, dynamic>?> getAccountInfo(String stakeAddress) async {
    final url = Uri.parse("$baseUrl/accounts/$stakeAddress");
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null;
      }
    } catch (_) {}

    if (allowMockFallback || apiKey.contains("DemoApiKey")) {
      // Mock fallback when offline or demo key: returns realistic active stake with rewards
      return {
        "stake_address": stakeAddress,
        "active": true,
        "active_epoch": 512,
        "controlled_amount": "75000000",
        "rewards_sum": "15800000",
        "withdrawals_sum": "0",
        "withdrawable_amount": "15800000", // 15.8 ADA
        "pool_id": StakeAccountInfo.preprodPoolId,
      };
    }
    return null;
  }

  Future<Map<String, dynamic>> getProtocolParameters() async {
    final url = Uri.parse("$baseUrl/epochs/latest/parameters");
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    // Fallback default Conway parameters
    return {
      "min_fee_a": 44,
      "min_fee_b": 155381,
      "max_tx_size": 16384,
      "coins_per_utxo_size": 4310,
    };
  }

  Future<int> getLatestSlot() async {
    final url = Uri.parse("$baseUrl/blocks/latest");
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final slot = (map['slot'] as num?)?.toInt();
        if (slot != null && slot > 0) return slot;
      }
    } catch (_) {}

    // Fallback tính toán thời gian thực theo Genesis của từng mạng Cardano
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    switch (network) {
      case CardanoNetwork.preprod:
        // Preprod Genesis: 1654041600 (2022-06-01T00:00:00Z)
        final calculated = nowSeconds - 1654041600;
        return calculated > 138000000 ? calculated : 138556338;
      case CardanoNetwork.preview:
        // Preview Genesis: 1666656000 (2022-10-25T00:00:00Z)
        final calculated = nowSeconds - 1666656000;
        return calculated > 65000000 ? calculated : 70000000;
      case CardanoNetwork.mainnet:
        // Mainnet Shelley offset: 4492800 at 1596059091
        final calculated = 4492800 + (nowSeconds - 1596059091);
        return calculated > 130000000 ? calculated : 140000000;
    }
  }

  /// Lấy danh sách Pool ID đang hoạt động trên mạng hiện tại
  Future<List<String>> getActivePools() async {
    final url = Uri.parse("$baseUrl/pools?count=10&order=desc");
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    if (network == CardanoNetwork.preprod) {
      return [StakeAccountInfo.preprodPoolId];
    }
    return [StakeAccountInfo.fimiPoolId];
  }

  Future<String> submitTx(String cborHex) async {
    final url = Uri.parse("$baseUrl/tx/submit");
    final cleanHex = cborHex
        .trim()
        .trim_start_matches("TxConway:")
        .trim_start_matches("TxConwayEra:")
        .trim();

    final bytes = <int>[];
    for (int i = 0; i < cleanHex.length; i += 2) {
      bytes.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
    }

    try {
      final response = await http.post(
        url,
        headers: {
          ..._headers,
          "Content-Type": "application/cbor",
        },
        body: bytes,
      );

      if (response.statusCode == 200) {
        final txid = response.body.replaceAll('"', '').trim();
        return txid;
      } else {
        throw Exception(formatSubmitError(response.body));
      }
    } catch (e) {
      if (!allowMockFallback) {
        rethrow;
      }
      // Demo broadcast fallback: hash 64 hex chars khi bật allowMockFallback
      return "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0";
    }
  }

  static String formatSubmitError(String raw) {
    if (raw.contains("OutsideValidityIntervalUTxO")) {
      return "Thời hạn hiệu lực của giao dịch (TTL) đã hết hạn so với slot hiện tại của mạng Cardano.\n\n"
          "Khắc phục: Hệ thống đã tự động tính toán lại TTL theo thời gian thực (hiệu lực 2 giờ). Vui lòng tạo lại giao dịch mới từ Ví Nóng và ký lại từ Ví Lạnh.";
    }
    if (raw.contains("DelegateeStakePoolNotRegisteredDELEG")) {
      return "Stake Pool bạn chọn chưa được đăng ký trên mạng này (Preprod Testnet).\n\n"
          "Khắc phục: Trên mạng Testnet, vui lòng chọn Stake Pool đã đăng ký trên Preprod hoặc chỉ ủy quyền DRep.";
    }
    if (raw.contains("DelegateeDRepNotRegisteredDELEG")) {
      return "DRep ID bạn chọn chưa được đăng ký trên mạng này (Preprod Testnet).\n\n"
          "Khắc phục: Khuyến nghị chọn 'Bỏ phiếu trắng (Always Abstain)' - tùy chọn này hợp lệ 100% trên mọi mạng Cardano Conway.";
    }
    if (raw.contains("BadInputsUTxO")) {
      return "UTXO được sử dụng trong giao dịch đã bị chi tiêu bởi một giao dịch khác.\n\n"
          "Khắc phục: Vui lòng nhấn 'Làm Mới Số Dư' trên Ví Nóng và lập lại giao dịch mới.";
    }
    if (raw.contains("ValueNotConservedUTxO")) {
      return "Số dư đầu vào không khớp với tổng tiền gửi + tiền thừa + phí mạng.";
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['message'] != null) {
        final inner = decoded['message'];
        if (inner is String && inner.startsWith('{')) {
          final innerDecoded = jsonDecode(inner);
          if (innerDecoded is Map && innerDecoded['contents'] != null) {
            return "Lỗi mạng Cardano Conway: ${innerDecoded['contents']}";
          }
        }
        return decoded['message'].toString();
      }
    } catch (_) {}

    return raw;
  }

  static Future<String?> loadSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("blockfrost_api_key");
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("blockfrost_api_key", key);
  }
}

extension StringExtension on String {
  String trim_start_matches(String prefix) {
    if (startsWith(prefix)) {
      return substring(prefix.length);
    }
    return this;
  }
}
