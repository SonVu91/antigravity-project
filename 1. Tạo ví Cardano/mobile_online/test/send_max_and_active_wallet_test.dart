import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';
import 'package:mobile_online/core/tx/tx_builder.dart';
import 'package:mobile_online/core/models/watched_wallet_entry.dart';
import 'package:mobile_online/core/migration/hot_migration_service.dart';
import 'package:mobile_online/presentation/providers/hot_wallet_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Send Max & UTXO Selection Tests', () {
    const sender = 'addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73';
    const recipient = 'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3pnzms9xmg9faasgytqqr30g0055g7s63kllcfv3w56v2qae5wrx';

    test('Send Max with multiple UTXOs calculates exact fee, 0 change, and does not fail', () {
      // Simulating user wallet with 538.526352 ADA across 2 UTXOs
      final mockUtxos = [
        {
          "tx_hash": "1111111111111111111111111111111111111111111111111111111111111111",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "300000000"} // 300 ADA
          ]
        },
        {
          "tx_hash": "2222222222222222222222222222222222222222222222222222222222222222",
          "tx_index": 1,
          "amount": [
            {"unit": "lovelace", "quantity": "238526352"} // 238.526352 ADA
          ]
        }
      ];

      final totalLovelace = 300000000 + 238526352; // 538526352

      final result = TransactionBuilder.buildTransaction(
        senderAddress: sender,
        recipientAddress: recipient,
        sendLovelace: totalLovelace,
        tokensToSend: const [],
        utxos: mockUtxos,
        sendMax: true,
      );

      expect(result.inputsUsed.length, 2);
      expect(result.changeLovelace, 0); // No change output
      expect(result.feeLovelace, greaterThan(155381)); // Valid Cardano fee
      // Total sent + fee must equal total wallet balance exactly!
      expect(result.sendLovelace + result.feeLovelace, totalLovelace);
      expect(result.rawCborHex.startsWith('TxBodyConway:'), isTrue);
    });

    test('Standard send of 525 ADA from 538.526352 ADA succeeds with change', () {
      final mockUtxos = [
        {
          "tx_hash": "1111111111111111111111111111111111111111111111111111111111111111",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "300000000"} // 300 ADA
          ]
        },
        {
          "tx_hash": "2222222222222222222222222222222222222222222222222222222222222222",
          "tx_index": 1,
          "amount": [
            {"unit": "lovelace", "quantity": "238526352"} // 238.526352 ADA
          ]
        }
      ];

      const sendAmount = 525000000; // 525 ADA

      final result = TransactionBuilder.buildTransaction(
        senderAddress: sender,
        recipientAddress: recipient,
        sendLovelace: sendAmount,
        tokensToSend: const [],
        utxos: mockUtxos,
        sendMax: false,
      );

      expect(result.sendLovelace, sendAmount);
      expect(result.inputsUsed.length, 2);
      expect(result.changeLovelace, greaterThan(1000000)); // Change >= 1 ADA
      expect(result.sendLovelace + result.feeLovelace + result.changeLovelace, 538526352);
    });

    test('Sending amount leaving < 1 ADA dust throws helpful exception', () {
      final mockUtxos = [
        {
          "tx_hash": "1111111111111111111111111111111111111111111111111111111111111111",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "500000000"} // 500 ADA
          ]
        }
      ];

      // Gửi 499.5 ADA (để lại 0.5 ADA - nhỏ hơn 1 ADA min change)
      expect(
        () => TransactionBuilder.buildTransaction(
          senderAddress: sender,
          recipientAddress: recipient,
          sendLovelace: 499500000,
          tokensToSend: const [],
          utxos: mockUtxos,
          sendMax: false,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains("không đủ mức tối thiểu 1 ADA theo quy định Cardano (Min-UTXO)"),
        )),
      );
    });
  });

  group('Active Wallet Synchronization Tests', () {
    test('HotMigrationService saves and restores activeWalletId', () async {
      final migration = HotMigrationService();

      final wallets = [
        WatchedWalletEntry(id: 'w_1', name: 'Ví Chính', address: 'addr1_w1'),
        WatchedWalletEntry(id: 'w_2', name: 'Ví Phụ', address: 'addr1_w2'),
      ];

      await migration.saveState(
        watchedAddress: 'addr1_w2',
        activeWalletId: 'w_2',
        watchedWalletsEntries: wallets,
      );

      final loaded = await migration.loadSavedState();
      expect(loaded['watchedAddress'], 'addr1_w2');
      expect(loaded['activeWalletId'], 'w_2');
    });

    test('HotWalletState.activeWallet prioritizes activeWalletId and matches address', () {
      final wallets = [
        WatchedWalletEntry(id: 'w_1', name: 'Ví 1', address: 'addr1_w1'),
        WatchedWalletEntry(id: 'w_2', name: 'Ví 2', address: 'addr1_w2'),
        WatchedWalletEntry(id: 'w_3', name: 'Ví 3', address: 'addr1_w3'),
      ];

      final state = HotWalletState(
        watchedAddress: 'addr1_w3',
        activeWalletId: 'w_3',
        watchedWallets: wallets,
      );

      expect(state.activeWallet?.id, 'w_3');
      expect(state.activeWallet?.name, 'Ví 3');
      expect(state.activeWallet?.address, 'addr1_w3');
    });
  });
}
