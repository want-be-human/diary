import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../shared/utils/date_util.dart';
import '../../shared/utils/text_util.dart';

/// 归档列表页：显示所有 isArchived == true 的条目，支持还原。
class ArchivePage extends ConsumerWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('归档')),
      body: repo == null
          ? const Center(child: Text('未登录'))
          : StreamBuilder<List<Entry>>(
              stream: repo.watchArchived(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? const <Entry>[];
                if (items.isEmpty) {
                  return const _Empty();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _ArchivedTile(entry: items[i]),
                );
              },
            ),
    );
  }
}

class _ArchivedTile extends ConsumerWidget {
  const _ArchivedTile({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snippet = _snippet();
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => GoRouter.of(context).push('/entry/${entry.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.isEmpty ? '（无标题）' : entry.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (snippet.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        snippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '归档于 ${DateUtil.relative(entry.updatedAt)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '还原',
                icon: const Icon(Icons.unarchive_outlined),
                onPressed: () async {
                  final repo = ref.read(entryRepositoryProvider);
                  if (repo == null) return;
                  await repo.unarchive(entry.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '已还原：${entry.title.isEmpty ? '（无标题）' : entry.title}',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _snippet() {
    final plain = TextUtil.extractPlainText(entry.contentDelta).trim();
    if (plain.isEmpty) return '';
    final flat = plain.replaceAll(RegExp(r'\s+'), ' ');
    return flat.length <= 60 ? flat : '${flat.substring(0, 60)}…';
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 48, color: scheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            '归档为空\n左滑卡片可把不再常看的条目移到这里',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
