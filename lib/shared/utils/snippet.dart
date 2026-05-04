/// 从长正文中抽取命中关键词周围的窗口片段，用于搜索结果预览。
///
/// 给定 [body] 和 [query]，返回最多 [max] 条片段，每条以命中位置为中心，
/// 前后各保留 [window] 个字符；越界用 `…` 截断。
/// 命中位置不重叠（每次从上一命中尾继续找）。换行折成空格便于一行展示。
class SnippetExtractor {
  SnippetExtractor._();

  static List<String> extract(
    String body,
    String query, {
    int max = 3,
    int window = 50,
  }) {
    final q = query.trim();
    if (q.isEmpty || body.isEmpty) return const [];
    final lower = body.toLowerCase();
    final ql = q.toLowerCase();
    final out = <String>[];
    var from = 0;
    while (out.length < max) {
      final idx = lower.indexOf(ql, from);
      if (idx == -1) break;
      final start = (idx - window).clamp(0, body.length);
      final end = (idx + ql.length + window).clamp(0, body.length);
      final raw = body.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
      final prefix = start > 0 ? '…' : '';
      final suffix = end < body.length ? '…' : '';
      out.add('$prefix$raw$suffix');
      from = idx + ql.length;
    }
    return out;
  }
}
