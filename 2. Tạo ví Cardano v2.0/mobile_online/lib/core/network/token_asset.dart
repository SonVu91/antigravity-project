import 'dart:convert';

class TokenAsset {
  final String policyId;
  final String assetNameHex;
  final String assetNameUtf8;
  final BigInt quantity;
  final int decimals;
  final String? ticker;
  final String? name;

  const TokenAsset({
    required this.policyId,
    required this.assetNameHex,
    required this.assetNameUtf8,
    required this.quantity,
    this.decimals = 0,
    this.ticker,
    this.name,
  });

  String get unit => "$policyId$assetNameHex";

  String get displayName {
    if (ticker != null && ticker!.isNotEmpty) return ticker!;
    if (assetNameUtf8.isNotEmpty && !assetNameUtf8.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
      return assetNameUtf8;
    }
    if (name != null && name!.isNotEmpty) return name!;
    if (policyId.length >= 8) {
      return "Token (${policyId.substring(0, 8)}...)";
    }
    return "Token ($unit)";
  }

  String get formattedBalance {
    if (decimals == 0) {
      return _formatNumberWithCommas(quantity.toString());
    }

    final s = quantity.toString().padLeft(decimals + 1, '0');
    final intPart = s.substring(0, s.length - decimals);
    var fracPart = s.substring(s.length - decimals);
    // Trim trailing zeros in fractional part
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

  BigInt parseInputAmount(String input) {
    final clean = input.replaceAll(',', '').trim();
    if (clean.isEmpty) return BigInt.zero;

    if (decimals == 0) {
      return BigInt.tryParse(clean) ?? BigInt.zero;
    }

    final parts = clean.split('.');
    final intPart = parts[0];
    var fracPart = parts.length > 1 ? parts[1] : '';

    if (fracPart.length > decimals) {
      fracPart = fracPart.substring(0, decimals);
    } else {
      fracPart = fracPart.padRight(decimals, '0');
    }

    final combined = "$intPart$fracPart";
    return BigInt.tryParse(combined) ?? BigInt.zero;
  }

  TokenAsset copyWith({
    String? policyId,
    String? assetNameHex,
    String? assetNameUtf8,
    BigInt? quantity,
    int? decimals,
    String? ticker,
    String? name,
  }) {
    return TokenAsset(
      policyId: policyId ?? this.policyId,
      assetNameHex: assetNameHex ?? this.assetNameHex,
      assetNameUtf8: assetNameUtf8 ?? this.assetNameUtf8,
      quantity: quantity ?? this.quantity,
      decimals: decimals ?? this.decimals,
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
    );
  }

  static String decodeHexToUtf8(String hexStr) {
    if (hexStr.isEmpty) return "";
    try {
      final bytes = <int>[];
      for (int i = 0; i < hexStr.length; i += 2) {
        bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
      }
      final decoded = utf8.decode(bytes, allowMalformed: true);
      return decoded.replaceAll('\u0000', '').trim();
    } catch (_) {
      return hexStr;
    }
  }

  static String encodeUtf8ToHex(String str) {
    final bytes = utf8.encode(str);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  factory TokenAsset.fromUnit({
    required String unit,
    required BigInt quantity,
    int decimals = 0,
    String? ticker,
    String? name,
  }) {
    final cleanUnit = unit.trim();
    if (cleanUnit.length <= 56) {
      return TokenAsset(
        policyId: cleanUnit,
        assetNameHex: "",
        assetNameUtf8: "",
        quantity: quantity,
        decimals: decimals,
        ticker: ticker,
        name: name,
      );
    }
    final policy = cleanUnit.substring(0, 56);
    final nameHex = cleanUnit.substring(56);
    final nameUtf8 = decodeHexToUtf8(nameHex);

    return TokenAsset(
      policyId: policy,
      assetNameHex: nameHex,
      assetNameUtf8: nameUtf8,
      quantity: quantity,
      decimals: decimals,
      ticker: ticker,
      name: name,
    );
  }
}
