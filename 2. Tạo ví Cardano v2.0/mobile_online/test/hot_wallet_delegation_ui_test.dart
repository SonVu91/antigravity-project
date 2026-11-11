import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_online/presentation/providers/hot_wallet_provider.dart';
import 'package:mobile_online/presentation/screens/dashboard_screen.dart';
import 'package:mobile_online/presentation/screens/delegate_tx_screen.dart';
import 'package:mobile_online/core/network/stake_account_info.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Hot Wallet Multi-Wallet & Delegation Tests', () {
    test('HotWalletNotifier manages multiple watched wallets', () {
      final notifier = HotWalletNotifier();
      const addr1 =
          'addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73';
      const addr2 =
          'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3pnzms9xmg9faasgytqqr30g0055g7s63kllcfv3w56v2qae5wrx';

      notifier.setWatchedAddress(addr1);
      expect(notifier.state.watchedAddress, equals(addr1));
      expect(notifier.state.watchedWallets.contains(addr1), isTrue);

      notifier.addWatchedWallet(addr2);
      expect(notifier.state.watchedAddress, equals(addr2));
      expect(notifier.state.watchedWallets.length, equals(2));

      notifier.switchWatchedWallet(addr1);
      expect(notifier.state.watchedAddress, equals(addr1));

      notifier.removeWatchedWallet(addr2);
      expect(notifier.state.watchedWallets.length, equals(1));
      expect(notifier.state.watchedWallets.contains(addr2), isFalse);
    });

    test('HotWalletNotifier builds delegation transaction properly', () async {
      final notifier = HotWalletNotifier();
      const addr =
          'addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73';
      notifier.setWatchedAddress(addr);

      // Inject mock UTXO
      notifier.state = notifier.state.copyWith(
        utxos: [
          {
            'tx_hash': '64a0e5b1285474b76c8c9f50e7b78912ef54876b5f4c3a2b109876543210abcd',
            'tx_index': 0,
            'amount': [
              {'unit': 'lovelace', 'quantity': '100000000'},
            ]
          }
        ],
      );

      final tx = await notifier.prepareDelegationTransaction(
        poolId: StakeAccountInfo.fimiPoolId,
        drepId: StakeAccountInfo.fimiDRepId,
      );

      expect(tx.rawCborHex.startsWith('TxBodyConwayDelegation:'), isTrue);
      expect(tx.delegatedPoolId, equals(StakeAccountInfo.fimiPoolId));
      expect(tx.delegatedDRepId, equals(StakeAccountInfo.fimiDRepId));
      expect(notifier.state.lastBuiltTx, equals(tx));
    });

    testWidgets('Dashboard renders Staking & Governance card and wallet switcher', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('VÍ ĐANG THEO DÕI'), findsOneWidget);
      expect(find.textContaining('ỦY THÁC & QUẢN TRỊ (CONWAY)'), findsOneWidget);
      expect(find.textContaining('ỦY THÁC POOL & DREP'), findsOneWidget);
    });

    testWidgets('DelegateTxScreen renders FIMI Pool and FIMI DRep defaults', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DelegateTxScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Ủy Thác Pool & DRep'), findsOneWidget);
      expect(find.textContaining('FIMI Stake Pool'), findsOneWidget);
      expect(find.textContaining('FIMI DRep'), findsOneWidget);
      expect(find.textContaining('Always Abstain'), findsOneWidget);
      expect(find.textContaining('Always No Confidence'), findsOneWidget);
      expect(find.textContaining('Khởi Tạo Giao Dịch Thô'), findsOneWidget);
    });
  });
}
