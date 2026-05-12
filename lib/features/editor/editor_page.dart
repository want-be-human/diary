import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/entry.dart';
import '../../data/models/entry_location.dart';
import '../../data/models/mood.dart';
import '../../data/models/weather_snapshot.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/image_upload_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/media_upload_queue.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/video_upload_service.dart';
import '../../data/services/weather_service.dart';
import '../../shared/utils/text_util.dart';
import 'widgets/drive_quill_embed_builder.dart';
import 'widgets/drive_video_embed_builder.dart';
import 'widgets/location_weather_bar.dart';
import 'widgets/pending_image_embed_builder.dart';

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
  late final VideoUploadService _videoSvc;
  late final MediaUploadQueue _videoQueueNotifier;

  /// 元数据栏状态。
  Mood? _mood;
  bool _isPinned = false;
  EntryLocation? _location;
  WeatherSnapshot? _weather;

  /// 自动抓取（仅新建模式触发一次）的转圈状态，给 chip 显示加载条。
  bool _autoFetching = false;

  /// 自动抓取失败时的提示（位置服务关 / 拒绝授权 / 无信号等），
  /// 显示在元数据条下方供用户判断要不要手动改设置。null = 没问题或没尝试。
  String? _autoFetchHint;

  /// 进入编辑模式时文档里已有的 image URL（旧条目里直接持久化的形态）。
  /// 保存后若不再被引用要清 Drive。本会话内新插入的图都走 [_addedJobIds]。
  final Set<String> _originalUrls = {};

  /// 视频 / 图片队列里本会话产生的 jobId。
  /// dispose-without-save → 全清；save → 按 kind 计算孤儿并清。
  final Set<String> _addedJobIds = {};

  /// 进入编辑模式时文档里已有的 video fileId。保存后若不再被引用要清掉。
  final Set<String> _originalVideoFileIds = {};

  /// 视频选/上一过程是否在进行——用于禁用按钮防止重复触发。
  bool _pickingVideo = false;

  bool get _isNew => widget.entryId == null;

  static const _embedBuilders = <EmbedBuilder>[
    DriveQuillImageEmbedBuilder(),
    DriveVideoEmbedBuilder(),
    PendingImageEmbedBuilder(),
  ];

  @override
  void initState() {
    super.initState();
    // 抓住 service 留给 dispose 用——dispose 阶段 ref 不可用。
    _videoSvc = ref.read(videoUploadServiceProvider);
    _videoQueueNotifier = ref.read(mediaUploadQueueProvider.notifier);
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
      // 新建条目首次进入：尽量自动抓一次位置 + 天气，best-effort，不阻塞。
      // 用户在抓取完成前手动改了位置/天气也不会被覆盖（_autoFillIfEmpty 里
      // 校验"还是 null 才填"）。
      unawaited(_autoFillLocationAndWeather());
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
      _location = entry.location;
      _weather = entry.weather;
      _quill = _buildController(entry.contentDelta);
      _originalUrls.addAll(_scanQuillImageUrls(_quill!));
      _originalVideoFileIds.addAll(_scanVideoFileIds(_quill!));
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

  /// 新建条目首次进入时尝试自动填充位置 + 天气。
  /// 优先级：geolocator → ipapi.co IP 反查 → 默认城市 → uapis.cn 服务端 IP 自动定位。
  /// 用户在抓取完成之前手动改过位置/天气 → 不覆盖（保留用户输入优先）。
  /// 失败原因保留在 [_autoFetchHint] 显示在元数据条下方，避免静默失败。
  Future<void> _autoFillLocationAndWeather() async {
    setState(() {
      _autoFetching = true;
      _autoFetchHint = null;
    });
    String? locError;
    try {
      EntryLocation? loc;
      try {
        loc = await ref.read(locationServiceProvider).fetchCurrent();
      } on LocationException catch (e) {
        locError = e.message;
        loc = null;
      } catch (e) {
        locError = '定位失败：$e';
        loc = null;
      }

      final wx = ref.read(weatherServiceProvider);
      WeatherSnapshot? snap;

      // uapis.cn 不收 lat/lng，只能传城市名。优先级：
      //   反查到的 placeName → 设置页默认城市 → uapis 服务端按 IP 自动定位。
      if (loc?.hasName == true) {
        snap = await wx.fetchByCityName(loc!.placeName!);
      } else {
        final defaultCity =
            await ref.read(settingsServiceProvider).getDefaultCity();
        if (defaultCity.isNotEmpty) {
          snap = await wx.fetchByCityName(defaultCity);
          loc ??= EntryLocation(placeName: defaultCity);
        } else {
          // 最后的兜底：让 uapis.cn 按客户端公网 IP 反查。
          // 注意 WeatherService 走的是 createDirectHttpClient——但如果
          // Clash TUN 模式启用，TUN 在内核层劫持 socket，仍会改出口 IP。
          snap = await wx.fetchByIp();
          // 服务端拿到的城市名顺手回填给 location，省得 chip 显示空白。
          if (snap?.cityName?.isNotEmpty == true) {
            loc ??= EntryLocation(placeName: snap!.cityName);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        if (_location == null && loc != null) _location = loc;
        if (_weather == null && snap != null) _weather = snap;
        _autoFetching = false;
        if (_location == null && locError != null) {
          _autoFetchHint = '$locError（点击 chip 手填，或到设置页填默认城市）';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _autoFetching = false);
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

  /// 给 save 用的"持久化版" delta：
  /// 1. 等队列空 → 所有进行中的图片/视频 job 都已落定
  /// 2. driveVideo 占位（jobId-only）→ 重写成 fileId-only
  /// 3. pendingImage 占位（仅 jobId）→ 重写成标准 image embed（URL 形态，
  ///    向后兼容历史条目和 [DriveQuillImageEmbedBuilder]）
  /// 4. 失败 / 取消 / 丢失的占位整段丢掉，避免持久化里留下"上传任务已丢失"
  Future<List<Map<String, dynamic>>> _persistableOps() async {
    await ref.read(mediaUploadQueueProvider.notifier).waitIdle();
    final raw = _quill!.document.toDelta().toJson();
    final queue = ref.read(mediaUploadQueueProvider);
    final out = <Map<String, dynamic>>[];
    for (final op in raw) {
      final ins = op['insert'];
      if (ins is Map) {
        // ---- 视频占位重写 ----
        if (ins.containsKey(DriveVideoEmbedBuilder.embedType)) {
          final rewritten =
              _rewriteVideoPlaceholder(op, ins, queue);
          if (rewritten != null) out.add(rewritten);
          continue; // null = 丢弃
        }
        // ---- 图片占位重写 ----
        if (ins.containsKey(PendingImageEmbedBuilder.embedType)) {
          final rewritten =
              _rewriteImagePlaceholder(op, ins, queue);
          if (rewritten != null) out.add(rewritten);
          continue;
        }
      }
      out.add(op);
    }
    return out;
  }

  /// 重写一段 driveVideo embed；返回 null 表示该 op 应整段丢弃。
  Map<String, dynamic>? _rewriteVideoPlaceholder(
    Map<String, dynamic> op,
    Map ins,
    Map<String, MediaUploadJob> queue,
  ) {
    final rawData = ins[DriveVideoEmbedBuilder.embedType];
    if (rawData is! String) return null;
    try {
      final d = DriveVideoEmbedData.decode(rawData);
      if (d.isUploaded) return op; // 已经是 fileId 形态，保留
      final jobId = d.jobId;
      if (jobId == null) return null;
      final job = queue[jobId];
      if (job != null &&
          job.status == MediaUploadStatus.done &&
          (job.fileId ?? '').isNotEmpty) {
        final next = Map<String, dynamic>.from(op);
        next['insert'] = {
          DriveVideoEmbedBuilder.embedType: DriveVideoEmbedData(
            fileId: job.fileId,
            name: d.name,
            size: d.size,
          ).encode(),
        };
        return next;
      }
      // failed / canceled / missing → 丢
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 重写一段 pendingImage embed 成标准 image embed；返回 null 表示丢弃。
  Map<String, dynamic>? _rewriteImagePlaceholder(
    Map<String, dynamic> op,
    Map ins,
    Map<String, MediaUploadJob> queue,
  ) {
    final rawData = ins[PendingImageEmbedBuilder.embedType];
    if (rawData is! String) return null;
    try {
      final d = PendingImageEmbedData.decode(rawData);
      final job = queue[d.jobId];
      if (job != null &&
          job.status == MediaUploadStatus.done &&
          (job.fileId ?? '').isNotEmpty) {
        final next = Map<String, dynamic>.from(op);
        // 标准 image embed：data 直接是 URL 字符串。跟历史条目同构，
        // 详情页 / 列表预览不需要额外分支。
        next['insert'] = {
          BlockEmbed.imageType: ImageUploadService.thumbnailUrl(job.fileId!),
        };
        return next;
      }
      return null;
    } catch (_) {
      return null;
    }
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

  /// 把文档里 driveVideo / pendingImage 占位 embed（按 jobId 匹配）整段抹掉。
  /// 用于"用户取消上传"时清掉残留占位——视频和图片占位都用这个走。
  ///
  /// 偏移量算法：遍历每个 op 计算它占文档多少个 character；text op 贡献
  /// 字符串长度，embed op 贡献 1。找到目标 embed 后用 [replaceText] 把那
  /// 1 个 character 替换为空串。
  void _removePlaceholderByJobId(String jobId) {
    final ctrl = _quill;
    if (ctrl == null) return;
    var offset = 0;
    int? hit;
    for (final op in ctrl.document.toDelta().toJson()) {
      final ins = op['insert'];
      if (ins is String) {
        offset += ins.length;
      } else if (ins is Map) {
        if (_matchesJobId(ins, DriveVideoEmbedBuilder.embedType, jobId,
                _videoJobIdOf) ||
            _matchesJobId(ins, PendingImageEmbedBuilder.embedType, jobId,
                _imageJobIdOf)) {
          hit = offset;
          break;
        }
        offset += 1;
      }
    }
    if (hit != null) {
      ctrl.replaceText(
        hit,
        1,
        '',
        TextSelection.collapsed(offset: hit),
      );
    }
  }

  bool _matchesJobId(Map ins, String key, String jobId,
      String? Function(String raw) extract) {
    if (!ins.containsKey(key)) return false;
    final raw = ins[key];
    if (raw is! String) return false;
    return extract(raw) == jobId;
  }

  String? _videoJobIdOf(String raw) {
    try {
      return DriveVideoEmbedData.decode(raw).jobId;
    } catch (_) {
      return null;
    }
  }

  String? _imageJobIdOf(String raw) {
    try {
      return PendingImageEmbedData.decode(raw).jobId;
    } catch (_) {
      return null;
    }
  }

  /// 扫文档里所有 `driveVideo` embed，返回**已上传的** fileId 集合。
  /// 占位（仅 jobId）的不算——它们的 fileId 还没确定。
  Set<String> _scanVideoFileIds(QuillController q) {
    final ids = <String>{};
    for (final op in q.document.toDelta().toJson()) {
      final ins = op['insert'];
      if (ins is Map) {
        final raw = ins[DriveVideoEmbedBuilder.embedType];
        if (raw is String && raw.isNotEmpty) {
          try {
            final d = DriveVideoEmbedData.decode(raw);
            if ((d.fileId ?? '').isNotEmpty) ids.add(d.fileId!);
          } catch (_) {/* 损坏 embed 跳过 */}
        }
      }
    }
    return ids;
  }

  /// 选视频 → 入队后台上传 → 立刻在光标插占位 embed。
  /// 不阻塞 UI，用户可以继续写文字；上传进度用 LinearProgressIndicator
  /// 在 embed 内显示。
  Future<void> _pickAndInsertVideo() async {
    if (_pickingVideo) return;
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未登录，无法上传视频')),
      );
      return;
    }
    setState(() => _pickingVideo = true);
    try {
      final picked =
          await ref.read(videoUploadServiceProvider).pickVideoFile();
      if (picked == null) return; // 用户取消
      final jobId = ref.read(mediaUploadQueueProvider.notifier).enqueueVideo(
            entryId: _entryId,
            picked: picked,
          );
      _addedJobIds.add(jobId);

      if (!mounted || _quill == null) return;
      // 占位 embed：data 只含 jobId + 文件名 + 大小，没有 fileId。
      // embed builder 监听队列状态，做进度条 / 完成翻面。
      final placeholder = BlockEmbed(
        DriveVideoEmbedBuilder.embedType,
        DriveVideoEmbedData(
          jobId: jobId,
          name: picked.name,
          size: picked.sizeBytes,
        ).encode(),
      );
      final ctrl = _quill!;
      final index = ctrl.selection.baseOffset.clamp(0, ctrl.document.length);
      ctrl.replaceText(
        index,
        0,
        placeholder,
        TextSelection.collapsed(offset: index + 1),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('视频选择失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingVideo = false);
    }
  }

  /// 选图片 → 入队后台上传 → 立刻在光标插占位 embed。
  /// 跟视频一样不阻塞 UI；上传完成时 pending embed 自动翻面成真图片。
  /// 保存阶段 [_persistableOps] 把 pendingImage embed 重写成普通 image embed
  /// （URL 形态），跟历史条目向后兼容。
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
      final picked =
          await ref.read(imageUploadServiceProvider).pickFile();
      if (picked == null) return; // 用户取消
      final jobId = ref.read(mediaUploadQueueProvider.notifier).enqueueImage(
            entryId: _entryId,
            bytes: picked.bytes,
            filename: picked.name,
          );
      _addedJobIds.add(jobId);

      if (!mounted || _quill == null) return;
      final placeholder = BlockEmbed(
        PendingImageEmbedBuilder.embedType,
        PendingImageEmbedData(jobId: jobId, name: picked.name).encode(),
      );
      final ctrl = _quill!;
      final index = ctrl.selection.baseOffset.clamp(0, ctrl.document.length);
      ctrl.replaceText(
        index,
        0,
        placeholder,
        TextSelection.collapsed(offset: index + 1),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片选择失败：$e')),
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
    // 等队列里所有视频 job 完成 / 失败 → 重写 embed 把 jobId 替成 fileId、
    // 把没成的占位丢掉，再序列化。这样保存到 Firestore 的 delta 一定是稳定形态。
    final ops = await _persistableOps();
    final delta = jsonEncode(ops);
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
          location: _location,
          weather: _weather,
        ));
      } else {
        final patched = (_loaded ?? _fallbackEntry()).copyWith(
          title: title,
          contentDelta: delta,
          tags: tags,
          wordCount: wordCount,
          mood: _mood,
          isPinned: _isPinned,
          location: _location,
          weather: _weather,
          updatedAt: now,
          clearMood: _mood == null,
          clearLocation: _location == null,
          clearWeather: _weather == null,
        );
        await repo.update(patched);
      }

      _savedOk = true;

      // 以"已持久化的 ops"为真相（包含已丢弃 / 重写后的最终形态）扫一遍，
      // 拿到真正落到 Firestore 的图片 URL 集合和视频 fileId 集合。
      final persistedImageUrls = <String>{};
      final persistedVideoFileIds = <String>{};
      for (final op in ops) {
        final ins = op['insert'];
        if (ins is! Map) continue;
        final img = ins[BlockEmbed.imageType];
        if (img is String && img.isNotEmpty) persistedImageUrls.add(img);
        final rawV = ins[DriveVideoEmbedBuilder.embedType];
        if (rawV is String) {
          try {
            final d = DriveVideoEmbedData.decode(rawV);
            if ((d.fileId ?? '').isNotEmpty) {
              persistedVideoFileIds.add(d.fileId!);
            }
          } catch (_) {/* 跳过 */}
        }
      }

      // 图片孤儿：进入编辑前就有的 URL，现在不再被引用 → 清。
      // （历史条目里的 image embed 才会进入 _originalUrls；本会话用 jobId 上传，
      // 看下面的队列分支。）
      final imageUploader = ref.read(imageUploadServiceProvider);
      for (final url in _originalUrls) {
        if (!persistedImageUrls.contains(url)) {
          unawaited(imageUploader.deleteByUrl(url));
        }
      }

      // 视频 / 图片队列孤儿：按 kind 分流删 Drive。
      final queueState = ref.read(mediaUploadQueueProvider);
      final videoSvc = ref.read(videoUploadServiceProvider);
      for (final jid in _addedJobIds) {
        final job = queueState[jid];
        if (job == null) continue;
        final fid = job.fileId;
        if ((fid ?? '').isEmpty) continue;
        switch (job.kind) {
          case MediaJobKind.image:
            final url = ImageUploadService.thumbnailUrl(fid!);
            if (!persistedImageUrls.contains(url)) {
              unawaited(imageUploader.deleteByUrl(url));
            }
            break;
          case MediaJobKind.video:
            if (!persistedVideoFileIds.contains(fid!)) {
              unawaited(videoSvc.deleteByFileId(fid));
            }
            break;
        }
      }

      // 原始视频 fileId 不再被引用 → 清。
      for (final id in _originalVideoFileIds) {
        if (!persistedVideoFileIds.contains(id)) {
          unawaited(videoSvc.deleteByFileId(id));
        }
      }

      // 不论保留 / 丢弃，本会话用过的 jobId 都从队列里抹掉——它们的工作已经
      // 反映到持久化 delta 里了，留着只会让队列状态无限增长。
      final queueNotifier = ref.read(mediaUploadQueueProvider.notifier);
      for (final jid in _addedJobIds) {
        queueNotifier.forget(jid);
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
    // 放弃保存时：取消所有进行中的 job + 删已完成但未持久化的 fileId。
    // 图片 / 视频 jobId 都在 _addedJobIds 里——_videoSvc.deleteByFileId
    // 内部就是 api.files.delete(fileId)，对任何 Drive 文件类型都通用。
    // 这里用 _videoQueueNotifier / _videoSvc（initState 缓存），dispose 阶段
    // ref 不可用。
    if (!_savedOk && _addedJobIds.isNotEmpty) {
      for (final jid in _addedJobIds) {
        _videoQueueNotifier.cancel(jid);
        final job = _videoQueueNotifier.jobOf(jid);
        final fid = job?.fileId;
        if (fid != null) {
          unawaited(_videoSvc.deleteByFileId(fid));
        }
        _videoQueueNotifier.forget(jid);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 监听上传队列：用户点击占位卡片上的「取消」后，把对应 placeholder
    // 从 Quill 文档里抹掉，避免一个无用的灰色占位赖在那里。
    ref.listen<Map<String, MediaUploadJob>>(mediaUploadQueueProvider,
        (prev, next) {
      if (_quill == null) return;
      for (final jobId in _addedJobIds) {
        final prevStatus = prev?[jobId]?.status;
        final nextStatus = next[jobId]?.status;
        if (prevStatus != MediaUploadStatus.canceled &&
            nextStatus == MediaUploadStatus.canceled) {
          _removePlaceholderByJobId(jobId);
        }
      }
    });

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
          LocationWeatherBar(
            location: _location,
            weather: _weather,
            busy: _autoFetching,
            onLocationChanged: (v) => setState(() {
              _location = v;
              if (v != null) _autoFetchHint = null;
            }),
            onWeatherChanged: (v) => setState(() => _weather = v),
          ),
          if (_autoFetchHint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _autoFetchHint!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 14,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close),
                    tooltip: '关闭提示',
                    onPressed: () => setState(() => _autoFetchHint = null),
                  ),
                ],
              ),
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
              // 视频按钮——后台串行队列，选完立刻插占位卡片返回，不阻塞用户写字。
              IconButton(
                icon: _pickingVideo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_library_outlined),
                tooltip: '插入视频（后台上传到 Drive）',
                onPressed: _pickingVideo ? null : _pickAndInsertVideo,
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
