import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_online/core/models/watched_wallet_entry.dart';
import 'package:mobile_online/core/theme/hot_theme.dart';
import 'package:mobile_online/core/network/token_asset.dart';
import 'package:mobile_online/presentation/providers/hot_wallet_provider.dart';
import 'package:mobile_online/presentation/screens/dashboard_screen.dart';
import 'package:mobile_online/presentation/screens/build_tx_screen.dart';
import 'package:mobile_online/presentation/screens/scan_signed_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UI/UX Pro Max Redesign Verification Tests (Hot Wallet)', () {
    test('1. HotTheme replaces alarming Red with Warm Amber/Gold and reserves Red strictly for errors', () {
      expect(HotTheme.primary, const Color(0xFFD97706));
      expect(HotTheme.accent, const Color(0xFFF59E0B));
      expect(HotTheme.textPrimary, const Color(0xFFF8FAFC));
      expect(HotTheme.dangerRed, const Color(0xFFEF4444));
      expect(HotTheme.primary, isNot(equals(HotTheme.dangerRed)));
    });

    testWidgets('2. DashboardScreen groups 3 core actions in Hero Card and switches between Tokens and UTXO tabs', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: HotTheme.darkTheme,
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hosky = TokenAsset.fromUnit(
        unit: "a0028f350aaabe0545fdcb56b039dbb01871b6330ebe111f2dc26960484f534b59",
        quantity: BigInt.from(250000),
        ticker: "HOSKY",
      );

      const addr = "addr_test1qqe7la8397klhm56gnqz029da79jgz249fzemm7j2uu4st2dc8etegkawayvpf867vhs93d70gjsgdwrl88tymkq8p6qec0p73";
      final notifier = container.read(hotWalletProvider.notifier);
      notifier.state = notifier.state.copyWith(
        isLoading: false,
        watchedAddress: addr,
        watchedWallets: [
          WatchedWalletEntry(id: 'w1', name: 'Trading-Ví Nóng', address: addr),
        ],
        activeWalletId: 'w1',
        totalLovelace: 45000000,
        tokens: [hosky],
        utxos: [
          {
            'tx_hash': '64a0e5b1285474b76c8c9f50e7b78912ef54876b5f4c3a2b109876543210abcd',
            'tx_index': 0,
            'amount': [
              {'unit': 'lovelace', 'quantity': '45000000'},
            ],
          },
        ],
      );
      await tester.pumpAndSettle();

      // Verify all 3 core actions are grouped inside the Hero Card above Staking
      final sendBtn = find.text("GỬI TIỀN");
      final receiveBtn = find.text("NHẬN TIỀN");
      final broadcastBtn = find.text("QUÉT GIAO DỊCH ĐÃ KÝ (txSigned) & PHÁT SÓNG");
      final conwayHeader = find.text("ỦY THÁC & QUẢN TRỊ (CONWAY)");

      expect(sendBtn, findsOneWidget);
      expect(receiveBtn, findsOneWidget);
      expect(broadcastBtn, findsOneWidget);
      expect(conwayHeader, findsOneWidget);

      // Broadcast button must be above the Conway Staking card (inside Hero Card)
      expect(
        tester.getTopLeft(broadcastBtn).dy,
        lessThan(tester.getTopLeft(conwayHeader).dy),
      );

      // Verify 2-column Bento layout: Stake Pool and DRep Quản Trị are on the same horizontal row
      final poolLabelY = tester.getTopLeft(find.text("Stake Pool:")).dy;
      final drepLabelY = tester.getTopLeft(find.text("DRep Quản Trị:")).dy;
      expect((poolLabelY - drepLabelY).abs(), lessThan(5.0));

      // Verify 2-tab switcher between Native Tokens and UTXO list
      expect(find.textContaining("Tài Sản Native Tokens (1)"), findsOneWidget);
      expect(find.textContaining("Danh Sách UTXO (1)"), findsOneWidget);
      expect(find.text("HOSKY"), findsWidgets);

      // Switch to UTXO tab
      await tester.tap(find.textContaining("Danh Sách UTXO (1)"));
      await tester.pumpAndSettle();
      expect(find.textContaining("64a0e5b1285474b76c8c9f50e7b78912ef54876b5f4c3a2b109876543210abcd#0"), findsOneWidget);
    });

    testWidgets('3. BuildTxScreen and ScanSignedScreen render 3-step Air-Gap progress headers', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: HotTheme.darkTheme,
            home: const BuildTxScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining("Bước 1/3: Khởi Tạo Giao Dịch Thô (txRaw)"), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: HotTheme.darkTheme,
            home: const ScanSignedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining("Bước 3/3: Quét Giao Dịch Đã Ký (txSigned) & Phát Sóng"), findsOneWidget);
    });
  });
}
