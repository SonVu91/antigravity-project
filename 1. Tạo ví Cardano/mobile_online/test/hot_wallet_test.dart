import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';
import 'package:mobile_online/main.dart';
import 'package:mobile_online/core/tx/tx_builder.dart';
import 'package:mobile_online/core/network/token_asset.dart';
import 'package:mobile_online/core/network/blockfrost_client.dart';
import 'package:mobile_online/core/migration/hot_migration_service.dart';
import 'package:mobile_online/core/update/hot_update_service.dart';
import 'package:mobile_online/presentation/providers/hot_wallet_provider.dart';
import 'package:mobile_online/presentation/screens/withdraw_reward_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Hot Wallet TxBuilder Unit Tests', () {
    test('Build simple ADA transaction with change', () {
      final mockUtxos = [
        {
          "tx_hash": "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "25000000"} // 25 ADA
          ]
        }
      ];

      final result = TransactionBuilder.buildSimpleAdaTx(
        senderAddress: "addr_test1qre84f9q7s5...",
        recipientAddress: "addr_test1vp8d92...",
        sendLovelace: 5000000, // 5 ADA
        utxos: mockUtxos,
      );

      expect(result.sendLovelace, 5000000);
      expect(result.sendAda, 5.0);
      expect(result.feeLovelace, 180000);
      expect(result.changeLovelace, 25000000 - 5000000 - 180000);
      expect(result.rawCborHex.startsWith("TxBodyConway:"), isTrue);
    });

    test('Preserves exact Bech32 recipient and change address in CBOR', () {
      const senderAddr = "addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73";
      const recAddr = "addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3pnzms9xmg9faasgytqqr30g0055g7s63kllcfv3w56v2qae5wrx";
      final mockUtxos = [
        {
          "tx_hash": "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "50000000"} // 50 ADA
          ]
        }
      ];

      final result = TransactionBuilder.buildSimpleAdaTx(
        senderAddress: senderAddr,
        recipientAddress: recAddr,
        sendLovelace: 20000000, // 20 ADA
        utxos: mockUtxos,
      );

      final parsed = CardanoCoreBridge.parseTransaction(result.rawCborHex, isTestnet: true);
      expect(parsed.recipientAddress, recAddr);
      expect(parsed.sendLovelace, 20000000);
      expect(parsed.outputs.length, 2);
      expect(parsed.outputs[1].address, senderAddr);
    });

    test('Throws error if UTXO balance is insufficient', () {
      final mockUtxos = [
        {
          "tx_hash": "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "2000000"} // 2 ADA
          ]
        }
      ];

      expect(
        () => TransactionBuilder.buildSimpleAdaTx(
          senderAddress: "addr_test1qre84f9q7s5...",
          recipientAddress: "addr_test1vp8d92...",
          sendLovelace: 10000000, // 10 ADA (exceeds balance)
          utxos: mockUtxos,
        ),
        throwsA(predicate((e) => e.toString().contains("không đủ"))),
      );
    });

    test('Build multi-asset transaction with multiple tokens and verify parsing', () {
      const senderAddr = "addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73";
      const recAddr = "addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3pnzms9xmg9faasgytqqr30g0055g7s63kllcfv3w56v2qae5wrx";

      final hosky = TokenAsset.fromUnit(
        unit: "a0028f350aaabe0545fdcb56b039dbb01871b6330ebe111f2dc26960484f534b59",
        quantity: BigInt.from(1000000),
        ticker: "HOSKY",
      );
      final snek = TokenAsset.fromUnit(
        unit: "279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f534e454b",
        quantity: BigInt.from(50000),
        ticker: "SNEK",
      );

      final mockUtxos = [
        {
          "tx_hash": "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "50000000"}, // 50 ADA
            {"unit": hosky.unit, "quantity": "1000000"},
            {"unit": snek.unit, "quantity": "50000"},
          ]
        }
      ];

      final itemsToSend = [
        TokenTransferItem(asset: hosky, sendQuantity: BigInt.from(300000)),
        TokenTransferItem(asset: snek, sendQuantity: BigInt.from(20000)),
      ];

      // Min-ADA for 2 tokens: 1,300,000 Lovelace (1.3 ADA)
      final expectedMinAda = TransactionBuilder.calculateMinUtxoLovelace(2);
      expect(expectedMinAda, 1300000);

      final result = TransactionBuilder.buildTransaction(
        senderAddress: senderAddr,
        recipientAddress: recAddr,
        sendLovelace: 0, // Should auto-elevate to min ADA
        tokensToSend: itemsToSend,
        utxos: mockUtxos,
      );

      // ignore: avoid_print
      print("SAMPLE_TOKEN_CBOR: " + result.rawCborHex);

      expect(result.sendLovelace, expectedMinAda);
      expect(result.sentTokens.length, 2);
      expect(result.changeTokens.length, 2);

      // Verify change tokens: 700k HOSKY and 30k SNEK
      final hoskyChange = result.changeTokens.firstWhere((t) => t.unit == hosky.unit);
      expect(hoskyChange.sendQuantity, BigInt.from(700000));
      final snekChange = result.changeTokens.firstWhere((t) => t.unit == snek.unit);
      expect(snekChange.sendQuantity, BigInt.from(30000));

      // Phân tích cú pháp CBOR bằng Bridge Core
      final parsed = CardanoCoreBridge.parseTransaction(result.rawCborHex, isTestnet: true);
      expect(parsed.outputs.length, 2);
      expect(parsed.outputs[0].address, recAddr);
      expect(parsed.outputs[0].tokens.length, 2);
      expect(parsed.outputs[0].tokens.any((t) => t.assetNameUtf8 == "HOSKY" && t.quantity == 300000), isTrue);
      expect(parsed.outputs[0].tokens.any((t) => t.assetNameUtf8 == "SNEK" && t.quantity == 20000), isTrue);

      expect(parsed.outputs[1].address, senderAddr);
      expect(parsed.outputs[1].tokens.length, 2);
      expect(parsed.outputs[1].tokens.any((t) => t.assetNameUtf8 == "HOSKY" && t.quantity == 700000), isTrue);
      expect(parsed.outputs[1].tokens.any((t) => t.assetNameUtf8 == "SNEK" && t.quantity == 30000), isTrue);
    });

    test('Throws error if token balance is insufficient', () {
      final hosky = TokenAsset.fromUnit(
        unit: "a0028f350aaabe0545fdcb56b039dbb01871b6330ebe111f2dc26960484f534b59",
        quantity: BigInt.from(100),
        ticker: "HOSKY",
      );
      final mockUtxos = [
        {
          "tx_hash": "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "50000000"},
            {"unit": hosky.unit, "quantity": "100"},
          ]
        }
      ];

      expect(
        () => TransactionBuilder.buildTransaction(
          senderAddress: "addr_test1qre84f9q7s5...",
          recipientAddress: "addr_test1vp8d92...",
          sendLovelace: 2000000,
          tokensToSend: [TokenTransferItem(asset: hosky, sendQuantity: BigInt.from(500))],
          utxos: mockUtxos,
        ),
        throwsA(predicate((e) => e.toString().contains("không đủ"))),
      );
    });
  });

  group('Hot Wallet Migration & Persistence Tests', () {
    test('Preserves existing watched address and auto-migrates to Schema v2', () async {
      final migration = HotMigrationService();
      const testAddr = "addr_test1qrx982347923749823749823479";

      // 1. Simulate existing v1 install with saved watched address but no schema version
      SharedPreferences.setMockInitialValues({
        HotMigrationService.keyWatchedAddress: testAddr,
      });

      final vBefore = await migration.getSchemaVersion();
      expect(vBefore, 1);

      // 2. Run migration
      final migrated = await migration.runMigrationIfNeeded();
      expect(migrated, isTrue);

      final vAfter = await migration.getSchemaVersion();
      expect(vAfter, HotMigrationService.currentSchemaVersion);

      // 3. Verify watched address is 100% preserved
      final state = await migration.loadSavedState();
      expect(state['watchedAddress'], testAddr);
      expect(state['network'], CardanoNetwork.preprod);
    });

    test('Exports backup and successfully restores watch config', () async {
      final migration = HotMigrationService();
      await migration.saveState(
        watchedAddress: "addr_test1qqqqqqqqqqqqqqqqqqqqqqqqq",
        network: CardanoNetwork.mainnet,
        apiKey: "mainnet_key_12345",
        balanceAda: 100.5,
      );

      final backupStr = await migration.exportBackup(includeApiKey: true);
      expect(backupStr, contains("CARDANO_HOT_BACKUP"));
      expect(backupStr, contains("mainnet_key_12345"));

      // Clear storage
      SharedPreferences.setMockInitialValues({});
      final stateBefore = await migration.loadSavedState();
      expect(stateBefore['watchedAddress'], isNull);

      // Restore
      final restored = await migration.importBackup(backupStr);
      expect(restored, isTrue);

      final stateAfter = await migration.loadSavedState();
      expect(stateAfter['watchedAddress'], "addr_test1qqqqqqqqqqqqqqqqqqqqqqqqq");
      expect(stateAfter['network'], CardanoNetwork.mainnet);
      expect(stateAfter['apiKey'], "mainnet_key_12345");
      expect(stateAfter['cachedBalance'], 100.5);
    });
  });

  group('Hot Update Service Tests', () {
    test('Accurately detects newer vs older versions', () {
      expect(HotUpdateService.isNewerVersion("1.2.0", "1.1.0"), isTrue);
      expect(HotUpdateService.isNewerVersion("v1.1.1", "1.1.0"), isTrue);
      expect(HotUpdateService.isNewerVersion("2.0.0", "1.9.9"), isTrue);
      expect(HotUpdateService.isNewerVersion("1.1.0", "1.1.0"), isFalse);
      expect(HotUpdateService.isNewerVersion("1.0.0", "1.1.0"), isFalse);
    });

    test('Check for update with mock release and simulate download', () async {
      final updateService = HotUpdateService();
      final update = await updateService.checkForUpdate(mockLatestVersion: "1.2.0");

      expect(update.hasUpdate, isTrue);
      expect(update.latestVersion, "1.2.0");
      expect(update.currentVersion, "1.1.0");

      final progressReports = <double>[];
      await updateService.downloadAndInstallUpdate(
        update,
        onProgress: (p, s) => progressReports.add(p),
      );

      expect(progressReports.isNotEmpty, isTrue);
      expect(progressReports.last, 1.0);
    });
  });

  group('Blockfrost Client Tests', () {
    test('Network base URLs', () {
      final clientPreprod = BlockfrostClient(network: CardanoNetwork.preprod);
      expect(clientPreprod.baseUrl, "https://cardano-preprod.blockfrost.io/api/v0");

      final clientMainnet = BlockfrostClient(network: CardanoNetwork.mainnet);
      expect(clientMainnet.baseUrl, "https://cardano-mainnet.blockfrost.io/api/v0");
    });
  });

  group('Hot Wallet Staking Reward & Withdrawal Tests', () {
    test('Query and parse staking rewards info from BlockfrostClient', () async {
      final client = BlockfrostClient(network: CardanoNetwork.preprod, allowMockFallback: true);
      final stakeAddr = await client.getStakeAddress("addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73");
      expect(stakeAddr, isNotNull);
      expect(stakeAddr!.startsWith("stake_test1"), isTrue);

      final accountInfo = await client.getAccountInfo(stakeAddr);
      expect(accountInfo, isNotNull);
      expect(accountInfo!['active'], isTrue);
      expect(accountInfo['withdrawable_amount'], isNotNull);
      final withdrawable = int.parse(accountInfo['withdrawable_amount'].toString());
      expect(withdrawable, greaterThan(0));
    });

    test('Build Conway Staking Reward Withdrawal transaction with auto-calculated fee', () {
      const senderAddr = "addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73";
      const stakeAddr = "stake_test1upxuru4u5twhwjxq5na0xtczckl85fgyxhplnn4jdmqrsaqm46y5m";
      final mockUtxos = [
        {
          "tx_hash": "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "10000000"} // 10 ADA UTXO
          ]
        }
      ];

      const rewardLovelace = 15800000; // 15.8 ADA rewards
      final result = TransactionBuilder.buildRewardWithdrawalTx(
        senderAddress: senderAddr,
        stakeAddress: stakeAddr,
        withdrawLovelace: rewardLovelace,
        utxos: mockUtxos,
      );

      expect(result.isWithdrawal, isTrue);
      expect(result.withdrawLovelace, rewardLovelace);
      expect(result.withdrawAda, 15.8);
      expect(result.feeLovelace, 195000); // Auto-calculated fee ~0.195 ADA
      expect(result.feeAda, 0.195);
      // Net reward = 15,800,000 - 195,000 = 15,605,000 Lovelace.
      // Total output = Input (10,000,000) + Net Reward (15,605,000) = 25,605,000 Lovelace
      expect(result.sendLovelace, 10000000 + (rewardLovelace - 195000));
      expect(result.rawCborHex.startsWith("TxBodyConwayWithdrawal:"), isTrue);
      print("SAMPLE_WITHDRAWAL_CBOR: ${result.rawCborHex}");
    });

    test('Reject withdrawal when reward amount is less than network fee', () {
      const senderAddr = "addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73";
      const stakeAddr = "stake_test1upxuru4u5twhwjxq5na0xtczckl85fgyxhplnn4jdmqrsaqm46y5m";
      final mockUtxos = [
        {
          "tx_hash": "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "10000000"}
          ]
        }
      ];

      // Small reward: 100,000 Lovelace (0.1 ADA) < 195,000 Lovelace fee
      expect(
        () => TransactionBuilder.buildRewardWithdrawalTx(
          senderAddress: senderAddr,
          stakeAddress: stakeAddr,
          withdrawLovelace: 100000,
          utxos: mockUtxos,
        ),
        throwsA(predicate((e) => e.toString().contains("không đủ chi trả phí"))),
      );
    });

    test('Withdraw reward to custom destination address', () {
      const senderAddr = "addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73";
      const stakeAddr = "stake_test1upxuru4u5twhwjxq5na0xtczckl85fgyxhplnn4jdmqrsaqm46y5m";
      const customDest = "addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3pnzms9xmg9faasgytqqr30g0055g7s63kllcfv3w56v2qae5wrx";
      final mockUtxos = [
        {
          "tx_hash": "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0",
          "tx_index": 0,
          "amount": [
            {"unit": "lovelace", "quantity": "5000000"}
          ]
        }
      ];

      final result = TransactionBuilder.buildRewardWithdrawalTx(
        senderAddress: senderAddr,
        stakeAddress: stakeAddr,
        withdrawLovelace: 20000000,
        utxos: mockUtxos,
        destinationAddress: customDest,
      );

      expect(result.inputsUsed.length, 1);
      expect(result.sendLovelace, 5000000 + 20000000 - 195000);
      expect(result.rawCborHex.contains("TxBodyConwayWithdrawal:"), isTrue);
    });

    test('HotWalletNotifier tracks reward and builds withdrawal transaction', () async {
      final client = BlockfrostClient(network: CardanoNetwork.preprod, allowMockFallback: true);
      final notifier = HotWalletNotifier(client: client);
      notifier.setWatchedAddress("addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73");

      await notifier.fetchBalance();
      await notifier.fetchRewardInfo();

      final state = notifier.state;
      expect(state.stakeAddress, isNotNull);
      expect(state.withdrawableRewardLovelace, greaterThan(0));
      expect(state.withdrawableRewardAda, greaterThan(0));

      final tx = await notifier.prepareRewardWithdrawalTransaction();
      expect(tx.isWithdrawal, isTrue);
      expect(tx.rawCborHex.startsWith("TxBodyConwayWithdrawal:"), isTrue);
      expect(notifier.state.lastBuiltTx, isNotNull);
    });
  });

  group('Hot Wallet UI Smoke Test', () {
    testWidgets('Hot Wallet App renders properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: CardanoHotApp(),
        ),
      );

      await tester.pump();
      expect(find.byType(CardanoHotApp), findsOneWidget);
    });
  });
}
