import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'image_upload_service.dart';

/// 把 Drive 私有文件按 fileId 缓存到 app cache 目录，给 `Image.file` 渲染用。
///
/// 为什么不直接 `Image.network` Drive 公开 URL？
/// - `lh3.googleusercontent.com/d/{id}` / `drive.google.com/thumbnail?id=...`
///   在国内常被节流，Image.network 经常 timeout
/// - 走我们已有的 OAuth 客户端（已挂 Clash 代理）下载文件字节，反而更稳
///
/// 缓存层级：
/// 1. **本地文件**：`<appCache>/diary_drive_images/{fileId}` —— 持久化，秒开
/// 2. **Flutter ImageCache**：`Image.file` 解码后存内存，本会话内复用
///
/// 并发去重：同一 fileId 若有多个 widget 同时请求，只下载一次（_inflight map）。
class DriveImageCache {
  DriveImageCache(this._uploader);

  final ImageUploadService _uploader;

  static const _kSubdir = 'diary_drive_images';
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

  /// 拿一个本地文件来渲染。
  /// - URL 解析不出 fileId（外链 / 旧 Firebase URL）→ null
  /// - 缓存命中 → 立刻返回 File（不走网络）
  /// - 缓存未命中 → 走 Drive API 下载 → 写本地 → 返回 File
  /// - 下载失败 → null
  Future<File?> getFile(String url) async {
    final fileId = ImageUploadService.extractFileId(url);
    if (fileId == null) return null;

    final dir = await _dir();
    final f = File('${dir.path}/$fileId');
    if (await f.exists() && await f.length() > 0) return f;

    return _inflight.putIfAbsent(fileId, () async {
      try {
        final bytes = await _uploader.downloadBytes(fileId);
        if (bytes == null || bytes.isEmpty) return null;
        await f.writeAsBytes(bytes, flush: true);
        return f;
      } finally {
        _inflight.remove(fileId);
      }
    });
  }

  /// 清单条目被永久删除时调用：把这张图的本地缓存也删掉，免得长期堆积。
  Future<void> remove(String url) async {
    final fileId = ImageUploadService.extractFileId(url);
    if (fileId == null) return;
    final dir = await _dir();
    final f = File('${dir.path}/$fileId');
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {
      // best-effort
    }
  }
}

final driveImageCacheProvider = Provider<DriveImageCache>(
  (ref) => DriveImageCache(ref.read(imageUploadServiceProvider)),
);
