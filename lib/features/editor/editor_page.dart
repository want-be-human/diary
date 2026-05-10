import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/entry.dart';
import '../../data/models/mood.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/image_upload_service.dart';
import '../../shared/utils/text_util.dart';
import 'widgets/drive_quill_embed_builder.dart';

/// 日记类目编辑页：
/// - 标题输入
/// - 元数据栏（心情 / 标签 / 置顶 / 实时字数）
/// - flutter_quill 富文本编辑器 + 自定义工具栏（含"插入图片"按钮）
/// - 图片走 Drive 上传（方案 2 预生成 docId）+ DriveImageCache 渲染
/// - dispose-without-save 自动清理本会话上传的孤儿图
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
  final _tagsCtrl = TextEditingController();
  QuillController? _quill;
  Entry? _loaded;
  bool _loading = true;
  bool _saving = false;
  bool _savedOk = false;
  bool _uploadingImage = false;
  String? _error;

  late final String _entryId;
  // 在 initState 里抓住，dispose 时还能用——Riverpod 的 ref 在 dispose 阶段
  // 不可用（StateError: Cannot use "ref" after the widget was disposed）。
  late final ImageUploadService _uploader;

  /// 元数据栏状态。
  Mood? _mood;
  bool _isPinned = false;

  /// 图片孤儿清理：跟 project / todo form 同一套语义。
  final Set<String> _originalUrls = {};
  final Set<String> _addedUrls = {};

  bool get _isNew => widget.entryId == null;

  static const _embedBuilders = <EmbedBuilder>[DriveQuillImageEmbedBuilder()];

  @override
  void initState() {
    super.initState();
    // 抓住 service 留给 dispose 用——dispose 阶段 ref 不可用。
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
      _quill = QuillController.basic();
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
      _tagsCtrl.text = entry.tags.join(', ');
      _mood = entry.mood;
      _isPinned = entry.isPinned;
      _quill = _buildController(entry.contentDelta);
      _originalUrls.addAll(_scanQuillImageUrls(_quill!));
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

  /// 扫 Quill 文档里所有 `{insert: {image: 'url'}}` op，返回当前文档里嵌入的图片 URL 集合。
  /// 用于 dispose / save 时算"哪些图被这次会话用过、哪些被删掉"。
  Set<String> _scanQuillImageUrls(QuillController q) {
    final urls = <String>{};
    // toJson() 返回 List<Map<String,dynamic>>，每条 op 形如 {insert: ..., attributes: ...}
    // insert 既可能是 String（普通文本），也可能是 Map（嵌入物）。只看后者。
    for (final op in q.document.toDelta().toJson()) {
      final ins = op['insert'];
      if (ins is Map) {
        final img = ins['image'];
        if (img is String && img.isNotEmpty) urls.add(img);
      }
    }
    return urls;
  }

  Future<void> _pickAndInsertImage() async {
    if (_uploadingImage) return;
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未登录，无法上传图片')),
      );
      return;
    }
    setState(() => _uploadingImage = true);
    try {
      final url = await ref
          .read(imageUploadServiceProvider)
          .pickAndUpload(uid: user.uid, entryId: _entryId);
      if (url != null && mounted && _quill != null) {
        _addedUrls.add(url);
        // 在当前光标位置插入 image embed，并把光标推到图片之后。
        final ctrl = _quill!;
        final index = ctrl.selection.baseOffset.clamp(0, ctrl.document.length);
        ctrl.replaceText(
          index,
          0,
          BlockEmbed.image(url),
          TextSelection.collapsed(offset: index + 1),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片上传失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  List<String> _parseTags() {
    return _tagsCtrl.text
        .split(RegExp(r'[,，\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet() // 去重
        .toList();
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
    final tags = _parseTags();
    final now = DateTime.now();

    try {
      if (_isNew) {
        await repo.create(Entry(
          id: _entryId,
          title: title,
          contentDelta: delta,
          category: widget.initialCategory ?? EntryCategory.diary,
          tags: tags,
          createdAt: now,
          updatedAt: now,
          mediaUrls: const <String>[],
          wordCount: wordCount,
          mood: _mood,
          isPinned: _isPinned,
        ));
      } else {
        final patched = (_loaded ?? _fallbackEntry()).copyWith(
          title: title,
          contentDelta: delta,
          tags: tags,
          wordCount: wordCount,
          mood: _mood,
          isPinned: _isPinned,
          updatedAt: now,
          clearMood: _mood == null,
        );
        await repo.update(patched);
      }

      _savedOk = true;

      // 计算 save 后要清理的图片：
      // - 当前 Quill 文档里仍存在的 URL（该保留）
      // - 不在文档里、但在 _originalUrls/_addedUrls 里的（该清理）
      final stillReferenced = _scanQuillImageUrls(_quill!);
      final orphans = <String>{
        ..._originalUrls.where((u) => !stillReferenced.contains(u)),
        ..._addedUrls.where((u) => !stillReferenced.contains(u)),
      };
      final uploader = ref.read(imageUploadServiceProvider);
      for (final url in orphans) {
        unawaited(uploader.deleteByUrl(url));
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

  Entry _fallbackEntry() {
    final now = DateTime.now();
    return Entry(
      id: _entryId,
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
    _tagsCtrl.dispose();
    _quill?.dispose();
    // 不保存就走人 → 清掉本会话上传但没保存的图。
    // 用 initState 缓存的 _uploader（dispose 阶段 ref 不可用）。
    if (!_savedOk && _addedUrls.isNotEmpty) {
      for (final url in _addedUrls) {
        unawaited(_uploader.deleteByUrl(url));
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? '新建日记' : '编辑日记')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _quill == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? '新建日记' : '编辑日记')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新建日记' : '编辑日记'),
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
          _MetadataBar(
            mood: _mood,
            isPinned: _isPinned,
            quill: _quill!,
            tagsCtrl: _tagsCtrl,
            onMoodChanged: (m) => setState(() => _mood = m),
            onPinChanged: (v) => setState(() => _isPinned = v),
          ),
          const Divider(height: 1),
          // QuillSimpleToolbar 内部用 flex 布局，外层不能给它 unbounded width
          // （否则触发 RenderFlex._computeSizes 死循环）。所以保留 multiRowsDisplay
          // 默认（窄屏自动换行），不套 horizontal scroll。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: QuillSimpleToolbar(
                  controller: _quill!,
                  config: const QuillSimpleToolbarConfig(
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
              ),
              // 自定义"插入图片"按钮——独立放置，不依赖 flutter_quill_extensions。
              IconButton(
                icon: _uploadingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                tooltip: '插入图片（上传到 Drive）',
                onPressed: _uploadingImage ? null : _pickAndInsertImage,
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: QuillEditor.basic(
                controller: _quill!,
                config: QuillEditorConfig(
                  placeholder: '开始写……',
                  padding: EdgeInsets.zero,
                  expands: true,
                  autoFocus: false,
                  embedBuilders: _embedBuilders,
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

/// 紧贴标题下方的元数据条：心情 / 标签 / 置顶 / 实时字数。
class _MetadataBar extends StatelessWidget {
  const _MetadataBar({
    required this.mood,
    required this.isPinned,
    required this.quill,
    required this.tagsCtrl,
    required this.onMoodChanged,
    required this.onPinChanged,
  });

  final Mood? mood;
  final bool isPinned;
  final QuillController quill;
  final TextEditingController tagsCtrl;
  final void Function(Mood?) onMoodChanged;
  final void Function(bool) onPinChanged;

  static const _moodEmojis = ['😢', '😔', '😐', '🙂', '😊'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.inkUmberDark : AppColors.inkUmber;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        children: [
          // 心情：5 档 emoji 单选
          for (var i = 0; i < _moodEmojis.length; i++) ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                final score = i + 1;
                final selected = mood?.score == score;
                onMoodChanged(selected
                    ? null
                    : Mood(score: score, emoji: _moodEmojis[i]));
              },
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: mood?.score == i + 1
                      ? accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(_moodEmojis[i],
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
          ],
          const SizedBox(width: 8),
          // 标签输入（紧凑）
          Expanded(
            child: TextField(
              controller: tagsCtrl,
              decoration: InputDecoration(
                hintText: '标签（逗号分隔）',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: const Icon(Icons.tag, size: 16),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 28,
                  maxWidth: 28,
                ),
                hintStyle: theme.textTheme.bodySmall,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
          // 置顶切换
          IconButton(
            tooltip: isPinned ? '取消置顶' : '置顶',
            iconSize: 20,
            icon: Icon(
              isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: isPinned ? scheme.primary : null,
            ),
            onPressed: () => onPinChanged(!isPinned),
          ),
          // 实时字数：用 ListenableBuilder 隔离重建——只刷这个 Text，
          // 不会让父级的 QuillEditor 跟着 rebuild（之前外层 setState 是删
          // 字时焦点丢失 / 光标不闪烁的根因）。
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ListenableBuilder(
              listenable: quill,
              builder: (_, __) {
                final wc = TextUtil.countWords(quill.document.toPlainText());
                return Text(
                  '$wc 字',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
