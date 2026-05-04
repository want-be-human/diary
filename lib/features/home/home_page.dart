import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../data/services/daily_quote_service.dart';
import '../../shared/utils/date_util.dart';
import '../../shared/utils/text_util.dart';

/// 首页 v2（方案 A）：
/// - AppBar：可点击搜索 pill + 设置图标
/// - 顶部：每日一言卡片（uapis.cn）
/// - 过滤芯片：全部 / 日记 / 项目
/// - 列表：Dismissible 卡片，左滑 → 归档（带 Undo）
/// - 置顶段始终在顶
/// - FAB：当前过滤为 全部 时弹底部表单选类目，否则直接以当前类目新建
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// 0 = 全部 / 1 = 日记 / 2 = 项目
  int _filter = 0;

  EntryCategory? get _currentCategory => switch (_filter) {
        1 => EntryCategory.diary,
        2 => EntryCategory.project,
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
                const SizedBox(height: 4),
                Expanded(child: _EntryList(category: _currentCategory)),
              ],
            ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget? _buildFab(BuildContext context) {
    final cat = _currentCategory;
    if (cat != null) {
      return FloatingActionButton.extended(
        onPressed: () => context.push('/editor?category=${cat.wireValue}'),
        icon: const Icon(Icons.edit_outlined),
        label: Text(cat == EntryCategory.diary ? '写日记' : '记项目'),
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
        // 点击刷新——失败的当天可以手动重试
        onTap: () => ref.invalidate(dailyQuoteProvider),
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
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                        color: scheme.onSurface.withValues(alpha: 0.78),
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
    final snippet = _snippetOf(entry);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => GoRouter.of(context).push('/entry/${entry.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                  Expanded(
                    child: Text(
                      entry.title.isEmpty ? '（无标题）' : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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
              if (snippet.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _CategoryBadge(category: entry.category),
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
                  if (entry.wordCount > 0) ...[
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
    );
  }

  static String _snippetOf(Entry e) {
    final plain = TextUtil.extractPlainText(e.contentDelta).trim();
    if (plain.isEmpty) return '';
    final flat = plain.replaceAll(RegExp(r'\s+'), ' ');
    if (flat.length <= 80) return flat;
    return '${flat.substring(0, 80)}…';
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final EntryCategory category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isProject = category == EntryCategory.project;
    final label = isProject ? '项目' : '日记';
    final bg = (isProject ? scheme.tertiary : scheme.secondary)
        .withValues(alpha: 0.16);
    final fg = isProject ? scheme.tertiary : scheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
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
