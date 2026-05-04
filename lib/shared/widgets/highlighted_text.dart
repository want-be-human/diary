import 'package:flutter/material.dart';

/// 把 [text] 中匹配 [query] 的子串用 [highlightColor] 背景标出来。
/// 大小写不敏感；空 query 退化为普通 [Text]。
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.highlightColor,
    this.boldMatches = true,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final Color? highlightColor;
  final bool boldMatches;

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty || text.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    final theme = Theme.of(context);
    final hl =
        highlightColor ?? theme.colorScheme.primary.withValues(alpha: 0.22);
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final ql = q.toLowerCase();
    var i = 0;
    while (i < text.length) {
      final idx = lower.indexOf(ql, i);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (idx > i) {
        spans.add(TextSpan(text: text.substring(i, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + ql.length),
        style: TextStyle(
          backgroundColor: hl,
          fontWeight: boldMatches ? FontWeight.w600 : null,
        ),
      ));
      i = idx + ql.length;
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
