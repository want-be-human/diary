import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/media_upload_queue.dart';
import '../../../data/services/video_upload_service.dart';

/// Quill 富文本里的 Drive 视频 embed 渲染器。
///
/// embed 类型为 `driveVideo`，data 是 JSON 字符串：
/// ```json
/// {"jobId":"j-...", "fileId":null, "name":"holiday.mp4", "size":12345}   // 上传中占位
/// {"jobId":null,    "fileId":"abc", "name":"holiday.mp4", "size":12345}  // 完成
/// ```
///
/// 渲染分支：
/// - 仅有 jobId（无 fileId）→ 监听 [mediaUploadQueueProvider] 的对应 job，
///   显示进度条 + 文件名 + 取消按钮
/// - 有 fileId → 显示视频卡片（缩略图 / 文件名 / 大小），点击 url_launcher
///   打开 https://drive.google.com/file/d/{id}/view
///
/// 编辑器在保存时会把所有 jobId-only 的 embed 重写成 fileId-only（见 editor_page._save）。
class DriveVideoEmbedBuilder extends EmbedBuilder {
  const DriveVideoEmbedBuilder({this.readOnly = false});

  /// 详情页只读模式：不显示「取消」按钮（因为详情页拿到的肯定是 fileId 已 done）。
  final bool readOnly;

  static const String embedType = 'driveVideo';

  @override
  String get key => embedType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final raw = embedContext.node.value.data;
    if (raw is! String || raw.isEmpty) return const SizedBox.shrink();
    DriveVideoEmbedData data;
    try {
      data = DriveVideoEmbedData.decode(raw);
    } catch (_) {
      return const _BrokenCard(reason: '视频嵌入数据损坏');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _DriveVideoCard(data: data, readOnly: readOnly),
    );
  }
}

/// 视频 embed 的载荷。`jobId` 和 `fileId` 互斥（同时存在时 fileId 优先）。
class DriveVideoEmbedData {
  const DriveVideoEmbedData({
    this.jobId,
    this.fileId,
    required this.name,
    required this.size,
  });

  final String? jobId;
  final String? fileId;
  final String name;
  final int size;

  /// 已上传 → 有 fileId；占位 → 只有 jobId。
  bool get isUploaded => (fileId ?? '').isNotEmpty;

  String encode() => jsonEncode({
        if ((jobId ?? '').isNotEmpty) 'jobId': jobId,
        if ((fileId ?? '').isNotEmpty) 'fileId': fileId,
        'name': name,
        'size': size,
      });

  static DriveVideoEmbedData decode(String raw) {
    final m = jsonDecode(raw);
    if (m is! Map) throw const FormatException('not a map');
    return DriveVideoEmbedData(
      jobId: m['jobId'] as String?,
      fileId: m['fileId'] as String?,
      name: m['name'] as String? ?? '',
      size: (m['size'] as num?)?.toInt() ?? 0,
    );
  }

  DriveVideoEmbedData copyAsUploaded(String fileId) {
    return DriveVideoEmbedData(
      fileId: fileId,
      name: name,
      size: size,
    );
  }
}

class _DriveVideoCard extends ConsumerWidget {
  const _DriveVideoCard({required this.data, required this.readOnly});

  final DriveVideoEmbedData data;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.isUploaded) {
      return _UploadedView(data: data);
    }
    // 占位：watch 队列中对应 jobId 的最新状态。
    final jobId = data.jobId;
    if (jobId == null) {
      return const _BrokenCard(reason: '视频引用缺失');
    }
    final queue = ref.watch(mediaUploadQueueProvider);
    final job = queue[jobId];
    if (job == null) {
      // 进程被重启 / 队列被清空 → 占位失效，显示损坏卡片。
      return const _BrokenCard(reason: '上传任务已丢失');
    }
    // 上传完成时立刻翻成"已上传卡片"视图，不必等用户按保存。
    // 持久化时（editor save）才把 fileId 写回 embed JSON——live 视图直接
    // 借用队列里的 fileId 即可。
    if (job.status == MediaUploadStatus.done &&
        (job.fileId ?? '').isNotEmpty) {
      return _UploadedView(data: data.copyAsUploaded(job.fileId!));
    }
    return _PendingView(job: job, readOnly: readOnly);
  }
}

class _UploadedView extends StatelessWidget {
  const _UploadedView({required this.data});
  final DriveVideoEmbedData data;

  /// 移动端 (Android/iOS) 走应用内播放页：本地缓存命中秒播，没命中走 Drive
  /// 下载后再播——同设备上传的视频一定已经在缓存里。
  /// 桌面 / Web：video_player 不支持 → 直接 url_launcher 打开 Drive 预览页。
  bool get _useInApp {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _open(BuildContext context) async {
    if (_useInApp) {
      final id = Uri.encodeQueryComponent(data.fileId!);
      final name = Uri.encodeQueryComponent(data.name);
      context.push('/video?id=$id&name=$name');
      return;
    }
    final url = VideoUploadService.previewUrl(data.fileId!);
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开 Drive 预览页')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_circle_outline,
                  size: 30,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name.isEmpty ? '视频' : data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_humanSize(data.size)} · ${_useInApp ? "点击播放" : "点击在 Drive 中打开"}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (!_useInApp) ...[
                      const SizedBox(height: 2),
                      // 桌面端走 Drive 预览页：Drive 转码完成后才能在线播放。
                      // 短视频几十秒，大文件可能要几分钟；这期间 Drive 会显示
                      // "此视频文件仍在处理中"。文件已上完，等就行。
                      Text(
                        'Drive 转码后即可在线播放',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.45),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _useInApp ? Icons.play_arrow : Icons.open_in_new,
                size: 18,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingView extends ConsumerWidget {
  const _PendingView({required this.job, required this.readOnly});
  final MediaUploadJob job;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = job.status;

    final (subtitle, icon, iconColor) = switch (s) {
      MediaUploadStatus.pending => (
          '等待上传…',
          Icons.schedule,
          scheme.onSurface.withValues(alpha: 0.55),
        ),
      MediaUploadStatus.uploading => (
          '上传中 ${(job.progress * 100).toStringAsFixed(0)}% · '
              '${_humanSize(job.sentBytes)} / ${_humanSize(job.totalBytes)}',
          Icons.cloud_upload_outlined,
          scheme.primary,
        ),
      MediaUploadStatus.done => (
          '上传完成（保存后生效）',
          Icons.check_circle_outline,
          scheme.primary,
        ),
      MediaUploadStatus.failed => (
          '失败：${job.error ?? "未知错误"}',
          Icons.error_outline,
          theme.colorScheme.error,
        ),
      MediaUploadStatus.canceled => (
          '已取消',
          Icons.cancel_outlined,
          scheme.onSurface.withValues(alpha: 0.55),
        ),
    };

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    job.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!readOnly &&
                    s != MediaUploadStatus.done &&
                    s != MediaUploadStatus.canceled)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: '取消上传',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(mediaUploadQueueProvider.notifier)
                        .cancel(job.jobId),
                  ),
                if (!readOnly &&
                    (s == MediaUploadStatus.failed ||
                        s == MediaUploadStatus.canceled))
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: '重试',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(mediaUploadQueueProvider.notifier)
                        .retry(job.jobId),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (s == MediaUploadStatus.uploading ||
                s == MediaUploadStatus.pending)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:
                      s == MediaUploadStatus.pending ? null : job.progress,
                  minHeight: 4,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrokenCard extends StatelessWidget {
  const _BrokenCard({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.broken_image_outlined,
              size: 22, color: scheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
