import 'dart:convert';
import 'dart:html' as html;
import 'models.dart';
import 'bip39_pure.dart';

class CardanoCoreBridge {
  static String get _serviceUrl {
    final host = html.window.location.hostname;
    if (host != null && host.isNotEmpty) {
      return 'http://$host:5050';
    }
    return 'http://localhost:5050';
  }

  static void init([String? customPath]) {}

  static bool get isNativeAvailable => false;

  static Map<String, dynamic> _post(String endpoint, Map<String, dynamic> body) {
    try {
      final xhr = html.HttpRequest();
      xhr.open('POST', '$_serviceUrl$endpoint', async: false);
      xhr.setRequestHeader('Content-Type', 'application/json');
      xhr.setRequestHeader('X-Cardano-AirGap-Bridge', '1');
      xhr.send(jsonEncode(body));
      if (xhr.status == 200 && xhr.responseText != null && xhr.responseText!.isNotEmpty) {
        return jsonDecode(xhr.responseText!) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'success': false, 'error': 'Auxiliary service not reachable at $_serviceUrl'};
  }

  static String generateMnemonic(int wordCount) {
    final res = _post('/api/generate_mnemonic', {'word_count': wordCount});
    if (res['success'] == true && res['data'] != null) {
      return res['data'] as String;
    }
    throw StateError(res['error']?.toString() ?? 'Failed to generate mnemonic: Auxiliary service unreachable.');
  }

  static bool validateMnemonic(String phrase) {
    final res = _post('/api/validate_mnemonic', {'phrase': phrase});
    if (res['success'] == true && res['data'] is bool) {
      return res['data'] as bool;
    }
    return false;
  }

  /// Kiểm tra một từ riêng lẻ có thuộc từ điển BIP-39 hay không
  static bool isWordValid(String word) => Bip39Pure.isWordValid(word);

  /// Trích xuất danh sách các từ bị sai (không thuộc BIP-39) từ chuỗi phrase
  static List<String> findInvalidWords(String phrase) => Bip39Pure.findInvalidWords(phrase);

  /// Lấy danh sách gợi ý từ nhanh dựa trên tiền tố (prefix) đang gõ
  static List<String> getSuggestions(String prefix, {int limit = 6}) => Bip39Pure.getSuggestions(prefix, limit: limit);

  /// Gợi ý từ đúng gần giống nhất cho từ gõ sai
  static String? suggestClosestWord(String invalidWord) => Bip39Pure.suggestClosestWord(invalidWord);


  static WalletKeysInfo createWallet(
    String phrase, {
    String passphrase = '',
    bool isTestnet = true,
    int accountIndex = 0,
    int addressIndex = 0,
    bool useIcarus = false,
  }) {
    final res = _post('/api/create_wallet', {
      'phrase': phrase,
      'passphrase': passphrase,
      'is_testnet': isTestnet,
      'account_index': accountIndex,
      'address_index': addressIndex,
      'use_icarus': useIcarus,
    });
    if (res['success'] == true && res['data'] != null) {
      return WalletKeysInfo.fromJson(res['data'] as Map<String, dynamic>);
    }
    throw StateError(res['error']?.toString() ?? 'Failed to create wallet: Auxiliary service unreachable.');
  }

  static ParsedTransaction parseTransaction(
    String cborHex, {
    String? accountXpubHex,
    bool isTestnet = true,
    String? knownAddress,
  }) {
    final res = _post('/api/parse_tx', {
      'cbor_hex': cborHex,
      'account_xpub_hex': accountXpubHex ?? '',
      'is_testnet': isTestnet,
      'known_address': knownAddress ?? '',
    });
    if (res['success'] == true && res['data'] != null) {
      return ParsedTransaction.fromJson(res['data'] as Map<String, dynamic>);
    }
    throw StateError(res['error']?.toString() ?? 'Failed to parse transaction: Auxiliary service unreachable.');
  }

  static String signTransaction(
    String cborHex,
    String mnemonic, {
    String passphrase = '',
    bool signStake = false,
    int accountIndex = 0,
    int addressIndex = 0,
    bool isTestnet = true,
    bool useIcarus = false,
  }) {
    final res = _post('/api/sign_tx', {
      'cbor_hex': cborHex,
      'mnemonic': mnemonic,
      'passphrase': passphrase,
      'sign_stake': signStake,
      'account_index': accountIndex,
      'address_index': addressIndex,
      'is_testnet': isTestnet,
      'use_icarus': useIcarus,
    });
    if (res['success'] == true && res['data'] != null) {
      return res['data'] as String;
    }
    throw Exception(res['error'] ?? 'Lỗi ký giao dịch qua Auxiliary Core Service');
  }

  static bool verifySignedTransaction(String signedCborHex) {
    final clean = signedCborHex.trim();
    if (clean.length < 64 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      return false;
    }
    // Transaction canonical Conway/Babbage bắt đầu bằng 84 (Array 4), Shelley/Mary bắt đầu bằng 83 (Array 3)
    return clean.startsWith('84') || clean.startsWith('83');
  }

  static bool verifyChange(String changeAddress, String accountXpubHex, {bool isTestnet = true}) {
    final res = _post('/api/verify_change', {
      'change_address': changeAddress,
      'account_xpub_hex': accountXpubHex,
      'is_testnet': isTestnet,
    });
    if (res['success'] == true && res['data'] != null) {
      return res['data'] as bool;
    }
    return false;
  }

  static String createSampleConwayTx(String recipientAddress, int sendLovelace, int feeLovelace) {
    final res = _post('/api/create_sample_conway_tx', {
      'recipient_addr': recipientAddress,
      'send_lovelace': sendLovelace,
      'fee_lovelace': feeLovelace,
    });
    if (res['success'] == true && res['data'] != null) {
      return res['data'] as String;
    }
    throw StateError(res['error']?.toString() ?? 'Failed to create sample Conway tx: Auxiliary service unreachable.');
  }
}
