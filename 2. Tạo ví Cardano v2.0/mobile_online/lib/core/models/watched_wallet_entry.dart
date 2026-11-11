import 'dart:convert';
import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';

class WatchedWalletEntry {
  final String id;
  final String name;
  final String address;
  final DateTime createdAt;
  final double cachedBalanceAda;
  final int cachedTotalLovelace;

  WatchedWalletEntry({
    required this.id,
    required this.name,
    required this.address,
    DateTime? createdAt,
    this.cachedBalanceAda = 0.0,
    this.cachedTotalLovelace = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  String get groupName => extractGroupName(name);

  WatchedWalletEntry copyWith({
    String? id,
    String? name,
    String? address,
    DateTime? createdAt,
    double? cachedBalanceAda,
    int? cachedTotalLovelace,
  }) {
    return WatchedWalletEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      cachedBalanceAda: cachedBalanceAda ?? this.cachedBalanceAda,
      cachedTotalLovelace: cachedTotalLovelace ?? this.cachedTotalLovelace,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'createdAt': createdAt.toIso8601String(),
    'cachedBalanceAda': cachedBalanceAda,
    'cachedTotalLovelace': cachedTotalLovelace,
  };

  factory WatchedWalletEntry.fromJson(Map<String, dynamic> json) {
    return WatchedWalletEntry(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Chung-Ví',
      address: json['address'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      cachedBalanceAda: (json['cachedBalanceAda'] as num?)?.toDouble() ?? 0.0,
      cachedTotalLovelace: (json['cachedTotalLovelace'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is String) {
      return id == other || address == other;
    }
    return identical(this, other) || (other is WatchedWalletEntry && other.id == id);
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => address;

  static String encodeList(List<WatchedWalletEntry> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }

  static List<WatchedWalletEntry> decodeList(String rawJson) {
    try {
      final List<dynamic> list = jsonDecode(rawJson);
      return list.map((e) => WatchedWalletEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
