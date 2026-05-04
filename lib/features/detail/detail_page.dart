import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository_impl.dart';

/// 详情只读页占位。阶段三渲染 Quill Delta + 导出按钮。
class DetailPage extends ConsumerWidget {
  const DetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('详情'),
        actions: [
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/editor?id=$entryId'),
          ),
          IconButton(
            tooltip: '导出',
            icon: const Icon(Icons.download_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: repo == null
          ? const Center(child: Text('未登录'))
          : StreamBuilder<Entry?>(
              stream: repo.watchById(entryId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entry = snap.data;
                if (entry == null) {
                  return const Center(child: Text('条目不存在或已删除'));
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title,
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 12),
                      Text(entry.contentDelta,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
