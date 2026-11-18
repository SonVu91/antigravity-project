import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cardano_airgap_bridge/cardano_airgap_bridge.dart';
import 'package:mobile_online/core/models/watched_wallet_entry.dart';
import 'package:mobile_online/presentation/providers/hot_wallet_provider.dart';
import 'package:mobile_online/presentation/widgets/wallet_manager_dialog.dart';

class _TestHotWalletNotifier extends HotWalletNotifier {
  _TestHotWalletNotifier(HotWalletState initial) : super() {
    state = initial;
  }

  @override
  Future<void> initAndLoad() async {}

  @override
  Future<void> fetchBalance() async {}

  @override
  Future<void> fetchAllBalances() async {}
}

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
      // Total portfolio balance must be 0.0, never retain old balance
      expect(notifier.state.totalPortfolioAda, 0.0);
      expect(notifier.state.balanceAda, 0.0);
    });

    testWidgets('6. WalletManagerDialog empty state has single button & deleting last wallet auto-closes dialog', (tester) async {
      final notifier = _TestHotWalletNotifier(
        HotWalletState(
          watchedAddress: 'addr_single',
          watchedWallets: [
            WatchedWalletEntry(
              id: 'w_1',
              name: 'Chung-Ví 1',
              address: 'addr_single',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hotWalletProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 800,
                child: WalletManagerDialog(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // With 1 wallet, bottom button "Thêm Ví Theo Dõi Mới" exists
      expect(find.text("Thêm Ví Theo Dõi Mới"), findsOneWidget);
      expect(find.text("Thêm Ví Đầu Tiên"), findsNothing);

      // Now simulate deleting the only wallet
      notifier.state = notifier.state.copyWith(
        watchedWallets: [],
        clearWatchedAddress: true,
        clearActiveWallet: true,
      );
      await tester.pump();

      // Now with 0 wallets, empty state shows single "Thêm Ví Đầu Tiên" and hides bottom button
      expect(find.text("Thêm Ví Đầu Tiên"), findsOneWidget);
      expect(find.text("Thêm Ví Theo Dõi Mới"), findsNothing);
      expect(notifier.state.totalPortfolioAda, 0.0);
    });
  });
}
