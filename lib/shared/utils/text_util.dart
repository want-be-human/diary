import 'dart:convert';

/// Quill Delta JSON 与字数处理的共享工具。
class TextUtil {
  TextUtil._();

  /// 从 Quill Delta JSON 字符串中提取纯文本。
  /// Delta 形如 `{"ops":[{"insert":"hello\n"},{"insert":{"image":"..."}}]}`，
  /// 只把字符串型 insert 拼起来；非字符串 insert（图片/视频 embed）忽略。
  /// 解析失败时退化为原字符串。
  static String extractPlainText(String delta) {
    try {
      final parsed = jsonDecode(delta);
      final ops = parsed is Map ? parsed['ops'] : parsed;
      if (ops is List) {
        final buf = StringBuffer();
        for (final op in ops) {
          if (op is Map && op['insert'] is String) {
            buf.write(op['insert']);
          }
        }
        return buf.toString();
      }
    } catch (_) {
      // 不是合法 Delta JSON；当成纯文本本身。
    }
    return delta;
  }

  /// 中英混排字数：每个汉字算 1，连续英文/数字串算 1（按空白切）。
  /// 不计空白与标点。
  static int countWords(String text) {
    if (text.isEmpty) return 0;
    final chineseCount = RegExp(r'[一-鿿]').allMatches(text).length;
    final stripped = text.replaceAll(RegExp(r'[一-鿿]'), ' ');
    final trimmed = stripped.trim();
    if (trimmed.isEmpty) return chineseCount;
    final englishCount =
        trimmed.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    return chineseCount + englishCount;
  }

  /// 给定 Delta JSON 直接返回字数。
  static int countWordsInDelta(String delta) =>
      countWords(extractPlainText(delta));
}
