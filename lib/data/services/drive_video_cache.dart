import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'video_upload_service.dart';

/// Drive 视频本地缓存：跟 [DriveImageCache] 同样的语义但走文件流而不是字节。
///
/// 写入时机：
/// 1. **本设备上传**：[MediaUploadQueue] 在上传成功后调 [cacheFromSource]
///    把源文件复制到缓存目录——上传完立刻能本地播，不必再走 Drive 下载。
/// 2. **跨设备查看**：当本地没有缓存时调 [downloadAndCache] 走 Drive API
///    （OAuth + Clash 代理）流式下到本地，再播。
///
/// 缓存路径：`<appCache>/diary_drive_videos/{fileId}`。文件名不带扩展名，
/// video_player 通过文件头嗅探格式，扩展名无关。
///
/// 并发：同一个 fileId 同时被多处请求时，只发起一次下载（_inflight）。
class DriveVideoCache {
  DriveVideoCache(this._videoSvc);

  final VideoUploadService _videoSvc;

  static const _kSubdir = 'diary_drive_videos';
  Directory? _dirCached;
  final Map<String, Future<File?>> _inflight = {};

  Future<Directory> _dir() async {
    if (_dirCached != null) return _dirCached!;
    final base = await getApplicationCacheDirectory();
    final d = Directory('${base.path}/$_kSubdir');
    if (!await d.exists()) await d.create(recursive: true);
    _dirCached = d;
    return d;
  }

  /// 返回缓存里这个 fileId 对应的 [File]，存在且非空则返回，否则 null。
  /// 同步轻量，可在 build 期间调，只用于 UI 决策"要不要直接播"。
  Future<File?> getCachedFile(String fileId) async {
    if (fileId.isEmpty) return null;
    final dir = await _dir();
    final f = File('${dir.path}/$fileId');
    if (await f.exists() && await f.length() > 0) return f;
    return null;
  }

  /// 本地有 → 直接返回；没有 → 走 Drive 下载并写入缓存，返回 File。
  /// [onProgress]：下载进度回调（sent, total）。失败返回 null。
  Future<File?> ensureLocal(
    String fileId, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final cached = await getCachedFile(fileId);
    if (cached != null) return cached;
    return _inflight.putIfAbsent(fileId, () async {
      try {
        final dir = await _dir();
        final f = File('${dir.path}/$fileId');
        return await _videoSvc.downloadToFile(
          fileId: fileId,
          destination: f,
          onProgress: onProgress,
        );
      } finally {
        _inflight.remove(fileId);
      }
    });
  }

  /// 把刚上传完的源文件复制进缓存——上传设备秒播。
  /// 失败（磁盘满 / 权限）静默忽略，下次播放时走 [ensureLocal] 回源下载。
  Future<void> cacheFromSource(String fileId, File source) async {
    try {
      final dir = await _dir();
      final dest = File('${dir.path}/$fileId');
      // copy 走系统 sendfile/类似优化，比 read+write 快也不占内存。
      await source.copy(dest.path);
    } catch (_) {
      // best-effort
    }
  }

  /// 视频从条目里被删除时调用：把本地缓存也删掉。
  Future<void> remove(String fileId) async {
    if (fileId.isEmpty) return;
    try {
      final dir = await _dir();
      final f = File('${dir.path}/$fileId');
      if (await f.exists()) await f.delete();
    } catch (_) {
      // best-effort
    }
  }
}

final driveVideoCacheProvider = Provider<DriveVideoCache>(
  (ref) => DriveVideoCache(ref.read(videoUploadServiceProvider)),
);
