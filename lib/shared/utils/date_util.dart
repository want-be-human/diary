/// 日期格式化工具。
class DateUtil {
  DateUtil._();

  /// 列表卡片用的相对时间：
  /// - 1 分钟内：刚刚
  /// - 1 小时内：N 分钟前
  /// - 当天：N 小时前
  /// - 昨天
  /// - 7 天内：N 天前
  /// - 当年：MM-DD
  /// - 跨年：YYYY-MM-DD
  static String relative(DateTime time, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(time);

    if (diff.isNegative) {
      // 时间在未来（钟差异），按"刚刚"处理。
      return '刚刚';
    }
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';

    final isSameDay =
        ref.year == time.year && ref.month == time.month && ref.day == time.day;
    if (isSameDay) return '${diff.inHours} 小时前';

    final yesterday = DateTime(ref.year, ref.month, ref.day)
        .subtract(const Duration(days: 1));
    final isYesterday = time.year == yesterday.year &&
        time.month == yesterday.month &&
        time.day == yesterday.day;
    if (isYesterday) return '昨天';

    if (diff.inDays < 7) return '${diff.inDays} 天前';

    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    if (ref.year == time.year) return '$m-$d';
    return '${time.year}-$m-$d';
  }

  /// 简短日期：当年 MM-DD，跨年 YYYY-MM-DD。用于时间轴节点等只需要日期不
  /// 需要相对语义的场合。
  static String short(DateTime time, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    if (ref.year == time.year) return '$m-$d';
    return '${time.year}-$m-$d';
  }

  /// 完整日期 YYYY-MM-DD HH:MM。
  static String full(DateTime time) {
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '${time.year}-$m-$d $hh:$mm';
  }
}
