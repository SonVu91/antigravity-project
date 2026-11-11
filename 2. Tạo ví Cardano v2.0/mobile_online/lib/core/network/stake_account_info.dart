class StakeAccountInfo {
  final String stakeAddress;
  final bool isRegistered;
  final String? poolId;
  final String? drepId;
  final BigInt controlledAmountLovelace;
  final BigInt rewardsAvailableLovelace;
  final String? poolName;
  final String? poolTicker;

  static const String fimiPoolId = "pool1rct5guwnp6nk9f4ldn5tr3s42j0nm5rxeayv56lxua5ck47ex39";
  static const String fimiDRepId = "drep1xgzlpyy3pvywm5wvhkvyz9cpga5wylme6wdu6l9vn5g6cp38jdj";
  static const String preprodPoolId = "pool1z22x5eljjsyyt9qqfqxc99s5q0vgpd409smqlmgpqamm2f3eh88";

  StakeAccountInfo({
    required this.stakeAddress,
    required this.isRegistered,
    this.poolId,
    this.drepId,
    required this.controlledAmountLovelace,
    required this.rewardsAvailableLovelace,
    this.poolName,
    this.poolTicker,
  });

  double get controlledAda => controlledAmountLovelace / BigInt.from(1000000);
  double get rewardsAda => rewardsAvailableLovelace / BigInt.from(1000000);

  bool get isDelegatedToPool => poolId != null && poolId!.isNotEmpty;
  bool get isDelegatedToDRep => drepId != null && drepId!.isNotEmpty;

  bool get isFimiPool => poolId == fimiPoolId;
  bool get isFimiDRep => drepId == fimiDRepId;

  String get displayPoolTitle {
    if (!isDelegatedToPool) return "Chưa ủy thác Stake Pool";
    if (isFimiPool) return "FIMI Stake Pool (FIMI)";
    if (poolTicker != null && poolTicker!.isNotEmpty) {
      return "$poolTicker (${poolName ?? poolId!.substring(0, 12)}...)";
    }
    return poolName ?? "${poolId!.substring(0, 14)}...${poolId!.substring(poolId!.length - 6)}";
  }

  String get displayDRepTitle {
    if (!isDelegatedToDRep) return "Chưa ủy quyền DRep";
    if (isFimiDRep) return "FIMI DRep";
    if (drepId == "always_abstain" || drepId == "drep_always_abstain") {
      return "Bỏ phiếu trắng (Always Abstain)";
    }
    if (drepId == "always_no_confidence" || drepId == "drep_always_no_confidence") {
      return "Luôn bất tín nhiệm (Always No Confidence)";
    }
    if (drepId!.startsWith("drep1")) {
      return "DRep: ${drepId!.substring(0, 12)}...${drepId!.substring(drepId!.length - 6)}";
    }
    return "DRep: $drepId";
  }

  factory StakeAccountInfo.fromJson(Map<String, dynamic> json, {String? poolName, String? poolTicker}) {
    final stakeAddr = json['stake_address'] as String? ?? '';
    final active = json['active'] as bool? ?? false;
    final pool = json['pool_id'] as String?;
    final drep = json['drep_id'] as String?;
    final controlledStr = json['controlled_amount']?.toString() ?? '0';
    final rewardsStr = json['withdrawable_amount']?.toString() ?? json['rewards_sum']?.toString() ?? '0';

    return StakeAccountInfo(
      stakeAddress: stakeAddr,
      isRegistered: active,
      poolId: pool,
      drepId: drep,
      controlledAmountLovelace: BigInt.tryParse(controlledStr) ?? BigInt.zero,
      rewardsAvailableLovelace: BigInt.tryParse(rewardsStr) ?? BigInt.zero,
      poolName: poolName ?? (pool == fimiPoolId ? "FIMI Stake Pool" : null),
      poolTicker: poolTicker ?? (pool == fimiPoolId ? "FIMI" : null),
    );
  }

  StakeAccountInfo copyWith({
    String? stakeAddress,
    bool? isRegistered,
    String? poolId,
    String? drepId,
    BigInt? controlledAmountLovelace,
    BigInt? rewardsAvailableLovelace,
    String? poolName,
    String? poolTicker,
  }) {
    return StakeAccountInfo(
      stakeAddress: stakeAddress ?? this.stakeAddress,
      isRegistered: isRegistered ?? this.isRegistered,
      poolId: poolId ?? this.poolId,
      drepId: drepId ?? this.drepId,
      controlledAmountLovelace: controlledAmountLovelace ?? this.controlledAmountLovelace,
      rewardsAvailableLovelace: rewardsAvailableLovelace ?? this.rewardsAvailableLovelace,
      poolName: poolName ?? this.poolName,
      poolTicker: poolTicker ?? this.poolTicker,
    );
  }
}
