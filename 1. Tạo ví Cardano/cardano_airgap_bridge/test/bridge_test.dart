import 'package:flutter_test/flutter_test.dart';
import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';
import 'package:cardano_airgap_bridge/src/cardano_pure.dart';

void main() {
  setUpAll(() {
    CardanoCoreBridge.init();
  });

  group('Cardano AirGap Bridge - Native FFI & Crypto Tests', () {
    test('Generate Mnemonic (12, 15, 24 words)', () {
      for (final count in [12, 15, 24]) {
        final mnemonic = CardanoCoreBridge.generateMnemonic(count);
        expect(mnemonic.split(' ').length, count);
        expect(CardanoCoreBridge.validateMnemonic(mnemonic), isTrue);
      }
    });

    test('Validate Mnemonic', () {
      expect(CardanoCoreBridge.validateMnemonic('abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'), isTrue);
      expect(CardanoCoreBridge.validateMnemonic('invalid mnemonic word list that fails checksum'), isFalse);
    });

    test('BIP-39 Word Validation & Autocomplete Suggestions', () {
      expect(CardanoCoreBridge.isWordValid('abandon'), isTrue);
      expect(CardanoCoreBridge.isWordValid('glag'), isFalse);
      expect(CardanoCoreBridge.isWordValid('glad'), isTrue);

      final invalidWords = CardanoCoreBridge.findInvalidWords('iron scout tenant giggle glory manual glag skull');
      expect(invalidWords, equals(['glag']));

      final suggestions = CardanoCoreBridge.getSuggestions('gla');
      expect(suggestions, contains('glad'));
      expect(suggestions, contains('glass'));

      final closest = CardanoCoreBridge.suggestClosestWord('glag');
      expect(closest, isNotNull);
      expect(closest == 'glad' || closest == 'flag' || closest == 'glass', isTrue);
    });

    test('Create Wallet CIP-1852 (BIP-39 Seed)', () {
      const phrase = 'test walk nut penalty hip pave soap entry language right filter choice';
      final wallet = CardanoCoreBridge.createWallet(phrase, isTestnet: true, accountIndex: 0, addressIndex: 0);

      expect(wallet.paymentAddress.startsWith('addr_test1'), isTrue);
      expect(wallet.stakeAddress.startsWith('stake_test1'), isTrue);
      expect(wallet.accountXpubHex.isNotEmpty, isTrue);
      expect(wallet.derivationPath, "m/1852'/1815'/0'/0/0");

      // Mainnet
      final mainnetWallet = CardanoCoreBridge.createWallet(phrase, isTestnet: false, accountIndex: 0, addressIndex: 0);
      expect(mainnetWallet.paymentAddress.startsWith('addr1'), isTrue);
      expect(mainnetWallet.stakeAddress.startsWith('stake1'), isTrue);
    });

    test('Create Wallet CIP-0003 Icarus Mode', () {
      const phrase = 'test walk nut penalty hip pave soap entry language right filter choice';
      final walletBip39 = CardanoCoreBridge.createWallet(phrase, isTestnet: true, useIcarus: false);
      final walletIcarus = CardanoCoreBridge.createWallet(phrase, isTestnet: true, useIcarus: true);

      expect(walletBip39.paymentAddress.startsWith('addr_test1'), isTrue);
      expect(walletIcarus.paymentAddress.startsWith('addr_test1'), isTrue);
      expect(walletBip39.paymentAddress, isNot(equals(walletIcarus.paymentAddress)));
      expect(walletIcarus.useIcarus, isTrue);
      expect(walletBip39.useIcarus, isFalse);
    });

    test('15-word Yoroi CIP-0003 Icarus wallet derivation', () {
      // 15 words standard Yoroi mnemonic
      final phrase15 = CardanoCoreBridge.generateMnemonic(15);
      expect(phrase15.split(' ').length, 15);

      final walletMainnetIcarus = CardanoCoreBridge.createWallet(phrase15, isTestnet: false, useIcarus: true);
      final walletMainnetBip39 = CardanoCoreBridge.createWallet(phrase15, isTestnet: false, useIcarus: false);

      expect(walletMainnetIcarus.paymentAddress.startsWith('addr1'), isTrue);
      expect(walletMainnetBip39.paymentAddress.startsWith('addr1'), isTrue);
      expect(walletMainnetIcarus.paymentAddress, isNot(equals(walletMainnetBip39.paymentAddress)));
      expect(walletMainnetIcarus.useIcarus, isTrue);

      // Verify Pure-Dart parity
      final pureWallet = CardanoPure.createWallet(phrase15, isTestnet: false, useIcarus: true);
      expect(pureWallet.paymentAddress.startsWith('addr1'), isTrue);
      expect(pureWallet.useIcarus, isTrue);
    });

    test('Change Guard verification', () {
      const phrase = 'test walk nut penalty hip pave soap entry language right filter choice';
      final wallet = CardanoCoreBridge.createWallet(phrase, isTestnet: true);

      // Own address must be safe
      final isOwnSafe = CardanoCoreBridge.verifyChange(wallet.paymentAddress, wallet.accountXpubHex, isTestnet: true);
      expect(isOwnSafe, isTrue);

      // Attacker address must be rejected
      const hackerAddr = 'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3pn0u5vvglpqjd2hn88z49txz2hxqqqqqqqqqqqqqq';
      final isHackerSafe = CardanoCoreBridge.verifyChange(hackerAddr, wallet.accountXpubHex, isTestnet: true);
      expect(isHackerSafe, isFalse);
    });

    test('Create sample Conway Tx and Parse Tx', () {
      const phrase = 'test walk nut penalty hip pave soap entry language right filter choice';
      final wallet = CardanoCoreBridge.createWallet(phrase, isTestnet: true);

      final sampleTxHex = CardanoCoreBridge.createSampleConwayTx(wallet.paymentAddress, 5000000, 180000);
      expect(sampleTxHex.isNotEmpty, isTrue);

      final parsed = CardanoCoreBridge.parseTransaction(sampleTxHex, accountXpubHex: wallet.accountXpubHex, isTestnet: true);
      expect(parsed.outputs.isNotEmpty, isTrue);
      expect(parsed.feeLovelace, 180000);
      expect(parsed.sendLovelace, 5000000);
      expect(parsed.isChangeSafe, isTrue);
    });

    test('Sign transaction and Verify Signed Tx with FIPS 140-3 self-verification', () {
      const phrase = 'test walk nut penalty hip pave soap entry language right filter choice';
      final wallet = CardanoCoreBridge.createWallet(phrase, isTestnet: true);

      final sampleTxHex = CardanoCoreBridge.createSampleConwayTx(wallet.paymentAddress, 5000000, 180000);
      final signedHex = CardanoCoreBridge.signTransaction(
        sampleTxHex,
        phrase,
        accountIndex: 0,
        addressIndex: 0,
        useIcarus: false,
      );
      expect(signedHex.isNotEmpty, isTrue);

      final isValid = CardanoCoreBridge.verifySignedTransaction(signedHex);
      expect(isValid, isTrue);
    });

    test('Sign transaction in Icarus mode and Verify Signed Tx', () {
      const phrase = 'test walk nut penalty hip pave soap entry language right filter choice';
      final walletIcarus = CardanoCoreBridge.createWallet(phrase, isTestnet: true, useIcarus: true);

      final sampleTxHex = CardanoCoreBridge.createSampleConwayTx(walletIcarus.paymentAddress, 5000000, 180000);
      final signedHex = CardanoCoreBridge.signTransaction(
        sampleTxHex,
        phrase,
        accountIndex: 0,
        addressIndex: 0,
        useIcarus: true,
      );
      expect(signedHex.isNotEmpty, isTrue);

      final isValid = CardanoCoreBridge.verifySignedTransaction(signedHex);
      expect(isValid, isTrue);
    });
  });

  group('Adaptive Multipart QR Tests', () {
    test('Single-frame static QR for small payloads (< 300 chars)', () {
      final encoder = MultipartQrEncoder();
      const smallPayload = 'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer';
      final frames = encoder.encode(smallPayload);

      expect(frames.length, 1);
      expect(frames[0], smallPayload);

      final decoder = MultipartQrDecoder();
      final result = decoder.feed(frames[0]);
      expect(result, smallPayload);
      expect(decoder.isComplete, isTrue);
    });

    test('Medium payload (300-499 chars) uses standard UR:CARDANO-TX Base64', () {
      final encoder = MultipartQrEncoder(chunkSize: 100);
      final mediumPayload = 'PAYLOAD_MEDIUM_' * 25; // ~375 chars
      expect(mediumPayload.length >= 300 && mediumPayload.length < 500, isTrue);

      final frames = encoder.encode(mediumPayload);
      expect(frames.length > 1, isTrue);
      expect(frames[0].startsWith('UR:CARDANO-TX/'), isTrue);
      expect(frames[0].startsWith('UR:CARDANO-TX-Z/'), isFalse);

      final decoder = MultipartQrDecoder();
      String? result;
      for (final frame in frames) {
        result = decoder.feed(frame);
      }
      expect(result, mediumPayload);
      expect(decoder.isZlibCompressed, isFalse);
    });

    test('Large payload (>= 500 chars) uses Adaptive Zlib UR:CARDANO-TX-Z', () {
      final encoder = MultipartQrEncoder(chunkSize: 80);
      final largePayload = List.generate(40, (i) => 'TxConway_Input_${i}_Hash_${i * 987654321}_Output_${i * 123456789}_StakeCert').join('_');
      expect(largePayload.length >= 500, isTrue);

      final frames = encoder.encode(largePayload);
      expect(frames.length > 1, isTrue);
      expect(frames[0].startsWith('UR:CARDANO-TX-Z/'), isTrue);

      final decoder = MultipartQrDecoder();
      String? result;
      for (final frame in frames) {
        result = decoder.feed(frame);
      }
      expect(result, largePayload);
      expect(decoder.isZlibCompressed, isTrue);
    });
  });

  group('Wallet Grouping & A-Z Sorting Tests', () {
    test('Extract group name by hyphen prefix', () {
      expect(extractGroupName('Staking-Ví 1'), 'Staking');
      expect(extractGroupName('ChiTiêu-Cá Nhân'), 'ChiTiêu');
      expect(extractGroupName('Ví Chung'), 'Chung');
      expect(extractGroupName('KhôngDấuGạch'), 'Chung');
    });

    test('Group and sort A-Z case-insensitively', () {
      final wallets = [
        'Zeta-Ví 1',
        'Staking-Ví B',
        'Alpha-Ví 2',
        'Staking-Ví A',
        'Ví Không Nhóm',
        'alpha-Ví 1',
      ];

      final grouped = groupAndSortWallets<String>(
        wallets: wallets,
        getName: (w) => w,
      );

      final groupNames = grouped.map((g) => g.groupName).toList();
      // Alphabetical order: Alpha, Chung, Staking, Zeta
      expect(groupNames, ['Alpha', 'Chung', 'Staking', 'Zeta']);

      // Check items inside Staking: Staking-Ví A, Staking-Ví B
      final stakingGroup = grouped.firstWhere((g) => g.groupName == 'Staking');
      expect(stakingGroup.wallets, ['Staking-Ví A', 'Staking-Ví B']);
    });

    test('Suggest next wallet name', () {
      final existing = ['Chung-Ví 1', 'Chung-Ví 2'];
      final nextName = suggestNextWalletName(existing, (w) => w);
      expect(nextName, 'Chung-Ví 3');
    });

    test('Suggest next derived wallet name with #2, #3 sequence', () {
      final existing = ['Ví Chính', 'Ví Chính #2'];
      final nextName1 = suggestNextDerivedWalletName(existing, (w) => w, 'Ví Chính');
      expect(nextName1, 'Ví Chính #3');

      final nextName2 = suggestNextDerivedWalletName(['Ví Phụ'], (w) => w, 'Ví Phụ');
      expect(nextName2, 'Ví Phụ #2');
    });
  });

  group('Hidden Wallet (Passphrase) & High Index Fast-Path Tests', () {
    test('Create Hidden Wallet with Passphrase and high index (acc 100, addr 500)', () {
      const phrase = 'test walk nut penalty hip pave soap entry language right filter choice';
      final hiddenWallet = CardanoCoreBridge.createWallet(
        phrase,
        passphrase: 'super_secret_passphrase_j7',
        isTestnet: true,
        accountIndex: 100,
        addressIndex: 500,
      );

      expect(hiddenWallet.paymentAddress.startsWith('addr_test1'), isTrue);
      expect(hiddenWallet.accountIndex, 100);
      expect(hiddenWallet.addressIndex, 500);
      expect(hiddenWallet.derivationPath, "m/1852'/1815'/100'/0/500");

      // Verify that sample tx change to this high-index address is verified safely via knownAddress (Fast-Path O(1))
      final sampleTxHex = CardanoCoreBridge.createSampleConwayTx(hiddenWallet.paymentAddress, 2000000, 175000);
      final parsedWithKnown = CardanoCoreBridge.parseTransaction(
        sampleTxHex,
        accountXpubHex: hiddenWallet.accountXpubHex,
        isTestnet: true,
        knownAddress: hiddenWallet.paymentAddress,
      );

      expect(parsedWithKnown.isChangeSafe, isTrue);
      expect(parsedWithKnown.securityWarnings, isEmpty);

      // Verify signing works seamlessly with passphrase & high index
      final signedHex = CardanoCoreBridge.signTransaction(
        sampleTxHex,
        phrase,
        passphrase: 'super_secret_passphrase_j7',
        accountIndex: 100,
        addressIndex: 500,
      );
      expect(signedHex.isNotEmpty, isTrue);
      expect(CardanoCoreBridge.verifySignedTransaction(signedHex), isTrue);
    });

    test('Change Guard rejects attacker address', () {
      const phrase = 'test walk nut penalty hip pave soap entry language right filter choice';
      final hiddenWallet = CardanoCoreBridge.createWallet(
        phrase,
        passphrase: 'super_secret_passphrase_j7',
        isTestnet: true,
        accountIndex: 100,
        addressIndex: 500,
      );

      final attackerWallet = CardanoCoreBridge.createWallet(
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
        isTestnet: true,
      );

      // Verify that ChangeGuard rejects attacker address for this hidden wallet
      final isAttackerChangeSafe = CardanoCoreBridge.verifyChange(
        attackerWallet.paymentAddress,
        hiddenWallet.accountXpubHex,
        isTestnet: true,
      );
      expect(isAttackerChangeSafe, isFalse);
    });
  });
}
