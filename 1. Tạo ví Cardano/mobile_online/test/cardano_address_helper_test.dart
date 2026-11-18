import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_online/core/network/cardano_address_helper.dart';

void main() {
  group('CardanoAddressHelper Tests', () {
    test('Derive stake address from testnet base address', () {
      const testnetBaseAddr =
          'addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73';
      final stakeAddr = CardanoAddressHelper.deriveStakeAddress(testnetBaseAddr);
      expect(stakeAddr, isNotNull);
      expect(stakeAddr!.startsWith('stake_test1'), isTrue);
    });

    test('Derive stake address returns itself if already a stake address', () {
      const stakeAddr = 'stake_test1uqz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzerq59p8l';
      expect(CardanoAddressHelper.deriveStakeAddress(stakeAddr), equals(stakeAddr));
    });

    test('FIMI Pool ID decoding and normalization', () {
      const fimiPool = 'pool1rct5guwnp6nk9f4ldn5tr3s42j0nm5rxeayv56lxua5ck47ex39';
      final bytes = CardanoAddressHelper.poolIdToBytes(fimiPool);
      expect(bytes, isNotNull);
      expect(bytes!.length, equals(28));

      final normalized = CardanoAddressHelper.normalizePoolIdToBech32(fimiPool);
      expect(normalized, equals(fimiPool));
    });

    test('FIMI DRep ID decoding and normalization', () {
      const fimiDRep = 'drep1xgzlpyy3pvywm5wvhkvyz9cpga5wylme6wdu6l9vn5g6cp38jdj';
      final bytes = CardanoAddressHelper.drepIdToBytes(fimiDRep);
      expect(bytes, isNotNull);
      expect(bytes!.length, equals(28));

      final normalized = CardanoAddressHelper.normalizeDrepIdToBech32(fimiDRep);
      expect(normalized, equals(fimiDRep));
    });
  });
}
