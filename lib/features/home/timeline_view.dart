import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../shared/utils/text_util.dart';

/// 时间线视图：按 月 → 日 两级分组的垂直时间轴。
///
/// 跟列表视图复用同一个 `repo.watchAll(category:)` 流，所以筛选芯片切换时
/// 数据切换是即时的；本组件只负责呈现。
///
/// 渲染策略：
/// - 不用 SliverStickyHeader（避免再引一个包），改用扁平化的 items 序列：
///   `_MonthHeader / _DayGroup` 交替排，由 ListView.builder 渲染
/// - 同一天的多条 entry 合并到 _DayGroup 内部，节省垂直空间
/// - 左侧 56px 的轨道画时间线：月头是粗实心圆点 + 月份；日头是空心小点 + 日数
class TimelineView extends ConsumerWidget {
  const TimelineView({super.key, this.category});

  /// 跟 `_EntryList` 同语义：null = 全部，其它 = 按类目过滤。
  final EntryCategory? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entryRepositoryProvider);
    if (repo == null) return const Center(child: Text('未登录'));

    return StreamBuilder<List<Entry>>(
      stream: repo.watchAll(category: category),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snap.data ?? const <Entry>[];
        if (entries.isEmpty) {
          return _empty(context);
        }
        final items = _buildItems(entries);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 96),
          itemCount: items.length,
          itemBuilder: (_, i) => items[i].build(context),
        );
      },
    );
  }

  /// 把 entries 折叠成扁平的渲染项序列：
  /// `[MonthHeader(2026-05), DayGroup(12), DayGroup(11), MonthHeader(2026-04), ...]`
  /// 入口数据已经是 updatedAt 降序，这里按 createdAt 重排——「日记当天写的」
  /// 比「过几天回来改的」更符合用户对"时间线"的直觉。
  static List<_Item> _buildItems(List<Entry> entries) {
    final sorted = [...entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final out = <_Item>[];
    int? curYear, curMonth, curDay;
    var currentDayEntries = <Entry>[];

    void flushDay() {
      if (currentDayEntries.isEmpty) return;
      out.add(_DayItem(
        day: curDay!,
        weekday: currentDayEntries.first.createdAt.weekday,
        entries: List.unmodifiable(currentDayEntries),
      ));
      currentDayEntries = [];
    }

    for (final e in sorted) {
      final t = e.createdAt;
      if (t.year != curYear || t.month != curMonth) {
        flushDay();
        out.add(_MonthItem(year: t.year, month: t.month));
        curYear = t.year;
        curMonth = t.month;
        curDay = null;
      }
      if (t.day != curDay) {
        flushDay();
        curDay = t.day;
      }
      currentDayEntries.add(e);
    }
    flushDay();
    return out;
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.32),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有内容\n时间线在你写下第一条之后展开',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 时间线 item 基类：让 ListView.builder 拿同质 List 就行。
sealed class _Item {
  const _Item();
  Widget build(BuildContext context);
}

class _MonthItem extends _Item {
  const _MonthItem({required this.year, required this.month});
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkUmberDark : AppColors.inkUmber;
    final now = DateTime.now();
    final showYear = year != now.year;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: ink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              showYear ? '$year 年 $month 月' : '$month 月',
              style: theme.textTheme.titleSmall?.copyWith(
                color: ink,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          // 月段下面的细分隔横线：拉到 row 末端给视觉一个清晰的分组。
          Container(
            width: 24,
            height: 1,
            margin: const EdgeInsets.only(left: 8),
            color: scheme.onSurface.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}

class _DayItem extends _Item {
  const _DayItem({
    required this.day,
    required this.weekday,
    required this.entries,
  });

  final int day;
  final int weekday;
  final List<Entry> entries;

  static const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = scheme.onSurface.withValues(alpha: isDark ? 0.18 : 0.12);
    final isWeekend = weekday == DateTime.saturday || weekday == DateTime.sunday;
    final dayColor = isWeekend
        ? (isDark ? AppColors.inkDustyDark : AppColors.inkDusty)
        : scheme.onSurface.withValues(alpha: 0.7);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧 56px 轨道：日数字 + 周几 + 贯穿的细竖线。
          SizedBox(
            width: 56,
            child: Stack(
              children: [
                // 竖线：占满全高，撑起多条 entry 的"日子"。
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 1.5,
                      color: lineColor,
                    ),
                  ),
                ),
                // 日期方块 + 圆点：放在最顶部，跟首条 entry 卡片对齐。
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Text(
                        day.toString().padLeft(2, '0'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: dayColor,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '周${_weekdayNames[weekday - 1]}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: dayColor.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: dayColor, width: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 右侧条目列：当天可能有多条，纵向堆叠紧凑卡片。
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TimelineEntryCard(entry: e),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 时间线里的条目卡片——比首页列表卡片更紧凑（去掉左色条、归档手势、入场动画），
/// 只保留：类目徽章 + 标题 + 摘要 + 时间。点击进详情。
class _TimelineEntryCard extends StatelessWidget {
  const _TimelineEntryCard({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final completed = entry.isCompleted;
    final hasCompletionState = entry.category == EntryCategory.todo ||
        entry.category == EntryCategory.project;
    final cardColor = hasCompletionState && completed
        ? (isDark ? AppColors.darkSurfaceUsed : AppColors.lightSurfaceUsed)
        : null;

    final ink = entry.category.inkColor(isDark: isDark);

    final hh = entry.createdAt.hour.toString().padLeft(2, '0');
    final mm = entry.createdAt.minute.toString().padLeft(2, '0');

    return Material(
      color: cardColor ?? scheme.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => GoRouter.of(context).push('/entry/${entry.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.category.displayLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (entry.isPinned) ...[
                    Icon(Icons.push_pin, size: 12, color: scheme.primary),
                    const SizedBox(width: 4),
                  ],
                  if (entry.category == EntryCategory.todo)
                    Icon(
                      completed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color: completed
                          ? (isDark
                              ? AppColors.statusDoneDark
                              : AppColors.statusDone)
                          : scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  const Spacer(),
                  if (entry.mood != null) ...[
                    Text(entry.mood!.emoji,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    '$hh:$mm',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                entry.title.isEmpty ? '（无标题）' : entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: entry.category == EntryCategory.todo && completed
                      ? TextDecoration.lineThrough
                      : null,
                  color: entry.category == EntryCategory.todo && completed
                      ? scheme.onSurface.withValues(alpha: 0.55)
                      : null,
                ),
              ),
              ..._snippetForCategory(theme, entry),
            ],
          ),
        ),
      ),
    );
  }

  /// 卡片正文摘要——跟列表卡片同语义，但更短（80 字 → 50 字）。
  List<Widget> _snippetForCategory(ThemeData theme, Entry e) {
    String? snippet;
    switch (e.category) {
      case EntryCategory.diary:
        final plain = TextUtil.extractPlainText(e.contentDelta).trim();
        if (plain.isEmpty) return const [];
        final flat = plain.replaceAll(RegExp(r'\s+'), ' ');
        snippet = flat.length <= 50 ? flat : '${flat.substring(0, 50)}…';
      case EntryCategory.project:
        final pm = e.projectMeta;
        if (pm == null) return const [];
        final pieces = <String>[];
        if (pm.projectName.isNotEmpty) pieces.add(pm.projectName);
        if (pm.version.isNotEmpty) pieces.add('v${pm.version}');
        if (pm.completedItems.isNotEmpty) {
          pieces.add('${pm.completedItems.length} 项完成');
        }
        if (pieces.isEmpty) return const [];
        snippet = pieces.join(' · ');
      case EntryCategory.todo:
        if (e.subtasks.isEmpty) return const [];
        final done = e.subtasks.where((t) => t.done).length;
        snippet = '$done / ${e.subtasks.length} 已完成';
    }
    return [
      const SizedBox(height: 4),
      Text(
        snippet,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          height: 1.4,
        ),
      ),
    ];
  }
}
