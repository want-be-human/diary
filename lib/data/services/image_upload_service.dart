import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart' as drive_v3;
import 'package:image_picker/image_picker.dart' as ip;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// 图片上传服务（**Google Drive 后端**，不再用 Firebase Storage）。
///
/// Drive 比 Firebase Storage 的优势：
/// - 用户已有 2TB Drive 空间，零额外成本
/// - 不需要 Firebase Blaze 计划（免绑信用卡）
/// - OAuth + scopes (`drive.file`) 已经在登录链路里复用
///
/// 路径约定：所有图片放在用户 Drive 的 "日记 App" 子文件夹下，
/// 文件名用 `{entryId}-{ts}-{rand}.{ext}`，
/// 通过 `appProperties` 打 tag（`app=diary`、`entryId=...`）方便后续聚合 / 清理。
/// folder ID 缓存到 SharedPreferences，避免每次上传都查一遍。
///
/// 共享策略：上传后立刻 `permissions.create({type:'anyone', role:'reader'})`
/// → 文件可通过 `https://lh3.googleusercontent.com/d/{fileId}` 这个 CDN URL
/// 公开访问；Flutter 端 `Image.network` 拿这个 URL 即可显示。
/// 文件 ID 是 33 字符随机串、不可枚举，对个人日记的隐私需求够用。
///
/// 平台分支：图片选择仍保持 Android: image_picker / 其它: file_picker。
class ImageUploadService {
  ImageUploadService(this._auth);

  final AuthService _auth;

  static const String _kFolderName = '日记 App';
  static const String _kPrefsFolderId = 'drive.diary_folder_id';

  /// 给定 fileId 拼 Drive 官方 thumbnail URL，列表 / Quill embed 渲染图片走它。
  /// width 默认 1024 像素够列表卡片用；详情页要原图就提到 2048。
  static String thumbnailUrl(String fileId, {int width = 1024}) =>
      'https://drive.google.com/thumbnail?id=$fileId&sz=w$width';

  /// 弹文件选择 → 上传到 Drive → 返回可直链显示的 URL。
  /// 用户取消选择返回 null；上传失败抛异常（调用方决定 UI 提示）。
  Future<String?> pickAndUpload({
    required String uid, // 保留参数兼容旧调用，Drive 路径不需要它
    required String entryId,
  }) async {
    final picked = await _pickFile();
    if (picked == null) return null;
    return uploadBytes(
      bytes: picked.bytes,
      filename: picked.name,
      entryId: entryId,
    );
  }

  /// 直接传字节流上传（已经在内存里的图片）。
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String filename,
    required String entryId,
  }) async {
    final client = await _auth.getAuthedClient();
    if (client == null) {
      throw StateError(
        '请先用 Google 账号登录以使用图片上传——Drive scope (drive.file) 必须授权。',
      );
    }
    try {
      final api = drive_v3.DriveApi(client);
      final folderId = await _ensureFolder(api);
      final ext = _extOf(filename);
      final mime = _mimeOf(ext);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final rand = (ts % 0xFFFF).toRadixString(16);

      final file = drive_v3.File()
        ..name = '$entryId-$ts-$rand$ext'
        ..mimeType = mime
        ..parents = [folderId]
        // 给文件打 tag，方便后续按 entryId 聚合 / 一键清理本应用上传的所有图。
        ..appProperties = {'app': 'diary', 'entryId': entryId};

      final media = drive_v3.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: mime,
      );

      final created = await api.files.create(file, uploadMedia: media);
      final fileId = created.id;
      if (fileId == null) {
        throw StateError('Drive create 返回空 id');
      }

      // 让任何拿到 URL 的人能 read，Flutter Image.network 才能渲染。
      // role=reader 不允许写、不允许删，仅查看；type=anyone 表示无需登录。
      await api.permissions.create(
        drive_v3.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        fileId,
      );

      // 用 Drive 官方 thumbnail 端点：稳定支持公开访问 + 服务端按 sz 参数缩放，
      // 比社区 hack 的 lh3.googleusercontent.com/d/{id} 更可靠。
      // sz=w1024 ≈ 列表卡片够用；详情页要原图把这个改成 w2048 即可。
      return thumbnailUrl(fileId);
    } finally {
      client.close();
    }
  }

  /// 尽量删除一张图。不存在 / 已删除 / 鉴权失败时静默忽略。
  Future<void> deleteByUrl(String url) async {
    final fileId = extractFileId(url);
    if (fileId == null) return;
    final client = await _auth.getAuthedClient();
    if (client == null) return;
    try {
      final api = drive_v3.DriveApi(client);
      await api.files.delete(fileId);
    } catch (_) {
      // 任何失败（404 / 鉴权 / 离线）都吞掉——清理是 best-effort。
    } finally {
      client.close();
    }
  }

  /// 拿到（或创建）"日记 App" 子文件夹 ID。视频上传管线（[VideoUploadService]）
  /// 需要复用同一个文件夹，所以暴露公共方法；调用方需自备 [drive_v3.DriveApi]。
  /// 内部委托给 [_ensureFolder]。
  Future<String> ensureDiaryFolder(drive_v3.DriveApi api) =>
      _ensureFolder(api);

  /// 确保 "日记 App" 子文件夹存在；返回 folder ID。
  ///
  /// 流程：
  /// 1. 优先读 SharedPreferences 缓存的 folder ID，验证未被删除（trashed/404）
  /// 2. 缓存失效 → 走 Drive `files.list` 查 `name='日记 App' and mimeType=folder`
  /// 3. 还没有 → `files.create` 建一个新的
  ///
  /// 注：用 `drive.file` scope，只能看到自己创建的文件，所以查询返回的就是
  /// 本 App 之前建的文件夹（如果有），不会跟用户的其它同名文件夹冲突。
  Future<String> _ensureFolder(drive_v3.DriveApi api) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kPrefsFolderId);
    if (cached != null && cached.isNotEmpty) {
      try {
        final f = await api.files.get(cached, $fields: 'id, trashed')
            as drive_v3.File;
        if (f.trashed != true) return cached;
      } catch (_) {
        // 文件夹已被删 / 没权限 / 网络错；走重建流程。
      }
      await prefs.remove(_kPrefsFolderId);
    }

    // 查询：drive.file scope 下只能看到本 App 创建的文件，所以这里查到的
    // 一定是之前自己建的"日记 App"文件夹。
    final list = await api.files.list(
      q: "name='$_kFolderName' "
          "and mimeType='application/vnd.google-apps.folder' "
          'and trashed=false',
      $fields: 'files(id)',
      spaces: 'drive',
      pageSize: 1,
    );
    final existing = list.files;
    if (existing != null && existing.isNotEmpty && existing.first.id != null) {
      final id = existing.first.id!;
      await prefs.setString(_kPrefsFolderId, id);
      return id;
    }

    // 都没有，创建新的。
    final newFolder = drive_v3.File()
      ..name = _kFolderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..appProperties = {'app': 'diary', 'kind': 'root_folder'};
    final created = await api.files.create(newFolder);
    final id = created.id;
    if (id == null) {
      throw StateError('Drive 创建"日记 App"文件夹失败：返回空 id');
    }
    await prefs.setString(_kPrefsFolderId, id);
    return id;
  }

  /// 从 Drive URL 反解 fileId。兼容三种格式：
  /// - `drive.google.com/thumbnail?id={id}&sz=...`（当前默认）
  /// - `lh3.googleusercontent.com/d/{id}`（旧版本上传的，保留兼容）
  /// - `drive.google.com/uc?id={id}`
  ///
  /// 其它格式 URL（外链、Firebase Storage URL）返回 null —— 调用方拿到 null
  /// 就当那张图不归我管，不去清理。
  static String? extractFileId(String url) {
    final patterns = <RegExp>[
      RegExp(r'drive\.google\.com/thumbnail\?(?:[^#]*&)?id=([A-Za-z0-9_-]+)'),
      RegExp(r'drive\.google\.com/uc\?(?:[^#]*&)?id=([A-Za-z0-9_-]+)'),
      RegExp(r'lh3\.googleusercontent\.com/d/([A-Za-z0-9_-]+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// 通过 Drive API 直接下载文件字节（带 OAuth + Clash 代理）。
  /// 用于 [DriveImageCache]——给 Image.file 喂本地路径，绕开"公开 URL"链路。
  /// 失败 / 没登录 / 文件不存在时返回 null。
  Future<Uint8List?> downloadBytes(String fileId) async {
    final client = await _auth.getAuthedClient();
    if (client == null) return null;
    try {
      final api = drive_v3.DriveApi(client);
      final media = await api.files.get(
        fileId,
        downloadOptions: drive_v3.DownloadOptions.fullMedia,
      ) as drive_v3.Media;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in media.stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// 弹文件选择器，返回文件名 + 字节流；用户取消返回 null。
  /// 暴露出来给 [MediaUploadQueue.enqueueImage] 用——队列模式下选完不立即
  /// 上传，先返回 jobId 让 UI 插占位 embed，worker 后台跑真上传。
  Future<PickedImage?> pickFile() async {
    final p = await _pickFile();
    if (p == null) return null;
    return PickedImage(name: p.name, bytes: p.bytes);
  }

  Future<_Picked?> _pickFile() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final picker = ip.ImagePicker();
      final x = await picker.pickImage(
        source: ip.ImageSource.gallery,
        imageQuality: 85, // 适度压缩，省流量
      );
      if (x == null) return null;
      return _Picked(name: x.name, bytes: await x.readAsBytes());
    }
    final result = await fp.FilePicker.platform.pickFiles(
      type: fp.FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return null;
    return _Picked(name: f.name, bytes: bytes);
  }

  static String _extOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    return name.substring(dot).toLowerCase();
  }

  static String _mimeOf(String ext) {
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}

class _Picked {
  _Picked({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// 选好的图片字节（公开版，供 MediaUploadQueue 用）。
class PickedImage {
  PickedImage({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

final imageUploadServiceProvider = Provider<ImageUploadService>(
  (ref) => ImageUploadService(ref.watch(authServiceProvider)),
);
