import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository_impl.dart';
import 'editor_page.dart';
import 'project_form_page.dart';
import 'todo_form_page.dart';

/// `/editor` 路由的总分流入口。按类目把请求转给三种编辑器之一：
/// - diary  → [EditorPage]（Quill 富文本）
/// - project → [ProjectFormPage]（结构化模板）
/// - todo   → [TodoFormPage]（标题 + subtask）
///
/// 新建模式下类目从 `?category=` 取；编辑模式下先按 id 拉一次 Entry 拿到原类目。
class EditorDispatcher extends ConsumerWidget {
  const EditorDispatcher({super.key, this.entryId, this.initialCategory});

  /// 编辑模式：传 entry id；新建模式：null。
  final String? entryId;

  /// 新建模式下指定的类目。编辑模式忽略，沿用原条目类目。
  final EntryCategory? initialCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 新建：直接按 query param 分流。
    if (entryId == null) {
      final cat = initialCategory ?? EntryCategory.diary;
      return _buildFor(cat, null);
    }

    // 编辑：先把 entry 拉一次拿到 category，再分流。
    final repo = ref.watch(entryRepositoryProvider);
    if (repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑')),
        body: const Center(child: Text('未登录')),
      );
    }
    return FutureBuilder<Entry?>(
      future: repo.findById(entryId!),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('编辑')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final entry = snap.data;
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('编辑')),
            body: const Center(child: Text('条目不存在或已删除')),
          );
        }
        return _buildFor(entry.category, entry.id);
      },
    );
  }

  Widget _buildFor(EntryCategory cat, String? id) {
    switch (cat) {
      case EntryCategory.diary:
        return EditorPage(entryId: id, initialCategory: EntryCategory.diary);
      case EntryCategory.project:
        return ProjectFormPage(entryId: id);
      case EntryCategory.todo:
        return TodoFormPage(entryId: id);
    }
  }
}
