import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../shared/utils/text_util.dart';

/// 富文本编辑页 v1（最小闭环）：
/// - 标题输入
/// - flutter_quill 富文本编辑器 + 简易工具栏
/// - 保存到 Firestore（新建或更新），自动计算 wordCount
/// - 心情 / 标签 / 置顶 / 项目字段等元数据后续迭代加入
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({
    super.key,
    this.entryId,
    this.initialCategory,
  });

  final String? entryId;

  /// 新建模式时的默认类目（来自首页 FAB 所在 Tab）。
  /// 编辑模式（entryId 非空）忽略此参数，沿用原条目的类目。
  final EntryCategory? initialCategory;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final _titleCtrl = TextEditingController();
  QuillController? _quill;
  Entry? _loaded; // 若为编辑现有条目，记录原始数据
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
      _quill = QuillController.basic();
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
      _quill = _buildController(entry.contentDelta);
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

  QuillController _buildController(String deltaJson) {
    if (deltaJson.trim().isEmpty) return QuillController.basic();
    try {
      final decoded = jsonDecode(deltaJson);
      // QuillController 支持两种 Delta 格式：直接的 ops 列表 或 {ops: [...]}。
      final ops = decoded is Map ? decoded['ops'] : decoded;
      if (ops is List) {
        return QuillController(
          document: Document.fromJson(ops),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {
      // 解析失败：退化为空文档，但保留 deltaJson 在原数据里以便重试。
    }
    return QuillController.basic();
  }

  String _serializeDelta() {
    final ops = _quill!.document.toDelta().toJson();
    return jsonEncode(ops);
  }

  Future<void> _save() async {
    final repo = ref.read(entryRepositoryProvider);
    if (repo == null) {
      setState(() => _error = '未登录');
      return;
    }
    if (_quill == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final title = _titleCtrl.text.trim();
    final delta = _serializeDelta();
    final wordCount = TextUtil.countWordsInDelta(delta);
    final now = DateTime.now();

    try {
      if (_isNew) {
        await repo.create(
          Entry(
            id: '', // Firestore 生成 docId
            title: title,
            contentDelta: delta,
            category: widget.initialCategory ?? EntryCategory.diary,
            tags: const <String>[],
            createdAt: now,
            updatedAt: now,
            mediaUrls: const <String>[],
            wordCount: wordCount,
          ),
        );
      } else {
        // 编辑：在原 entry 基础上修改正文/标题/字数；其它元数据保留。
        final patched = (_loaded ?? _fallbackEntry()).copyWith(
          title: title,
          contentDelta: delta,
          wordCount: wordCount,
          updatedAt: now,
        );
        await repo.update(patched);
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

  /// 极少数情况：编辑模式但 _loaded 还没拿到（理论上 bootstrap 阻塞了 UI 不会发生），
  /// 兜底构造一份带 widget.entryId 的 Entry，避免空指针。
  Entry _fallbackEntry() {
    final now = DateTime.now();
    return Entry(
      id: widget.entryId!,
      title: _titleCtrl.text,
      contentDelta: _serializeDelta(),
      category: widget.initialCategory ?? EntryCategory.diary,
      tags: const <String>[],
      createdAt: now,
      updatedAt: now,
      mediaUrls: const <String>[],
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _quill?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? '新建' : '编辑')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _quill == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? '新建' : '编辑')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
      );
    }

    final saveDisabled = _saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新建' : '编辑'),
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
              onPressed: saveDisabled ? null : _save,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: '标题',
                border: InputBorder.none,
              ),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              textInputAction: TextInputAction.next,
            ),
          ),
          const Divider(height: 1),
          QuillSimpleToolbar(
            controller: _quill!,
            config: const QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              showAlignmentButtons: false,
              showSubscript: false,
              showSuperscript: false,
              showSearchButton: false,
              showFontFamily: false,
              showFontSize: false,
              showBackgroundColorButton: false,
              showColorButton: false,
              showInlineCode: false,
              showCodeBlock: true,
              showQuote: true,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: QuillEditor.basic(
                controller: _quill!,
                config: const QuillEditorConfig(
                  placeholder: '开始写……',
                  padding: EdgeInsets.zero,
                  expands: true,
                  autoFocus: false,
                ),
              ),
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: theme.colorScheme.errorContainer,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
        ],
      ),
    );
  }
}

