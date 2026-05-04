import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository_impl.dart';

/// 首页占位实现：搜索栏 + 分类 Tab + 列表 + 浮动新建按钮。
/// 真实卡片样式与动画在阶段三完善。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  EntryCategory? _categoryFor(int index) => switch (index) {
        1 => EntryCategory.diary,
        2 => EntryCategory.project,
        _ => null,
      };

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(entryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('日记'),
        actions: [
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '日记'),
            Tab(text: '项目'),
          ],
        ),
      ),
      body: repo == null
          ? const _EmptyState(message: '请先登录以查看日记')
          : TabBarView(
              controller: _tab,
              children: List.generate(3, (i) {
                return _EntryList(category: _categoryFor(i));
              }),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/editor'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('新建'),
      ),
    );
  }
}

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
        final items = snap.data ?? const <Entry>[];
        if (items.isEmpty) {
          return const _EmptyState(message: '还没有内容，点右下角新建一篇吧');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final e = items[i];
            return Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  e.title.isEmpty ? '（无标题）' : e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${e.category.name} · ${e.updatedAt.toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => context.push('/entry/${e.id}'),
              ),
            );
          },
        );
      },
    );
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
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
