import 'package:convert/convert.dart';

class CardanoAddressHelper {
  static const String charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

  static int _polymod(List<int> values) {
    int chk = 1;
    for (final v in values) {
      final b = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ v;
      if ((b & 1) != 0) chk ^= 0x3b6a57b2;
      if ((b & 2) != 0) chk ^= 0x26508e6d;
      if ((b & 4) != 0) chk ^= 0x1ea119fa;
      if ((b & 8) != 0) chk ^= 0x3d4233dd;
      if ((b & 16) != 0) chk ^= 0x2a1462b3;
    }
    return chk;
  }

  static List<int> _hrpExpand(String hrp) {
    final res = <int>[];
    for (int i = 0; i < hrp.length; i++) {
      res.add(hrp.codeUnitAt(i) >> 5);
    }
    res.add(0);
    for (int i = 0; i < hrp.length; i++) {
      res.add(hrp.codeUnitAt(i) & 31);
    }
    return res;
  }

  static bool _verifyChecksum(String hrp, List<int> data) {
    return _polymod([..._hrpExpand(hrp), ...data]) == 1;
  }

  static List<int> _createChecksum(String hrp, List<int> data) {
    final values = [..._hrpExpand(hrp), ...data, 0, 0, 0, 0, 0, 0];
    final mod = _polymod(values) ^ 1;
    final ret = <int>[];
    for (int p = 0; p < 6; p++) {
      ret.add((mod >> (5 * (5 - p))) & 31);
    }
    return ret;
  }

  static List<int>? _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    int acc = 0;
    int bits = 0;
    final ret = <int>[];
    final maxv = (1 << toBits) - 1;
    final maxAcc = (1 << (fromBits + toBits - 1)) - 1;
    for (final value in data) {
      if (value < 0 || (value >> fromBits) != 0) return null;
      acc = ((acc << fromBits) | value) & maxAcc;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        ret.add((acc >> bits) & maxv);
      }
    }
    if (pad) {
      if (bits > 0) {
        ret.add((acc << (toBits - bits)) & maxv);
      }
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
      return null;
    }
    return ret;
  }

  /// Decode Bech32 string to {hrp, bytes}
  static Map<String, dynamic>? decodeBech32(String bech) {
    final clean = bech.trim().toLowerCase();
    final pos = clean.lastIndexOf('1');
    if (pos == -1 || pos == 0 || pos + 7 > clean.length) return null;

    final hrp = clean.substring(0, pos);
    final data = <int>[];
    for (int i = pos + 1; i < clean.length; i++) {
      final idx = charset.indexOf(clean[i]);
      if (idx == -1) return null;
      data.add(idx);
    }

    if (!_verifyChecksum(hrp, data)) return null;

    final payload5Bit = data.sublist(0, data.length - 6);
    final bytes = _convertBits(payload5Bit, 5, 8, false);
    if (bytes == null) return null;

    return {
      'hrp': hrp,
      'bytes': bytes,
    };
  }

  /// Encode raw bytes to Bech32 with given HRP
  static String encodeToBech32(String hrp, List<int> bytes) {
    final data5Bit = _convertBits(bytes, 8, 5, true);
    if (data5Bit == null) {
      throw Exception("Lỗi chuyển đổi dữ liệu 8-bit sang 5-bit cho Bech32.");
    }
    final checksum = _createChecksum(hrp, data5Bit);
    final combined = [...data5Bit, ...checksum];
    final buffer = StringBuffer();
    buffer.write(hrp);
    buffer.write('1');
    for (final b in combined) {
      buffer.write(charset[b]);
    }
    return buffer.toString();
  }

  /// Trích xuất Stake Address (CIP-19) từ Base Payment Address (addr1... hoặc addr_test1...)
  static String? deriveStakeAddress(String paymentAddress) {
    final clean = paymentAddress.trim();
    if (clean.startsWith('stake1') || clean.startsWith('stake_test1')) {
      return clean;
    }

    final decoded = decodeBech32(clean);
    if (decoded == null) return null;

    final List<int> bytes = decoded['bytes'] as List<int>;
    // Base address theo CIP-19 có độ dài 57 bytes (1 byte header + 28 bytes payment cred + 28 bytes stake cred)
    if (bytes.length != 57) {
      return null;
    }

    final int header = bytes[0];
    final int addrType = (header >> 4) & 0x0f;
    // addrType 0, 1, 2, 3 là base address có chứa stake credential
    if (addrType > 3) {
      return null;
    }

    final int networkTag = header & 0x0f;
    final bool isMainnet = networkTag == 1;
    final String stakeHrp = isMainnet ? 'stake' : 'stake_test';

    // Stake address type = 14 (0b1110)
    final int stakeHeader = (14 << 4) | (isMainnet ? 1 : 0);
    final List<int> stakeCred = bytes.sublist(29, 57);

    final List<int> stakeAddressBytes = [stakeHeader, ...stakeCred];
    return encodeToBech32(stakeHrp, stakeAddressBytes);
  }

  /// Trích xuất 28-byte hash từ Pool ID (Bech32 pool1... hoặc chuỗi hex 56 ký tự)
  static List<int>? poolIdToBytes(String poolId) {
    final clean = poolId.trim();
    if (clean.startsWith('pool1')) {
      final decoded = decodeBech32(clean);
      if (decoded != null && decoded['bytes'] != null) {
        final bytes = decoded['bytes'] as List<int>;
        if (bytes.length == 28) return bytes;
      }
    }
    if (clean.length == 56 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      return hex.decode(clean);
    }
    return null;
  }

  /// Chuẩn hóa Pool ID thành Bech32 (pool1...)
  static String? normalizePoolIdToBech32(String poolId) {
    final clean = poolId.trim();
    if (clean.startsWith('pool1')) return clean;
    final bytes = poolIdToBytes(clean);
    if (bytes != null) {
      return encodeToBech32('pool', bytes);
    }
    return null;
  }

  /// Trích xuất 28-byte hash từ DRep ID (Bech32 drep1... hoặc chuỗi hex 56 ký tự)
  static List<int>? drepIdToBytes(String drepId) {
    final clean = drepId.trim();
    if (clean.startsWith('drep1')) {
      final decoded = decodeBech32(clean);
      if (decoded != null && decoded['bytes'] != null) {
        final bytes = decoded['bytes'] as List<int>;
        // drep1 payload có thể gồm 28 bytes hash (hoặc 1 byte header + 28 bytes hash CIP-105)
        if (bytes.length == 28) return bytes;
        if (bytes.length == 29) return bytes.sublist(1);
      }
    }
    if (clean.length == 56 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      return hex.decode(clean);
    }
    return null;
  }

  /// Chuẩn hóa DRep ID thành Bech32 (drep1...)
  static String? normalizeDrepIdToBech32(String drepId) {
    final clean = drepId.trim();
    if (clean == 'always_abstain' || clean == 'always_no_confidence') {
      return clean;
    }
    if (clean.startsWith('drep1')) return clean;
    final bytes = drepIdToBytes(clean);
    if (bytes != null) {
      return encodeToBech32('drep', bytes);
    }
    return null;
  }
}
