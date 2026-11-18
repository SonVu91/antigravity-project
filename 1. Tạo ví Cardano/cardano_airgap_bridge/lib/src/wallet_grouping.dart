/// Logic gom nhóm và sắp xếp ví theo tên
/// Quy tắc:
/// - Tự động gom nhóm các ví có từ đầu tiên trước dấu gạch ngang (-) vào nhóm.
/// - Nếu tên ví không có dấu gạch ngang (-), gom vào nhóm mặc định 'Chung'.
/// - Tên nhóm và danh sách ví trong mỗi nhóm được sắp xếp A-Z (không phân biệt hoa/thường).
class WalletGroup<T> {
  final String groupName;
  final List<T> wallets;

  WalletGroup({
    required this.groupName,
    required this.wallets,
  });
}

/// Trích xuất tên nhóm từ tên ví.
/// Lấy từ đầu tiên trước dấu gạch ngang (-). Nếu không có, trả về 'Chung'.
String extractGroupName(String walletName) {
  final trimmed = walletName.trim();
  final hyphenIndex = trimmed.indexOf('-');
  if (hyphenIndex > 0) {
    final prefix = trimmed.substring(0, hyphenIndex).trim();
    if (prefix.isNotEmpty) {
      return prefix;
    }
  }
  return 'Chung';
}

/// Gom nhóm và sắp xếp danh sách ví theo thứ tự A-Z
List<WalletGroup<T>> groupAndSortWallets<T>({
  required List<T> wallets,
  required String Function(T) getName,
}) {
  final Map<String, List<T>> groupsMap = {};
  final Map<String, String> displayGroupNames = {};

  for (final w in wallets) {
    final name = getName(w);
    final group = extractGroupName(name);
    final key = group.toLowerCase();

    if (!groupsMap.containsKey(key)) {
      groupsMap[key] = [];
      displayGroupNames[key] = group;
    }
    groupsMap[key]!.add(w);
  }

  // Sắp xếp các nhóm A-Z (case-insensitive)
  final sortedKeys = groupsMap.keys.toList()
    ..sort((a, b) => a.compareTo(b));

  final List<WalletGroup<T>> result = [];
  for (final key in sortedKeys) {
    final groupWallets = groupsMap[key]!;
    // Sắp xếp các ví trong nhóm A-Z theo tên ví (case-insensitive)
    groupWallets.sort((a, b) => getName(a).toLowerCase().compareTo(getName(b).toLowerCase()));
    result.add(WalletGroup<T>(
      groupName: displayGroupNames[key] ?? key,
      wallets: groupWallets,
    ));
  }

  return result;
}

/// Gợi ý tên ví mặc định tiếp theo theo định dạng 'Chung-Ví <N>'
String suggestNextWalletName<T>(
  List<T> existingWallets,
  String Function(T) getName, {
  String prefix = "Chung-Ví",
}) {
  int maxIndex = 0;
  final regex = RegExp('^' + RegExp.escape(prefix) + r'\s*(\d+)$', caseSensitive: false);
  for (final w in existingWallets) {
    final name = getName(w).trim();
    final match = regex.firstMatch(name);
    if (match != null) {
      final val = int.tryParse(match.group(1) ?? '0') ?? 0;
      if (val > maxIndex) maxIndex = val;
    }
  }
  return '$prefix ${maxIndex + 1}';
}

/// Gợi ý tên ví con tiếp theo khi phân nhánh từ một ví gốc: '<Tên ví gốc> #2', '#3'...
String suggestNextDerivedWalletName<T>(
  List<T> existingWallets,
  String Function(T) getName,
  String parentName,
) {
  final cleanBase = parentName.replaceFirst(RegExp(r'\s*#\d+$'), '').trim();
  int nextNum = 2;
  while (existingWallets.any((w) => getName(w).trim().toLowerCase() == '$cleanBase #$nextNum'.toLowerCase())) {
    nextNum++;
  }
  return '$cleanBase #$nextNum';
}

