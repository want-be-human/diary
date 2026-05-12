import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../shared/utils/date_util.dart';

/// 日历热力图视图：GitHub 贡献图风格的年度方格。
///
/// quantile 跨年度计算——切年份格子色阶稳定可比，比"按当年 quantile"直观。
/// 周一作为一周首日（跟中国惯例一致；CN locale 没有内置的 weekday-first 处理）。
class HeatmapView extends ConsumerStatefulWidget {
  const HeatmapView({super.key, this.category});

  final EntryCategory? category;

  @override
  ConsumerState<HeatmapView> createState() => _HeatmapViewState();
}

class _HeatmapViewState extends ConsumerState<HeatmapView> {
  late int _year = DateTime.now().year;

  /// 上一次喂给 _HeatmapData.build 的 entries 列表引用——stream 反复推同一
  /// 列表（或 setState 触发 build 重跑）时跳过 O(n log n) 的 quantile 排序。
  /// 列表引用变就重新算；其它情况复用 _cachedData。
  List<Entry>? _lastEntries;
  _HeatmapData? _cachedData;

  _HeatmapData _dataFor(List<Entry> entries) {
    if (identical(entries, _lastEntries) && _cachedData != null) {
      return _cachedData!;
    }
    _lastEntries = entries;
    return _cachedData = _HeatmapData.build(entries);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(entryRepositoryProvider);
    if (repo == null) return const Center(child: Text('未登录'));

    return StreamBuilder<List<Entry>>(
      stream: repo.watchAll(category: widget.category),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snap.data ?? const <Entry>[];
        if (entries.isEmpty) {
          return _empty(context);
        }
        final data = _dataFor(entries);
        return Column(
          children: [
            _YearSwitcher(
              year: _year,
              minYear: data.minYear,
              maxYear: data.maxYear,
              onChange: (y) => setState(() => _year = y),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                child: _YearGrid(
                  year: _year,
                  data: data,
                  onTapDay: (day) => _openDaySheet(context, day, data),
                ),
              ),
            ),
            _Legend(data: data),
          ],
        );
      },
    );
  }

  void _openDaySheet(BuildContext context, DateTime day, _HeatmapData data) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _DaySheet(day: day, entries: data.entriesOn(day)),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grid_on_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.32),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有内容\n写下第一篇日记，方格就会亮起来',
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

class _HeatmapData {
  _HeatmapData._({
    required Map<DateTime, List<Entry>> byDay,
    required Map<DateTime, int> byDayWeight,
    required this.thresholds,
    required this.minYear,
    required this.maxYear,
    required this.maxWeight,
  })  : _byDay = byDay,
        _byDayWeight = byDayWeight;

  final Map<DateTime, List<Entry>> _byDay;
  final Map<DateTime, int> _byDayWeight;

  /// 4 个阈值，按 [25%, 50%, 75%, 95%] 分位；用于把 dayWeight 分到 5 档。
  final List<int> thresholds;
  final int maxWeight;
  final int minYear;
  final int maxYear;

  static _HeatmapData build(List<Entry> entries) {
    final now = DateTime.now();
    if (entries.isEmpty) {
      return _HeatmapData._(
        byDay: const {},
        byDayWeight: const {},
        thresholds: const [0, 0, 0, 0],
        minYear: now.year,
        maxYear: now.year,
        maxWeight: 0,
      );
    }

    final byDay = <DateTime, List<Entry>>{};
    var minYear = entries.first.createdAt.year;
    var maxYear = minYear;
    for (final e in entries) {
      final key = _dayKey(e.createdAt);
      byDay.putIfAbsent(key, () => []).add(e);
      final y = e.createdAt.year;
      if (y < minYear) minYear = y;
      if (y > maxYear) maxYear = y;
    }

    final byDayWeight = <DateTime, int>{};
    byDay.forEach((day, list) {
      var w = 0;
      for (final e in list) {
        w += _weightOf(e);
      }
      byDayWeight[day] = w;
    });

    final weights = byDayWeight.values.toList()..sort();
    int q(double p) =>
        weights[(p * (weights.length - 1)).round().clamp(0, weights.length - 1)];

    return _HeatmapData._(
      byDay: byDay,
      byDayWeight: byDayWeight,
      thresholds: [q(0.25), q(0.50), q(0.75), q(0.95)],
      minYear: minYear,
      // maxYear 至少跟今年同高——便于"今年没数据但还在写"的初始体验。
      maxYear: maxYear > now.year ? maxYear : now.year,
      maxWeight: weights.last,
    );
  }

  List<Entry> entriesOn(DateTime day) =>
      _byDay[_dayKey(day)] ?? const <Entry>[];

  int weightOnKey(DateTime dayKey) => _byDayWeight[dayKey] ?? 0;

  /// 0 = 无活动；1..4 = 按 quantile 递增。
  int levelOfKey(DateTime dayKey) {
    final w = _byDayWeight[dayKey] ?? 0;
    if (w <= 0) return 0;
    for (var i = 0; i < thresholds.length; i++) {
      if (w <= thresholds[i]) return i + 1;
    }
    return thresholds.length;
  }
}

/// diary：实际字数+保底 50（避免短日记成稀疏点）。
/// project/todo：固定 50（一条记录就贡献一点温度，热力图才有意义）。
int _weightOf(Entry e) {
  if (e.category == EntryCategory.diary) {
    return e.wordCount < 50 ? 50 : e.wordCount;
  }
  return 50;
}

DateTime _dayKey(DateTime t) => DateTime(t.year, t.month, t.day);

const _weekdayCn = ['一', '二', '三', '四', '五', '六', '日'];

/// 5 档色阶 alpha 系数；level=0 走 base 色不在这里取。
const _levelAlphas = [0.0, 0.25, 0.45, 0.7, 0.95];

class _HeatmapPalette {
  _HeatmapPalette._(this.base, this.accent);
  final Color base;
  final Color accent;

  factory _HeatmapPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return _HeatmapPalette._(
      isDark
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      isDark ? AppColors.inkSageDark : AppColors.inkSage,
    );
  }

  Color colorForLevel(int level) =>
      level == 0 ? base : accent.withValues(alpha: _levelAlphas[level]);
}

class _YearSwitcher extends StatelessWidget {
  const _YearSwitcher({
    required this.year,
    required this.minYear,
    required this.maxYear,
    required this.onChange,
  });

  final int year;
  final int minYear;
  final int maxYear;
  final void Function(int) onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPrev = year > minYear;
    final canNext = year < maxYear;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: '上一年',
            icon: const Icon(Icons.chevron_left),
            onPressed: canPrev ? () => onChange(year - 1) : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$year 年',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '下一年',
            icon: const Icon(Icons.chevron_right),
            onPressed: canNext ? () => onChange(year + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _YearGrid extends StatelessWidget {
  const _YearGrid({
    required this.year,
    required this.data,
    required this.onTapDay,
  });

  final int year;
  final _HeatmapData data;
  final void Function(DateTime) onTapDay;

  static const double _cellSize = 14;
  static const double _cellGap = 3;
  static const double _weekdayLabelWidth = 24;
  static const double _monthLabelHeight = 18;

  @override
  Widget build(BuildContext context) {
    final jan1 = DateTime(year, 1, 1);
    final dec31 = DateTime(year, 12, 31);
    // firstCell = Jan 1 那周的周一（可能在上一年 12 月底）。
    final firstCell = jan1.subtract(Duration(days: jan1.weekday - 1));
    final lastCell = dec31.add(Duration(days: 7 - dec31.weekday));
    final cols = (lastCell.difference(firstCell).inDays + 1) ~/ 7;

    final width = _weekdayLabelWidth + cols * (_cellSize + _cellGap);
    final height = _monthLabelHeight + 7 * (_cellSize + _cellGap);

    return SizedBox(
      width: width,
      height: height,
      // 横向滚动——一年 52-53 列，窄屏装不下。
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              _MonthLabels(year: year, firstCell: firstCell, columns: cols),
              const Positioned(
                left: 0,
                top: _monthLabelHeight,
                child: _WeekdayLabels(cellSize: _cellSize, cellGap: _cellGap),
              ),
              Positioned(
                left: _weekdayLabelWidth,
                top: _monthLabelHeight,
                child: _Cells(
                  year: year,
                  firstCell: firstCell,
                  columns: cols,
                  cellSize: _cellSize,
                  cellGap: _cellGap,
                  data: data,
                  onTap: onTapDay,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthLabels extends StatelessWidget {
  const _MonthLabels({
    required this.year,
    required this.firstCell,
    required this.columns,
  });

  final int year;
  final DateTime firstCell;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final children = <Widget>[];
    int? prevMonth;
    for (var c = 0; c < columns; c++) {
      final date = firstCell.add(Duration(days: c * 7));
      if (date.year != year) continue;
      if (prevMonth != date.month) {
        prevMonth = date.month;
        children.add(Positioned(
          left: _YearGrid._weekdayLabelWidth +
              c * (_YearGrid._cellSize + _YearGrid._cellGap),
          top: 0,
          child: Text(
            '${date.month} 月',
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ));
      }
    }
    return SizedBox(
      width: double.infinity,
      height: _YearGrid._monthLabelHeight,
      child: Stack(children: children),
    );
  }
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels({required this.cellSize, required this.cellGap});
  final double cellSize;
  final double cellGap;

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return SizedBox(
      width: _YearGrid._weekdayLabelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 7; i++)
            SizedBox(
              height: cellSize + cellGap,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  // 隔行才显示，跟 GitHub 同节奏——避免列标签密成一团。
                  i.isOdd ? '' : _weekdayCn[i],
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: color, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cells extends StatelessWidget {
  const _Cells({
    required this.year,
    required this.firstCell,
    required this.columns,
    required this.cellSize,
    required this.cellGap,
    required this.data,
    required this.onTap,
  });

  final int year;
  final DateTime firstCell;
  final int columns;
  final double cellSize;
  final double cellGap;
  final _HeatmapData data;
  final void Function(DateTime) onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _HeatmapPalette.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final today = _dayKey(DateTime.now());

    return SizedBox(
      width: columns * (cellSize + cellGap),
      height: 7 * (cellSize + cellGap),
      child: Stack(
        children: [
          for (var c = 0; c < columns; c++)
            for (var r = 0; r < 7; r++)
              _cell(c, r, palette, primary, today),
        ],
      ),
    );
  }

  Widget _cell(
    int col,
    int row,
    _HeatmapPalette palette,
    Color primaryColor,
    DateTime today,
  ) {
    final date = firstCell.add(Duration(days: col * 7 + row));
    final inYear = date.year == year;
    final left = col * (cellSize + cellGap);
    final top = row * (cellSize + cellGap);

    if (!inYear) {
      return Positioned(
        left: left,
        top: top,
        child: SizedBox(width: cellSize, height: cellSize),
      );
    }

    final key = _dayKey(date);
    final level = data.levelOfKey(key);
    final isToday = key == today;
    final cellWidget = Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        color: palette.colorForLevel(level),
        borderRadius: BorderRadius.circular(3),
        border: isToday
            ? Border.all(color: primaryColor, width: 1.5)
            : null,
      ),
    );

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => onTap(date),
        // Tooltip 只挂在有内容的格子上——空格子没必要弹"0 权重"，也省下
        // 370 个空 Tooltip 维护 overlay state 的开销。
        child: level == 0
            ? cellWidget
            : Tooltip(
                message:
                    '${DateUtil.short(date)} · ${data.weightOnKey(key)}',
                child: cellWidget,
              ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.data});
  final _HeatmapData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = _HeatmapPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Text(
            '少',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 6),
          for (var i = 0; i < 5; i++) ...[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: palette.colorForLevel(i),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 3),
          ],
          const SizedBox(width: 3),
          Text(
            '多',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const Spacer(),
          if (data.maxWeight > 0)
            Text(
              '最多一天 ≈ ${data.maxWeight}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.day, required this.entries});
  final DateTime day;
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${day.year}-$m-$d · 周${_weekdayCn[day.weekday - 1]}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entries.isEmpty
                  ? '这一天没有任何条目'
                  : '共 ${entries.length} 条',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '点击「新建」按钮在这天补一条',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _DaySheetRow(entry: entries[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DaySheetRow extends StatelessWidget {
  const _DaySheetRow({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ink = entry.category.inkColor(isDark: isDark);
    final hh = entry.createdAt.hour.toString().padLeft(2, '0');
    final mm = entry.createdAt.minute.toString().padLeft(2, '0');

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          GoRouter.of(context).push('/entry/${entry.id}');
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.title.isEmpty ? '（无标题）' : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$hh:$mm',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
