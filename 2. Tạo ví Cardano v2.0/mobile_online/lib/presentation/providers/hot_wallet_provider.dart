import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';
import '../../core/network/blockfrost_client.dart';
import '../../core/network/token_asset.dart';
import '../../core/network/stake_account_info.dart';
import '../../core/network/cardano_address_helper.dart';
import '../../core/tx/tx_builder.dart';
import '../../core/migration/hot_migration_service.dart';
import '../../core/models/watched_wallet_entry.dart';

class HotWalletState {
  final String? watchedAddress;
  final List<WatchedWalletEntry> watchedWallets;
  final String? activeWalletId;
  final String? stakeAddress;
  final StakeAccountInfo? stakeInfo;
  final double balanceAda;
  final int totalLovelace;
  final double withdrawableRewardAda;
  final int withdrawableRewardLovelace;
  final String? stakedPoolId;
  final bool isStakeActive;
  final bool isLoadingRewards;
  final List<Map<String, dynamic>> utxos;
  final List<TokenAsset> tokens;
  final bool isLoading;
  final bool isRefreshingAll;
  final String? errorMessage;
  final CardanoNetwork network;
  final BuiltTxResult? lastBuiltTx;
  final String? lastSubmittedTxId;
  final List<Map<String, dynamic>> txHistory;

  HotWalletState({
    this.watchedAddress,
    this.watchedWallets = const [],
    this.activeWalletId,
    this.stakeAddress,
    this.stakeInfo,
    this.balanceAda = 0.0,
    this.totalLovelace = 0,
    this.withdrawableRewardAda = 0.0,
    this.withdrawableRewardLovelace = 0,
    this.stakedPoolId,
    this.isStakeActive = false,
    this.isLoadingRewards = false,
    this.utxos = const [],
    this.tokens = const [],
    this.isLoading = false,
    this.isRefreshingAll = false,
    this.errorMessage,
    this.network = CardanoNetwork.preprod,
    this.lastBuiltTx,
    this.lastSubmittedTxId,
    this.txHistory = const [],
  });

  WatchedWalletEntry? get activeWallet {
    if (watchedWallets.isEmpty) return null;
    if (activeWalletId != null) {
      final found = watchedWallets.where((w) => w.id == activeWalletId);
      if (found.isNotEmpty) return found.first;
    }
    if (watchedAddress != null) {
      final found = watchedWallets.where((w) => w.address == watchedAddress);
      if (found.isNotEmpty) return found.first;
    }
    return watchedWallets.first;
  }

  double get totalPortfolioAda {
    if (watchedWallets.isEmpty) return 0.0;
    return watchedWallets.fold(0.0, (sum, w) => sum + w.cachedBalanceAda);
  }

  List<String> get watchedWalletAddresses => watchedWallets.map((e) => e.address).toList();

  HotWalletState copyWith({
    String? watchedAddress,
    bool clearWatchedAddress = false,
    List<WatchedWalletEntry>? watchedWallets,
    String? activeWalletId,
    bool clearActiveWallet = false,
    String? stakeAddress,
    StakeAccountInfo? stakeInfo,
    double? balanceAda,
    int? totalLovelace,
    double? withdrawableRewardAda,
    int? withdrawableRewardLovelace,
    String? stakedPoolId,
    bool? isStakeActive,
    bool? isLoadingRewards,
    List<Map<String, dynamic>>? utxos,
    List<TokenAsset>? tokens,
    bool? isLoading,
    bool? isRefreshingAll,
    String? errorMessage,
    CardanoNetwork? network,
    BuiltTxResult? lastBuiltTx,
    String? lastSubmittedTxId,
    List<Map<String, dynamic>>? txHistory,
  }) {
    return HotWalletState(
      watchedAddress: clearWatchedAddress ? null : (watchedAddress ?? this.watchedAddress),
      watchedWallets: watchedWallets ?? this.watchedWallets,
      activeWalletId: clearActiveWallet ? null : (activeWalletId ?? this.activeWalletId),
      stakeAddress: stakeAddress ?? this.stakeAddress,
      stakeInfo: stakeInfo ?? this.stakeInfo,
      balanceAda: balanceAda ?? this.balanceAda,
      totalLovelace: totalLovelace ?? this.totalLovelace,
      withdrawableRewardAda: withdrawableRewardAda ?? this.withdrawableRewardAda,
      withdrawableRewardLovelace: withdrawableRewardLovelace ?? this.withdrawableRewardLovelace,
      stakedPoolId: stakedPoolId ?? this.stakedPoolId,
      isStakeActive: isStakeActive ?? this.isStakeActive,
      isLoadingRewards: isLoadingRewards ?? this.isLoadingRewards,
      utxos: utxos ?? this.utxos,
      tokens: tokens ?? this.tokens,
      isLoading: isLoading ?? this.isLoading,
      isRefreshingAll: isRefreshingAll ?? this.isRefreshingAll,
      errorMessage: errorMessage,
      network: network ?? this.network,
      lastBuiltTx: lastBuiltTx ?? this.lastBuiltTx,
      lastSubmittedTxId: lastSubmittedTxId ?? this.lastSubmittedTxId,
      txHistory: txHistory ?? this.txHistory,
    );
  }
}

class HotWalletNotifier extends StateNotifier<HotWalletState> {
  final BlockfrostClient _client;
  final HotMigrationService _migration = HotMigrationService();

  HotWalletNotifier({BlockfrostClient? client})
      : _client = client ?? BlockfrostClient(),
        super(HotWalletState()) {
    initAndLoad();
  }

  Future<void> initAndLoad() async {
    try {
      await _migration.runMigrationIfNeeded();
      final saved = await _migration.loadSavedState();
      final addr = saved['watchedAddress'] as String?;
      final walletEntries = saved['watchedWalletsEntries'] as List<WatchedWalletEntry>? ?? [];
      final net = saved['network'] as CardanoNetwork? ?? CardanoNetwork.preprod;
      final apiKey = saved['apiKey'] as String?;
      final balance = saved['cachedBalance'] as double? ?? 0.0;
      final history = saved['txHistory'] as List<Map<String, dynamic>>? ?? [];

      _client.network = net;
      if (apiKey != null && apiKey.isNotEmpty) {
        _client.customApiKey = apiKey;
      }

      state = state.copyWith(
        watchedAddress: addr,
        watchedWallets: walletEntries,
        activeWalletId: walletEntries.isNotEmpty ? walletEntries.first.id : null,
        network: net,
        balanceAda: balance,
        txHistory: history,
      );

      if (addr != null && addr.isNotEmpty) {
        fetchBalance();
        fetchAllBalances();
      }
    } catch (_) {}
  }

  void setWatchedAddress(String address, {String? name}) {
    addWatchedWallet(address, name: name);
  }

  void addWatchedWallet(String address, {String? name}) {
    final cleanAddr = address.trim();
    if (cleanAddr.isEmpty) return;

    final existingIndex = state.watchedWallets.indexWhere((w) => w.address == cleanAddr);
    List<WatchedWalletEntry> updatedWallets = List.from(state.watchedWallets);

    String assignedId;
    if (existingIndex >= 0) {
      assignedId = updatedWallets[existingIndex].id;
      if (name != null && name.trim().isNotEmpty) {
        updatedWallets[existingIndex] = updatedWallets[existingIndex].copyWith(name: name.trim());
      }
    } else {
      final defaultName = (name != null && name.trim().isNotEmpty)
          ? name.trim()
          : suggestNextWalletName<WatchedWalletEntry>(state.watchedWallets, (w) => w.name);
      assignedId = 'w_${DateTime.now().millisecondsSinceEpoch}_${state.watchedWallets.length}';
      final newEntry = WatchedWalletEntry(
        id: assignedId,
        name: defaultName,
        address: cleanAddr,
      );
      updatedWallets.add(newEntry);
    }

    final derivedStake = CardanoAddressHelper.deriveStakeAddress(cleanAddr);

    state = state.copyWith(
      watchedAddress: cleanAddr,
      activeWalletId: assignedId,
      watchedWallets: updatedWallets,
      stakeAddress: derivedStake,
    );

    _migration.saveState(
      watchedAddress: cleanAddr,
      watchedWalletsEntries: updatedWallets,
    );

    fetchBalance();
    fetchAllBalances();
  }

  void renameWatchedWallet(String idOrAddress, String newName) {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return;

    final updated = state.watchedWallets.map((w) {
      if (w.id == idOrAddress || w.address == idOrAddress) {
        return w.copyWith(name: cleanName);
      }
      return w;
    }).toList();

    state = state.copyWith(watchedWallets: updated);
    _migration.saveState(watchedWalletsEntries: updated);
  }

  void switchWatchedWallet(String idOrAddress) {
    final found = state.watchedWallets.where((w) => w.id == idOrAddress || w.address == idOrAddress);
    if (found.isEmpty) return;
    final target = found.first;

    if (state.watchedAddress == target.address && state.activeWalletId == target.id) {
      return;
    }

    state = state.copyWith(
      watchedAddress: target.address,
      activeWalletId: target.id,
      balanceAda: target.cachedBalanceAda,
      totalLovelace: target.cachedTotalLovelace,
      utxos: const [],
      tokens: const [],
      stakeInfo: null,
      stakeAddress: null,
    );

    _migration.saveState(watchedAddress: target.address);
    fetchBalance();
  }

  void removeWatchedWallet(String idOrAddress) {
    final updated = List<WatchedWalletEntry>.from(state.watchedWallets)
      ..removeWhere((w) => w.id == idOrAddress || w.address == idOrAddress);

    String? nextAddr;
    String? nextId;
    if (updated.isNotEmpty) {
      final next = updated.first;
      nextAddr = next.address;
      nextId = next.id;
    }

    state = state.copyWith(
      watchedAddress: nextAddr,
      clearWatchedAddress: nextAddr == null,
      activeWalletId: nextId,
      clearActiveWallet: nextId == null,
      watchedWallets: updated,
      stakeInfo: null,
      stakeAddress: null,
      balanceAda: updated.isEmpty ? 0.0 : state.balanceAda,
      totalLovelace: updated.isEmpty ? 0 : state.totalLovelace,
      utxos: updated.isEmpty ? const [] : state.utxos,
      tokens: updated.isEmpty ? const [] : state.tokens,
    );

    _migration.saveState(
      watchedAddress: nextAddr ?? '',
      watchedWalletsEntries: updated,
    );

    if (nextAddr != null) {
      fetchBalance();
    }
  }

  Future<void> switchNetwork(CardanoNetwork net, {String? apiKey}) async {
    _client.network = net;
    if (apiKey != null) {
      final clean = apiKey.trim();
      _client.customApiKey = clean.isNotEmpty ? clean : null;
      await _migration.saveApiKeyForNetwork(net, clean);
    } else {
      final savedKey = await _migration.getApiKeyForNetwork(net);
      _client.customApiKey = savedKey;
    }
    state = state.copyWith(network: net);
    await _migration.saveState(network: net, apiKey: _client.customApiKey);
    if (state.watchedAddress != null) {
      fetchBalance();
      fetchAllBalances();
    }
  }

  Future<String?> getSavedApiKeyForNetwork(CardanoNetwork net) async {
    return _migration.getApiKeyForNetwork(net);
  }

  String? get activeCustomApiKey => _client.customApiKey;

  Future<void> fetchAllBalances() async {
    if (state.watchedWallets.isEmpty) return;
    state = state.copyWith(isRefreshingAll: true);

    try {
      final updatedList = <WatchedWalletEntry>[];
      for (final w in state.watchedWallets) {
        try {
          final utxos = await _client.getUtxos(w.address);
          int love = 0;
          for (final u in utxos) {
            final amounts = u['amount'] as List<dynamic>? ?? [];
            for (final a in amounts) {
              if ((a['unit'] as String? ?? 'lovelace') == 'lovelace') {
                love += int.tryParse(a['quantity'].toString()) ?? 0;
              }
            }
          }
          final ada = love / 1000000.0;
          updatedList.add(w.copyWith(
            cachedBalanceAda: ada,
            cachedTotalLovelace: love,
          ));
        } catch (_) {
          updatedList.add(w);
        }
      }

      state = state.copyWith(
        isRefreshingAll: false,
        watchedWallets: updatedList,
      );
      _migration.saveState(watchedWalletsEntries: updatedList);
    } catch (_) {
      state = state.copyWith(isRefreshingAll: false);
    }
  }

  Future<void> fetchBalance() async {
    final addr = state.watchedAddress;
    if (addr == null || addr.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final utxos = await _client.getUtxos(addr);
      int totalLove = 0;
      final Map<String, BigInt> tokenTotals = {};

      for (final u in utxos) {
        final amounts = u['amount'] as List<dynamic>? ?? [];
        for (final a in amounts) {
          final unit = a['unit'] as String? ?? 'lovelace';
          final qtyStr = a['quantity'].toString();
          if (unit == 'lovelace') {
            totalLove += int.tryParse(qtyStr) ?? 0;
          } else {
            final q = BigInt.tryParse(qtyStr) ?? BigInt.zero;
            tokenTotals[unit] = (tokenTotals[unit] ?? BigInt.zero) + q;
          }
        }
      }

      // Nạp thông tin metadata cho từng Token
      final List<TokenAsset> loadedTokens = [];
      for (final entry in tokenTotals.entries) {
        final unit = entry.key;
        final qty = entry.value;

        final meta = await _client.getAssetMetadata(unit);
        String? ticker;
        String? name;
        int decimals = 0;

        if (meta != null && meta['metadata'] != null) {
          final m = meta['metadata'] as Map<String, dynamic>;
          ticker = m['ticker'] as String?;
          name = m['name'] as String?;
          decimals = (m['decimals'] as num?)?.toInt() ?? 0;
        }

        loadedTokens.add(TokenAsset.fromUnit(
          unit: unit,
          quantity: qty,
          decimals: decimals,
          ticker: ticker,
          name: name,
        ));
      }

      // Sắp xếp Token theo tên hiển thị
      loadedTokens.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

      final balanceAda = totalLove / 1000000.0;

      // Cập nhật lại số dư trong cache của active wallet trong danh sách
      final updatedList = state.watchedWallets.map((w) {
        if (w.address == addr) {
          return w.copyWith(cachedBalanceAda: balanceAda, cachedTotalLovelace: totalLove);
        }
        return w;
      }).toList();

      state = state.copyWith(
        isLoading: false,
        utxos: utxos,
        tokens: loadedTokens,
        totalLovelace: totalLove,
        balanceAda: balanceAda,
        watchedWallets: updatedList,
      );
      _migration.saveState(balanceAda: balanceAda, watchedWalletsEntries: updatedList);

      // Tự động truy vấn số dư thưởng Staking kèm theo
      fetchRewardInfo();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      fetchRewardInfo();
    }
  }

  Future<void> fetchRewardInfo() async {
    final addr = state.watchedAddress;
    if (addr == null || addr.isEmpty) return;

    state = state.copyWith(isLoadingRewards: true);

    try {
      String? stakeAddr = state.stakeAddress;
      if (stakeAddr == null || stakeAddr.isEmpty) {
        stakeAddr = CardanoAddressHelper.deriveStakeAddress(addr);
      }
      if (stakeAddr == null || stakeAddr.isEmpty) {
        stakeAddr = await _client.getStakeAddress(addr);
      }

      if (stakeAddr != null && stakeAddr.isNotEmpty) {
        final stakeDetails = await _client.getStakeAccountDetails(stakeAddr);
        final withLovelace = stakeDetails.rewardsAvailableLovelace.toInt();
        final withAda = stakeDetails.rewardsAda;
        final pool = stakeDetails.poolId;
        final active = stakeDetails.isRegistered;

        state = state.copyWith(
          stakeAddress: stakeAddr,
          stakeInfo: stakeDetails,
          withdrawableRewardLovelace: withLovelace,
          withdrawableRewardAda: withAda,
          stakedPoolId: pool,
          isStakeActive: active,
          isLoadingRewards: false,
        );
        return;
      }

      state = state.copyWith(isLoadingRewards: false);
    } catch (_) {
      state = state.copyWith(isLoadingRewards: false);
    }
  }

  Future<BuiltTxResult> prepareDelegationTransaction({String? poolId, String? drepId}) async {
    if (state.watchedAddress == null) {
      throw Exception("Chưa cài đặt địa chỉ ví theo dõi.");
    }

    String? stakeAddr = state.stakeAddress;
    if (stakeAddr == null || stakeAddr.isEmpty) {
      stakeAddr = CardanoAddressHelper.deriveStakeAddress(state.watchedAddress!);
    }
    if (stakeAddr == null || stakeAddr.isEmpty) {
      throw Exception("Không thể xác định Stake Address từ địa chỉ ví.");
    }

    final isReg = state.stakeInfo?.isRegistered ?? state.isStakeActive;

    int? liveTtl;
    try {
      final slot = await _client.getLatestSlot();
      if (slot > 0) liveTtl = slot + 7200;
    } catch (_) {}

    final result = TransactionBuilder.buildDelegationTx(
      senderAddress: state.watchedAddress!,
      stakeAddress: stakeAddr,
      poolId: poolId,
      drepId: drepId,
      isStakeKeyRegistered: isReg,
      utxos: state.utxos,
      ttl: liveTtl,
    );

    state = state.copyWith(lastBuiltTx: result);
    return result;
  }

  Future<BuiltTxResult> prepareRewardWithdrawalTransaction({String? destinationAddress}) async {
    if (state.watchedAddress == null) {
      throw Exception("Chưa cài đặt địa chỉ ví theo dõi.");
    }
    if (state.stakeAddress == null) {
      throw Exception("Không tìm thấy địa chỉ Stake Address để rút thưởng.");
    }
    if (state.withdrawableRewardLovelace <= 0) {
      throw Exception("Không có phần thưởng khả dụng để rút.");
    }

    int? liveTtl;
    try {
      final slot = await _client.getLatestSlot();
      if (slot > 0) liveTtl = slot + 7200;
    } catch (_) {}

    final result = TransactionBuilder.buildRewardWithdrawalTx(
      senderAddress: state.watchedAddress!,
      stakeAddress: state.stakeAddress!,
      withdrawLovelace: state.withdrawableRewardLovelace,
      utxos: state.utxos,
      destinationAddress: destinationAddress,
      ttl: liveTtl,
    );

    state = state.copyWith(lastBuiltTx: result);
    return result;
  }

  Future<BuiltTxResult> prepareTransaction({
    required String recipient,
    required double amountAda,
    List<TokenTransferItem> tokensToSend = const [],
    bool sendMax = false,
  }) async {
    if (state.watchedAddress == null) {
      throw Exception("Chưa cài đặt địa chỉ ví theo dõi.");
    }

    int sendLovelace;
    if (sendMax && tokensToSend.isEmpty) {
      const estFee = 180000;
      sendLovelace = state.totalLovelace - estFee;
      if (sendLovelace <= 0) {
        throw Exception("Số dư không đủ để chi trả phí giao dịch tối thiểu.");
      }
    } else {
      sendLovelace = (amountAda * 1000000).round();
    }

    int? liveTtl;
    try {
      final slot = await _client.getLatestSlot();
      if (slot > 0) liveTtl = slot + 7200;
    } catch (_) {}

    final result = TransactionBuilder.buildTransaction(
      senderAddress: state.watchedAddress!,
      recipientAddress: recipient,
      sendLovelace: sendLovelace,
      tokensToSend: tokensToSend,
      utxos: state.utxos,
      ttl: liveTtl,
    );

    state = state.copyWith(lastBuiltTx: result);
    return result;
  }

  Future<String> submitSignedTx(String signedCborHex) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cleanHex = signedCborHex.trim();
      if (cleanHex.length < 64 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleanHex)) {
        throw Exception("LỖI ĐỊNH DẠNG: Chuỗi giao dịch đã ký không phải là chuỗi CBOR Hex hợp lệ!");
      }

      // 1. Xác minh chữ ký Ed25519 độc lập trước khi phát sóng (Pre-broadcast Cryptographic Verification)
      try {
        final isValid = CardanoCoreBridge.verifySignedTransaction(cleanHex);
        if (!isValid) {
          throw Exception("LỖI XÁC THỰC MẬT MÃ: Chữ ký Ed25519 trong giao dịch không hợp lệ hoặc đã bị can thiệp!");
        }
      } catch (e) {
        if (e.toString().contains("LỖI XÁC THỰC MẬT MÃ")) rethrow;
      }

      // 2. Chốt chặn đối chiếu với giao dịch vừa lập trên Ví Nóng (Anti-Broadcast-Substitution)
      if (state.lastBuiltTx != null) {
        try {
          final parsed = CardanoCoreBridge.parseTransaction(
            cleanHex,
            isTestnet: state.network != CardanoNetwork.mainnet,
          );
          if (state.lastBuiltTx!.sendLovelace > 0 && parsed.sendLovelace != state.lastBuiltTx!.sendLovelace) {
            throw Exception(
              "CẢNH BÁO AN NINH: Số lượng ADA gửi trong giao dịch đã ký (${(parsed.sendLovelace / 1000000).toStringAsFixed(6)} ADA) không khớp với giao dịch bạn vừa lập (${state.lastBuiltTx!.sendAda.toStringAsFixed(6)} ADA)!",
            );
          }
        } catch (e) {
          if (e.toString().contains("CẢNH BÁO AN NINH")) rethrow;
        }
      }

      final txid = await _client.submitTx(cleanHex);
      final newHistory = List<Map<String, dynamic>>.from(state.txHistory);
      newHistory.insert(0, {
        "txId": txid,
        "timestamp": DateTime.now().toIso8601String(),
        "network": state.network.name,
      });

      state = state.copyWith(
        isLoading: false,
        lastSubmittedTxId: txid,
        txHistory: newHistory,
      );
      _migration.saveState(txHistory: newHistory);
      fetchBalance();
      fetchAllBalances();
      return txid;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }
}

final hotWalletProvider = StateNotifierProvider<HotWalletNotifier, HotWalletState>((ref) {
  return HotWalletNotifier();
});
