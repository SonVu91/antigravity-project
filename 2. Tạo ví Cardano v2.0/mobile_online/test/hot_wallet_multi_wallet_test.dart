import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';
import 'package:mobile_online/core/models/watched_wallet_entry.dart';
import 'package:mobile_online/presentation/providers/hot_wallet_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Hot Wallet Multi-Wallet Management Tests', () {
    test('1. Tracking multiple wallets & Total Portfolio Balance calculation', () async {
      final notifier = HotWalletNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      notifier.addWatchedWallet('addr_test1_wallet1', name: 'Chung-Ví 1');
      notifier.addWatchedWallet('addr_test1_wallet2', name: 'Trading-Ví 2');

      expect(notifier.state.watchedWallets.length, 2);
      expect(notifier.state.watchedWallets[0].name, 'Chung-Ví 1');
      expect(notifier.state.watchedWallets[1].name, 'Trading-Ví 2');

      // Check total portfolio balance computation
      expect(notifier.state.totalPortfolioAda, isNotNull);
    });

    test('2. Preset naming suggestions and renaming support', () async {
      final notifier = HotWalletNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      // Auto suggested name for first wallet
      final name1 = suggestNextWalletName<WatchedWalletEntry>(
        notifier.state.watchedWallets,
        (w) => w.name,
      );
      expect(name1, 'Chung-Ví 1');
      notifier.addWatchedWallet('addr_test1_wallet1', name: name1);

      // Auto suggested name for second wallet
      final name2 = suggestNextWalletName<WatchedWalletEntry>(
        notifier.state.watchedWallets,
        (w) => w.name,
      );
      expect(name2, 'Chung-Ví 2');
      notifier.addWatchedWallet('addr_test1_wallet2', name: name2);

      // Rename wallet 1
      notifier.renameWatchedWallet(notifier.state.watchedWallets[0].id, 'Savings-Master');
      expect(notifier.state.watchedWallets[0].name, 'Savings-Master');
    });

    test('3 & 4. Auto-grouping by first word before hyphen (-) & sorting groups and wallets A-Z', () async {
      final notifier = HotWalletNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      notifier.addWatchedWallet('addr_1', name: 'trading-Delta');
      notifier.addWatchedWallet('addr_2', name: 'Trading-Alpha');
      notifier.addWatchedWallet('addr_3', name: 'Savings-02');
      notifier.addWatchedWallet('addr_4', name: 'savings-01');
      notifier.addWatchedWallet('addr_5', name: 'MyUngroupedWallet');
      notifier.addWatchedWallet('addr_6', name: 'Chung-Ví 1');
      notifier.addWatchedWallet('addr_7', name: 'Alpha-First');

      final grouped = groupAndSortWallets<WatchedWalletEntry>(
        wallets: notifier.state.watchedWallets,
        getName: (w) => w.name,
      );

      final groupNames = grouped.map((g) => g.groupName.toLowerCase()).toList();
      // Should be sorted alphabetically case-insensitively: alpha, chung, savings, trading
      expect(groupNames, ['alpha', 'chung', 'savings', 'trading']);

      // Wallets inside group sorted A-Z
      final tradingGroup = grouped.firstWhere((g) => g.groupName.toLowerCase() == 'trading');
      expect(tradingGroup.wallets.map((w) => w.name).toList(), [
        'Trading-Alpha',
        'trading-Delta',
      ]);

      // Ungrouped wallet is placed in Chung group
      final chungGroup = grouped.firstWhere((g) => g.groupName.toLowerCase() == 'chung');
      expect(chungGroup.wallets.map((w) => w.name).toList(), [
        'Chung-Ví 1',
        'MyUngroupedWallet',
      ]);
    });

    test('5. Deleting a wallet from list with safe active wallet fallback', () async {
      final notifier = HotWalletNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      notifier.addWatchedWallet('addr_1', name: 'Chung-Ví 1');
      notifier.addWatchedWallet('addr_2', name: 'Chung-Ví 2');
      expect(notifier.state.watchedAddress, 'addr_2');

      // Remove the currently active wallet
      notifier.removeWatchedWallet('addr_2');

      expect(notifier.state.watchedWallets.length, 1);
      expect(notifier.state.watchedWallets.first.address, 'addr_1');
      // Should fallback to the remaining wallet
      expect(notifier.state.watchedAddress, 'addr_1');

      // Remove last wallet
      notifier.removeWatchedWallet('addr_1');
      expect(notifier.state.watchedWallets.isEmpty, isTrue);
      expect(notifier.state.watchedAddress, isNull);
    });
  });
}
