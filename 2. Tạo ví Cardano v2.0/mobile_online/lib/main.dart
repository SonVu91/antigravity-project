import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/hot_theme.dart';
import 'presentation/providers/hot_wallet_provider.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/setup_watch_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CardanoHotApp()));
}

class CardanoHotApp extends ConsumerWidget {
  const CardanoHotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hotWalletProvider);

    return MaterialApp(
      title: 'Cardano Hot Wallet',
      debugShowCheckedModeBanner: false,
      theme: HotTheme.darkTheme,
      builder: (context, child) {
        return Container(
          color: const Color(0xFF080A0E), // Nền tối trang trọng khi mở trên Desktop / Tablet
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480), // Mobile-First Form Factor
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipRect(
                child: child ?? const SizedBox(),
              ),
            ),
          ),
        );
      },
      home: state.watchedAddress != null ? const DashboardScreen() : const SetupWatchScreen(),
    );
  }
}
