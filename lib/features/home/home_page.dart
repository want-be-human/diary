import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../data/services/daily_quote_service.dart';
import '../../shared/utils/date_util.dart';
import '../../shared/utils/text_util.dart';
import 'timeline_view.dart';

/// 首页视图：列表 / 时间线 / 热力图。热力图待 stage 15 完成。
enum HomeViewMode { list, timeline, heatmap }

/// 首页 v2（方案 A）：
/// - AppBar：可点击搜索 pill + 设置图标
/// - 顶部：每日一言卡片（hitokoto.cn）
/// - 过滤芯片：全部 / 日记 / 项目 / 待办
/// - 列表：Dismissible 卡片，左滑 → 归档（带 Undo）
/// - 置顶段始终在顶
/// - 待办/项目：卡片底色按完成态变化
/// - FAB：当前过滤为 全部 时弹底部表单选类目，否则直接以当前类目新建
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// 0 = 全部 / 1 = 日记 / 2 = 项目 / 3 = 待办
  int _filter = 0;

  /// 列表 / 时间线 / 热力图——切换不重新拉数据，仅换 widget。
  HomeViewMode _view = HomeViewMode.list;

  EntryCategory? get _currentCategory => switch (_filter) {
        1 => EntryCategory.diary,
        2 => EntryCategory.project,
        3 => EntryCategory.todo,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(entryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const _SearchPill(),
        actions: [
          _ViewModeToggle(
            mode: _view,
            onChange: (m) => setState(() => _view = m),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: repo == null
          ? const _EmptyState(message: '请先登录以查看日记')
          : Column(
              children: [
                const _DailyQuoteCard(),
                _FilterChipRow(
                  selected: _filter,
                  onChange: (v) => setState(() => _filter = v),
                ),
                // 选了项目 Tab 时显示「项目聚合」入口——按 projectName 归集
                // 视图，对长期跨多 entry 的项目维护很有用，平 Tab 流体验里
                // 看不出来这层。日记 / 待办 Tab 暂无聚合视图，不渲染。
                if (_currentCategory == EntryCategory.project)
                  const _ProjectsEntry(),
                const SizedBox(height: 4),
                Expanded(
                  // AnimatedSwitcher 切换三视图，子组件用 KeyedSubtree 携带
                  // 一个独立 key，触发淡入淡出过渡（spec 要求"切换有渐变过渡"）。
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey('${_view.name}-$_filter'),
                      child: _viewBody(),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _viewBody() {
    switch (_view) {
      case HomeViewMode.list:
        return _EntryList(category: _currentCategory);
      case HomeViewMode.timeline:
        return TimelineView(category: _currentCategory);
      case HomeViewMode.heatmap:
        // stage 15 接入；先给个友好占位避免点了无反应。
        return const _ComingSoonHeatmap();
    }
  }

  Widget? _buildFab(BuildContext context) {
    final cat = _currentCategory;
    if (cat != null) {
      final label = switch (cat) {
        EntryCategory.diary => '写日记',
        EntryCategory.project => '记项目',
        EntryCategory.todo => '加待办',
      };
      return FloatingActionButton.extended(
        onPressed: () => context.push('/editor?category=${cat.wireValue}'),
        icon: const Icon(Icons.edit_outlined),
        label: Text(label),
      );
    }
    return _ChooseCategoryFab(
      onChoose: (c) => context.push('/editor?category=${c.wireValue}'),
    );
  }
}

// ===== 顶部搜索 pill =====

class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => GoRouter.of(context).push('/search'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 18,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '搜索日记…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 每日一言 =====

class _DailyQuoteCard extends ConsumerWidget {
  const _DailyQuoteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final asyncQuote = ref.watch(dailyQuoteProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // 点击强制刷新（跳过当天缓存重新请求）。
        onTap: () => ref.read(dailyQuoteProvider.notifier).refresh(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.10),
                scheme.tertiary.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: asyncQuote.when(
            loading: () => _quoteSkeleton(theme),
            error: (_, __) => _quoteFallback(theme,
                hint: '每日一言加载失败，点击重试'),
            data: (text) {
              if (text == null || text.isEmpty) {
                return _quoteFallback(theme, hint: '每日一言暂不可用');
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote,
                      size: 18,
                      color: scheme.primary.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        // 关键字体技巧：fontFamily = FrauncesItalic（永远斜体），
                        // fallback = NotoSerifSC（中文正体）。Flutter 逐字符寻
                        // 字形——英文走 Fraunces 斜体，中文走 Noto Serif SC 正体，
                        // 不会对中文做 synthetic italic（避免难看的强行倾斜）。
                        fontFamily: AppFonts.serifItalicEnPrimary,
                        fontFamilyFallback: AppFonts.serifItalicEnFallback,
                        height: 1.75,
                        letterSpacing: 0.4,
                        fontSize: 15,
                        color: scheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _quoteSkeleton(ThemeData theme) {
    final base = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(4),
            )),
        const SizedBox(height: 8),
        Container(
            height: 12,
            width: 200,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(4),
            )),
      ],
    );
  }

  Widget _quoteFallback(ThemeData theme, {required String hint}) {
    return Row(
      children: [
        Icon(
          Icons.format_quote,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        const SizedBox(width: 8),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// ===== 过滤芯片 =====

/// 视图切换按钮：AppBar 右侧 SegmentedButton 风格的小三段，icon-only。
/// 切换不重新拉数据；状态住在 _HomePageState 里。
class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.mode, required this.onChange});

  final HomeViewMode mode;
  final void Function(HomeViewMode) onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seg(context, HomeViewMode.list, Icons.view_agenda_outlined, '列表'),
            _seg(context, HomeViewMode.timeline, Icons.timeline_outlined, '时间线'),
            _seg(context, HomeViewMode.heatmap, Icons.grid_on_outlined, '热力图'),
          ],
        ),
      ),
    );
  }

  Widget _seg(BuildContext context, HomeViewMode m, IconData icon,
      String tooltip) {
    final scheme = Theme.of(context).colorScheme;
    final active = mode == m;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onChange(m),
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active
                ? scheme.onPrimary
                : scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// 热力图视图占位——stage 15 接入。
class _ComingSoonHeatmap extends StatelessWidget {
  const _ComingSoonHeatmap();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_on_outlined,
                size: 48, color: scheme.onSurface.withValues(alpha: 0.32)),
            const SizedBox(height: 16),
            Text(
              '日历热力图\n年度方格按当日字数着色，稍后上线',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 项目 Tab 下方的「项目聚合」入口条——单行 InkWell，点击跳 /projects。
/// 只在 _filter == 项目 时渲染，省掉对日记/待办来说无意义的视觉噪点。
class _ProjectsEntry extends StatelessWidget {
  const _ProjectsEntry();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkSageDark : AppColors.inkSage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => GoRouter.of(context).push('/projects'),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 16, color: ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '按项目聚合查看（里程碑时间轴）',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18,
                  color: scheme.onSurface.withValues(alpha: 0.45)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.selected, required this.onChange});
  final int selected;
  final void Function(int) onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          _chip(context, label: '全部', index: 0),
          const SizedBox(width: 8),
          _chip(context, label: '日记', index: 1),
          const SizedBox(width: 8),
          _chip(context, label: '项目', index: 2),
          const SizedBox(width: 8),
          _chip(context, label: '待办', index: 3),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context,
      {required String label, required int index}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = selected == index;
    return InkWell(
      onTap: () => onChange(index),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: active ? scheme.onPrimary : scheme.onSurface,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ===== 全部 Tab 时的"新建"FAB =====

class _ChooseCategoryFab extends StatelessWidget {
  const _ChooseCategoryFab({required this.onChoose});
  final void Function(EntryCategory) onChoose;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<EntryCategory>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('写日记'),
                subtitle: const Text('记录日常 / 心情 / 想法'),
                onTap: () => Navigator.of(ctx).pop(EntryCategory.diary),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('记项目'),
                subtitle: const Text('版本进度 / 完成项 / 里程碑'),
                onTap: () => Navigator.of(ctx).pop(EntryCategory.project),
              ),
              ListTile(
                leading: const Icon(Icons.checklist_outlined),
                title: const Text('加待办'),
                subtitle: const Text('清单事项 / 勾选完成'),
                onTap: () => Navigator.of(ctx).pop(EntryCategory.todo),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked != null) onChoose(picked);
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _open(context),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('新建'),
    );
  }
}

// ===== 列表 =====

class _EntryList extends ConsumerWidget {
  const _EntryList({this.category});

  final EntryCategory? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entryRepositoryProvider);
    if (repo == null) return const _EmptyState(message: '未登录');

    return StreamBuilder<List<Entry>>(
      stream: repo.watchAll(category: category),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data ?? const <Entry>[];
        if (all.isEmpty) {
          return const _EmptyState(message: '还没有内容\n点右下角按钮开始记录');
        }

        final pinned = all.where((e) => e.isPinned).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final regular = all.where((e) => !e.isPinned).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        final items = <_ListItem>[];
        if (pinned.isNotEmpty) {
          items.add(const _ListItem.header('置顶'));
          items.addAll(pinned.map(_ListItem.entry));
        }
        if (regular.isNotEmpty) {
          if (pinned.isNotEmpty) {
            items.add(const _ListItem.header('全部'));
          }
          items.addAll(regular.map(_ListItem.entry));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final item = items[i];
            return item.when(
              header: (text) => _SectionHeader(text: text),
              entry: (e) => _SwipeableEntryCard(
                entry: e,
                animationIndex: i,
              ),
            );
          },
        );
      },
    );
  }
}

/// 卡片包一层 Dismissible：左滑（endToStart）→ 归档 + Undo SnackBar。
class _SwipeableEntryCard extends ConsumerWidget {
  const _SwipeableEntryCard({
    required this.entry,
    required this.animationIndex,
  });

  final Entry entry;
  final int animationIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey('entry-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.archive_outlined, color: Colors.white),
            SizedBox(width: 6),
            Text('归档',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
      onDismissed: (_) async {
        final repo = ref.read(entryRepositoryProvider);
        if (repo == null) return;
        await repo.archive(entry.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已归档：${entry.title.isEmpty ? '（无标题）' : entry.title}'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () => repo.unarchive(entry.id),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      },
      child: _AnimatedEntryCard(
        entry: entry,
        animationIndex: animationIndex,
      ),
    );
  }
}

class _AnimatedEntryCard extends StatelessWidget {
  const _AnimatedEntryCard({
    required this.entry,
    required this.animationIndex,
  });

  final Entry entry;
  final int animationIndex;

  @override
  Widget build(BuildContext context) {
    final delayMs = (animationIndex.clamp(0, 8)) * 40;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
      child: _EntryCard(entry: entry),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final completed = entry.isCompleted;
    final hasCompletionState = entry.category == EntryCategory.todo ||
        entry.category == EntryCategory.project;

    // 完成态用"用过的纸"底色（仅 +3% 暖灰位移）；未完成 / diary 走默认 surface。
    final cardColor = hasCompletionState && completed
        ? (isDark ? AppColors.darkSurfaceUsed : AppColors.lightSurfaceUsed)
        : null;

    // 4px 左色条：完成 → sage；未完成 → 暖琥珀；diary → 透明（不显示）。
    final stripColor = hasCompletionState
        ? (completed
            ? (isDark ? AppColors.statusDoneDark : AppColors.statusDone)
                .withValues(alpha: 0.65)
            : (isDark
                    ? AppColors.statusInProgressDark
                    : AppColors.statusInProgress)
                .withValues(alpha: 0.65))
        : Colors.transparent;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: cardColor,
      child: InkWell(
        onTap: () => GoRouter.of(context).push('/entry/${entry.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: stripColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.isPinned) ...[
                    Icon(Icons.push_pin, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                  ],
                  if (entry.category == EntryCategory.todo) ...[
                    Icon(
                      completed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: completed
                          ? (isDark
                              ? AppColors.statusDoneDark
                              : AppColors.statusDone)
                          : scheme.onSurface.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      entry.title.isEmpty ? '（无标题）' : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        // todo 完成时标题划线 + 弱化；其它情况保持默认。
                        decoration:
                            entry.category == EntryCategory.todo && completed
                                ? TextDecoration.lineThrough
                                : null,
                        color:
                            entry.category == EntryCategory.todo && completed
                                ? scheme.onSurface.withValues(alpha: 0.55)
                                : null,
                      ),
                    ),
                  ),
                  if (entry.mood != null) ...[
                    const SizedBox(width: 8),
                    Text(entry.mood!.emoji,
                        style: const TextStyle(fontSize: 18)),
                  ],
                ],
              ),
              ..._bodyForCategory(theme, entry),
              const SizedBox(height: 10),
              Row(
                children: [
                  _CategoryBadge(
                    category: entry.category,
                    completed: completed && hasCompletionState,
                  ),
                  const SizedBox(width: 8),
                  if (entry.category == EntryCategory.project &&
                      entry.projectMeta?.version.isNotEmpty == true) ...[
                    Text(
                      'v${entry.projectMeta!.version}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  if (entry.category == EntryCategory.diary &&
                      entry.wordCount > 0) ...[
                    Icon(Icons.notes,
                        size: 14,
                        color: scheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 3),
                    Text(
                      '${entry.wordCount} 字',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    DateUtil.relative(entry.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 卡片中部的"摘要行"。三种类目内容不同：
  /// - diary  ：Quill 正文前 80 字
  /// - project：项目名 + 已完成项数
  /// - todo   ：未完成 / 已完成 计数
  List<Widget> _bodyForCategory(ThemeData theme, Entry e) {
    switch (e.category) {
      case EntryCategory.diary:
        final plain = TextUtil.extractPlainText(e.contentDelta).trim();
        if (plain.isEmpty) return const [];
        final flat = plain.replaceAll(RegExp(r'\s+'), ' ');
        final snippet = flat.length <= 80 ? flat : '${flat.substring(0, 80)}…';
        return [
          const SizedBox(height: 6),
          Text(
            snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
        ];

      case EntryCategory.project:
        final pm = e.projectMeta;
        if (pm == null) return const [];
        final pieces = <String>[];
        if (pm.projectName.isNotEmpty) pieces.add(pm.projectName);
        if (pm.completedItems.isNotEmpty) {
          pieces.add('完成 ${pm.completedItems.length} 项');
        }
        if (pieces.isEmpty) return const [];
        return [
          const SizedBox(height: 6),
          Text(
            pieces.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ];

      case EntryCategory.todo:
        if (e.subtasks.isEmpty) return const [];
        final done = e.subtasks.where((t) => t.done).length;
        final total = e.subtasks.length;
        return [
          const SizedBox(height: 6),
          Text(
            '$done / $total 已完成',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ];
    }
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, this.completed = false});
  final EntryCategory category;

  /// 项目/待办的派生完成态。完成时徽章右侧追加一个绿色"✓ 完成"小标。
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 三种"墨水色"避免所有徽章泛绿：日记=咖啡棕，项目=sage，待办=dusty blue。
    final ink = switch (category) {
      EntryCategory.diary =>
        isDark ? AppColors.inkUmberDark : AppColors.inkUmber,
      EntryCategory.project =>
        isDark ? AppColors.inkSageDark : AppColors.inkSage,
      EntryCategory.todo =>
        isDark ? AppColors.inkDustyDark : AppColors.inkDusty,
    };
    final sage =
        isDark ? AppColors.statusDoneDark : AppColors.statusDone;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: ink.withValues(alpha: completed ? 0.10 : 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            category.displayLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: ink.withValues(alpha: completed ? 0.7 : 1.0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (completed) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: sage.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 12, color: sage),
                const SizedBox(width: 2),
                Text(
                  '完成',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: sage,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

class _ListItem {
  const _ListItem._({this.entry, this.headerText});

  final Entry? entry;
  final String? headerText;

  const _ListItem.header(String text) : this._(headerText: text);
  const _ListItem.entry(Entry e) : this._(entry: e);

  T when<T>({
    required T Function(String text) header,
    required T Function(Entry entry) entry,
  }) {
    if (this.entry != null) return entry(this.entry!);
    return header(headerText!);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.32),
            ),
            const SizedBox(height: 16),
            Text(
              message,
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
