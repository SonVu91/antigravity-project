import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_online/core/network/blockfrost_client.dart';
import 'package:mobile_online/core/utils/cardanoscan_helper.dart';

void main() {
  group('CardanoscanHelper Tests', () {
    const testMainnetAddr = 'addr1qxy246f90m3h787n4w884h4fcmwcfw47e9y76k403p9p3f2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qs9x26r';
    const testPreprodAddr = 'addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73';
    const testTxId = '64a0e5b1285474b76c8c9f50e7b78912ef54876b5f4c3a2b109876543210abcd';
    const testPoolId = 'pool10hex9l4wjgqarvhr94xgyh9frv5lhtajhrj4dah0kl65jtws30k';

    test('Generates correct base URLs for Mainnet, Preprod, and Preview', () {
      expect(CardanoscanHelper.getBaseUrl(CardanoNetwork.mainnet), equals('https://cardanoscan.io'));
      expect(CardanoscanHelper.getBaseUrl(CardanoNetwork.preprod), equals('https://preprod.cardanoscan.io'));
      expect(CardanoscanHelper.getBaseUrl(CardanoNetwork.preview), equals('https://preview.cardanoscan.io'));
    });

    test('Generates correct address URLs for Mainnet and Preprod', () {
      expect(
        CardanoscanHelper.getAddressUrl(CardanoNetwork.mainnet, testMainnetAddr),
        equals('https://cardanoscan.io/address/$testMainnetAddr'),
      );
      expect(
        CardanoscanHelper.getAddressUrl(CardanoNetwork.preprod, testPreprodAddr),
        equals('https://preprod.cardanoscan.io/address/$testPreprodAddr'),
      );
    });

    test('Generates correct transaction URLs', () {
      expect(
        CardanoscanHelper.getTxUrl(CardanoNetwork.mainnet, testTxId),
        equals('https://cardanoscan.io/transaction/$testTxId'),
      );
      expect(
        CardanoscanHelper.getTxUrl(CardanoNetwork.preprod, testTxId),
        equals('https://preprod.cardanoscan.io/transaction/$testTxId'),
      );
    });

    test('Generates correct pool and drep URLs', () {
      expect(
        CardanoscanHelper.getPoolUrl(CardanoNetwork.preprod, testPoolId),
        equals('https://preprod.cardanoscan.io/pool/$testPoolId'),
      );
      expect(
        CardanoscanHelper.getDRepUrl(CardanoNetwork.mainnet, 'drep1xgzlpyy3pvywm5wvhkvyz9cpga5wylme6wdu6l9vn5g6cp38jdj'),
        equals('https://cardanoscan.io/drep/drep1xgzlpyy3pvywm5wvhkvyz9cpga5wylme6wdu6l9vn5g6cp38jdj'),
      );
    });
  });
}
