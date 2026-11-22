import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_online/core/network/blockfrost_client.dart';
import 'package:mobile_online/core/network/cardano_address_helper.dart';
import 'package:mobile_online/core/tx/tx_builder.dart';

void main() {
  group('Multi-Branch UTXO Discovery & DRep Conway Withdrawal Tests', () {
    const testPaymentAddress =
        "addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73";
    const testStakeAddress =
        "stake_test1upxuru4u5twhwjxq5na0xtczckl85fgyxhplnn4jdmqrsaqm46y5m";

    test('BlockfrostClient: getAllAccountUtxos queries payment address and aggregates UTXOs', () async {
      final client = BlockfrostClient(
        customApiKey: "preprodDemoApiKey1234567890",
        allowMockFallback: true,
      );

      final utxos = await client.getAllAccountUtxos(
        testPaymentAddress,
        stakeAddress: testStakeAddress,
      );

      expect(utxos, isNotEmpty);
      expect(utxos.length, greaterThanOrEqualTo(1));
      final firstUtxo = utxos.first;
      expect(firstUtxo.containsKey('tx_hash'), isTrue);
      expect(firstUtxo.containsKey('amount'), isTrue);
    });

    test('TransactionBuilder: buildRewardWithdrawalTx bundles VoteDelegation (AlwaysAbstain) into Key 4', () {
      final mockUtxos = [
        {
          "tx_hash": "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "10000000"} // 10 ADA
          ]
        }
      ];

      final builtTx = TransactionBuilder.buildRewardWithdrawalTx(
        senderAddress: testPaymentAddress,
        stakeAddress: testStakeAddress,
        withdrawLovelace: 5000000, // 5 ADA
        utxos: mockUtxos,
        autoDelegateDRep: true,
        drepId: "always_abstain",
      );

      expect(builtTx.rawCborHex, startsWith("TxBodyConwayWithdrawal:a6"));
      // Map of 6 elements: inputs (0), outputs (1), fee (2), ttl (3), certs (4), withdrawals (5)
      expect(builtTx.delegatedDRepId, equals("always_abstain"));
      expect(builtTx.withdrawLovelace, equals(5000000));
      expect(builtTx.feeLovelace, equals(195000));
    });

    test('TransactionBuilder: buildRewardWithdrawalTx without DRep delegation generates a5 Map', () {
      final mockUtxos = [
        {
          "tx_hash": "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "10000000"}
          ]
        }
      ];

      final builtTx = TransactionBuilder.buildRewardWithdrawalTx(
        senderAddress: testPaymentAddress,
        stakeAddress: testStakeAddress,
        withdrawLovelace: 5000000,
        utxos: mockUtxos,
        autoDelegateDRep: false,
      );

      expect(builtTx.rawCborHex, startsWith("TxBodyConwayWithdrawal:a5"));
      expect(builtTx.delegatedDRepId, isNull);
    });
  });
}
