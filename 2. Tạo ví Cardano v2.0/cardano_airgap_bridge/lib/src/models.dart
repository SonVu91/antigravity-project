enum CardanoNetwork { preprod, preview, mainnet }

extension CardanoNetworkExtension on CardanoNetwork {
  bool get isTestnet => this != CardanoNetwork.mainnet;

  String get displayName {
    switch (this) {
      case CardanoNetwork.mainnet:
        return 'Cardano Mainnet';
      case CardanoNetwork.preprod:
        return 'Preprod Testnet';
      case CardanoNetwork.preview:
        return 'Preview Testnet';
    }
  }

  String get shortName {
    switch (this) {
      case CardanoNetwork.mainnet:
        return 'Mainnet';
      case CardanoNetwork.preprod:
        return 'Preprod';
      case CardanoNetwork.preview:
        return 'Preview';
    }
  }

  String get badgeText {
    switch (this) {
      case CardanoNetwork.mainnet:
        return 'MAINNET';
      case CardanoNetwork.preprod:
        return 'PREPROD TESTNET';
      case CardanoNetwork.preview:
        return 'PREVIEW TESTNET';
    }
  }

  static CardanoNetwork fromString(String? val) {
    if (val == null) return CardanoNetwork.preprod;
    final lower = val.toLowerCase().trim();
    if (lower == 'mainnet') return CardanoNetwork.mainnet;
    if (lower == 'preview') return CardanoNetwork.preview;
    return CardanoNetwork.preprod;
  }
}

class WalletKeysInfo {
  final String mnemonic;
  final String paymentAddress;
  final String stakeAddress;
  final String accountXpubHex;
  final int accountIndex;
  final int addressIndex;
  final String derivationPath;

  WalletKeysInfo({
    required this.mnemonic,
    required this.paymentAddress,
    required this.stakeAddress,
    required this.accountXpubHex,
    this.accountIndex = 0,
    this.addressIndex = 0,
    this.derivationPath = "m/1852'/1815'/0'/0/0",
  });

  factory WalletKeysInfo.fromJson(Map<String, dynamic> json) {
    final accIdx = (json['account_index'] as num?)?.toInt() ?? 0;
    final addrIdx = (json['address_index'] as num?)?.toInt() ?? 0;
    return WalletKeysInfo(
      mnemonic: json['mnemonic'] as String? ?? '',
      paymentAddress: json['payment_address'] as String? ?? '',
      stakeAddress: json['stake_address'] as String? ?? '',
      accountXpubHex: json['account_xpub_hex'] as String? ?? '',
      accountIndex: accIdx,
      addressIndex: addrIdx,
      derivationPath: json['derivation_path'] as String? ?? "m/1852'/1815'/$accIdx'/0/$addrIdx",
    );
  }

  Map<String, dynamic> toJson() => {
    'mnemonic': mnemonic,
    'payment_address': paymentAddress,
    'stake_address': stakeAddress,
    'account_xpub_hex': accountXpubHex,
    'account_index': accountIndex,
    'address_index': addressIndex,
    'derivation_path': derivationPath,
  };
}

class ParsedTokenItem {
  final String policyId;
  final String assetNameHex;
  final String assetNameUtf8;
  final int quantity;

  ParsedTokenItem({
    required this.policyId,
    required this.assetNameHex,
    required this.assetNameUtf8,
    required this.quantity,
  });

  factory ParsedTokenItem.fromJson(Map<String, dynamic> json) {
    return ParsedTokenItem(
      policyId: json['policy_id'] as String? ?? '',
      assetNameHex: json['asset_name_hex'] as String? ?? '',
      assetNameUtf8: json['asset_name_utf8'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'policy_id': policyId,
    'asset_name_hex': assetNameHex,
    'asset_name_utf8': assetNameUtf8,
    'quantity': quantity,
  };
}

class ParsedOutput {
  final String address;
  final int lovelace;
  final bool isChange;
  final bool isChangeVerified;
  final List<ParsedTokenItem> tokens;

  ParsedOutput({
    required this.address,
    required this.lovelace,
    required this.isChange,
    required this.isChangeVerified,
    this.tokens = const [],
  });

  double get ada => lovelace / 1000000.0;

  factory ParsedOutput.fromJson(Map<String, dynamic> json) {
    final rawTokens = json['tokens'] as List<dynamic>? ?? [];
    return ParsedOutput(
      address: json['address'] as String? ?? '',
      lovelace: (json['lovelace'] as num?)?.toInt() ?? 0,
      isChange: json['is_change'] as bool? ?? false,
      isChangeVerified: json['is_change_verified'] as bool? ?? false,
      tokens: rawTokens.map((t) => ParsedTokenItem.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }
}

class ParsedTransaction {
  final int feeLovelace;
  final int? ttl;
  final int inputsCount;
  final List<ParsedOutput> outputs;
  final String recipientAddress;
  final int sendLovelace;
  final int changeLovelace;
  final bool isChangeSafe;
  final String? securityWarning;
  final String txHashHex;
  final bool hasCerts;
  final int certsCount;
  final List<String> certificatesSummary;
  final bool hasWithdrawals;
  final int withdrawalsTotalLovelace;
  final List<String> withdrawalsSummary;
  final bool requiresStakeSigning;

  ParsedTransaction({
    required this.feeLovelace,
    this.ttl,
    required this.inputsCount,
    required this.outputs,
    required this.recipientAddress,
    required this.sendLovelace,
    required this.changeLovelace,
    required this.isChangeSafe,
    this.securityWarning,
    this.txHashHex = '',
    this.hasCerts = false,
    this.certsCount = 0,
    this.certificatesSummary = const [],
    this.hasWithdrawals = false,
    this.withdrawalsTotalLovelace = 0,
    this.withdrawalsSummary = const [],
    this.requiresStakeSigning = false,
  });

  double get feeAda => feeLovelace / 1000000.0;
  double get sendAda => sendLovelace / 1000000.0;
  double get changeAda => changeLovelace / 1000000.0;
  double get withdrawalsTotalAda => withdrawalsTotalLovelace / 1000000.0;

  List<ParsedTokenItem> get recipientTokens => outputs.isNotEmpty ? outputs[0].tokens : [];
  List<ParsedTokenItem> get changeTokens => outputs.length > 1 ? outputs[1].tokens : [];
  bool get hasTokens => recipientTokens.isNotEmpty || changeTokens.isNotEmpty;

  factory ParsedTransaction.fromJson(Map<String, dynamic> json) {
    final rawOutputs = json['outputs'] as List<dynamic>? ?? [];
    final rawCertsSummary = json['certificates_summary'] as List<dynamic>? ?? [];
    final rawWithdrawalsSummary = json['withdrawals_summary'] as List<dynamic>? ?? [];
    return ParsedTransaction(
      feeLovelace: (json['fee_lovelace'] as num?)?.toInt() ?? 0,
      ttl: (json['ttl'] as num?)?.toInt(),
      inputsCount: (json['inputs_count'] as num?)?.toInt() ?? 0,
      outputs: rawOutputs.map((e) => ParsedOutput.fromJson(e as Map<String, dynamic>)).toList(),
      recipientAddress: json['recipient_address'] as String? ?? '',
      sendLovelace: (json['send_lovelace'] as num?)?.toInt() ?? 0,
      changeLovelace: (json['change_lovelace'] as num?)?.toInt() ?? 0,
      isChangeSafe: json['is_change_safe'] as bool? ?? true,
      securityWarning: json['security_warning'] as String?,
      txHashHex: json['tx_hash_hex'] as String? ?? '',
      hasCerts: json['has_certs'] as bool? ?? false,
      certsCount: (json['certs_count'] as num?)?.toInt() ?? 0,
      certificatesSummary: rawCertsSummary.map((e) => e.toString()).toList(),
      hasWithdrawals: json['has_withdrawals'] as bool? ?? false,
      withdrawalsTotalLovelace: (json['withdrawals_total_lovelace'] as num?)?.toInt() ?? 0,
      withdrawalsSummary: rawWithdrawalsSummary.map((e) => e.toString()).toList(),
      requiresStakeSigning: json['requires_stake_signing'] as bool? ?? false,
    );
  }
}
