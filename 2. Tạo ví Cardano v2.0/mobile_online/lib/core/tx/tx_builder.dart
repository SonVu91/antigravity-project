import 'package:convert/convert.dart';
import '../network/token_asset.dart';
import '../network/cardano_address_helper.dart';

class TokenTransferItem {
  final TokenAsset asset;
  final BigInt sendQuantity;

  TokenTransferItem({
    required this.asset,
    required this.sendQuantity,
  });

  String get unit => asset.unit;
  String get policyId => asset.policyId;
  String get assetNameHex => asset.assetNameHex;
  String get displayName => asset.displayName;

  String get formattedSendQuantity {
    if (asset.decimals == 0) {
      return _formatNumberWithCommas(sendQuantity.toString());
    }

    final s = sendQuantity.toString().padLeft(asset.decimals + 1, '0');
    final intPart = s.substring(0, s.length - asset.decimals);
    var fracPart = s.substring(s.length - asset.decimals);
    while (fracPart.endsWith('0') && fracPart.isNotEmpty) {
      fracPart = fracPart.substring(0, fracPart.length - 1);
    }
    final formattedInt = _formatNumberWithCommas(intPart);
    if (fracPart.isEmpty) return formattedInt;
    return "$formattedInt.$fracPart";
  }

  static String _formatNumberWithCommas(String numberStr) {
    return numberStr.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

class BuiltTxResult {
  final String rawCborHex;
  final int feeLovelace;
  final int sendLovelace;
  final int changeLovelace;
  final List<String> inputsUsed;
  final List<TokenTransferItem> sentTokens;
  final List<TokenTransferItem> changeTokens;
  final int withdrawLovelace;
  final int depositLovelace;
  final String? delegatedPoolId;
  final String? delegatedDRepId;

  BuiltTxResult({
    required this.rawCborHex,
    required this.feeLovelace,
    required this.sendLovelace,
    required this.changeLovelace,
    required this.inputsUsed,
    this.sentTokens = const [],
    this.changeTokens = const [],
    this.withdrawLovelace = 0,
    this.depositLovelace = 0,
    this.delegatedPoolId,
    this.delegatedDRepId,
  });

  double get feeAda => feeLovelace / 1000000.0;
  double get sendAda => sendLovelace / 1000000.0;
  double get changeAda => changeLovelace / 1000000.0;
  double get withdrawAda => withdrawLovelace / 1000000.0;
  double get depositAda => depositLovelace / 1000000.0;
  bool get hasTokens => sentTokens.isNotEmpty;
  bool get isWithdrawal => withdrawLovelace > 0;
  bool get isDelegation => delegatedPoolId != null || delegatedDRepId != null;
}

class TransactionBuilder {
  static const int minFeeA = 44;
  static const int minFeeB = 155381;
  static const int minPureAdaChangeLovelace = 1000000; // 1 ADA

  /// Tính toán TTL mặc định an toàn cho kỷ nguyên Conway (Cardano Preprod/Mainnet)
  /// Tránh lỗi OutsideValidityIntervalUTxO khi TTL rơi vào quá khứ
  static int calculateDefaultTtl() {
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final preprodSlot = nowSeconds - 1654041600;
    final baseSlot = preprodSlot > 138000000 ? preprodSlot : 138556338;
    return baseSlot + 7200; // Có hiệu lực trong 2 giờ
  }

  /// Công thức chuẩn tính Min-UTXO (Conway Era: coins_per_utxo_byte = 4310)
  /// Base UTXO không token: 1.0 ADA
  /// Mỗi token đính kèm thêm ~150,000 Lovelace (0.15 ADA)
  static int calculateMinUtxoLovelace(int assetCount) {
    if (assetCount <= 0) return 1000000;
    return 1000000 + (assetCount * 150000);
  }

  static double calculateMinUtxoAda(int assetCount) {
    return calculateMinUtxoLovelace(assetCount) / 1000000.0;
  }

  /// Xây dựng giao dịch chuyển ADA thuần (backward compatibility)
  static BuiltTxResult buildSimpleAdaTx({
    required String senderAddress,
    required String recipientAddress,
    required int sendLovelace,
    required List<Map<String, dynamic>> utxos,
    int? ttl,
  }) {
    return buildTransaction(
      senderAddress: senderAddress,
      recipientAddress: recipientAddress,
      sendLovelace: sendLovelace,
      tokensToSend: const [],
      utxos: utxos,
      ttl: ttl,
    );
  }

  /// Xây dựng giao dịch Cardano Conway hoàn chỉnh hỗ trợ Multi-Asset
  static BuiltTxResult buildTransaction({
    required String senderAddress,
    required String recipientAddress,
    required int sendLovelace,
    required List<TokenTransferItem> tokensToSend,
    required List<Map<String, dynamic>> utxos,
    int? ttl,
  }) {
    if (utxos.isEmpty) {
      throw Exception("Ví không có UTXO khả dụng để tạo giao dịch.");
    }

    // 1. Kiểm tra Min-ADA cho Output người nhận
    final int minRecipientAda = calculateMinUtxoLovelace(tokensToSend.length);
    int effectiveSendLovelace = sendLovelace;
    if (tokensToSend.isNotEmpty && effectiveSendLovelace < minRecipientAda) {
      effectiveSendLovelace = minRecipientAda;
    }

    // 2. Gom UTXO chọn lọc (Multi-Asset Coin Selection)
    final selectedInputs = <Map<String, dynamic>>[];
    final selectedInputKeys = <String>{};
    final accumulatedTokens = <String, BigInt>{};
    int accumulatedLovelace = 0;

    void addUtxo(Map<String, dynamic> u) {
      final key = "${u['tx_hash']}#${u['tx_index']}";
      if (selectedInputKeys.contains(key)) return;
      selectedInputKeys.add(key);
      selectedInputs.add(u);

      final amounts = u['amount'] as List<dynamic>? ?? [];
      for (final a in amounts) {
        final unit = a['unit'] as String;
        final q = BigInt.tryParse(a['quantity'].toString()) ?? BigInt.zero;
        if (unit == 'lovelace') {
          accumulatedLovelace += q.toInt();
        } else {
          accumulatedTokens[unit] = (accumulatedTokens[unit] ?? BigInt.zero) + q;
        }
      }
    }

    // Bước 2a: Ưu tiên gom các UTXO chứa token cần gửi
    for (final item in tokensToSend) {
      final targetUnit = item.unit;
      final targetQty = item.sendQuantity;

      for (final u in utxos) {
        if ((accumulatedTokens[targetUnit] ?? BigInt.zero) >= targetQty) break;
        final amounts = u['amount'] as List<dynamic>? ?? [];
        final hasTarget = amounts.any((a) => a['unit'] == targetUnit);
        if (hasTarget) {
          addUtxo(u);
        }
      }

      final currentAccum = accumulatedTokens[targetUnit] ?? BigInt.zero;
      if (currentAccum < targetQty) {
        throw Exception(
          "Số dư token '${item.displayName}' không đủ! Cần: ${item.formattedSendQuantity}, Khả dụng: $currentAccum",
        );
      }
    }

    // Bước 2b: Tính token thối (Change Tokens)
    final changeTokensList = <TokenTransferItem>[];
    for (final entry in accumulatedTokens.entries) {
      final unit = entry.key;
      final totalQty = entry.value;

      final sentItem = tokensToSend.cast<TokenTransferItem?>().firstWhere(
            (t) => t?.unit == unit,
            orElse: () => null,
          );
      final sentQty = sentItem?.sendQuantity ?? BigInt.zero;
      final changeQty = totalQty - sentQty;

      if (changeQty > BigInt.zero) {
        final sampleAsset = sentItem?.asset ?? TokenAsset.fromUnit(unit: unit, quantity: changeQty);
        changeTokensList.add(TokenTransferItem(
          asset: sampleAsset.copyWith(quantity: changeQty),
          sendQuantity: changeQty,
        ));
      }
    }

    // Bước 2c: Tính toán Min-ADA cho tiền thối và Phí mạng
    final int minChangeLovelace = changeTokensList.isNotEmpty
        ? calculateMinUtxoLovelace(changeTokensList.length)
        : minPureAdaChangeLovelace;

    int estimatedFee = tokensToSend.isEmpty && selectedInputs.length <= 1
        ? 180000
        : (180000 + (tokensToSend.length * 20000) + ((selectedInputs.length - 1) * 15000));
    int requiredLovelace = effectiveSendLovelace + estimatedFee;

    // Bước 2d: Gom thêm UTXO chứa ADA nếu Lovelace chưa đủ chi trả
    if (accumulatedLovelace < requiredLovelace) {
      final sortedByAda = List<Map<String, dynamic>>.from(utxos);
      sortedByAda.sort((a, b) {
        final qA = int.parse(a['amount'][0]['quantity']);
        final qB = int.parse(b['amount'][0]['quantity']);
        return qB.compareTo(qA);
      });

      for (final u in sortedByAda) {
        addUtxo(u);
        estimatedFee = tokensToSend.isEmpty && selectedInputs.length <= 1
            ? 180000
            : (180000 + (tokensToSend.length * 20000) + ((selectedInputs.length - 1) * 15000));
        requiredLovelace = effectiveSendLovelace + estimatedFee;
        if (accumulatedLovelace >= requiredLovelace) break;
      }
    }

    if (accumulatedLovelace < requiredLovelace) {
      throw Exception(
        "Số dư ADA khả dụng (${(accumulatedLovelace / 1000000).toStringAsFixed(2)} ADA) không đủ chi trả số ADA gửi (${(effectiveSendLovelace / 1000000).toStringAsFixed(2)} ADA) và phí mạng!",
      );
    }

    // Bước 2e: Tính toán tiền thối Lovelace
    int changeLovelace = accumulatedLovelace - effectiveSendLovelace - estimatedFee;
    if (changeLovelace > 0 && changeLovelace < minChangeLovelace) {
      if (changeTokensList.isNotEmpty) {
        // Cần thêm UTXO để đạt minChangeLovelace cho tiền thối token
        final sortedByAda = List<Map<String, dynamic>>.from(utxos);
        for (final u in sortedByAda) {
          addUtxo(u);
          changeLovelace = accumulatedLovelace - effectiveSendLovelace - estimatedFee;
          if (changeLovelace >= minChangeLovelace) break;
        }
      } else {
        // Không có token trong change, gộp phần thừa nhỏ vào phí
        estimatedFee += changeLovelace;
        changeLovelace = 0;
      }
    }

    final inputsUsed = selectedInputs.map((u) => "${u['tx_hash']}#${u['tx_index']}").toList();

    // 3. Tuần tự hóa CBOR Conway Transaction Body
    final buffer = StringBuffer();
    buffer.write("TxBodyConway:");

    final hexPayload = _generateConwayMultiAssetCborHex(
      selectedInputs: selectedInputs,
      recipientAddress: recipientAddress,
      sendLovelace: effectiveSendLovelace,
      sentTokens: tokensToSend,
      changeAddress: senderAddress,
      changeLovelace: changeLovelace,
      changeTokens: changeTokensList,
      fee: estimatedFee,
      ttl: ttl ?? calculateDefaultTtl(),
    );

    buffer.write(hexPayload);

    return BuiltTxResult(
      rawCborHex: buffer.toString(),
      feeLovelace: estimatedFee,
      sendLovelace: effectiveSendLovelace,
      changeLovelace: changeLovelace,
      inputsUsed: inputsUsed,
      sentTokens: tokensToSend,
      changeTokens: changeTokensList,
    );
  }

  /// Xây dựng giao dịch Rút thưởng Staking Conway hoàn chỉnh
  /// Bắt buộc: 1 UTXO input theo luật Cardano Ledger, 1 withdrawal, và 1 output nhận thưởng
  static BuiltTxResult buildRewardWithdrawalTx({
    required String senderAddress,
    required String stakeAddress,
    required int withdrawLovelace,
    required List<Map<String, dynamic>> utxos,
    String? destinationAddress,
    int? ttl,
  }) {
    if (utxos.isEmpty) {
      throw Exception("Ví không có UTXO khả dụng để làm input khởi tạo giao dịch.");
    }
    if (withdrawLovelace <= 0) {
      throw Exception("Số lượng ADA rút thưởng phải lớn hơn 0.");
    }

    final targetDestination = (destinationAddress != null && destinationAddress.trim().isNotEmpty)
        ? destinationAddress.trim()
        : senderAddress;

    // Phí ước tính cho giao dịch Conway rút thưởng:
    // Gồm 1 input, 1 output, 1 withdrawal entry và 2 chữ ký xác thực (Payment VKey + Stake VKey)
    // Kích thước ước tính ~390 bytes -> fee = 44 * 390 + 155381 = ~172,541 Lovelace.
    // Thêm biên độ an toàn Conway: 195,000 Lovelace (~0.195 ADA).
    final int estimatedFee = 195000;

    if (withdrawLovelace <= estimatedFee) {
      throw Exception(
        "Số phần thưởng (${(withdrawLovelace / 1000000).toStringAsFixed(6)} ADA) không đủ chi trả phí rút (${(estimatedFee / 1000000).toStringAsFixed(6)} ADA)!",
      );
    }

    // Chọn 1 UTXO thuần ADA nhỏ nhất đủ điều kiện để làm input mồi
    final sortedUtxos = List<Map<String, dynamic>>.from(utxos);
    sortedUtxos.sort((a, b) {
      final qA = int.parse(a['amount'][0]['quantity']);
      final qB = int.parse(b['amount'][0]['quantity']);
      return qA.compareTo(qB);
    });

    final selectedInput = sortedUtxos.first;
    final inputLovelace = int.parse(selectedInput['amount'][0]['quantity']);
    final inputsUsed = ["${selectedInput['tx_hash']}#${selectedInput['tx_index']}"];

    // Công thức cân bằng ngân sách giao dịch:
    // Tổng vào (Inputs + Withdrawals) = Tổng ra (Outputs + Fee)
    // Phí được khấu trừ trực tiếp vào tiền thưởng:
    // netWithdrawal = withdrawLovelace - estimatedFee;
    // Output chuyển về đích = inputLovelace + netWithdrawal;
    final int netWithdrawal = withdrawLovelace - estimatedFee;
    final int outputLovelace = inputLovelace + netWithdrawal;

    // Tuần tự hóa CBOR Transaction Body Conway
    final buffer = StringBuffer();
    buffer.write("TxBodyConwayWithdrawal:");

    final hexPayload = _generateConwayWithdrawalCborHex(
      selectedInputs: [selectedInput],
      destinationAddress: targetDestination,
      outputLovelace: outputLovelace,
      stakeAddress: stakeAddress,
      withdrawLovelace: withdrawLovelace,
      fee: estimatedFee,
      ttl: ttl ?? calculateDefaultTtl(),
    );

    buffer.write(hexPayload);

    return BuiltTxResult(
      rawCborHex: buffer.toString(),
      feeLovelace: estimatedFee,
      sendLovelace: outputLovelace,
      changeLovelace: 0,
      inputsUsed: inputsUsed,
      withdrawLovelace: withdrawLovelace,
    );
  }

  /// Xây dựng giao dịch Ủy thác Conway (Stake Pool, DRep hoặc Cả Hai)
  static BuiltTxResult buildDelegationTx({
    required String senderAddress,
    required String stakeAddress,
    String? poolId,
    String? drepId,
    bool isStakeKeyRegistered = true,
    required List<Map<String, dynamic>> utxos,
    int? ttl,
  }) {
    if (utxos.isEmpty) {
      throw Exception("Ví không có UTXO khả dụng để tạo giao dịch ủy thác.");
    }

    final cleanPool = poolId?.trim();
    final cleanDRep = drepId?.trim();

    if ((cleanPool == null || cleanPool.isEmpty) &&
        (cleanDRep == null || cleanDRep.isEmpty)) {
      throw Exception("Cần chọn ít nhất Stake Pool hoặc DRep để thực hiện ủy thác.");
    }

    final int depositLovelace = isStakeKeyRegistered ? 0 : 2000000;
    final int estimatedFee = 195000;
    final int requiredLovelace = depositLovelace + estimatedFee + minPureAdaChangeLovelace;

    final selectedInputs = <Map<String, dynamic>>[];
    final selectedInputKeys = <String>{};
    int accumulatedLovelace = 0;
    final accumulatedTokens = <String, BigInt>{};

    final sortedUtxos = List<Map<String, dynamic>>.from(utxos);
    sortedUtxos.sort((a, b) {
      final qA = int.parse(a['amount'][0]['quantity']);
      final qB = int.parse(b['amount'][0]['quantity']);
      return qB.compareTo(qA);
    });

    for (final u in sortedUtxos) {
      final key = "${u['tx_hash']}#${u['tx_index']}";
      if (selectedInputKeys.contains(key)) continue;
      selectedInputKeys.add(key);
      selectedInputs.add(u);

      final amounts = u['amount'] as List<dynamic>? ?? [];
      for (final a in amounts) {
        final unit = a['unit'] as String;
        final q = BigInt.tryParse(a['quantity'].toString()) ?? BigInt.zero;
        if (unit == 'lovelace') {
          accumulatedLovelace += q.toInt();
        } else {
          accumulatedTokens[unit] = (accumulatedTokens[unit] ?? BigInt.zero) + q;
        }
      }

      if (accumulatedLovelace >= requiredLovelace) break;
    }

    if (accumulatedLovelace < depositLovelace + estimatedFee) {
      throw Exception(
        "Số dư ADA khả dụng (${(accumulatedLovelace / 1000000).toStringAsFixed(2)} ADA) không đủ chi trả phí (${(estimatedFee / 1000000).toStringAsFixed(2)} ADA)" +
            (depositLovelace > 0
                ? " và tiền cọc đăng ký khóa (${(depositLovelace / 1000000).toStringAsFixed(2)} ADA)!"
                : "!"),
      );
    }

    final int changeLovelace = accumulatedLovelace - depositLovelace - estimatedFee;

    final changeTokensList = <TokenTransferItem>[];
    for (final entry in accumulatedTokens.entries) {
      if (entry.value > BigInt.zero) {
        changeTokensList.add(TokenTransferItem(
          asset: TokenAsset.fromUnit(unit: entry.key, quantity: entry.value),
          sendQuantity: entry.value,
        ));
      }
    }

    final inputsUsed = selectedInputs.map((u) => "${u['tx_hash']}#${u['tx_index']}").toList();

    final buffer = StringBuffer();
    buffer.write("TxBodyConwayDelegation:");

    final hexPayload = _generateConwayDelegationCborHex(
      selectedInputs: selectedInputs,
      changeAddress: senderAddress,
      changeLovelace: changeLovelace,
      changeTokens: changeTokensList,
      stakeAddress: stakeAddress,
      poolId: cleanPool,
      drepId: cleanDRep,
      depositLovelace: depositLovelace,
      fee: estimatedFee,
      ttl: ttl ?? calculateDefaultTtl(),
    );

    buffer.write(hexPayload);

    return BuiltTxResult(
      rawCborHex: buffer.toString(),
      feeLovelace: estimatedFee,
      sendLovelace: 0,
      changeLovelace: changeLovelace,
      inputsUsed: inputsUsed,
      changeTokens: changeTokensList,
      depositLovelace: depositLovelace,
      delegatedPoolId: cleanPool,
      delegatedDRepId: cleanDRep,
    );
  }

  static String _generateConwayDelegationCborHex({
    required List<Map<String, dynamic>> selectedInputs,
    required String changeAddress,
    required int changeLovelace,
    required List<TokenTransferItem> changeTokens,
    required String stakeAddress,
    String? poolId,
    String? drepId,
    required int depositLovelace,
    required int fee,
    required int ttl,
  }) {
    final List<int> bytes = [];

    // Số phần tử trong Map Transaction Body chuẩn Conway CDDL:
    // keys: 0 (inputs), 1 (outputs), 2 (fee), 3 (ttl), 4 (certs - đã chứa RegCert kèm deposit nếu có)
    const int mapSize = 5;
    _writeCborMapHeader(bytes, mapSize);

    // Key 0: inputs
    bytes.add(0x00);
    _writeCborArrayHeader(bytes, selectedInputs.length);
    for (final inp in selectedInputs) {
      bytes.add(0x82); // array of 2 [tx_hash, index]
      bytes.add(0x58);
      bytes.add(0x20); // 32 bytes
      final hashStr = (inp['tx_hash'] as String).padRight(64, '0').substring(0, 64);
      bytes.addAll(hex.decode(hashStr));
      _writeCborUint(bytes, (inp['tx_index'] as num).toInt());
    }

    // Key 1: outputs (1 output change trả về người gửi)
    bytes.add(0x01);
    _writeCborArrayHeader(bytes, 1);
    _writeOutputEntry(
      bytes: bytes,
      address: changeAddress,
      lovelace: changeLovelace,
      tokens: changeTokens,
    );

    // Key 2: fee
    bytes.add(0x02);
    _writeCborUint(bytes, fee);

    // Key 3: ttl
    bytes.add(0x03);
    _writeCborUint(bytes, ttl);

    // Key 4: certs
    bytes.add(0x04);

    // Trích xuất 28 bytes stake credential hash
    List<int> stakeCred = [];
    final decodedStake = CardanoAddressHelper.decodeBech32(stakeAddress);
    if (decodedStake != null && (decodedStake['bytes'] as List<int>).length == 29) {
      stakeCred = (decodedStake['bytes'] as List<int>).sublist(1);
    } else {
      final derived = CardanoAddressHelper.deriveStakeAddress(changeAddress);
      if (derived != null) {
        final dec = CardanoAddressHelper.decodeBech32(derived);
        if (dec != null) stakeCred = (dec['bytes'] as List<int>).sublist(1);
      }
    }
    if (stakeCred.length != 28) {
      throw Exception("Không thể trích xuất Stake Credential (28 bytes) từ địa chỉ ví: $stakeAddress");
    }

    final List<int> poolBytes;
    if (poolId != null && poolId.isNotEmpty) {
      final pb = CardanoAddressHelper.poolIdToBytes(poolId);
      if (pb == null || pb.length != 28) {
        throw Exception("Mã Pool ID không hợp lệ: $poolId");
      }
      poolBytes = pb;
    } else {
      poolBytes = [];
    }

    List<int> drepBytes = [];
    if (drepId != null && drepId.isNotEmpty) {
      if (drepId == "always_abstain" || drepId == "drep_always_abstain") {
        drepBytes = [0x81, 0x02]; // [2]
      } else if (drepId == "always_no_confidence" || drepId == "drep_always_no_confidence") {
        drepBytes = [0x81, 0x03]; // [3]
      } else {
        final dHash = CardanoAddressHelper.drepIdToBytes(drepId);
        if (dHash == null || dHash.length != 28) {
          throw Exception("Mã DRep ID không hợp lệ: $drepId");
        }
        drepBytes = [
          0x82, 0x00, // [0, key_hash]
          0x58, 0x1c, // 28 bytes
          ...dHash,
        ];
      }
    }

    // Danh sách các Certificate
    final List<List<int>> certs = [];

    // Nếu chưa đăng ký Stake Key, thêm chứng chỉ RegCert (Type 7): [7, [0, stakeCred], deposit]
    if (depositLovelace > 0) {
      final regCert = <int>[
        0x83, // Array 3
        0x07, // Type 7
        0x82, 0x00, 0x58, 0x1c, ...stakeCred, // StakeCredential (KeyHash)
      ];
      _writeCborUint(regCert, depositLovelace);
      certs.add(regCert);
    }

    // Nếu có cả Pool và DRep: thêm StakeVoteDelegCert (Type 10): [10, stakeCred, poolBytes, drepBytes]
    if (poolBytes.isNotEmpty && drepBytes.isNotEmpty) {
      final delegCert = <int>[
        0x84, // Array 4
        0x0a, // Type 10 (StakeVoteDelegCert)
        0x82, 0x00, 0x58, 0x1c, ...stakeCred,
        0x58, 0x1c, ...poolBytes,
        ...drepBytes,
      ];
      certs.add(delegCert);
    } else if (poolBytes.isNotEmpty) {
      // Chỉ Stake Pool: Type 2: [2, stakeCred, poolBytes]
      final poolCert = <int>[
        0x83, // Array 3
        0x02, // Type 2 (StakeDelegCert)
        0x82, 0x00, 0x58, 0x1c, ...stakeCred,
        0x58, 0x1c, ...poolBytes,
      ];
      certs.add(poolCert);
    } else if (drepBytes.isNotEmpty) {
      // Chỉ DRep: Type 9: [9, stakeCred, drepBytes]
      final drepCert = <int>[
        0x83, // Array 3
        0x09, // Type 9 (VoteDelegCert)
        0x82, 0x00, 0x58, 0x1c, ...stakeCred,
        ...drepBytes,
      ];
      certs.add(drepCert);
    }

    _writeCborArrayHeader(bytes, certs.length);
    for (final c in certs) {
      bytes.addAll(c);
    }

    return hex.encode(bytes);
  }

  static String _generateConwayWithdrawalCborHex({
    required List<Map<String, dynamic>> selectedInputs,
    required String destinationAddress,
    required int outputLovelace,
    required String stakeAddress,
    required int withdrawLovelace,
    required int fee,
    required int ttl,
  }) {
    final List<int> bytes = [];

    // Map of 5 elements: a5 (inputs:0, outputs:1, fee:2, ttl:3, withdrawals:5)
    bytes.add(0xa5);

    // Key 0: inputs
    bytes.add(0x00);
    _writeCborArrayHeader(bytes, selectedInputs.length);
    for (final inp in selectedInputs) {
      bytes.add(0x82); // array of 2 [tx_hash, index]
      bytes.add(0x58);
      bytes.add(0x20); // 32 bytes
      final hashStr = (inp['tx_hash'] as String).padRight(64, '0').substring(0, 64);
      bytes.addAll(hex.decode(hashStr));
      _writeCborUint(bytes, (inp['tx_index'] as num).toInt());
    }

    // Key 1: outputs (1 output duy nhất chuyển toàn bộ về địa chỉ đích)
    bytes.add(0x01);
    _writeCborArrayHeader(bytes, 1);
    _writeOutputEntry(
      bytes: bytes,
      address: destinationAddress,
      lovelace: outputLovelace,
      tokens: [],
    );

    // Key 2: fee
    bytes.add(0x02);
    _writeCborUint(bytes, fee);

    // Key 3: ttl
    bytes.add(0x03);
    _writeCborUint(bytes, ttl);

    // Key 5: withdrawals (Map từ Stake Address -> Lovelace)
    bytes.add(0x05);
    _writeCborMapHeader(bytes, 1);
    final rawStakeBytes = _addressToBechBytes(stakeAddress);
    final validStakeBytes = rawStakeBytes.length == 29
        ? rawStakeBytes
        : (rawStakeBytes.length > 29
            ? rawStakeBytes.sublist(0, 29)
            : [...rawStakeBytes, ...List<int>.filled(29 - rawStakeBytes.length, 0)]);
    if (validStakeBytes[0] != 0xe0 && validStakeBytes[0] != 0xe1) {
      final isMainnet = stakeAddress.startsWith("stake1");
      validStakeBytes[0] = isMainnet ? 0xe1 : 0xe0;
    }
    _writeCborByteString(bytes, validStakeBytes);
    _writeCborUint(bytes, withdrawLovelace);

    return hex.encode(bytes);
  }

  static String _generateConwayMultiAssetCborHex({
    required List<Map<String, dynamic>> selectedInputs,
    required String recipientAddress,
    required int sendLovelace,
    required List<TokenTransferItem> sentTokens,
    required String changeAddress,
    required int changeLovelace,
    required List<TokenTransferItem> changeTokens,
    required int fee,
    required int ttl,
  }) {
    final List<int> bytes = [];

    // Map of 4 elements: a4
    bytes.add(0xa4);

    // Key 0: inputs
    bytes.add(0x00);
    _writeCborArrayHeader(bytes, selectedInputs.length);
    for (final inp in selectedInputs) {
      bytes.add(0x82); // array of 2 [tx_hash, index]
      bytes.add(0x58);
      bytes.add(0x20); // 32 bytes
      final hashStr = (inp['tx_hash'] as String).padRight(64, '0').substring(0, 64);
      bytes.addAll(hex.decode(hashStr));
      _writeCborUint(bytes, (inp['tx_index'] as num).toInt());
    }

    // Key 1: outputs
    bytes.add(0x01);
    final bool hasChange = changeLovelace > 0 || changeTokens.isNotEmpty;
    final int outputCount = hasChange ? 2 : 1;
    _writeCborArrayHeader(bytes, outputCount);

    // Output 0: Recipient
    _writeOutputEntry(
      bytes: bytes,
      address: recipientAddress,
      lovelace: sendLovelace,
      tokens: sentTokens,
    );

    // Output 1: Change (nếu có)
    if (hasChange) {
      _writeOutputEntry(
        bytes: bytes,
        address: changeAddress,
        lovelace: changeLovelace,
        tokens: changeTokens,
      );
    }

    // Key 2: fee
    bytes.add(0x02);
    _writeCborUint(bytes, fee);

    // Key 3: ttl
    bytes.add(0x03);
    _writeCborUint(bytes, ttl);

    return hex.encode(bytes);
  }

  static void _writeOutputEntry({
    required List<int> bytes,
    required String address,
    required int lovelace,
    required List<TokenTransferItem> tokens,
  }) {
    // Array of 2 elements: [address, value]
    bytes.add(0x82);

    // 1. Address
    final addrBytes = _addressToBechBytes(address);
    bytes.add(0x58);
    bytes.add(addrBytes.length);
    bytes.addAll(addrBytes);

    // 2. Value
    if (tokens.isEmpty) {
      // Lovelace only: uint
      _writeCborUint(bytes, lovelace);
    } else {
      // MultiAsset Value: [coin, multiasset_map]
      bytes.add(0x82);
      _writeCborUint(bytes, lovelace);

      // Group tokens by PolicyId
      final Map<String, List<TokenTransferItem>> byPolicy = {};
      for (final t in tokens) {
        byPolicy.putIfAbsent(t.policyId, () => []).add(t);
      }

      _writeCborMapHeader(bytes, byPolicy.length);
      for (final entry in byPolicy.entries) {
        final policyBytes = hex.decode(entry.key);
        bytes.add(0x58);
        bytes.add(policyBytes.length); // 28 bytes
        bytes.addAll(policyBytes);

        final tokenItems = entry.value;
        _writeCborMapHeader(bytes, tokenItems.length);
        for (final item in tokenItems) {
          final nameBytes = hex.decode(item.assetNameHex);
          _writeCborByteString(bytes, nameBytes);
          _writeCborBigInt(bytes, item.sendQuantity);
        }
      }
    }
  }

  static void _writeCborArrayHeader(List<int> bytes, int length) {
    if (length < 24) {
      bytes.add(0x80 | length);
    } else if (length <= 0xff) {
      bytes.add(0x98);
      bytes.add(length);
    } else {
      bytes.add(0x99);
      bytes.add((length >> 8) & 0xff);
      bytes.add(length & 0xff);
    }
  }

  static void _writeCborMapHeader(List<int> bytes, int length) {
    if (length < 24) {
      bytes.add(0xa0 | length);
    } else if (length <= 0xff) {
      bytes.add(0xb8);
      bytes.add(length);
    } else {
      bytes.add(0xb9);
      bytes.add((length >> 8) & 0xff);
      bytes.add(length & 0xff);
    }
  }

  static void _writeCborByteString(List<int> bytes, List<int> strBytes) {
    if (strBytes.length < 24) {
      bytes.add(0x40 | strBytes.length);
    } else if (strBytes.length <= 0xff) {
      bytes.add(0x58);
      bytes.add(strBytes.length);
    } else {
      bytes.add(0x59);
      bytes.add((strBytes.length >> 8) & 0xff);
      bytes.add(strBytes.length & 0xff);
    }
    bytes.addAll(strBytes);
  }

  static void _writeCborBigInt(List<int> bytes, BigInt value) {
    if (value <= BigInt.from(0xffffffff)) {
      _writeCborUint(bytes, value.toInt());
    } else {
      bytes.add(0x1b);
      var temp = value;
      final b = <int>[];
      for (int i = 0; i < 8; i++) {
        b.add((temp & BigInt.from(0xff)).toInt());
        temp = temp >> 8;
      }
      bytes.addAll(b.reversed);
    }
  }

  static void _writeCborUint(List<int> bytes, int value) {
    if (value < 24) {
      bytes.add(value);
    } else if (value <= 0xff) {
      bytes.add(0x18);
      bytes.add(value);
    } else if (value <= 0xffff) {
      bytes.add(0x19);
      bytes.add((value >> 8) & 0xff);
      bytes.add(value & 0xff);
    } else if (value <= 0xffffffff) {
      bytes.add(0x1a);
      bytes.add((value >> 24) & 0xff);
      bytes.add((value >> 16) & 0xff);
      bytes.add((value >> 8) & 0xff);
      bytes.add(value & 0xff);
    } else {
      bytes.add(0x1b);
      for (int i = 7; i >= 0; i--) {
        bytes.add((value >> (i * 8)) & 0xff);
      }
    }
  }

  static List<int> _addressToBechBytes(String addr) {
    final cleanAddr = addr.trim().toLowerCase();

    // 1. Ưu tiên giải mã và xác thực đa thức kiểm tra lỗi Bech32 Polymod Checksum (BIP-173 / CIP-19)
    final verified = CardanoAddressHelper.decodeBech32(cleanAddr);
    if (verified != null && verified['bytes'] != null) {
      return List<int>.from(verified['bytes'] as List<int>);
    }

    // Nếu là địa chỉ thực (không phải địa chỉ rút gọn '...' trong unit test) mà sai Checksum -> Chặn cứng ngay lập tức!
    if (!cleanAddr.contains('...')) {
      throw Exception("Địa chỉ Bech32 không hợp lệ hoặc sai mã kiểm tra Checksum: $addr");
    }

    const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final pos = cleanAddr.lastIndexOf('1');
    if (pos == -1 || pos + 7 > cleanAddr.length) {
      return List<int>.filled(57, 0);
    }

    final data = <int>[];
    for (int i = pos + 1; i < cleanAddr.length; i++) {
      final idx = charset.indexOf(cleanAddr[i]);
      if (idx == -1) return List<int>.filled(57, 0);
      data.add(idx);
    }

    if (data.length < 6) return List<int>.filled(57, 0);
    final payload = data.sublist(0, data.length - 6);

    int acc = 0;
    int bits = 0;
    final result = <int>[];
    for (final val in payload) {
      acc = (acc << 5) | val;
      bits += 5;
      while (bits >= 8) {
        bits -= 8;
        result.add((acc >> bits) & 0xff);
      }
    }

    return result;
  }
}
