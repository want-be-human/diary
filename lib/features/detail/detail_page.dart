import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/entry.dart';
import '../../data/models/project_meta.dart';
import '../../data/models/task_item.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../shared/utils/date_util.dart';
import '../editor/widgets/image_attachment_grid.dart';

/// 详情只读页：
/// - 顶部元数据条（类目 / 心情 / 字数 / 时间 / 置顶）
/// - 正文按 category 分支：
///     diary  → Quill 只读渲染
///     project → 模板字段只读视图（项目名 / 版本 / 状态 / 里程碑 / 完成项）
///     todo   → 子任务清单（可勾选 + 划线 + 图片附件）
/// - 整体底色按完成态变化（仅 project / todo）
/// - AppBar 操作：编辑 / 置顶切换 / 删除（带确认）
class DetailPage extends ConsumerWidget {
  const DetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entryRepositoryProvider);
    if (repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('详情')),
        body: const Center(child: Text('未登录')),
      );
    }

    return StreamBuilder<Entry?>(
      stream: repo.watchById(entryId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('详情')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final entry = snap.data;
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('详情')),
            body: const Center(child: Text('条目不存在或已删除')),
          );
        }
        return _DetailView(entry: entry);
      },
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({required this.entry});
  final Entry entry;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  bool _busy = false;

  Future<void> _togglePin() async {
    final repo = ref.read(entryRepositoryProvider);
    if (repo == null || _busy) return;
    setState(() => _busy = true);
    try {
      await repo.update(
        widget.entry.copyWith(isPinned: !widget.entry.isPinned),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('置顶切换失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSubtask(TaskItem item) async {
    final repo = ref.read(entryRepositoryProvider);
    if (repo == null || _busy) return;
    final updated = widget.entry.subtasks
        .map((t) => t.id == item.id ? t.copyWith(done: !t.done) : t)
        .toList(growable: false);
    setState(() => _busy = true);
    try {
      await repo.update(widget.entry.copyWith(subtasks: updated));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新子任务失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后无法恢复，相关 Isar 搜索索引会一并移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final repo = ref.read(entryRepositoryProvider);
    if (repo == null) return;
    setState(() => _busy = true);
    try {
      await repo.delete(widget.entry.id);
      if (!mounted) return;
      // 删除后回首页；当前路由若不可 pop（深链直接打开），则 go 到 /
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final completed = entry.isCompleted;
    // 完成态背景：仅 project / todo 生效。
    final hasCompletionState = entry.category == EntryCategory.todo ||
        entry.category == EntryCategory.project;
    final bgColor = hasCompletionState
        ? (completed
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.6)
            : scheme.tertiaryContainer.withValues(alpha: 0.18))
        : scheme.surface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text('详情'),
        actions: [
          IconButton(
            tooltip: entry.isPinned ? '取消置顶' : '置顶',
            icon: Icon(
              entry.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: entry.isPinned ? scheme.primary : null,
            ),
            onPressed: _busy ? null : _togglePin,
          ),
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _busy
                ? null
                : () => context.push('/editor?id=${entry.id}'),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            enabled: !_busy,
            onSelected: (v) {
              switch (v) {
                case 'delete':
                  _confirmDelete();
                  break;
                case 'export':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('导出功能将在阶段四接入')),
                  );
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('导出本条'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('删除', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // 标题
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.category == EntryCategory.todo) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8),
                  child: Icon(
                    completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: completed
                        ? Colors.green
                        : scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  entry.title.isEmpty ? '（无标题）' : entry.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration:
                        entry.category == EntryCategory.todo && completed
                            ? TextDecoration.lineThrough
                            : null,
                    color: entry.category == EntryCategory.todo && completed
                        ? scheme.onSurface.withValues(alpha: 0.55)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _MetaRow(entry: entry),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 正文按类目分支
          ..._bodyForCategory(entry),

          const SizedBox(height: 24),
          // 创建/更新时间
          Text(
            '创建于 ${DateUtil.full(entry.createdAt)}\n'
            '更新于 ${DateUtil.full(entry.updatedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.5),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _bodyForCategory(Entry entry) {
    switch (entry.category) {
      case EntryCategory.diary:
        return [
          _QuillReadOnly(
            key: ValueKey(
                '${entry.id}-${entry.updatedAt.millisecondsSinceEpoch}'),
            deltaJson: entry.contentDelta,
          ),
        ];
      case EntryCategory.project:
        return [
          _ProjectMetaPanel(
            meta: entry.projectMeta ??
                ProjectMeta(
                  entryId: entry.id,
                  projectName: '',
                  version: '',
                  completedItems: const [],
                  status: ProjectStatus.inProgress,
                ),
          ),
        ];
      case EntryCategory.todo:
        return [
          _SubtaskPanel(
            subtasks: entry.subtasks,
            busy: _busy,
            onToggle: _toggleSubtask,
          ),
        ];
    }
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final children = <Widget>[];

    final (catLabel, catColor) = switch (entry.category) {
      EntryCategory.diary => ('日记', scheme.secondary),
      EntryCategory.project => ('项目', scheme.tertiary),
      EntryCategory.todo => ('待办', scheme.primary),
    };
    children.add(_chip(context, label: catLabel, color: catColor));

    if (entry.mood != null) {
      children.add(_chip(
        context,
        leading: Text(entry.mood!.emoji,
            style: const TextStyle(fontSize: 14)),
        label: entry.mood!.label ?? '心情 ${entry.mood!.score}',
        color: scheme.primary,
      ));
    }

    if (entry.weather != null) {
      children.add(_chip(
        context,
        leading: const Icon(Icons.cloud_outlined, size: 14),
        label: '${entry.weather!.condition.name} '
            '${entry.weather!.tempCelsius.toStringAsFixed(0)}°',
        color: scheme.primary,
      ));
    }

    if (entry.location?.placeName?.isNotEmpty == true) {
      children.add(_chip(
        context,
        leading: const Icon(Icons.place_outlined, size: 14),
        label: entry.location!.placeName!,
        color: scheme.primary,
      ));
    }

    // 字数仅对 diary 有意义。
    if (entry.category == EntryCategory.diary) {
      children.add(_chip(
        context,
        leading: const Icon(Icons.notes, size: 14),
        label: '${entry.wordCount} 字',
        color: scheme.onSurface.withValues(alpha: 0.7),
      ));
    }

    children.add(_chip(
      context,
      leading: const Icon(Icons.schedule, size: 14),
      label: DateUtil.relative(entry.updatedAt),
      color: scheme.onSurface.withValues(alpha: 0.7),
    ));

    if (entry.tags.isNotEmpty) {
      for (final t in entry.tags) {
        children.add(_chip(
          context,
          leading: const Icon(Icons.tag, size: 14),
          label: t,
          color: scheme.tertiary,
        ));
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required Color color,
    Widget? leading,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            IconTheme(
              data: IconThemeData(color: color),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: color),
                child: leading,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// 只读 Quill 渲染。每次外层 entry 更新（key 变化）会重建 controller。
class _QuillReadOnly extends StatefulWidget {
  const _QuillReadOnly({super.key, required this.deltaJson});
  final String deltaJson;

  @override
  State<_QuillReadOnly> createState() => _QuillReadOnlyState();
}

class _QuillReadOnlyState extends State<_QuillReadOnly> {
  late final QuillController _ctrl = _build();

  QuillController _build() {
    if (widget.deltaJson.trim().isEmpty) {
      return QuillController.basic()..readOnly = true;
    }
    try {
      final decoded = jsonDecode(widget.deltaJson);
      final ops = decoded is Map ? decoded['ops'] : decoded;
      if (ops is List) {
        return QuillController(
          document: Document.fromJson(ops),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      }
    } catch (_) {
      // 退化为空文档；原始 deltaJson 仍保留在 entry，编辑时可重试。
    }
    return QuillController.basic()..readOnly = true;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuillEditor.basic(
      controller: _ctrl,
      config: const QuillEditorConfig(
        showCursor: false,
        padding: EdgeInsets.zero,
        autoFocus: false,
        expands: false,
        // 让正文跟随父 ListView 滚动，不开自身滚动。
        scrollable: false,
      ),
    );
  }
}

class _SubtaskPanel extends StatelessWidget {
  const _SubtaskPanel({
    required this.subtasks,
    required this.busy,
    required this.onToggle,
  });

  final List<TaskItem> subtasks;
  final bool busy;
  final void Function(TaskItem) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (subtasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '清单为空，点击右上角"编辑"添加事项',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    final done = subtasks.where((t) => t.done).length;
    final total = subtasks.length;
    final progress = total == 0 ? 0.0 : done / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '清单',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$done / $total',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 8),
        ...subtasks.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Checkbox(
                          value: t.done,
                          onChanged:
                              busy ? null : (_) => onToggle(t),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            t.text,
                            style: t.done
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  )
                                : theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (t.imageUrls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 48, top: 4),
                      child: ImageAttachmentGrid(
                        urls: t.imageUrls,
                        // 详情页只读：onChanged 收到改动也不持久化（详情不应改图）。
                        // 真正的增删走"编辑"页。
                        onChanged: (_) {},
                      ),
                    ),
                ],
              ),
            )),
      ],
    );
  }
}

class _ProjectMetaPanel extends StatelessWidget {
  const _ProjectMetaPanel({required this.meta});
  final ProjectMeta meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (meta.isMilestone) ...[
                Icon(Icons.flag, size: 18, color: scheme.tertiary),
                const SizedBox(width: 6),
              ],
              Text(
                meta.projectName.isEmpty ? '（未命名项目）' : meta.projectName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.tertiary,
                ),
              ),
              if (meta.version.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  'v${meta.version}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.tertiary.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                meta.status.displayLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: meta.status == ProjectStatus.done
                      ? Colors.green
                      : scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (meta.completedItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '本次完成',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            ...meta.completedItems.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text('• '),
                          ),
                          Expanded(child: Text(item.title)),
                        ],
                      ),
                      if (item.imageUrls.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 14, top: 4),
                          child: ImageAttachmentGrid(
                            urls: item.imageUrls,
                            onChanged: (_) {},
                          ),
                        ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
