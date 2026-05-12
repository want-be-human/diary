import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'drive_video_cache.dart';
import 'image_upload_service.dart';
import 'video_upload_service.dart';

/// 视频后台上传队列（**串行**，一次只跑一个），暴露 Riverpod 反应式状态。
///
/// 设计：
/// - 编辑器选了视频文件 → `enqueueVideo()` 立刻拿到 jobId，state 里多一条
///   `MediaUploadJob`（pending）；编辑器立刻把占位 embed 插进 Quill，jobId
///   作为 embed 的 key
/// - worker 串行 drain 等候队列；每块上传后 `onProgress` 回调更新
///   `sentBytes`，state 变更触发 placeholder 重绘进度条
/// - 完成 → state 里把 status 标为 done、写入 fileId；编辑器在保存时把 Quill
///   delta 里的 placeholder embed 重写为 final embed（带 fileId）
/// - 失败 / 取消 → status 切到 failed/canceled，UI 显示重试或删除
///
/// 私有 [_files] 持有 [PickedVideo] 引用——state 不能放 File 之类的重对象，
/// 否则 widget tree 的 `==` 比较和序列化都麻烦；把上传所需的数据藏在闭包外。
class MediaUploadQueue extends Notifier<Map<String, MediaUploadJob>> {
  /// 等候上传的 jobId 顺序。worker 从头部取，FIFO。
  final List<String> _waiting = [];

  /// jobId → 视频源文件（私有，不进 state）。
  final Map<String, PickedVideo> _files = {};

  /// jobId → 图片字节 + 文件名（图片走 image_picker，拿到的是 bytes 不是 File）。
  final Map<String, _ImageSource> _imageFiles = {};

  /// jobId → 取消令牌（私有，service 用）。视频用得上，图片用 dart 包不支持取消，
  /// 不过 token 保留口子方便未来扩展。
  final Map<String, UploadCancelToken> _tokens = {};

  /// worker 是否正在跑——用 future 而不是 bool 是为了让 [waitIdle] 能 await。
  Future<void>? _worker;

  static final _rand = Random.secure();

  @override
  Map<String, MediaUploadJob> build() => const <String, MediaUploadJob>{};

  /// 生成一个本地 jobId。33 字符随机串，跟 Drive fileId 风格一致但加 `j-` 前缀，
  /// 方便代码里区分"还没传完的占位"和"真 fileId"。
  String _generateJobId() {
    final n = List<int>.generate(20, (_) => _rand.nextInt(256));
    final b = n.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return 'j-$b';
  }

  /// 把一份已选好的视频丢进队列。立即返回 jobId 给调用方插占位 embed 用。
  String enqueueVideo({
    required String entryId,
    required PickedVideo picked,
  }) {
    final jobId = _generateJobId();
    final token = UploadCancelToken();
    _files[jobId] = picked;
    _tokens[jobId] = token;
    state = {
      ...state,
      jobId: MediaUploadJob(
        jobId: jobId,
        entryId: entryId,
        kind: MediaJobKind.video,
        filename: picked.name,
        totalBytes: picked.sizeBytes,
        sentBytes: 0,
        status: MediaUploadStatus.pending,
      ),
    };
    _waiting.add(jobId);
    _kickWorker();
    return jobId;
  }

  /// 把一份已选好的图片字节丢进队列。返回 jobId。
  ///
  /// 图片用 ImageUploadService.uploadBytes（非 resumable），中途无法上报进度，
  /// 整段当原子操作；UI 在 placeholder 阶段画 indeterminate 进度条即可。
  /// 跟视频共用串行 worker——避免同时上传多份文件抢 Drive 带宽。
  String enqueueImage({
    required String entryId,
    required Uint8List bytes,
    required String filename,
  }) {
    final jobId = _generateJobId();
    _imageFiles[jobId] = _ImageSource(bytes: bytes, filename: filename);
    _tokens[jobId] = UploadCancelToken();
    state = {
      ...state,
      jobId: MediaUploadJob(
        jobId: jobId,
        entryId: entryId,
        kind: MediaJobKind.image,
        filename: filename,
        totalBytes: bytes.length,
        sentBytes: 0,
        status: MediaUploadStatus.pending,
      ),
    };
    _waiting.add(jobId);
    _kickWorker();
    return jobId;
  }

  /// 取消一个 job——pending 的直接出队，uploading 的让 token 触发 stream 抛错。
  void cancel(String jobId) {
    final job = state[jobId];
    if (job == null) return;
    _tokens[jobId]?.cancel();
    if (job.status == MediaUploadStatus.pending) {
      _waiting.remove(jobId);
      _setJob(jobId, job.copyWith(status: MediaUploadStatus.canceled));
    }
  }

  /// 重试失败 / 取消的 job——把它丢回队尾。
  void retry(String jobId) {
    final job = state[jobId];
    if (job == null) return;
    if (!(job.status == MediaUploadStatus.failed ||
        job.status == MediaUploadStatus.canceled)) {
      return;
    }
    // 视频源在 _files，图片源在 _imageFiles；任一存在都可以重试。
    if (!_files.containsKey(jobId) && !_imageFiles.containsKey(jobId)) {
      return; // 源丢失，不重试
    }
    _tokens[jobId] = UploadCancelToken();
    _setJob(
      jobId,
      job.copyWith(
        status: MediaUploadStatus.pending,
        sentBytes: 0,
        error: null,
        clearError: true,
      ),
    );
    _waiting.add(jobId);
    _kickWorker();
  }

  /// 删除一个完成的 job：从 Drive 撤掉文件 + 从 state 抹掉。
  /// 编辑器 dispose-without-save 用来清孤儿。
  Future<void> deleteUploaded(String jobId) async {
    final job = state[jobId];
    if (job == null) return;
    final fid = job.fileId;
    if (fid != null) {
      try {
        await ref.read(videoUploadServiceProvider).deleteByFileId(fid);
      } catch (_) {
        // best-effort
      }
    }
    _files.remove(jobId);
    _imageFiles.remove(jobId);
    _tokens.remove(jobId);
    final next = {...state}..remove(jobId);
    state = next;
  }

  /// 从 state 里彻底抹掉一个 job——比如已经被映射到 final embed 后调用，
  /// 不删 Drive 文件。
  void forget(String jobId) {
    _files.remove(jobId);
    _imageFiles.remove(jobId);
    _tokens.remove(jobId);
    if (!state.containsKey(jobId)) return;
    final next = {...state}..remove(jobId);
    state = next;
  }

  /// 公开读取 job 快照——provider 外部（如 dispose 阶段无法 ref.read 的场景）
  /// 通过 notifier 直接拿一份当前状态。
  MediaUploadJob? jobOf(String jobId) => state[jobId];

  /// 等待当前所有 job 跑完（用于编辑器 save 时确保 fileId 都到位再写盘）。
  /// 没有进行中的就立刻返回。
  Future<void> waitIdle() async {
    final w = _worker;
    if (w == null) return;
    await w;
  }

  void _kickWorker() {
    if (_worker != null) return;
    _worker = _drain();
  }

  Future<void> _drain() async {
    try {
      while (_waiting.isNotEmpty) {
        final id = _waiting.removeAt(0);
        final job = state[id];
        if (job == null) continue;
        if (_tokens[id]?.isCanceled == true) {
          _setJob(id, job.copyWith(status: MediaUploadStatus.canceled));
          continue;
        }
        await _runOne(id);
      }
    } finally {
      _worker = null;
    }
  }

  Future<void> _runOne(String jobId) async {
    final job = state[jobId];
    if (job == null) return;
    switch (job.kind) {
      case MediaJobKind.video:
        await _runVideo(jobId, job);
        return;
      case MediaJobKind.image:
        await _runImage(jobId, job);
        return;
    }
  }

  Future<void> _runImage(String jobId, MediaUploadJob job) async {
    final src = _imageFiles[jobId];
    if (src == null) {
      _setJob(
        jobId,
        job.copyWith(
          status: MediaUploadStatus.failed,
          error: '本地图片字节丢失',
        ),
      );
      return;
    }
    _setJob(jobId, job.copyWith(status: MediaUploadStatus.uploading));
    try {
      final svc = ref.read(imageUploadServiceProvider);
      final url = await svc.uploadBytes(
        bytes: src.bytes,
        filename: src.filename,
        entryId: job.entryId,
      );
      final fid = ImageUploadService.extractFileId(url) ?? '';
      final cur = state[jobId];
      if (cur == null) return;
      _setJob(
        jobId,
        cur.copyWith(
          status: MediaUploadStatus.done,
          fileId: fid,
          sentBytes: src.bytes.length,
        ),
      );
    } catch (e) {
      final cur = state[jobId];
      if (cur != null) {
        _setJob(
          jobId,
          cur.copyWith(
            status: MediaUploadStatus.failed,
            error: e.toString(),
          ),
        );
      }
    }
  }

  Future<void> _runVideo(String jobId, MediaUploadJob job) async {
    final picked = _files[jobId];
    if (picked == null) {
      _setJob(
        jobId,
        job.copyWith(
          status: MediaUploadStatus.failed,
          error: '本地文件丢失',
        ),
      );
      return;
    }

    _setJob(jobId, job.copyWith(status: MediaUploadStatus.uploading));
    try {
      final svc = ref.read(videoUploadServiceProvider);
      final res = await svc.upload(
        picked: picked,
        entryId: job.entryId,
        onProgress: (sent) {
          final cur = state[jobId];
          if (cur == null) return;
          _setJob(jobId, cur.copyWith(sentBytes: sent));
        },
        token: _tokens[jobId],
      );
      final cur = state[jobId];
      if (cur == null) return;
      _setJob(
        jobId,
        cur.copyWith(
          status: MediaUploadStatus.done,
          fileId: res.fileId,
          sentBytes: res.sizeBytes,
        ),
      );
      // 本设备上传完成 → 立刻把源文件复制进视频缓存，后续点击播放秒开，
      // 不需要再走 Drive 下载。失败 best-effort，下次播放时走 ensureLocal
      // 回源拉一次也能补上。
      unawaited(
        ref.read(driveVideoCacheProvider).cacheFromSource(
              res.fileId,
              picked.file,
            ),
      );
    } on UploadCanceledException {
      final cur = state[jobId];
      if (cur != null) {
        _setJob(jobId, cur.copyWith(status: MediaUploadStatus.canceled));
      }
    } catch (e) {
      final cur = state[jobId];
      if (cur != null) {
        _setJob(
          jobId,
          cur.copyWith(
            status: MediaUploadStatus.failed,
            error: e.toString(),
          ),
        );
      }
    }
  }

  void _setJob(String jobId, MediaUploadJob next) {
    state = {...state, jobId: next};
  }
}

/// 上传 job 的快照。Riverpod 状态里就是 `Map<jobId, MediaUploadJob>`。
class MediaUploadJob {
  const MediaUploadJob({
    required this.jobId,
    required this.entryId,
    required this.kind,
    required this.filename,
    required this.totalBytes,
    required this.sentBytes,
    required this.status,
    this.fileId,
    this.error,
  });

  final String jobId;
  final String entryId;
  final MediaJobKind kind;
  final String filename;
  final int totalBytes;
  final int sentBytes;
  final MediaUploadStatus status;

  /// 完成后的 Drive fileId；其它状态下为 null。
  final String? fileId;

  /// 失败时的错误消息。
  final String? error;

  double get progress {
    if (totalBytes <= 0) return 0;
    return (sentBytes / totalBytes).clamp(0.0, 1.0);
  }

  MediaUploadJob copyWith({
    int? sentBytes,
    MediaUploadStatus? status,
    String? fileId,
    String? error,
    bool clearError = false,
  }) {
    return MediaUploadJob(
      jobId: jobId,
      entryId: entryId,
      kind: kind,
      filename: filename,
      totalBytes: totalBytes,
      sentBytes: sentBytes ?? this.sentBytes,
      status: status ?? this.status,
      fileId: fileId ?? this.fileId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

enum MediaUploadStatus { pending, uploading, done, failed, canceled }
enum MediaJobKind { image, video }

class _ImageSource {
  _ImageSource({required this.bytes, required this.filename});
  final Uint8List bytes;
  final String filename;
}

final mediaUploadQueueProvider =
    NotifierProvider<MediaUploadQueue, Map<String, MediaUploadJob>>(
  MediaUploadQueue.new,
);
