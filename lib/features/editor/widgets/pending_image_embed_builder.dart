import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/image_upload_service.dart';
import '../../../data/services/media_upload_queue.dart';

/// 编辑器里"图片上传中"占位 embed。
///
/// 跟视频共用同一套队列；但图片完成后我们在保存阶段把这个 embed 整段
/// 重写成普通的 `image` URL embed（[BlockEmbed.image]）——这样持久化形态
/// 跟旧条目向后兼容，详情页 / 历史条目用同一个 [DriveQuillImageEmbedBuilder]
/// 即可显示，不需要新加 readOnly 分支。
///
/// 实时显示策略：watch [mediaUploadQueueProvider] 中对应 jobId 的状态：
/// - pending / uploading → 灰底卡片 + 进度条（图片用 uploadBytes 不报进度，
///   画 indeterminate 转圈）
/// - done → 立即翻面成 `Image.network(thumbnailUrl)`，等用户保存时持久化
/// - failed → 错误提示 + 重试/移除按钮
/// - canceled → editor 监听到自动从文档移除（不会停留在此态）
class PendingImageEmbedBuilder extends EmbedBuilder {
  const PendingImageEmbedBuilder();

  static const String embedType = 'pendingImage';

  @override
  String get key => embedType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final raw = embedContext.node.value.data;
    if (raw is! String || raw.isEmpty) return const SizedBox.shrink();
    PendingImageEmbedData data;
    try {
      data = PendingImageEmbedData.decode(raw);
    } catch (_) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _PendingImageCard(data: data),
    );
  }
}

class PendingImageEmbedData {
  const PendingImageEmbedData({required this.jobId, required this.name});

  final String jobId;
  final String name;

  String encode() => jsonEncode({'jobId': jobId, 'name': name});

  static PendingImageEmbedData decode(String raw) {
    final m = jsonDecode(raw);
    if (m is! Map) throw const FormatException('not a map');
    return PendingImageEmbedData(
      jobId: m['jobId'] as String? ?? '',
      name: m['name'] as String? ?? '',
    );
  }
}

class _PendingImageCard extends ConsumerWidget {
  const _PendingImageCard({required this.data});
  final PendingImageEmbedData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final queue = ref.watch(mediaUploadQueueProvider);
    final job = queue[data.jobId];

    if (job == null) {
      return _shell(
        context,
        child: const _BrokenInline(reason: '上传任务已丢失'),
      );
    }

    // 完成 → 直接渲染 thumbnail URL；保存时会被重写成 image embed，
    // 但 live 视图里立即翻面到正常图片。
    if (job.status == MediaUploadStatus.done &&
        (job.fileId ?? '').isNotEmpty) {
      final url = ImageUploadService.thumbnailUrl(job.fileId!);
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          // 完成态走 Image.network 而不是 DriveImageCache：因为这是 live 视图，
          // 几秒就刷掉了；缓存路径在保存后下次进来才会命中。
          child: Image.network(url, fit: BoxFit.contain),
        ),
      );
    }

    final isFailed = job.status == MediaUploadStatus.failed;
    final spinner = isFailed
        ? Icon(Icons.error_outline,
            color: theme.colorScheme.error, size: 22)
        : const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );

    return _shell(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              spinner,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isFailed)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '取消',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref
                      .read(mediaUploadQueueProvider.notifier)
                      .cancel(job.jobId),
                ),
              if (isFailed)
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
          if (!isFailed)
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              // 图片用非 resumable 上传，没法上报进度——画 indeterminate
              // 条让用户知道在跑。
              child: LinearProgressIndicator(minHeight: 4),
            )
          else
            Text(
              job.error ?? '上传失败',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            isFailed ? '失败' : '上传中…',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shell(BuildContext context, {required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _BrokenInline extends StatelessWidget {
  const _BrokenInline({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
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
    );
  }
}
