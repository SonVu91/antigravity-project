import 'package:flutter_test/flutter_test.dart';
import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';
import 'package:mobile_online/core/tx/tx_builder.dart';
import 'package:mobile_online/core/network/stake_account_info.dart';

void main() {
  group('Conway Delegation Transaction Tests', () {
    const senderAddr =
        'addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73';
    const stakeAddr = 'stake_test1uqz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzerq59p8l';

    final mockUtxos = [
      {
        'tx_hash': '64a0e5b1285474b76c8c9f50e7b78912ef54876b5f4c3a2b109876543210abcd',
        'tx_index': 0,
        'amount': [
          {'unit': 'lovelace', 'quantity': '50000000'}, // 50 ADA
        ]
      }
    ];

    test('Build combined FIMI Pool and FIMI DRep delegation transaction (Registered)', () {
      final result = TransactionBuilder.buildDelegationTx(
        senderAddress: senderAddr,
        stakeAddress: stakeAddr,
        poolId: StakeAccountInfo.fimiPoolId,
        drepId: StakeAccountInfo.fimiDRepId,
        isStakeKeyRegistered: true,
        utxos: mockUtxos,
      );

      expect(result.rawCborHex.startsWith('TxBodyConwayDelegation:'), isTrue);
      expect(result.feeLovelace, equals(195000));
      expect(result.depositLovelace, equals(0));
      expect(result.delegatedPoolId, equals(StakeAccountInfo.fimiPoolId));
      expect(result.delegatedDRepId, equals(StakeAccountInfo.fimiDRepId));
      expect(result.changeLovelace, equals(50000000 - 195000));
      expect(result.isDelegation, isTrue);
    });

    test('Build combined delegation with 2 ADA Key Deposit if unregistered', () {
      final result = TransactionBuilder.buildDelegationTx(
        senderAddress: senderAddr,
        stakeAddress: stakeAddr,
        poolId: StakeAccountInfo.fimiPoolId,
        drepId: 'always_abstain',
        isStakeKeyRegistered: false,
        utxos: mockUtxos,
      );

      expect(result.depositLovelace, equals(2000000));
      expect(result.changeLovelace, equals(50000000 - 2000000 - 195000));
      expect(result.depositAda, equals(2.0));

      // Verify Conway CDDL compliance (no invalid map key 25) by parsing & signing via Rust Core
      const mnemonic = 'test walk nut penalty hip pave soap entry language right filter choice';
      final wallet = CardanoCoreBridge.createWallet(mnemonic, isTestnet: true);
      final realDelegation = TransactionBuilder.buildDelegationTx(
        senderAddress: wallet.paymentAddress,
        stakeAddress: wallet.stakeAddress,
        poolId: StakeAccountInfo.fimiPoolId,
        drepId: 'always_abstain',
        isStakeKeyRegistered: false,
        utxos: mockUtxos,
      );
      final parsed = CardanoCoreBridge.parseTransaction(
        realDelegation.rawCborHex,
        accountXpubHex: wallet.accountXpubHex,
        isTestnet: true,
      );
      expect(parsed.hasCerts, isTrue);
      expect(parsed.certsCount, equals(2)); // RegCert + StakeVoteDelegCert
      expect(parsed.requiresStakeSigning, isTrue);
      expect(parsed.isChangeSafe, isTrue);

      final signed = CardanoCoreBridge.signTransaction(
        realDelegation.rawCborHex,
        mnemonic,
        signStake: parsed.requiresStakeSigning,
      );
      expect(CardanoCoreBridge.verifySignedTransaction(signed), isTrue);
    });

    test('Rejects full-length Bech32 address with corrupted Polymod checksum', () {
      // Flip last character of senderAddr ('3' -> '4') so length is valid (>50) but Bech32 checksum is corrupted
      final corruptedSender = '${senderAddr.substring(0, senderAddr.length - 1)}4';
      expect(
        () => TransactionBuilder.buildDelegationTx(
          senderAddress: corruptedSender,
          stakeAddress: stakeAddr,
          poolId: StakeAccountInfo.fimiPoolId,
          drepId: StakeAccountInfo.fimiDRepId,
          isStakeKeyRegistered: true,
          utxos: mockUtxos,
        ),
        throwsException,
      );
    });

    test('Build Pool only delegation with FIMI Pool', () {
      final result = TransactionBuilder.buildDelegationTx(
        senderAddress: senderAddr,
        stakeAddress: stakeAddr,
        poolId: StakeAccountInfo.fimiPoolId,
        drepId: null,
        isStakeKeyRegistered: true,
        utxos: mockUtxos,
      );

      expect(result.delegatedPoolId, equals(StakeAccountInfo.fimiPoolId));
      expect(result.delegatedDRepId, isNull);
    });

    test('Build DRep only delegation with Always No Confidence', () {
      final result = TransactionBuilder.buildDelegationTx(
        senderAddress: senderAddr,
        stakeAddress: stakeAddr,
        poolId: null,
        drepId: 'always_no_confidence',
        isStakeKeyRegistered: true,
        utxos: mockUtxos,
      );

      expect(result.delegatedPoolId, isNull);
      expect(result.delegatedDRepId, equals('always_no_confidence'));
    });

    test('Rejects delegation when neither Pool nor DRep is provided', () {
      expect(
        () => TransactionBuilder.buildDelegationTx(
          senderAddress: senderAddr,
          stakeAddress: stakeAddr,
          poolId: null,
          drepId: null,
          utxos: mockUtxos,
        ),
        throwsException,
      );
    });

    test('Rejects delegation when UTXO ADA balance is insufficient for fee and deposit', () {
      final poorUtxos = [
        {
          'tx_hash': '64a0e5b1285474b76c8c9f50e7b78912ef54876b5f4c3a2b109876543210abcd',
          'tx_index': 0,
          'amount': [
            {'unit': 'lovelace', 'quantity': '100000'}, // 0.1 ADA (less than fee)
          ]
        }
      ];

      expect(
        () => TransactionBuilder.buildDelegationTx(
          senderAddress: senderAddr,
          stakeAddress: stakeAddr,
          poolId: StakeAccountInfo.fimiPoolId,
          drepId: StakeAccountInfo.fimiDRepId,
          isStakeKeyRegistered: true,
          utxos: poorUtxos,
        ),
        throwsException,
      );
    });
  });
}
