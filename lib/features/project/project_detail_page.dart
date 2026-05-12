import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/entry.dart';
import '../../data/models/project_meta.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../shared/utils/date_util.dart';
import 'project_group.dart';

/// 单个项目的详情聚合页。
///
/// - 顶部：里程碑时间轴（按 createdAt 升序，左→右；isMilestone 节点放大，
///   非里程碑节点缩小到普通点；点击节点 → 跳详情页）
/// - 下方：该项目的全部条目倒序列表（createdAt desc）；每条点击进 [DetailPage]
class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.projectName});

  /// 已 URL 解码后的项目名。空字符串 / [ProjectGroup.unnamed] 表示未命名项目。
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entryRepositoryProvider);
    final displayName = (projectName.isEmpty ||
            projectName == ProjectGroup.unnamed)
        ? '（未命名项目）'
        : projectName;

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: repo == null
          ? const Center(child: Text('未登录'))
          : StreamBuilder<List<Entry>>(
              stream: repo.watchAll(category: EntryCategory.project),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? const <Entry>[];
                final groups = ProjectGroup.groupAll(all);
                final group = groups.firstWhere(
                  (g) => g.projectName == projectName,
                  orElse: () => _emptyGroup(),
                );
                if (group.entries.isEmpty) {
                  return const _Empty();
                }
                return _DetailBody(group: group);
              },
            ),
    );
  }

  /// firstWhere 找不到时的占位——避免抛 StateError 让 UI 显示空态。
  ProjectGroup _emptyGroup() {
    return ProjectGroup(
      projectName: projectName,
      entries: [
        Entry(
          id: '__placeholder__',
          title: '',
          contentDelta: '',
          category: EntryCategory.project,
          tags: const [],
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          mediaUrls: const [],
        ),
      ],
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.group});
  final ProjectGroup group;

  @override
  Widget build(BuildContext context) {
    final entriesDesc = [...group.entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _ProjectHeader(group: group)),
        SliverToBoxAdapter(child: _MilestoneTimeline(group: group)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverList.separated(
            itemCount: entriesDesc.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _EntryRow(entry: entriesDesc[i]),
          ),
        ),
      ],
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.group});
  final ProjectGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isDone = group.currentStatus == ProjectStatus.done;
    final statusColor = isDone
        ? (isDark ? AppColors.statusDoneDark : AppColors.statusDone)
        : (isDark
            ? AppColors.statusInProgressDark
            : AppColors.statusInProgress);
    final ink = isDark ? AppColors.inkSageDark : AppColors.inkSage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (group.latestVersion.isNotEmpty)
            _chip(
              context,
              icon: Icons.history,
              label: '最新 v${group.latestVersion}',
              color: ink,
            ),
          _chip(
            context,
            icon: isDone ? Icons.check_circle_outline : Icons.autorenew,
            label: group.currentStatus.displayLabel,
            color: statusColor,
          ),
          _chip(
            context,
            icon: Icons.history_edu_outlined,
            label: '${group.entries.length} 条记录',
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
          if (group.totalCompletedItems > 0)
            _chip(
              context,
              icon: Icons.task_alt,
              label: '${group.totalCompletedItems} 个完成项',
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          _chip(
            context,
            icon: Icons.schedule,
            label: '最近 ${DateUtil.relative(group.lastActivity)}',
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context,
      {required IconData icon, required String label, required Color color}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 里程碑时间轴。条目按 createdAt 升序，里程碑节点画大点 + 标题 + 版本；
/// 非里程碑画小点（细灰，让 UI 节奏感更强但不喧宾夺主）。
/// 节点点击 → 进对应 entry 的详情页。
class _MilestoneTimeline extends StatelessWidget {
  const _MilestoneTimeline({required this.group});
  final ProjectGroup group;

  @override
  Widget build(BuildContext context) {
    // 时间轴节点：所有条目都画一个点，里程碑点放大并带文字。
    // 顺序：createdAt 升序——左侧老、右侧新。
    final nodes = [...group.entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (nodes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final lineColor =
        scheme.onSurface.withValues(alpha: isDark ? 0.18 : 0.12);
    final milestoneColor =
        isDark ? AppColors.statusDoneDark : AppColors.statusDone;
    final dotColor = scheme.onSurface.withValues(alpha: 0.35);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(
          top: BorderSide(color: lineColor),
          bottom: BorderSide(color: lineColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < nodes.length; i++) ...[
                _TimelineNode(
                  entry: nodes[i],
                  isFirst: i == 0,
                  isLast: i == nodes.length - 1,
                  milestoneColor: milestoneColor,
                  dotColor: dotColor,
                  lineColor: lineColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.milestoneColor,
    required this.dotColor,
    required this.lineColor,
  });

  final Entry entry;
  final bool isFirst;
  final bool isLast;
  final Color milestoneColor;
  final Color dotColor;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMilestone = entry.projectMeta?.isMilestone == true;
    final version = entry.projectMeta?.version ?? '';
    final color = isMilestone ? milestoneColor : dotColor;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/entry/${entry.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 节点 + 横线一体的 Row：左半段线（首点隐藏）→ 圆点 → 右半段线（尾点隐藏）。
            SizedBox(
              height: isMilestone ? 32 : 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 18,
                    height: 1.5,
                    color: isFirst ? Colors.transparent : lineColor,
                  ),
                  Container(
                    width: isMilestone ? 16 : 8,
                    height: isMilestone ? 16 : 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isMilestone
                          ? Border.all(
                              color: milestoneColor.withValues(alpha: 0.3),
                              width: 4,
                            )
                          : null,
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 1.5,
                    color: isLast ? Colors.transparent : lineColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // 标题：里程碑节点显示 version + 标题，非里程碑只显示日期。
            SizedBox(
              width: 96,
              child: Column(
                children: [
                  Text(
                    isMilestone
                        ? (version.isNotEmpty ? 'v$version' : '里程碑')
                        : DateUtil.short(entry.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isMilestone ? milestoneColor : null,
                      fontWeight:
                          isMilestone ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  if (isMilestone) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.title.isEmpty ? '里程碑' : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final meta = entry.projectMeta;
    final isMilestone = meta?.isMilestone == true;
    final isDone = meta?.status == ProjectStatus.done;
    final statusColor = isDone
        ? (isDark ? AppColors.statusDoneDark : AppColors.statusDone)
        : (isDark
            ? AppColors.statusInProgressDark
            : AppColors.statusInProgress);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/entry/${entry.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isMilestone) ...[
                    Icon(Icons.flag, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      entry.title.isEmpty ? '（无标题）' : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if ((meta?.version ?? '').isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      'v${meta!.version}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (meta != null && meta.completedItems.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '完成 ${meta.completedItems.length} 项 · '
                  '${meta.completedItems.first.title}'
                  '${meta.completedItems.length > 1 ? "…" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      meta?.status.displayLabel ?? '进行中',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateUtil.relative(entry.createdAt),
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
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('这个项目没有条目'),
      ),
    );
  }
}
