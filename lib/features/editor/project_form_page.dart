import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/entry.dart';
import '../../data/models/project_meta.dart';
import '../../data/repositories/entry_repository_impl.dart';
import 'widgets/image_attachment_grid.dart';

/// 项目类目专用编辑器：纯结构化模板，无 Quill 富文本。
/// 字段：标题 / 项目名 / 版本 / 状态 / 里程碑 / "本次完成"列表（每项可挂图）。
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

  Entry? _loaded;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.entryId == null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_isNew) {
      _items.add(_CompletedRow.empty());
      setState(() => _loading = false);
      return;
    }
    final repo = ref.read(entryRepositoryProvider);
    if (repo == null) {
      setState(() {
        _error = '未登录，无法加载条目';
        _loading = false;
      });
      return;
    }
    try {
      final entry = await repo.findById(widget.entryId!);
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
    super.dispose();
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
        final draft = Entry(
          id: '',
          title: title,
          contentDelta: '',
          category: EntryCategory.project,
          tags: const [],
          createdAt: now,
          updatedAt: now,
          mediaUrls: const [],
          wordCount: 0,
          // entryId 在 create 后由 datasource 回填，这里先放占位串。
          projectMeta: ProjectMeta(
            entryId: '',
            projectName: _projectCtrl.text.trim(),
            version: _versionCtrl.text.trim(),
            completedItems: completed,
            status: _status,
            isMilestone: _isMilestone,
          ),
        );
        final saved = await repo.create(draft);
        // create 之后把 projectMeta.entryId 补回真实 docId。
        await repo.update(
          saved.copyWith(
            projectMeta: saved.projectMeta?.copyWith(entryId: saved.id),
          ),
        );
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
        await repo.update(
          base.copyWith(
            title: title,
            category: EntryCategory.project,
            projectMeta: meta,
            updatedAt: now,
          ),
        );
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
                        onChanged: (urls) =>
                            setState(() => row.imageUrls = urls),
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
