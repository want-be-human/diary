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

  /// 中英混排字数：每个有效字符（汉字 / 字母 / 数字）算 1。
  /// 不计空白与标点。
  ///
  /// 与"按词切分"的英文统计不同——这里 "12345" 算 5 字，"hello" 算 5 字，
  /// 跟中文 "你好" 算 2 字 一致，对个人日记的"今天写了多少字"语义更直观。
  static int countWords(String text) {
    if (text.isEmpty) return 0;
    // \p{L} 任意 Unicode 字母（含 CJK / 拉丁 / 西里尔等），\p{N} 任意数字。
    // 标点 \p{P}、符号 \p{S}、空白 \p{Z}、控制字符 \p{C} 全部不计。
    return RegExp(r'[\p{L}\p{N}]', unicode: true).allMatches(text).length;
  }

  /// 给定 Delta JSON 直接返回字数。
  static int countWordsInDelta(String delta) =>
      countWords(extractPlainText(delta));
}
