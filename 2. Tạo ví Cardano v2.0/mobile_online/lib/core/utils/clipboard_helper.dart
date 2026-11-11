import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tiện ích hỗ trợ Sao Chép & Dán từ Clipboard tối ưu cho Web và Di Động (iOS / Android)
class ClipboardHelper {
  /// Sao chép chuỗi vào Clipboard kèm SnackBar thông báo ngắn gọn
  static Future<void> copy(
    BuildContext context,
    String text, {
    String message = "Đã sao chép vào bộ nhớ tạm!",
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: clean));
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Dán chuỗi từ Clipboard vào ô nhập liệu
  static Future<String?> paste(
    BuildContext context, {
    TextEditingController? targetController,
    void Function(String)? onChanged,
    String? fieldName,
  }) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();

      if (text == null || text.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Bộ nhớ tạm (Clipboard) đang trống!",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return null;
      }

      if (targetController != null) {
        targetController.text = text;
        targetController.selection = TextSelection.collapsed(offset: text.length);
      }

      if (onChanged != null) {
        onChanged(text);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final displayPreview = text.length > 20 ? "${text.substring(0, 10)}...${text.substring(text.length - 8)}" : text;
        final nameInfo = fieldName != null ? " vào $fieldName" : "";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.paste_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Đã dán$nameInfo: $displayPreview",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      return text;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Không thể đọc bộ nhớ tạm: $e. Hãy cho phép quyền truy cập Clipboard trong cài đặt trình duyệt.",
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.red[900],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return null;
    }
  }
}
