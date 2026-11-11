import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'models.dart';
import 'bip39_pure.dart';

/// Pure-Dart Cardano CIP-1852 Cryptographic Engine
/// Hoạt động 100% độc lập không phụ thuộc thư viện native C-FFI,
/// tương thích hoàn hảo cho điện thoại Android 32-bit (armeabi-v7a) và 64-bit.
class CardanoPure {
  /// Sinh thông tin ví CIP-1852 hoàn chỉnh từ Mnemonic
  static WalletKeysInfo createWallet(
    String phrase, {
    String passphrase = '',
    bool isTestnet = true,
    int accountIndex = 0,
    int addressIndex = 0,
    bool useIcarus = false,
  }) {
    final seed = _mnemonicToSeed(phrase, passphrase);
    final rootKey = _deriveRootKey(seed);

    final accountKey = _deriveAccountKey(rootKey, accountIndex);
    final paymentKey = _derivePaymentKey(accountKey, addressIndex);
    final stakeKey = _deriveStakeKey(accountKey, 0);

    final paymentVkey = _toPublicKey(paymentKey.sublist(0, 32));
    final stakeVkey = _toPublicKey(stakeKey.sublist(0, 32));

    final paymentAddr = _buildBaseAddress(paymentVkey, stakeVkey, isTestnet);
    final stakeAddr = _buildStakeAddress(stakeVkey, isTestnet);

    final accountPub = _toPublicKey(accountKey.sublist(0, 32));
    final accountChainCode = accountKey.sublist(64, 96);
    final accountXpubHex = _toHex(Uint8List.fromList([...accountPub, ...accountChainCode]));

    final derivationPath = "m/1852'/1815'/$accountIndex'/0/$addressIndex";

    return WalletKeysInfo(
      mnemonic: phrase,
      paymentAddress: paymentAddr,
      stakeAddress: stakeAddr,
      accountXpubHex: accountXpubHex,
      accountIndex: accountIndex,
      addressIndex: addressIndex,
      derivationPath: derivationPath,
    );
  }

  /// PBKDF2-HMAC-SHA512: 2048 vòng lặp tạo 64-byte seed
  static Uint8List _mnemonicToSeed(String phrase, String passphrase) {
    final passBytes = utf8.encode(phrase.trim());
    final saltBytes = utf8.encode('mnemonic$passphrase');
    return _pbkdf2HmacSha512(passBytes, saltBytes, 2048, 64);
  }

  /// Root Key derivation theo chuẩn BIP39 entropy seed
  static Uint8List _deriveRootKey(Uint8List seed) {
    final hmac = _hmacSha512(utf8.encode('ed25519 seed'), seed.sublist(0, 32));
    final kL = Uint8List.fromList(hmac.sublist(0, 32));
    final kR = Uint8List.fromList(hmac.sublist(32, 64));

    // Clamping Ed25519
    kL[0] &= 248;
    kL[31] &= 127;
    kL[31] |= 64;

    // Root key: 64 bytes private key (kL + kR) + 32 bytes chaincode
    final secondHmac = _hmacSha512(utf8.encode('ed25519 seed'), seed.sublist(32, 64));
    final chainCode = secondHmac.sublist(32, 64);

    return Uint8List.fromList([...kL, ...kR, ...chainCode]);
  }

  /// Dẫn xuất Account Key m/1852'/1815'/account' (Hardened >= 2^31)
  static Uint8List _deriveAccountKey(Uint8List root, int accountIndex) {
    final purpose = 1852 | 0x80000000;
    final coinType = 1815 | 0x80000000;
    final account = accountIndex | 0x80000000;

    var cur = _deriveHardenedChild(root, purpose);
    cur = _deriveHardenedChild(cur, coinType);
    return _deriveHardenedChild(cur, account);
  }

  /// Dẫn xuất Payment Key m/1852'/1815'/account'/0/index
  static Uint8List _derivePaymentKey(Uint8List account, int index) {
    final role = _deriveNonHardenedChild(account, 0);
    return _deriveNonHardenedChild(role, index);
  }

  /// Dẫn xuất Stake Key m/1852'/1815'/account'/2/0
  static Uint8List _deriveStakeKey(Uint8List account, int index) {
    final role = _deriveNonHardenedChild(account, 2);
    return _deriveNonHardenedChild(role, index);
  }

  /// Hardened child derivation (BIP32-Ed25519)
  static Uint8List _deriveHardenedChild(Uint8List parent, int index) {
    final chainCode = parent.sublist(64, 96);
    final idxBytes = ByteData(4)..setUint32(0, index, Endian.little);
    
    final data = Uint8List.fromList([0x00, ...parent.sublist(0, 64), ...idxBytes.buffer.asUint8List()]);
    final z = _hmacSha512(chainCode, data);

    final dataCc = Uint8List.fromList([0x01, ...parent.sublist(0, 64), ...idxBytes.buffer.asUint8List()]);
    final nextCc = _hmacSha512(chainCode, dataCc).sublist(32, 64);

    final childKl = _addScalars(parent.sublist(0, 32), z.sublist(0, 32));
    final childKr = _addScalars(parent.sublist(32, 64), z.sublist(32, 64));

    return Uint8List.fromList([...childKl, ...childKr, ...nextCc]);
  }

  /// Non-hardened child derivation
  static Uint8List _deriveNonHardenedChild(Uint8List parent, int index) {
    final chainCode = parent.sublist(64, 96);
    final pub = _toPublicKey(parent.sublist(0, 32));
    final idxBytes = ByteData(4)..setUint32(0, index, Endian.little);

    final data = Uint8List.fromList([0x02, ...pub, ...idxBytes.buffer.asUint8List()]);
    final z = _hmacSha512(chainCode, data);

    final dataCc = Uint8List.fromList([0x03, ...pub, ...idxBytes.buffer.asUint8List()]);
    final nextCc = _hmacSha512(chainCode, dataCc).sublist(32, 64);

    final childKl = _addScalars(parent.sublist(0, 32), z.sublist(0, 32));
    final childKr = _addScalars(parent.sublist(32, 64), z.sublist(32, 64));

    return Uint8List.fromList([...childKl, ...childKr, ...nextCc]);
  }

  /// Cộng hai vô hướng (Scalar addition mod 2^256)
  static Uint8List _addScalars(Uint8List a, Uint8List b) {
    final res = Uint8List(32);
    int carry = 0;
    for (int i = 0; i < 32; i++) {
      final sum = a[i] + b[i] + carry;
      res[i] = sum & 0xFF;
      carry = sum >> 8;
    }
    return res;
  }

  /// Tính Public Key từ 32-byte Ed25519 private scalar
  static Uint8List _toPublicKey(Uint8List scalar) {
    final k = _bytesToBigIntLE(scalar);
    final pt = _edwardsMul(k, _basePoint);
    return _pointToBytes(pt);
  }

  /// Base Address: 0x00 (testnet) / 0x01 (mainnet) + payment_hash (28B) + stake_hash (28B)
  static String _buildBaseAddress(Uint8List paymentVkey, Uint8List stakeVkey, bool isTestnet) {
    final payHash = _blake2b224(paymentVkey);
    final stakeHash = _blake2b224(stakeVkey);
    final header = isTestnet ? 0x00 : 0x01;
    final payload = Uint8List.fromList([header, ...payHash, ...stakeHash]);
    final hrp = isTestnet ? 'addr_test' : 'addr';
    return _bech32Encode(hrp, payload);
  }

  /// Stake Reward Address: 0xe0 (testnet) / 0xe1 (mainnet) + stake_hash (28B)
  static String _buildStakeAddress(Uint8List stakeVkey, bool isTestnet) {
    final stakeHash = _blake2b224(stakeVkey);
    final header = isTestnet ? 0xe0 : 0xe1;
    final payload = Uint8List.fromList([header, ...stakeHash]);
    final hrp = isTestnet ? 'stake_test' : 'stake';
    return _bech32Encode(hrp, payload);
  }

  // --- CRYPTO PRIMITIVES (Pure-Dart) ---

  static final BigInt _p = (BigInt.one << 255) - BigInt.from(19);
  static final BigInt _d = (-BigInt.from(121665) * _modInverse(BigInt.from(121666), _p)) % _p;
  static final List<BigInt> _basePoint = [
    BigInt.parse('1511222244956363773229892709888804241697308952701886643585534125895840079088'),
    (BigInt.from(4) * _modInverse(BigInt.from(5), _p)) % _p
  ];

  static BigInt _modInverse(BigInt a, BigInt m) => a.modInverse(m);

  static List<BigInt> _edwardsAdd(List<BigInt> p1, List<BigInt> p2) {
    final x1 = p1[0], y1 = p1[1];
    final x2 = p2[0], y2 = p2[1];
    final common = (_d * x1 * x2 * y1 * y2) % _p;
    final x3 = ((x1 * y2 + x2 * y1) * _modInverse((BigInt.one + common) % _p, _p)) % _p;
    final y3 = ((y1 * y2 + x1 * x2) * _modInverse((BigInt.one - common) % _p, _p)) % _p;
    return [(x3 + _p) % _p, (y3 + _p) % _p];
  }

  static List<BigInt> _edwardsMul(BigInt k, List<BigInt> pt) {
    var res = [BigInt.zero, BigInt.one];
    var cur = pt;
    var scalar = k;
    while (scalar > BigInt.zero) {
      if ((scalar & BigInt.one) == BigInt.one) {
        res = _edwardsAdd(res, cur);
      }
      cur = _edwardsAdd(cur, cur);
      scalar >>= 1;
    }
    return res;
  }

  static Uint8List _pointToBytes(List<BigInt> pt) {
    final y = pt[1];
    final bytes = _bigIntToBytesLE(y, 32);
    if ((pt[0] & BigInt.one) == BigInt.one) {
      bytes[31] |= 0x80;
    }
    return bytes;
  }

  static BigInt _bytesToBigIntLE(Uint8List bytes) {
    var res = BigInt.zero;
    for (int i = bytes.length - 1; i >= 0; i--) {
      res = (res << 8) | BigInt.from(bytes[i]);
    }
    return res;
  }

  static Uint8List _bigIntToBytesLE(BigInt val, int length) {
    final res = Uint8List(length);
    var cur = val;
    for (int i = 0; i < length; i++) {
      res[i] = (cur & BigInt.from(0xFF)).toInt();
      cur >>= 8;
    }
    return res;
  }

  static Uint8List _hmacSha512(List<int> key, List<int> data) {
    const blockSize = 128;
    var k = Uint8List.fromList(key);
    if (k.length > blockSize) {
      k = _sha512(k);
    }
    if (k.length < blockSize) {
      final padded = Uint8List(blockSize);
      padded.setRange(0, k.length, k);
      k = padded;
    }

    final oKeyPad = Uint8List(blockSize);
    final iKeyPad = Uint8List(blockSize);
    for (int i = 0; i < blockSize; i++) {
      oKeyPad[i] = k[i] ^ 0x5c;
      iKeyPad[i] = k[i] ^ 0x36;
    }

    final inner = _sha512(Uint8List.fromList([...iKeyPad, ...data]));
    return _sha512(Uint8List.fromList([...oKeyPad, ...inner]));
  }

  static Uint8List _pbkdf2HmacSha512(List<int> password, List<int> salt, int iterations, int keyLength) {
    final numBlocks = (keyLength + 63) ~/ 64;
    final out = Uint8List(keyLength);
    var offset = 0;

    for (int block = 1; block <= numBlocks; block++) {
      final blockBytes = ByteData(4)..setUint32(0, block, Endian.big);
      var u = _hmacSha512(password, [...salt, ...blockBytes.buffer.asUint8List()]);
      final t = Uint8List.fromList(u);

      for (int i = 1; i < iterations; i++) {
        u = _hmacSha512(password, u);
        for (int j = 0; j < 64; j++) {
          t[j] ^= u[j];
        }
      }

      final copyLen = min(64, keyLength - offset);
      out.setRange(offset, offset + copyLen, t.sublist(0, copyLen));
      offset += copyLen;
    }

    return out;
  }

  /// Pure-Dart SHA-512 (FIPS 180-4)
  static Uint8List _sha512(Uint8List data) {
    final bitLen = BigInt.from(data.length) * BigInt.from(8);
    final padLen = (data.length % 128 < 112) ? (112 - data.length % 128) : (240 - data.length % 128);
    final padded = Uint8List(data.length + padLen + 16);
    padded.setRange(0, data.length, data);
    padded[data.length] = 0x80;

    // Append 128-bit big-endian length
    var curLen = bitLen;
    for (int i = 0; i < 16; i++) {
      padded[padded.length - 1 - i] = (curLen & BigInt.from(0xFF)).toInt();
      curLen >>= 8;
    }

    const k = [
      0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
      0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
      0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
      0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
      0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
      0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
      0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
      0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
      0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42a9f, 0x53380d139d95b3df,
      0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47867871, 0x92722c851482353b,
      0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
      0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
      0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
      0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
      0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
      0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
      0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
      0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
      0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
      0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817
    ];

    var h = [
      0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
      0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179
    ];

    final bd = ByteData.view(padded.buffer);
    final w = List<int>.filled(80, 0);

    for (int chunk = 0; chunk < padded.length; chunk += 128) {
      for (int i = 0; i < 16; i++) {
        w[i] = bd.getUint64(chunk + i * 8, Endian.big);
      }
      for (int i = 16; i < 80; i++) {
        final s0 = _rotr64(w[i - 15], 1) ^ _rotr64(w[i - 15], 8) ^ (w[i - 15] >>> 7);
        final s1 = _rotr64(w[i - 2], 19) ^ _rotr64(w[i - 2], 61) ^ (w[i - 2] >>> 6);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFFFFFFFFFF;
      }

      var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hVal = h[7];

      for (int i = 0; i < 80; i++) {
        final s1 = _rotr64(e, 14) ^ _rotr64(e, 18) ^ _rotr64(e, 41);
        final ch = (e & f) ^ (~e & g);
        final t1 = (hVal + s1 + ch + k[i] + w[i]) & 0xFFFFFFFFFFFFFFFF;
        final s0 = _rotr64(a, 28) ^ _rotr64(a, 34) ^ _rotr64(a, 39);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final t2 = (s0 + maj) & 0xFFFFFFFFFFFFFFFF;

        hVal = g;
        g = f;
        f = e;
        e = (d + t1) & 0xFFFFFFFFFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (t1 + t2) & 0xFFFFFFFFFFFFFFFF;
      }

      h[0] = (h[0] + a) & 0xFFFFFFFFFFFFFFFF;
      h[1] = (h[1] + b) & 0xFFFFFFFFFFFFFFFF;
      h[2] = (h[2] + c) & 0xFFFFFFFFFFFFFFFF;
      h[3] = (h[3] + d) & 0xFFFFFFFFFFFFFFFF;
      h[4] = (h[4] + e) & 0xFFFFFFFFFFFFFFFF;
      h[5] = (h[5] + f) & 0xFFFFFFFFFFFFFFFF;
      h[6] = (h[6] + g) & 0xFFFFFFFFFFFFFFFF;
      h[7] = (h[7] + hVal) & 0xFFFFFFFFFFFFFFFF;
    }

    final res = Uint8List(64);
    final resBd = ByteData.view(res.buffer);
    for (int i = 0; i < 8; i++) {
      resBd.setUint64(i * 8, h[i], Endian.big);
    }
    return res;
  }

  static int _rotr64(int x, int n) => ((x >>> n) | (x << (64 - n))) & 0xFFFFFFFFFFFFFFFF;

  /// Pure-Dart Blake2b-224 (28 bytes output digest)
  static Uint8List _blake2b224(Uint8List data) {
    const iv = [
      0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
      0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179
    ];
    const sigma = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
      [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
      [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
      [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
      [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
      [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
      [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
      [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
      [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0],
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3]
    ];

    var h = List<int>.from(iv);
    // Parameter block: digest length = 28 (0x1c)
    h[0] ^= 0x01010000 ^ 28;

    final blockLen = 128;
    int offset = 0;
    int remaining = data.length;
    var t0 = 0;
    var f0 = 0;

    while (remaining > blockLen) {
      t0 += blockLen;
      final m = _bytesToUint64ListLE(data.sublist(offset, offset + blockLen));
      h = _compressBlake2b(h, m, t0, 0, f0, 0, sigma, iv);
      offset += blockLen;
      remaining -= blockLen;
    }

    t0 += remaining;
    f0 = 0xFFFFFFFFFFFFFFFF;
    final lastBlock = Uint8List(blockLen);
    lastBlock.setRange(0, remaining, data.sublist(offset));
    final m = _bytesToUint64ListLE(lastBlock);
    h = _compressBlake2b(h, m, t0, 0, f0, 0, sigma, iv);

    final out = Uint8List(28);
    final outBd = ByteData.view(out.buffer);
    for (int i = 0; i < 3; i++) {
      outBd.setUint64(i * 8, h[i], Endian.little);
    }
    // Last 4 bytes
    final lastWord = ByteData(8)..setUint64(0, h[3], Endian.little);
    out.setRange(24, 28, lastWord.buffer.asUint8List().sublist(0, 4));
    return out;
  }

  static List<int> _bytesToUint64ListLE(Uint8List bytes) {
    final res = List<int>.filled(16, 0);
    final bd = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    for (int i = 0; i < 16; i++) {
      res[i] = bd.getUint64(i * 8, Endian.little);
    }
    return res;
  }

  static List<int> _compressBlake2b(
    List<int> h, List<int> m, int t0, int t1, int f0, int f1, List<List<int>> sigma, List<int> iv
  ) {
    final v = List<int>.filled(16, 0);
    for (int i = 0; i < 8; i++) v[i] = h[i];
    v[8] = iv[0]; v[9] = iv[1]; v[10] = iv[2]; v[11] = iv[3];
    v[12] = iv[4] ^ t0; v[13] = iv[5] ^ t1; v[14] = iv[6] ^ f0; v[15] = iv[7] ^ f1;

    void g(int a, int b, int c, int d, int x, int y) {
      v[a] = (v[a] + v[b] + x) & 0xFFFFFFFFFFFFFFFF;
      v[d] = _rotr64(v[d] ^ v[a], 32);
      v[c] = (v[c] + v[d]) & 0xFFFFFFFFFFFFFFFF;
      v[b] = _rotr64(v[b] ^ v[c], 24);
      v[a] = (v[a] + v[b] + y) & 0xFFFFFFFFFFFFFFFF;
      v[d] = _rotr64(v[d] ^ v[a], 16);
      v[c] = (v[c] + v[d]) & 0xFFFFFFFFFFFFFFFF;
      v[b] = _rotr64(v[b] ^ v[c], 63);
    }

    for (int round = 0; round < 12; round++) {
      final s = sigma[round];
      g(0, 4, 8, 12, m[s[0]], m[s[1]]);
      g(1, 5, 9, 13, m[s[2]], m[s[3]]);
      g(2, 6, 10, 14, m[s[4]], m[s[5]]);
      g(3, 7, 11, 15, m[s[6]], m[s[7]]);
      g(0, 5, 10, 15, m[s[8]], m[s[9]]);
      g(1, 6, 11, 12, m[s[10]], m[s[11]]);
      g(2, 7, 8, 13, m[s[12]], m[s[13]]);
      g(3, 4, 9, 14, m[s[14]], m[s[15]]);
    }

    final newH = List<int>.filled(8, 0);
    for (int i = 0; i < 8; i++) {
      newH[i] = h[i] ^ v[i] ^ v[i + 8];
    }
    return newH;
  }

  /// Bech32 Encoding (BIP-0173)
  static String _bech32Encode(String hrp, Uint8List data) {
    final values = _convertBits(data, 8, 5, true);
    final checksum = _createChecksum(hrp, values);
    final combined = [...values, ...checksum];
    const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final sb = StringBuffer(hrp)..write('1');
    for (final v in combined) {
      sb.write(charset[v]);
    }
    return sb.toString();
  }

  static List<int> _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    int acc = 0;
    int bits = 0;
    final ret = <int>[];
    final maxv = (1 << toBits) - 1;
    for (final value in data) {
      acc = (acc << fromBits) | value;
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
    }
    return ret;
  }

  static List<int> _createChecksum(String hrp, List<int> values) {
    final hrpExpanded = _hrpExpand(hrp);
    final enc = [...hrpExpanded, ...values, 0, 0, 0, 0, 0, 0];
    final mod = _polymod(enc) ^ 1;
    final ret = <int>[];
    for (int p = 0; p < 6; ++p) {
      ret.add((mod >> (5 * (5 - p))) & 31);
    }
    return ret;
  }

  static List<int> _hrpExpand(String hrp) {
    final ret = <int>[];
    for (int i = 0; i < hrp.length; i++) {
      ret.add(hrp.codeUnitAt(i) >> 5);
    }
    ret.add(0);
    for (int i = 0; i < hrp.length; i++) {
      ret.add(hrp.codeUnitAt(i) & 31);
    }
    return ret;
  }

  static int _polymod(List<int> values) {
    int chk = 1;
    for (final value in values) {
      final top = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ value;
      if ((top & 1) != 0) chk ^= 0x3b6a57b2;
      if ((top & 2) != 0) chk ^= 0x26508e6d;
      if ((top & 4) != 0) chk ^= 0x1ea119fa;
      if ((top & 8) != 0) chk ^= 0x3d4233dd;
      if ((top & 16) != 0) chk ^= 0x2a1462b3;
    }
    return chk;
  }

  static String _toHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
