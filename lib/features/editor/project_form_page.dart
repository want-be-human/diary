import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/entry.dart';
import '../../data/models/project_meta.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/image_upload_service.dart';
import 'widgets/image_attachment_grid.dart';

/// 项目类目专用编辑器：纯结构化模板，无 Quill 富文本。
/// 字段：标题 / 项目名 / 版本 / 状态 / 里程碑 / "本次完成"列表（每项可挂图）。
///
/// 图片上传走"方案 2 - 预生成 docId"：
/// initState 立刻 `repo.newId()` 拿到将来真正会写入的 ID，挂图直接传到
/// `users/{uid}/entries/{id}/images/`，保存时只 `set` 同一个文档，不需要 move。
/// dispose-without-save 时把本会话新增的图片清掉，避免 Storage 孤儿。
class ProjectFormPage extends ConsumerStatefulWidget {
  const ProjectFormPage({super.key, this.entryId});

  final String? entryId;

  @override
  ConsumerState<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends ConsumerState<ProjectFormPage> {
  final _titleCtrl = TextEditingController();
  final _projectCtrl = TextEditingController();
  final _versionCtrl = TextEditingController();
  ProjectStatus _status = ProjectStatus.inProgress;
  bool _isMilestone = false;
  final List<_CompletedRow> _items = [];

  late final String _entryId; // 新建：repo.newId() 预生成；编辑：widget.entryId
  // 在 initState 抓住 service 留给 dispose 用——dispose 阶段 ref 不可用
  // (StateError: Cannot use "ref" after the widget was disposed)。
  late final ImageUploadService _uploader;
  Entry? _loaded;
  bool _loading = true;
  bool _saving = false;
  bool _savedOk = false; // dispose 时区分是 saved 离开还是放弃离开
  String? _error;
  int _uploadingRow = -1; // 当前正在上传的行 index（-1 = 无）

  /// 进入页面时已经存在的图片 URL 集合：删除这些要等 save 才落 Storage。
  final Set<String> _originalUrls = {};

  /// 本次会话新加的 URL 集合：dispose-without-save 时要清掉。
  final Set<String> _addedUrls = {};

  /// 本次会话从原始集合里删掉的 URL：save 成功后清掉它们。
  final Set<String> _removedUrls = {};

  bool get _isNew => widget.entryId == null;

  @override
  void initState() {
    super.initState();
    _uploader = ref.read(imageUploadServiceProvider);
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
      _items.add(_CompletedRow.empty());
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
      final meta = entry.projectMeta;
      if (meta != null) {
        _projectCtrl.text = meta.projectName;
        _versionCtrl.text = meta.version;
        _status = meta.status;
        _isMilestone = meta.isMilestone;
        _items
          ..clear()
          ..addAll(meta.completedItems
              .map((c) => _CompletedRow.from(c.title, c.imageUrls)));
        for (final c in meta.completedItems) {
          _originalUrls.addAll(c.imageUrls);
        }
      }
      if (_items.isEmpty) _items.add(_CompletedRow.empty());
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
    _projectCtrl.dispose();
    _versionCtrl.dispose();
    for (final r in _items) {
      r.dispose();
    }
    // 用户没保存就走人 → 把本次新上传的图清掉，免得 Storage 留孤儿。
    // 用 initState 缓存的 _uploader（dispose 阶段 ref 不可用）。
    if (!_savedOk && _addedUrls.isNotEmpty) {
      for (final url in _addedUrls) {
        // best-effort，错误吞掉。
        unawaited(_uploader.deleteByUrl(url));
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
          _items[rowIndex].imageUrls = [..._items[rowIndex].imageUrls, url];
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
    final row = _items[rowIndex];
    final url = row.imageUrls[urlIndex];
    setState(() {
      row.imageUrls = [...row.imageUrls]..removeAt(urlIndex);
    });
    if (_originalUrls.contains(url)) {
      // 编辑前就已存在的图：先记下，等 save 成功后再去 Storage 删
      // （万一用户取消编辑，这张图还要还原回原 entry）。
      _removedUrls.add(url);
    } else {
      // 本次会话刚上传的图：直接走人，立刻清 Storage。
      _addedUrls.remove(url);
      unawaited(
        ref.read(imageUploadServiceProvider).deleteByUrl(url),
      );
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

    final completed = _items
        .map((r) => CompletedItem(
              title: r.controller.text.trim(),
              imageUrls: List<String>.from(r.imageUrls),
            ))
        .where((c) => c.title.isNotEmpty || c.imageUrls.isNotEmpty)
        .toList(growable: false);

    final now = DateTime.now();
    final title = _titleCtrl.text.trim();

    try {
      if (_isNew) {
        await repo.create(Entry(
          id: _entryId, // 用预生成 ID，跟图片路径里的 ID 一致
          title: title,
          contentDelta: '',
          category: EntryCategory.project,
          tags: const [],
          createdAt: now,
          updatedAt: now,
          mediaUrls: const [],
          wordCount: 0,
          projectMeta: ProjectMeta(
            entryId: _entryId,
            projectName: _projectCtrl.text.trim(),
            version: _versionCtrl.text.trim(),
            completedItems: completed,
            status: _status,
            isMilestone: _isMilestone,
          ),
        ));
      } else {
        final base = _loaded!;
        final meta = (base.projectMeta ??
                ProjectMeta(
                  entryId: base.id,
                  projectName: '',
                  version: '',
                  completedItems: const [],
                  status: ProjectStatus.inProgress,
                ))
            .copyWith(
          projectName: _projectCtrl.text.trim(),
          version: _versionCtrl.text.trim(),
          completedItems: completed,
          status: _status,
          isMilestone: _isMilestone,
        );
        await repo.update(base.copyWith(
          title: title,
          category: EntryCategory.project,
          projectMeta: meta,
          updatedAt: now,
        ));
      }

      _savedOk = true;
      // 用户编辑期间删除的旧图：写入成功后再去 Storage 删。
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
        appBar: AppBar(title: Text(_isNew ? '新建项目' : '编辑项目')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _loaded == null && !_isNew) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? '新建项目' : '编辑项目')),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新建项目' : '编辑项目'),
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
          _label(theme, '标题'),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              hintText: '给这次进度起个标题',
              border: OutlineInputBorder(),
            ),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(theme, '项目名'),
                    TextField(
                      controller: _projectCtrl,
                      decoration: const InputDecoration(
                        hintText: '如：日记 App',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(theme, '版本'),
                    TextField(
                      controller: _versionCtrl,
                      decoration: const InputDecoration(
                        hintText: '0.1.0',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _label(theme, '状态'),
          SegmentedButton<ProjectStatus>(
            segments: const [
              ButtonSegment(
                value: ProjectStatus.inProgress,
                label: Text('进行中'),
                icon: Icon(Icons.autorenew),
              ),
              ButtonSegment(
                value: ProjectStatus.done,
                label: Text('已完成'),
                icon: Icon(Icons.check_circle_outline),
              ),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _isMilestone,
            onChanged: (v) => setState(() => _isMilestone = v),
            title: const Text('里程碑'),
            subtitle: const Text('首发版本 / 重大功能 / 重要修复时勾上'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('本次完成', style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _items.add(_CompletedRow.empty())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加一项'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: row.controller,
                            decoration: const InputDecoration(
                              hintText: '完成了什么…',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: '删除',
                          onPressed: () {
                            // 删除整行也要把行上的图标记成"待清理"。
                            for (var idx = row.imageUrls.length - 1;
                                idx >= 0;
                                idx--) {
                              _removeFor(i, idx);
                            }
                            setState(() {
                              row.dispose();
                              _items.removeAt(i);
                              if (_items.isEmpty) {
                                _items.add(_CompletedRow.empty());
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 30, top: 4),
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

  Widget _label(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CompletedRow {
  _CompletedRow({required this.controller, required this.imageUrls});

  factory _CompletedRow.empty() =>
      _CompletedRow(controller: TextEditingController(), imageUrls: []);

  factory _CompletedRow.from(String text, List<String> urls) =>
      _CompletedRow(
        controller: TextEditingController(text: text),
        imageUrls: List.of(urls),
      );

  final TextEditingController controller;
  List<String> imageUrls;

  void dispose() => controller.dispose();
}
