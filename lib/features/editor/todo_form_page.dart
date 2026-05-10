import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/entry.dart';
import '../../data/models/task_item.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/image_upload_service.dart';
import 'widgets/image_attachment_grid.dart';

/// 待办类目专用编辑器：纯结构化模板，无 Quill 富文本。
/// 字段：标题 + subtask 列表（每项：勾选框 / 文本 / 图片附件 / 删除）。
/// 完成态由"所有 subtask 都勾上"派生（Entry.isCompleted）。
///
/// 图片上传同 [ProjectFormPage]：方案 2 - 预生成 docId 直传，
/// dispose-without-save 时清理本会话上传的孤儿图。
class TodoFormPage extends ConsumerStatefulWidget {
  const TodoFormPage({super.key, this.entryId});

  final String? entryId;

  @override
  ConsumerState<TodoFormPage> createState() => _TodoFormPageState();
}

class _TodoFormPageState extends ConsumerState<TodoFormPage> {
  final _titleCtrl = TextEditingController();
  final List<_TaskRow> _rows = [];

  late final String _entryId;
  Entry? _loaded;
  bool _loading = true;
  bool _saving = false;
  bool _savedOk = false;
  String? _error;
  int _uploadingRow = -1;

  final Set<String> _originalUrls = {};
  final Set<String> _addedUrls = {};
  final Set<String> _removedUrls = {};

  bool get _isNew => widget.entryId == null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(entryRepositoryProvider);
    if (repo == null) {
      setState(() {
        _error = '未登录，无法进入编辑';
        _loading = false;
      });
      return;
    }

    if (_isNew) {
      _entryId = repo.newId();
      _rows.add(_TaskRow.empty());
      setState(() => _loading = false);
      return;
    }

    _entryId = widget.entryId!;
    try {
      final entry = await repo.findById(_entryId);
      if (entry == null) {
        if (!mounted) return;
        setState(() {
          _error = '条目不存在或已删除';
          _loading = false;
        });
        return;
      }
      _loaded = entry;
      _titleCtrl.text = entry.title;
      _rows
        ..clear()
        ..addAll(entry.subtasks
            .map((t) => _TaskRow.from(t.id, t.text, t.done, t.imageUrls)));
      for (final t in entry.subtasks) {
        _originalUrls.addAll(t.imageUrls);
      }
      if (_rows.isEmpty) _rows.add(_TaskRow.empty());
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败：$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    if (!_savedOk && _addedUrls.isNotEmpty) {
      final uploader = ref.read(imageUploadServiceProvider);
      for (final url in _addedUrls) {
        unawaited(uploader.deleteByUrl(url));
      }
    }
    super.dispose();
  }

  Future<void> _pickFor(int rowIndex) async {
    if (_uploadingRow != -1) return;
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    setState(() => _uploadingRow = rowIndex);
    try {
      final url = await ref
          .read(imageUploadServiceProvider)
          .pickAndUpload(uid: user.uid, entryId: _entryId);
      if (url != null && mounted) {
        setState(() {
          _rows[rowIndex].imageUrls = [..._rows[rowIndex].imageUrls, url];
          _addedUrls.add(url);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingRow = -1);
    }
  }

  void _removeFor(int rowIndex, int urlIndex) {
    final row = _rows[rowIndex];
    final url = row.imageUrls[urlIndex];
    setState(() {
      row.imageUrls = [...row.imageUrls]..removeAt(urlIndex);
    });
    if (_originalUrls.contains(url)) {
      _removedUrls.add(url);
    } else {
      _addedUrls.remove(url);
      unawaited(ref.read(imageUploadServiceProvider).deleteByUrl(url));
    }
  }

  Future<void> _save() async {
    final repo = ref.read(entryRepositoryProvider);
    if (repo == null) {
      setState(() => _error = '未登录');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final subtasks = _rows
        .map((r) => TaskItem(
              id: r.id,
              text: r.controller.text.trim(),
              done: r.done,
              imageUrls: List<String>.from(r.imageUrls),
            ))
        .where((t) => t.text.isNotEmpty || t.imageUrls.isNotEmpty)
        .toList(growable: false);

    final now = DateTime.now();
    final title = _titleCtrl.text.trim();

    try {
      if (_isNew) {
        await repo.create(Entry(
          id: _entryId,
          title: title,
          contentDelta: '',
          category: EntryCategory.todo,
          tags: const [],
          createdAt: now,
          updatedAt: now,
          mediaUrls: const [],
          wordCount: 0,
          subtasks: subtasks,
        ));
      } else {
        await repo.update(_loaded!.copyWith(
          title: title,
          category: EntryCategory.todo,
          subtasks: subtasks,
          updatedAt: now,
        ));
      }

      _savedOk = true;
      if (_removedUrls.isNotEmpty) {
        final uploader = ref.read(imageUploadServiceProvider);
        for (final url in _removedUrls) {
          unawaited(uploader.deleteByUrl(url));
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? '新建待办' : '编辑待办')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _loaded == null && !_isNew) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? '新建待办' : '编辑待办')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error)),
          ),
        ),
      );
    }

    final doneCount = _rows.where((r) => r.done).length;
    final totalCount = _rows
        .where((r) =>
            r.controller.text.trim().isNotEmpty || r.imageUrls.isNotEmpty)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新建待办' : '编辑待办'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: '保存',
              onPressed: _save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              hintText: '标题，例如：周末前要做完',
              border: InputBorder.none,
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Text('清单', style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Text(
                '$doneCount / $totalCount',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _rows.add(_TaskRow.empty())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加一项'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ..._rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: row.done,
                          onChanged: (v) =>
                              setState(() => row.done = v ?? false),
                        ),
                        Expanded(
                          child: TextField(
                            controller: row.controller,
                            decoration: const InputDecoration(
                              hintText: '要做的事…',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: row.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: row.done
                                  ? scheme.onSurface.withValues(alpha: 0.55)
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: '删除',
                          onPressed: () {
                            // 整行删除时连同行内的图一起进入清理流程。
                            for (var idx = row.imageUrls.length - 1;
                                idx >= 0;
                                idx--) {
                              _removeFor(i, idx);
                            }
                            setState(() {
                              row.dispose();
                              _rows.removeAt(i);
                              if (_rows.isEmpty) {
                                _rows.add(_TaskRow.empty());
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 48, top: 2),
                      child: ImageAttachmentGrid(
                        urls: row.imageUrls,
                        uploading: _uploadingRow == i,
                        onAdd: () => _pickFor(i),
                        onRemove: (urlIdx) => _removeFor(i, urlIdx),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
        ],
      ),
    );
  }
}

class _TaskRow {
  _TaskRow({
    required this.id,
    required this.controller,
    required this.done,
    required this.imageUrls,
  });

  factory _TaskRow.empty() => _TaskRow(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        controller: TextEditingController(),
        done: false,
        imageUrls: [],
      );

  factory _TaskRow.from(String id, String text, bool done, List<String> urls) =>
      _TaskRow(
        id: id,
        controller: TextEditingController(text: text),
        done: done,
        imageUrls: List.of(urls),
      );

  final String id;
  final TextEditingController controller;
  bool done;
  List<String> imageUrls;

  void dispose() => controller.dispose();
}
