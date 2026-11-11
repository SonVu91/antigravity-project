import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/blockfrost_client.dart';
import '../models/watched_wallet_entry.dart';

class HotMigrationService {
  static const int currentSchemaVersion = 3;
  static const String appVersion = "2.0.5";

  static const String keySchemaVersion = 'hot_schema_version';
  static const String keyAppVersion = 'hot_app_version';
  static const String keyWatchedAddress = 'hot_watched_address';
  static const String keyWatchedWallets = 'hot_watched_wallets';
  static const String keyWatchedWalletsV3 = 'hot_watched_wallets_v3';
  static const String keyNetwork = 'hot_network';
  static const String keyApiKey = 'hot_custom_api_key';
  static const String keyApiKeyPreprod = 'hot_custom_api_key_preprod';
  static const String keyApiKeyPreview = 'hot_custom_api_key_preview';
  static const String keyApiKeyMainnet = 'hot_custom_api_key_mainnet';
  static const String keyCachedBalance = 'hot_cached_balance';
  static const String keyTxHistory = 'hot_tx_history';
  static const String keyUpdatedAt = 'hot_updated_at';
  static const String keySnapshotPreV2 = 'hot_snapshot_pre_v2';
  static const String keySnapshotPreV3 = 'hot_snapshot_pre_v3';

  Future<int> getSchemaVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keySchemaVersion) ?? (prefs.containsKey(keyWatchedAddress) ? 1 : 0);
  }

  Future<bool> runMigrationIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final version = await getSchemaVersion();

    if (version == 0) {
      // Fresh install, initialize schema v3
      await prefs.setInt(keySchemaVersion, currentSchemaVersion);
      await prefs.setString(keyAppVersion, appVersion);
      return true;
    }

    if (version < currentSchemaVersion) {
      // Create rollback safety snapshot before migration
      final snapshot = {
        keyWatchedAddress: prefs.getString(keyWatchedAddress),
        keyWatchedWallets: prefs.getStringList(keyWatchedWallets),
        keyNetwork: prefs.getString(keyNetwork),
        keyApiKey: prefs.getString(keyApiKey),
        keyCachedBalance: prefs.getDouble(keyCachedBalance),
      };
      await prefs.setString(keySnapshotPreV3, jsonEncode(snapshot));

      try {
        if (version == 1) {
          if (!prefs.containsKey(keyNetwork)) {
            await prefs.setString(keyNetwork, CardanoNetwork.preprod.name);
          }
          if (!prefs.containsKey(keyTxHistory)) {
            await prefs.setString(keyTxHistory, '[]');
          }
        }
        if (version <= 2) {
          // Migrate addresses to WatchedWalletEntry V3
          if (!prefs.containsKey(keyWatchedWalletsV3)) {
            final oldList = prefs.getStringList(keyWatchedWallets) ?? [];
            final single = prefs.getString(keyWatchedAddress);
            final List<String> addrs = List.from(oldList);
            if (addrs.isEmpty && single != null && single.isNotEmpty) {
              addrs.add(single);
            }
            final List<WatchedWalletEntry> entries = [];
            for (int i = 0; i < addrs.length; i++) {
              entries.add(WatchedWalletEntry(
                id: 'migrated_${DateTime.now().millisecondsSinceEpoch}_$i',
                name: 'Chung-Ví ${i + 1}',
                address: addrs[i],
              ));
            }
            await prefs.setString(keyWatchedWalletsV3, WatchedWalletEntry.encodeList(entries));
          }
        }

        await prefs.setInt(keySchemaVersion, currentSchemaVersion);
        await prefs.setString(keyAppVersion, appVersion);
        await prefs.setString(keyUpdatedAt, DateTime.now().toIso8601String());
        return true;
      } catch (e) {
        // Rollback snapshot on error
        final raw = prefs.getString(keySnapshotPreV3);
        if (raw != null) {
          final Map<String, dynamic> snap = jsonDecode(raw);
          for (final entry in snap.entries) {
            if (entry.value is String) {
              await prefs.setString(entry.key, entry.value as String);
            } else if (entry.value is double) {
              await prefs.setDouble(entry.key, entry.value as double);
            } else if (entry.value is List) {
              await prefs.setStringList(entry.key, (entry.value as List).map((e) => e.toString()).toList());
            }
          }
        }
        rethrow;
      }
    }
    return false;
  }

  String _keyForNetwork(CardanoNetwork net) {
    switch (net) {
      case CardanoNetwork.preprod:
        return keyApiKeyPreprod;
      case CardanoNetwork.preview:
        return keyApiKeyPreview;
      case CardanoNetwork.mainnet:
        return keyApiKeyMainnet;
    }
  }

  /// Lấy Project ID đã lưu riêng cho một mạng cụ thể
  Future<String?> getApiKeyForNetwork(CardanoNetwork net) async {
    final prefs = await SharedPreferences.getInstance();
    final specific = prefs.getString(_keyForNetwork(net));
    if (specific != null && specific.trim().isNotEmpty) {
      return specific.trim();
    }
    // Fallback: nếu có legacy key bắt đầu bằng prefix của mạng
    final legacy = prefs.getString(keyApiKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      if (legacy.trim().toLowerCase().startsWith(net.name)) {
        return legacy.trim();
      }
    }
    return null;
  }

  /// Lưu riêng Project ID cho từng mạng (truyền rỗng hoặc null để xóa)
  Future<void> saveApiKeyForNetwork(CardanoNetwork net, String? key) async {
    final prefs = await SharedPreferences.getInstance();
    final k = _keyForNetwork(net);
    final clean = key?.trim();
    if (clean == null || clean.isEmpty) {
      await prefs.remove(k);
    } else {
      await prefs.setString(k, clean);
    }
  }

  Future<Map<String, dynamic>> loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(keyWatchedAddress);
    final rawV3 = prefs.getString(keyWatchedWalletsV3);

    List<WatchedWalletEntry> walletEntries = [];
    if (rawV3 != null && rawV3.isNotEmpty) {
      walletEntries = WatchedWalletEntry.decodeList(rawV3);
    }

    // Fallback if V3 is empty but old legacy exists
    if (walletEntries.isEmpty) {
      List<String> oldList = prefs.getStringList(keyWatchedWallets) ?? [];
      if (oldList.isEmpty && address != null && address.isNotEmpty) {
        oldList = [address];
      }
      for (int i = 0; i < oldList.length; i++) {
        walletEntries.add(WatchedWalletEntry(
          id: 'wallet_${i + 1}',
          name: 'Chung-Ví ${i + 1}',
          address: oldList[i],
        ));
      }
    }

    final netStr = prefs.getString(keyNetwork) ?? CardanoNetwork.preprod.name;
    final balance = prefs.getDouble(keyCachedBalance) ?? 0.0;
    final txHistStr = prefs.getString(keyTxHistory) ?? '[]';

    CardanoNetwork network = CardanoNetwork.preprod;
    for (final n in CardanoNetwork.values) {
      if (n.name == netStr) {
        network = n;
        break;
      }
    }

    final apiKey = await getApiKeyForNetwork(network) ?? prefs.getString(keyApiKey);

    List<Map<String, dynamic>> txHistory = [];
    try {
      final list = jsonDecode(txHistStr) as List<dynamic>;
      txHistory = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}

    return {
      'watchedAddress': address ?? (walletEntries.isNotEmpty ? walletEntries.first.address : null),
      'watchedWalletsEntries': walletEntries,
      'watchedWallets': walletEntries.map((e) => e.address).toList(),
      'network': network,
      'apiKey': apiKey,
      'cachedBalance': balance,
      'txHistory': txHistory,
    };
  }

  Future<void> saveState({
    String? watchedAddress,
    List<WatchedWalletEntry>? watchedWalletsEntries,
    List<String>? watchedWallets,
    CardanoNetwork? network,
    String? apiKey,
    double? balanceAda,
    List<Map<String, dynamic>>? txHistory,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (watchedAddress != null) {
      await prefs.setString(keyWatchedAddress, watchedAddress);
    }
    if (watchedWalletsEntries != null) {
      await prefs.setString(keyWatchedWalletsV3, WatchedWalletEntry.encodeList(watchedWalletsEntries));
      await prefs.setStringList(keyWatchedWallets, watchedWalletsEntries.map((e) => e.address).toList());
    } else if (watchedWallets != null) {
      await prefs.setStringList(keyWatchedWallets, watchedWallets);
    }
    if (network != null) {
      await prefs.setString(keyNetwork, network.name);
    }
    if (apiKey != null) {
      await prefs.setString(keyApiKey, apiKey);
      if (network != null) {
        await saveApiKeyForNetwork(network, apiKey);
      }
    }
    if (balanceAda != null) {
      await prefs.setDouble(keyCachedBalance, balanceAda);
    }
    if (txHistory != null) {
      await prefs.setString(keyTxHistory, jsonEncode(txHistory));
    }
    await prefs.setString(keyUpdatedAt, DateTime.now().toIso8601String());
  }

  Future<String> exportBackup({bool includeApiKey = true}) async {
    final state = await loadSavedState();
    final entries = state['watchedWalletsEntries'] as List<WatchedWalletEntry>? ?? [];
    final payload = {
      "magic": "CARDANO_HOT_BACKUP",
      "schema_version": currentSchemaVersion,
      "app_version": appVersion,
      "timestamp": DateTime.now().toIso8601String(),
      "network": (state['network'] as CardanoNetwork).name,
      if (includeApiKey) "api_key": state['apiKey'],
      "watched_address": state['watchedAddress'],
      "watched_wallets_v3": entries.map((e) => e.toJson()).toList(),
      "watched_wallets": state['watchedWallets'],
      "cached_balance": state['cachedBalance'],
      "tx_history": state['txHistory'],
    };
    return jsonEncode(payload);
  }

  Future<bool> importBackup(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      if (data["magic"] != "CARDANO_HOT_BACKUP") {
        throw Exception("Dữ liệu sao lưu không hợp lệ hoặc sai định dạng.");
      }

      final netStr = data["network"] as String? ?? CardanoNetwork.preprod.name;
      CardanoNetwork network = CardanoNetwork.preprod;
      for (final n in CardanoNetwork.values) {
        if (n.name == netStr) {
          network = n;
          break;
        }
      }

      final apiKey = data["api_key"] as String?;
      final addr = data["watched_address"] as String?;
      List<WatchedWalletEntry> entries = [];
      if (data["watched_wallets_v3"] != null) {
        final list = data["watched_wallets_v3"] as List<dynamic>;
        entries = list.map((e) => WatchedWalletEntry.fromJson(e as Map<String, dynamic>)).toList();
      } else if (data["watched_wallets"] != null) {
        final list = data["watched_wallets"] as List<dynamic>;
        for (int i = 0; i < list.length; i++) {
          entries.add(WatchedWalletEntry(
            id: 'import_$i',
            name: 'Chung-Ví ${i + 1}',
            address: list[i].toString(),
          ));
        }
      }

      final hist = (data["tx_history"] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final balance = (data["cached_balance"] as num?)?.toDouble() ?? 0.0;

      await saveState(
        watchedAddress: addr,
        watchedWalletsEntries: entries,
        network: network,
        apiKey: apiKey,
        balanceAda: balance,
        txHistory: hist,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
