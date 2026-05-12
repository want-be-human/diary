import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/entry.dart';
import '../../data/models/project_meta.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../shared/utils/date_util.dart';
import 'project_group.dart';

/// 项目聚合页：把所有 `category == project` 的条目按 projectName 归集，
/// 每个项目渲染一张卡片（项目名 / 最新版本 / 状态徽章 / 条目数 / 最近更新）。
/// 点击卡片 → [ProjectDetailPage]（里程碑时间轴 + 该项目全部条目倒序）。
class ProjectListPage extends ConsumerWidget {
  const ProjectListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('项目聚合')),
      body: repo == null
          ? const Center(child: Text('未登录'))
          : StreamBuilder<List<Entry>>(
              stream: repo.watchAll(category: EntryCategory.project),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snap.data ?? const <Entry>[];
                final groups = ProjectGroup.groupAll(entries);
                if (groups.isEmpty) {
                  return const _Empty();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ProjectCard(group: groups[i]),
                );
              },
            ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.group});
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

    final displayName = group.projectName == ProjectGroup.unnamed
        ? '（未命名项目）'
        : group.projectName;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push(
          // 项目名走 query 参数——含任意字符（中文 / `/` / `%` / 空格）都安全。
          // 详见路由层 /project 的注释。
          Uri(
            path: '/project',
            queryParameters: {'name': group.projectName},
          ).toString(),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: statusColor.withValues(alpha: 0.65)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flag_outlined,
                              size: 18, color: ink),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (group.latestVersion.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              'v${group.latestVersion}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: ink.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              group.currentStatus.displayLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.history_edu_outlined,
                              size: 14,
                              color: scheme.onSurface.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            '${group.entries.length} 条 · '
                            '${group.totalCompletedItems} 个完成项',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                          if (group.milestones.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.flag,
                                size: 14, color: statusColor),
                            const SizedBox(width: 2),
                            Text(
                              '${group.milestones.length} 个里程碑',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Icon(Icons.schedule,
                              size: 13,
                              color: scheme.onSurface.withValues(alpha: 0.5)),
                          const SizedBox(width: 3),
                          Text(
                            DateUtil.relative(group.lastActivity),
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
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.32),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有项目条目\n切到「项目」Tab 新建一条试试',
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
