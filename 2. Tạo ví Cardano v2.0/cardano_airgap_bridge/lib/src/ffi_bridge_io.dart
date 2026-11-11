import 'cardano_pure.dart';
import 'bip39_pure.dart';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'models.dart';

typedef _CardanoGenMnemonicC = Pointer<Utf8> Function(Uint32 wordCount);
typedef _CardanoGenMnemonicDart = Pointer<Utf8> Function(int wordCount);

typedef _CardanoValMnemonicC = Bool Function(Pointer<Utf8> phrase);
typedef _CardanoValMnemonicDart = bool Function(Pointer<Utf8> phrase);

typedef _CardanoCreateWalletC = Pointer<Utf8> Function(Pointer<Utf8> phrase, Pointer<Utf8> passphrase, Bool isTestnet, Uint32 accountIndex, Uint32 addressIndex);
typedef _CardanoCreateWalletDart = Pointer<Utf8> Function(Pointer<Utf8> phrase, Pointer<Utf8> passphrase, bool isTestnet, int accountIndex, int addressIndex);

typedef _CardanoCreateWalletExtC = Pointer<Utf8> Function(Pointer<Utf8> phrase, Pointer<Utf8> passphrase, Bool isTestnet, Uint32 accountIndex, Uint32 addressIndex, Bool useIcarus);
typedef _CardanoCreateWalletExtDart = Pointer<Utf8> Function(Pointer<Utf8> phrase, Pointer<Utf8> passphrase, bool isTestnet, int accountIndex, int addressIndex, bool useIcarus);

typedef _CardanoParseTxC = Pointer<Utf8> Function(Pointer<Utf8> cborHex, Pointer<Utf8> accountXpubHex, Bool isTestnet);
typedef _CardanoParseTxDart = Pointer<Utf8> Function(Pointer<Utf8> cborHex, Pointer<Utf8> accountXpubHex, bool isTestnet);

typedef _CardanoSignTxC = Pointer<Utf8> Function(Pointer<Utf8> cborHex, Pointer<Utf8> mnemonic, Pointer<Utf8> passphrase, Bool signStake, Uint32 accountIndex, Uint32 addressIndex);
typedef _CardanoSignTxDart = Pointer<Utf8> Function(Pointer<Utf8> cborHex, Pointer<Utf8> mnemonic, Pointer<Utf8> passphrase, bool signStake, int accountIndex, int addressIndex);

typedef _CardanoSignTxExtC = Pointer<Utf8> Function(Pointer<Utf8> cborHex, Pointer<Utf8> mnemonic, Pointer<Utf8> passphrase, Bool signStake, Uint32 accountIndex, Uint32 addressIndex, Bool useIcarus);
typedef _CardanoSignTxExtDart = Pointer<Utf8> Function(Pointer<Utf8> cborHex, Pointer<Utf8> mnemonic, Pointer<Utf8> passphrase, bool signStake, int accountIndex, int addressIndex, bool useIcarus);

typedef _CardanoSignTxV2C = Pointer<Utf8> Function(Pointer<Utf8> cborHex, Pointer<Utf8> mnemonic, Pointer<Utf8> passphrase, Bool signStake, Uint32 accountIndex, Uint32 addressIndex, Bool isTestnet, Bool useIcarus);
typedef _CardanoSignTxV2Dart = Pointer<Utf8> Function(Pointer<Utf8> cborHex, Pointer<Utf8> mnemonic, Pointer<Utf8> passphrase, bool signStake, int accountIndex, int addressIndex, bool isTestnet, bool useIcarus);

typedef _CardanoVerifySignedTxC = Pointer<Utf8> Function(Pointer<Utf8> signedCborHex);
typedef _CardanoVerifySignedTxDart = Pointer<Utf8> Function(Pointer<Utf8> signedCborHex);

typedef _CardanoVerifyChangeC = Pointer<Utf8> Function(Pointer<Utf8> changeAddr, Pointer<Utf8> accountXpubHex, Bool isTestnet);
typedef _CardanoVerifyChangeDart = Pointer<Utf8> Function(Pointer<Utf8> changeAddr, Pointer<Utf8> accountXpubHex, bool isTestnet);

typedef _CardanoSampleTxC = Pointer<Utf8> Function(Pointer<Utf8> recipientAddr, Uint64 sendLovelace, Uint64 feeLovelace);
typedef _CardanoSampleTxDart = Pointer<Utf8> Function(Pointer<Utf8> recipientAddr, int sendLovelace, int feeLovelace);

typedef _CardanoFreeStrC = Void Function(Pointer<Utf8> ptr);
typedef _CardanoFreeStrDart = void Function(Pointer<Utf8> ptr);

class CardanoCoreBridge {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  /// Ghi đè toàn bộ vùng nhớ C-Heap chứa dữ liệu nhạy cảm bằng 0x00 trước khi giải phóng (Zeroization)
  static void _secureFreeUtf8(Pointer<Utf8> ptr, [int? knownByteLen]) {
    if (ptr == nullptr) return;
    try {
      final len = knownByteLen ?? ptr.length;
      final bytePtr = ptr.cast<Uint8>();
      for (int i = 0; i < len; i++) {
        bytePtr[i] = 0;
      }
    } catch (_) {}
    malloc.free(ptr);
  }

  static void init([String? customPath]) {
    if (_initialized && _lib != null) return;

    if (customPath != null && File(customPath).existsSync()) {
      _lib = DynamicLibrary.open(customPath);
      _initialized = true;
      return;
    }

    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      String? scriptDir;
      try {
        scriptDir = File(Platform.script.toFilePath()).parent.path;
      } catch (_) {}
      final cwd = Directory.current.path;

      final possiblePaths = [
        // 1. Thư mục chứa tệp thực thi ứng dụng (An toàn cao nhất)
        '$exeDir\\rust_cardano_core.dll',
        // 2. Thư mục làm việc hiện tại của tiến trình
        '$cwd\\rust_cardano_core.dll',
        if (scriptDir != null) '$scriptDir\\rust_cardano_core.dll',
        '$cwd\\rust_cardano_core\\target\\release\\rust_cardano_core.dll',
        // 3. Vị trí build artifact chính thức
        'E:\\Antigravity\\2. Tạo ví Cardano v2.0\\rust_cardano_core.dll',
        'E:\\cargo_target\\release\\rust_cardano_core.dll',
      ];
      for (final p in possiblePaths) {
        if (File(p).existsSync()) {
          try {
            _lib = DynamicLibrary.open(p);
            _initialized = true;
            return;
          } catch (_) {}
        }
      }
    } else if (Platform.isAndroid) {
      try {
        _lib = DynamicLibrary.open('librust_cardano_core.so');
        _initialized = true;
        return;
      } catch (_) {}
    } else if (Platform.isIOS || Platform.isMacOS) {
      try {
        _lib = DynamicLibrary.process();
        _initialized = true;
        return;
      } catch (_) {}
    }
  }

  static bool get isNativeAvailable {
    if (!_initialized) init();
    return _lib != null;
  }

  static String generateMnemonic(int wordCount) {
    init();
    if (_lib != null) {
      final fn = _lib!.lookupFunction<_CardanoGenMnemonicC, _CardanoGenMnemonicDart>('cardano_core_generate_mnemonic');
      final freeFn = _lib!.lookupFunction<_CardanoFreeStrC, _CardanoFreeStrDart>('cardano_core_free_string');
      final ptr = fn(wordCount);
      final jsonStr = ptr.toDartString();
      freeFn(ptr);
      final map = jsonDecode(jsonStr);
      if (map['success'] == true) {
        return map['data'] as String;
      } else {
        throw Exception(map['error']);
      }
    }
    // Fallback Pure-Dart BIP-39 cho thiết bị 32-bit (armeabi-v7a) và môi trường không có C-FFI
    return Bip39Pure.generateMnemonic(wordCount);
  }

  static bool validateMnemonic(String phrase) {
    init();
    if (_lib != null) {
      final fn = _lib!.lookupFunction<_CardanoValMnemonicC, _CardanoValMnemonicDart>('cardano_core_validate_mnemonic');
      final pPhrase = phrase.toNativeUtf8();
      try {
        return fn(pPhrase);
      } finally {
        _secureFreeUtf8(pPhrase);
      }
    }
    // Fallback Pure-Dart BIP-39
    return Bip39Pure.validateMnemonic(phrase);
  }

  static WalletKeysInfo createWallet(
    String phrase, {
    String passphrase = '',
    bool isTestnet = true,
    int accountIndex = 0,
    int addressIndex = 0,
    bool useIcarus = false,
  }) {
    init();
    if (_lib != null) {
      final freeFn = _lib!.lookupFunction<_CardanoFreeStrC, _CardanoFreeStrDart>('cardano_core_free_string');
      final pPhrase = phrase.toNativeUtf8();
      final pPass = passphrase.toNativeUtf8();
      Pointer<Utf8> ptr = nullptr;
      String jsonStr = '';

      try {
        try {
          final fnExt = _lib!.lookupFunction<_CardanoCreateWalletExtC, _CardanoCreateWalletExtDart>('cardano_core_create_wallet_ext');
          ptr = fnExt(pPhrase, pPass, isTestnet, accountIndex, addressIndex, useIcarus);
        } catch (_) {
          final fn = _lib!.lookupFunction<_CardanoCreateWalletC, _CardanoCreateWalletDart>('cardano_core_create_wallet');
          ptr = fn(pPhrase, pPass, isTestnet, accountIndex, addressIndex);
        }
        jsonStr = ptr.toDartString();
      } finally {
        if (ptr != nullptr) freeFn(ptr);
        _secureFreeUtf8(pPhrase);
        _secureFreeUtf8(pPass);
      }

      final map = jsonDecode(jsonStr);
      if (map['success'] == true) {
        return WalletKeysInfo.fromJson(map['data'] as Map<String, dynamic>);
      } else {
        throw Exception(map['error']);
      }
    }
    // Fallback Pure-Dart Cardano CIP-1852 Derivation cho thiet bi 32-bit (armeabi-v7a)
    return CardanoPure.createWallet(
      phrase,
      passphrase: passphrase,
      isTestnet: isTestnet,
      accountIndex: accountIndex,
      addressIndex: addressIndex,
      useIcarus: useIcarus,
    );
  }

  static ParsedTransaction parseTransaction(String cborHex, {String? accountXpubHex, bool isTestnet = true}) {
    init();
    if (_lib != null) {
      final fn = _lib!.lookupFunction<_CardanoParseTxC, _CardanoParseTxDart>('cardano_core_parse_transaction');
      final freeFn = _lib!.lookupFunction<_CardanoFreeStrC, _CardanoFreeStrDart>('cardano_core_free_string');
      final pCbor = cborHex.toNativeUtf8();
      final pXpub = (accountXpubHex ?? '').toNativeUtf8();
      Pointer<Utf8> ptr = nullptr;
      String jsonStr = '';
      try {
        ptr = fn(pCbor, pXpub, isTestnet);
        jsonStr = ptr.toDartString();
      } finally {
        if (ptr != nullptr) freeFn(ptr);
        _secureFreeUtf8(pCbor);
        _secureFreeUtf8(pXpub);
      }

      final map = jsonDecode(jsonStr);
      if (map['success'] == true) {
        return ParsedTransaction.fromJson(map['data'] as Map<String, dynamic>);
      } else {
        throw Exception(map['error']);
      }
    }
    throw UnimplementedError('Native library not loaded for parseTransaction');
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
    init();
    if (_lib != null) {
      final freeFn = _lib!.lookupFunction<_CardanoFreeStrC, _CardanoFreeStrDart>('cardano_core_free_string');
      final pCbor = cborHex.toNativeUtf8();
      final pPhrase = mnemonic.toNativeUtf8();
      final pPass = passphrase.toNativeUtf8();
      Pointer<Utf8> ptr = nullptr;
      String jsonStr = '';
      try {
        try {
          final fnV2 = _lib!.lookupFunction<_CardanoSignTxV2C, _CardanoSignTxV2Dart>('cardano_core_sign_transaction_v2');
          ptr = fnV2(pCbor, pPhrase, pPass, signStake, accountIndex, addressIndex, isTestnet, useIcarus);
        } catch (_) {
          try {
            final fnExt = _lib!.lookupFunction<_CardanoSignTxExtC, _CardanoSignTxExtDart>('cardano_core_sign_transaction_ext');
            ptr = fnExt(pCbor, pPhrase, pPass, signStake, accountIndex, addressIndex, useIcarus);
          } catch (_) {
            final fn = _lib!.lookupFunction<_CardanoSignTxC, _CardanoSignTxDart>('cardano_core_sign_transaction');
            ptr = fn(pCbor, pPhrase, pPass, signStake, accountIndex, addressIndex);
          }
        }
        jsonStr = ptr.toDartString();
      } finally {
        if (ptr != nullptr) freeFn(ptr);
        _secureFreeUtf8(pCbor);
        _secureFreeUtf8(pPhrase);
        _secureFreeUtf8(pPass);
      }

      final map = jsonDecode(jsonStr);
      if (map['success'] == true) {
        return map['data'] as String;
      } else {
        throw Exception(map['error']);
      }
    }
    throw UnimplementedError('Native library not loaded for signTransaction');
  }

  static bool verifySignedTransaction(String signedCborHex) {
    init();
    if (_lib != null) {
      final fn = _lib!.lookupFunction<_CardanoVerifySignedTxC, _CardanoVerifySignedTxDart>('cardano_core_verify_signed_tx');
      final freeFn = _lib!.lookupFunction<_CardanoFreeStrC, _CardanoFreeStrDart>('cardano_core_free_string');
      final pSigned = signedCborHex.toNativeUtf8();
      Pointer<Utf8> ptr = nullptr;
      String jsonStr = '';
      try {
        ptr = fn(pSigned);
        jsonStr = ptr.toDartString();
      } finally {
        if (ptr != nullptr) freeFn(ptr);
        _secureFreeUtf8(pSigned);
      }

      final map = jsonDecode(jsonStr);
      if (map['success'] == true) {
        return map['data'] as bool;
      } else {
        return false;
      }
    }
    return false;
  }

  static bool verifyChange(String changeAddress, String accountXpubHex, {bool isTestnet = true}) {
    init();
    if (_lib != null) {
      final fn = _lib!.lookupFunction<_CardanoVerifyChangeC, _CardanoVerifyChangeDart>('cardano_core_verify_change');
      final freeFn = _lib!.lookupFunction<_CardanoFreeStrC, _CardanoFreeStrDart>('cardano_core_free_string');
      final pAddr = changeAddress.toNativeUtf8();
      final pXpub = accountXpubHex.toNativeUtf8();
      Pointer<Utf8> ptr = nullptr;
      String jsonStr = '';
      try {
        ptr = fn(pAddr, pXpub, isTestnet);
        jsonStr = ptr.toDartString();
      } finally {
        if (ptr != nullptr) freeFn(ptr);
        _secureFreeUtf8(pAddr);
        _secureFreeUtf8(pXpub);
      }

      final map = jsonDecode(jsonStr);
      if (map['success'] == true) {
        return map['data'] as bool;
      } else {
        return false;
      }
    }
    return false;
  }

  static String createSampleConwayTx(String recipientAddress, int sendLovelace, int feeLovelace) {
    init();
    if (_lib != null) {
      final fn = _lib!.lookupFunction<_CardanoSampleTxC, _CardanoSampleTxDart>('cardano_core_create_sample_conway_tx');
      final freeFn = _lib!.lookupFunction<_CardanoFreeStrC, _CardanoFreeStrDart>('cardano_core_free_string');
      final pAddr = recipientAddress.toNativeUtf8();
      Pointer<Utf8> ptr = nullptr;
      String jsonStr = '';
      try {
        ptr = fn(pAddr, sendLovelace, feeLovelace);
        jsonStr = ptr.toDartString();
      } finally {
        if (ptr != nullptr) freeFn(ptr);
        _secureFreeUtf8(pAddr);
      }

      final map = jsonDecode(jsonStr);
      if (map['success'] == true) {
        return map['data'] as String;
      } else {
        throw Exception(map['error']);
      }
    }
    throw UnimplementedError('Native library not loaded for createSampleConwayTx');
  }
}
