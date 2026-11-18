import 'dart:convert';
import 'package:archive/archive.dart';

class MultipartQrEncoder {
  final int chunkSize;

  MultipartQrEncoder({this.chunkSize = 180});

  /// Tính mã kiểm tra CRC-32 (8 hex chars) làm Session ID và Checksum bảo vệ toàn vẹn
  static String computeChecksum(String input) {
    int crc = 0xFFFFFFFF;
    final bytes = utf8.encode(input);
    for (final b in bytes) {
      crc ^= b;
      for (int i = 0; i < 8; i++) {
        crc = (crc & 1 != 0) ? (crc >>> 1) ^ 0xEDB88320 : (crc >>> 1);
      }
    }
    final val = (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
    return val.toRadixString(16).padLeft(8, '0');
  }

  /// Nén chuỗi bằng Zlib Deflate và xuất chuỗi Base64
  static String compressZlibBase64(String input) {
    final rawBytes = utf8.encode(input);
    final compressedBytes = ZLibEncoder().encode(rawBytes);
    return base64.encode(compressedBytes);
  }

  /// Giải nén chuỗi Base64 Zlib Inflate về chuỗi UTF-8 gốc (Giới hạn tối đa 64 KB ngăn chặn Decompression Bomb)
  static String decompressZlibBase64(String b64Input, {int maxDecompressedBytes = 65536}) {
    if (b64Input.length > 131072) {
      throw FormatException('Base64 input exceeds safety limit (128 KB)');
    }
    final compressedBytes = base64.decode(b64Input);
    final decompressedBytes = ZLibDecoder().decodeBytes(compressedBytes);
    if (decompressedBytes.length > maxDecompressedBytes) {
      throw FormatException('Decompressed payload exceeds safety limit ($maxDecompressedBytes bytes)');
    }
    return utf8.decode(decompressedBytes);
  }

  /// Chuyển đổi payload (txRaw hoặc txSigned) thành danh sách các frame mã QR
  /// Áp dụng cơ chế Thích ứng (Adaptive Dual-Mode):
  /// - Dưới 300 bytes: QR tĩnh thông thường
  /// - 300 - 499 bytes: Base64 thuần với prefix UR:CARDANO-TX/
  /// - Từ 500 bytes trở lên: Nén Zlib với prefix UR:CARDANO-TX-Z/
  List<String> encode(String payload) {
    final cleanPayload = payload.trim();
    if (cleanPayload.length < 300) {
      // Dưới 300 ký tự: Sử dụng 1 mã QR tĩnh duy nhất
      return [cleanPayload];
    }

    final bool useZlib = cleanPayload.length >= 500;
    final String streamData = useZlib ? compressZlibBase64(cleanPayload) : cleanPayload;
    final String prefix = useZlib ? 'UR:CARDANO-TX-Z' : 'UR:CARDANO-TX';
    final sessionId = computeChecksum(cleanPayload);

    final List<String> chunks = [];
    for (int i = 0; i < streamData.length; i += chunkSize) {
      final end = (i + chunkSize < streamData.length) ? i + chunkSize : streamData.length;
      chunks.add(streamData.substring(i, end));
    }

    final total = chunks.length;
    final List<String> frames = [];
    for (int i = 0; i < total; i++) {
      final seq = i + 1;
      frames.add('$prefix/${seq}OF$total/$sessionId:${chunks[i]}');
    }
    return frames;
  }
}

class MultipartQrDecoder {
  final Map<int, String> _receivedChunks = {};
  int _totalChunks = 0;
  String? _currentSessionId;
  bool _isZlib = false;

  bool get isComplete => _totalChunks > 0 && _receivedChunks.length == _totalChunks;
  int get receivedCount => _receivedChunks.length;
  int get totalCount => _totalChunks;
  double get progress => _totalChunks == 0 ? 0.0 : (_receivedChunks.length / _totalChunks);
  String? get currentSessionId => _currentSessionId;
  bool get isZlibCompressed => _isZlib;

  void reset() {
    _receivedChunks.clear();
    _totalChunks = 0;
    _currentSessionId = null;
    _isZlib = false;
  }

  /// Tiếp nhận frame vừa quét được qua camera
  /// Trả về chuỗi payload đầy đủ nếu đã thu thập xong 100%, hoặc null nếu đang tiếp tục gom
  String? feed(String rawScanned) {
    final trimmed = rawScanned.trim();

    // Trường hợp 1: Mã QR tĩnh đơn lẻ (không có header multipart)
    if (!trimmed.startsWith('UR:CARDANO-TX/') && !trimmed.startsWith('UR:CARDANO-TX-Z/')) {
      reset();
      _totalChunks = 1;
      _receivedChunks[1] = trimmed;
      return trimmed;
    }

    final bool frameIsZlib = trimmed.startsWith('UR:CARDANO-TX-Z/');
    final prefix = frameIsZlib ? 'UR:CARDANO-TX-Z' : 'UR:CARDANO-TX';

    // Trường hợp 2: Frame thuộc Animated QR
    // Cấu trúc: UR:CARDANO-TX[-Z]/<seq>OF<total>/[<sessionId>:]<data>
    final regex = RegExp('^$prefix/(\\d+)OF(\\d+)/(.+)\$', dotAll: true);
    final match = regex.firstMatch(trimmed);
    if (match == null) return null;

    final seq = int.tryParse(match.group(1) ?? '');
    final total = int.tryParse(match.group(2) ?? '');
    var chunkData = match.group(3);

    if (seq == null || total == null || chunkData == null) return null;
    if (seq < 1 || total < 1 || seq > total || total > 500) return null;

    // Tách Session ID (8 ký tự hex + ':') nếu có
    String? frameSessionId;
    if (chunkData.length > 9 && chunkData[8] == ':') {
      final candidate = chunkData.substring(0, 8);
      if (RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(candidate)) {
        frameSessionId = candidate;
        chunkData = chunkData.substring(9);
      }
    }

    // Chống Frame Collision: Reset nếu đổi giao dịch khác hoặc đổi chế độ nén
    if (_totalChunks != 0 && (
      _totalChunks != total ||
      _isZlib != frameIsZlib ||
      (frameSessionId != null && _currentSessionId != null && _currentSessionId != frameSessionId)
    )) {
      reset();
    }

    _totalChunks = total;
    _isZlib = frameIsZlib;
    if (frameSessionId != null) {
      _currentSessionId = frameSessionId;
    }
    _receivedChunks[seq] = chunkData;

    if (isComplete) {
      final buffer = StringBuffer();
      for (int i = 1; i <= _totalChunks; i++) {
        buffer.write(_receivedChunks[i] ?? '');
      }
      final assembledStream = buffer.toString();

      String fullPayload;
      if (_isZlib) {
        try {
          fullPayload = MultipartQrEncoder.decompressZlibBase64(assembledStream);
        } catch (_) {
          reset();
          return null;
        }
      } else {
        fullPayload = assembledStream;
      }

      // Xác thực tính toàn vẹn (Checksum / Session Verification)
      if (_currentSessionId != null) {
        final calculatedChecksum = MultipartQrEncoder.computeChecksum(fullPayload);
        if (calculatedChecksum.toLowerCase() != _currentSessionId!.toLowerCase()) {
          // Bị lỗi toàn vẹn hoặc mất gói -> hủy dữ liệu hỏng để quét lại an toàn
          reset();
          return null;
        }
      }

      return fullPayload;
    }

    return null;
  }
}
