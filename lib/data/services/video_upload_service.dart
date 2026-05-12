import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart' as drive_v3;

import 'auth_service.dart';
import 'image_upload_service.dart';

/// 视频上传服务（**Google Drive 后端，resumable**）。
///
/// 跟 [ImageUploadService] 共用同一个 Drive 文件夹（"日记 App"）和同一套
/// `appProperties` tag，方便后续按 entryId 聚合或一键清理；区别是：
/// - 走 [ResumableUploadOptions]，1MB 一块、分块上传，支持中途网络抖动重试
/// - 不读整个文件到内存（`File.openRead()` 流式读）
/// - 提供 [onProgress] 回调，UI 用来画进度条
/// - 提供 [token] 让调用方中途取消（编辑器关页/dispose 时撤销未完成的传）
///
/// 不返回 CDN URL（Drive 没有公开视频 CDN），返回的是 Drive `fileId`，
/// 详情页/编辑器自己用 `https://drive.google.com/file/d/{id}/view` 拼出预览页 URL。
class VideoUploadService {
  VideoUploadService(this._auth, this._imageSvc);

  final AuthService _auth;
  final ImageUploadService _imageSvc;

  /// 弹文件选择器；用户取消时返回 null。
  /// 用 file_picker 而不是 image_picker 是因为 image_picker 在桌面端不支持
  /// 视频，且我们也不希望它在 Android 上压缩视频（默认会触发 transcoding）。
  Future<PickedVideo?> pickVideoFile() async {
    final result = await fp.FilePicker.platform.pickFiles(
      type: fp.FileType.video,
      allowMultiple: false,
      // withData: false 不读到内存——视频可能 100MB+，要走流式。
      // 平台返回 path（Android/iOS/Win/Linux 都有），桌面 web 拿不到 path
      // 但 web 我们暂不支持。
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    final path = f.path;
    if (path == null) return null;
    final file = File(path);
    final size = await file.length();
    return PickedVideo(file: file, name: f.name, sizeBytes: size);
  }

  /// 上传一份视频文件到 Drive。
  ///
  /// [picked] 来自 [pickVideoFile]；[entryId] 用于打 tag 关联条目；
  /// [onProgress] 在每块上传后被调用，传入累计已发送字节数；
  /// [token] 上传过程中调用 [UploadCancelToken.cancel] 即抛 [UploadCanceledException]。
  ///
  /// 返回的 [VideoUploadResult.fileId] 是 Drive 上的 33 字符随机 ID，
  /// 可拼出预览页 URL；调用方负责把 fileId/name/size 编码进 Quill embed。
  Future<VideoUploadResult> upload({
    required PickedVideo picked,
    required String entryId,
    required void Function(int sent) onProgress,
    UploadCancelToken? token,
  }) async {
    final client = await _auth.getAuthedClient();
    if (client == null) {
      throw StateError(
        '请先用 Google 账号登录以使用视频上传——Drive scope (drive.file) 必须授权。',
      );
    }
    try {
      final api = drive_v3.DriveApi(client);
      final folderId = await _imageSvc.ensureDiaryFolder(api);
      final mime = _mimeOf(picked.name);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final rand = (ts % 0xFFFF).toRadixString(16);

      final file = drive_v3.File()
        ..name = '$entryId-$ts-$rand-${picked.name}'
        ..mimeType = mime
        ..parents = [folderId]
        ..appProperties = {
          'app': 'diary',
          'entryId': entryId,
          'mediaType': 'video',
        };

      // 包装 openRead 流：每块读出来时累加字节数 + 检查取消。
      // chunkSize 1MB（resumable 最小块对齐 256KB 的倍数）。
      final stream = _wrapWithProgress(
        picked.file.openRead(),
        onProgress,
        token,
      );

      final media = drive_v3.Media(
        stream,
        picked.sizeBytes,
        contentType: mime,
      );

      final created = await api.files.create(
        file,
        uploadMedia: media,
        uploadOptions: drive_v3.ResumableUploadOptions(
          // 1MB 块；视频文件普遍较大，块越大请求次数越少效率越高。
          chunkSize: 1024 * 1024,
        ),
      );
      final fileId = created.id;
      if (fileId == null) {
        throw StateError('Drive create 返回空 id');
      }

      // 公开读，便于点击"打开 Drive 预览"时无需登录就能播放。
      // 注意：anyone+reader 之后任何拿到 URL 的人都能看；对个人日记的私密性
      // 已经由 33 字符不可枚举 ID 兜住，跟 image 上传同等模型。
      await api.permissions.create(
        drive_v3.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        fileId,
      );

      return VideoUploadResult(
        fileId: fileId,
        name: picked.name,
        sizeBytes: picked.sizeBytes,
        mime: mime,
      );
    } finally {
      client.close();
    }
  }

  /// 流式下载一份 Drive 视频到本地文件，全程不把整文件读进内存。
  /// 用途：跨设备查看时，目标设备没有本地源文件，需要从 Drive 拉一次再播。
  ///
  /// [onProgress] 每块写盘后回调（sent / total）。`total` 可能为 0——
  /// Drive 不一定带 Content-Length，此时 UI 显示「下载中…」不画百分比。
  /// 失败 / 未登录返回 null，且 best-effort 删掉部分写入的目标文件。
  Future<File?> downloadToFile({
    required String fileId,
    required File destination,
    void Function(int sent, int total)? onProgress,
  }) async {
    final client = await _auth.getAuthedClient();
    if (client == null) return null;
    IOSink? sink;
    try {
      final api = drive_v3.DriveApi(client);
      final media = await api.files.get(
        fileId,
        downloadOptions: drive_v3.DownloadOptions.fullMedia,
      ) as drive_v3.Media;

      final total = media.length ?? 0;
      // 父目录可能不存在，比如 cache 第一次写。
      await destination.parent.create(recursive: true);
      sink = destination.openWrite();
      var sent = 0;
      await for (final chunk in media.stream) {
        sink.add(chunk);
        sent += chunk.length;
        if (onProgress != null) onProgress(sent, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      return destination;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {/* best-effort */}
      try {
        if (await destination.exists()) await destination.delete();
      } catch (_) {/* best-effort */}
      return null;
    } finally {
      client.close();
    }
  }

  /// 删除一份已上传的视频（best-effort，跟 image 删除语义一致）。
  Future<void> deleteByFileId(String fileId) async {
    final client = await _auth.getAuthedClient();
    if (client == null) return;
    try {
      final api = drive_v3.DriveApi(client);
      await api.files.delete(fileId);
    } catch (_) {
      // 失败吞掉——清理是 best-effort。
    } finally {
      client.close();
    }
  }

  /// 拼一个外部预览页 URL，[url_launcher] 直接 open 即可。
  static String previewUrl(String fileId) =>
      'https://drive.google.com/file/d/$fileId/view';

  Stream<List<int>> _wrapWithProgress(
    Stream<List<int>> source,
    void Function(int sent) onProgress,
    UploadCancelToken? token,
  ) async* {
    var sent = 0;
    await for (final chunk in source) {
      // 每次取数据时检查取消标志——resumable 上传是 push 模型，
      // 我们这边停止 yield 即可让上层 abort。
      if (token?.isCanceled == true) {
        throw UploadCanceledException();
      }
      yield chunk;
      sent += chunk.length;
      onProgress(sent);
    }
  }

  static String _mimeOf(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    if (lower.endsWith('.flv')) return 'video/x-flv';
    return 'video/mp4'; // 默认 mp4，兼容性最好
  }
}

class PickedVideo {
  PickedVideo({
    required this.file,
    required this.name,
    required this.sizeBytes,
  });

  final File file;
  final String name;
  final int sizeBytes;
}

class VideoUploadResult {
  VideoUploadResult({
    required this.fileId,
    required this.name,
    required this.sizeBytes,
    required this.mime,
  });

  final String fileId;
  final String name;
  final int sizeBytes;
  final String mime;
}

/// 取消 token：编辑器在 dispose-without-save 或用户点击"取消上传"时
/// 调用 [cancel]，VideoUploadService 内部的 stream wrapper 检查到就抛错。
class UploadCancelToken {
  bool _canceled = false;
  bool get isCanceled => _canceled;
  void cancel() => _canceled = true;
}

class UploadCanceledException implements Exception {
  @override
  String toString() => 'UploadCanceledException';
}

final videoUploadServiceProvider = Provider<VideoUploadService>(
  (ref) => VideoUploadService(
    ref.watch(authServiceProvider),
    ref.watch(imageUploadServiceProvider),
  ),
);
