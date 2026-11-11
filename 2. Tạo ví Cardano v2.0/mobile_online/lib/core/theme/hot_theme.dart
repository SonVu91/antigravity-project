import 'package:flutter/material.dart';

class HotTheme {
  // Chế độ Ví Nóng (Warm Amber / Energetic Gold — Phân biệt hoàn toàn với Xanh Lạnh & Đỏ Báo Động)
  static const Color primary = Color(0xFFD97706);       // Amber 600
  static const Color accent = Color(0xFFF59E0B);        // Amber 500 (Hot Gold Accent)
  static const Color background = Color(0xFF111318);    // Deep Carbon Dark
  static const Color surface = Color(0xFF1C2029);       // Elevated Carbon Surface
  static const Color cardColor = Color(0xFF1C2029);
  static const Color border = Color(0xFF2E3440);
  static const Color textPrimary = Color(0xFFF8FAFC);   // Crisp White for Balances
  static const Color textMuted = Color(0xFF94A3B8);

  // Ngữ nghĩa bảo mật (Màu Đỏ chỉ dành riêng cho Lỗi / Cảnh báo nguy hiểm)
  static const Color safeGreen = Color(0xFF10B981);
  static const Color dangerRed = Color(0xFFEF4444);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: accent, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),
      cardTheme: CardTheme(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        elevation: 2,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
    );
  }

  static Widget buildLiveNetworkBadge({String networkName = "PREPROD TESTNET", VoidCallback? onTap}) {
    final isMainnet = networkName.toUpperCase().contains("MAINNET");
    final dotColor = isMainnet ? safeGreen : accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primary.withOpacity(0.22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
            const SizedBox(width: 8),
            Text(
              "VÍ TRỰC TUYẾN - $networkName",
              style: const TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 16, color: accent),
            ],
          ],
        ),
      ),
    );
  }

  /// Thanh tiến trình 3 bước của luồng giao dịch Air-Gap trên Ví Nóng
  static Widget buildAirGapStepHeader({
    required int currentStep,
    required String stepTitle,
    String? subtitle,
  }) {
    final steps = [
      (1, "1. Tạo txRaw"),
      (2, "2. Ký Ví Lạnh"),
      (3, "3. Phát Sóng"),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    decoration: BoxDecoration(
                      color: steps[i].$1 == currentStep
                          ? accent.withOpacity(0.2)
                          : (steps[i].$1 < currentStep
                              ? safeGreen.withOpacity(0.15)
                              : Colors.black26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: steps[i].$1 == currentStep
                            ? accent
                            : (steps[i].$1 < currentStep
                                ? safeGreen.withOpacity(0.6)
                                : Colors.white12),
                        width: steps[i].$1 == currentStep ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          steps[i].$1 < currentStep
                              ? Icons.check_circle
                              : (steps[i].$1 == currentStep
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked),
                          size: 13,
                          color: steps[i].$1 == currentStep
                              ? accent
                              : (steps[i].$1 < currentStep ? safeGreen : textMuted),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            steps[i].$2,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: steps[i].$1 == currentStep
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: steps[i].$1 == currentStep
                                  ? Colors.white
                                  : (steps[i].$1 < currentStep
                                      ? safeGreen
                                      : textMuted),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < steps.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_right, size: 16, color: textMuted),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stepTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Tô sáng 8 ký tự đầu (sau tiền tố addr1/addr_test1) và 8 ký tự cuối để chống Address Poisoning
  static Widget buildHighlightedAddress(
    String address, {
    Color? highlightColor,
    double fontSize = 12.5,
    TextAlign textAlign = TextAlign.start,
  }) {
    final hl = highlightColor ?? accent;
    if (address.length <= 24) {
      return SelectableText(
        address,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          color: hl,
        ),
      );
    }

    int prefixEnd = 0;
    if (address.startsWith('addr_test1')) {
      prefixEnd = 10;
    } else if (address.startsWith('addr1')) {
      prefixEnd = 5;
    } else if (address.startsWith('stake_test1')) {
      prefixEnd = 11;
    } else if (address.startsWith('stake1')) {
      prefixEnd = 6;
    }

    final int headEnd = (prefixEnd + 8).clamp(0, address.length - 8);
    final int tailStart = (address.length - 8).clamp(headEnd, address.length);

    final prefix = address.substring(0, prefixEnd);
    final head8 = address.substring(prefixEnd, headEnd);
    final middle = address.substring(headEnd, tailStart);
    final tail8 = address.substring(tailStart);

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: 'monospace',
          height: 1.4,
        ),
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: prefix,
              style: const TextStyle(color: textMuted, fontWeight: FontWeight.w600),
            ),
          TextSpan(
            text: head8,
            style: TextStyle(
              color: hl,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: hl.withOpacity(0.6),
            ),
          ),
          TextSpan(
            text: middle,
            style: const TextStyle(color: Colors.white70),
          ),
          TextSpan(
            text: tail8,
            style: TextStyle(
              color: hl,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: hl.withOpacity(0.6),
            ),
          ),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
