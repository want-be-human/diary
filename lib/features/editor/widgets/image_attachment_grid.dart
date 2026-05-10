import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/drive_image_cache.dart';

/// "已挂图片"网格 + ➕ 上传槽位的纯展示组件。
///
/// 自己不知道怎么上传——选图 / 上传 / 删 Storage 全部委托给父级回调。
/// 这样 [ImageAttachmentGrid] 可以同时给"编辑模式"和"详情只读"复用：
/// - 编辑模式：父级在 [onAdd] 里调 ImageUploadService，[onRemove] 里维护清理
/// - 只读模式：父级把 [onAdd] / [onRemove] 留空，槽位自然消失
class ImageAttachmentGrid extends StatelessWidget {
  const ImageAttachmentGrid({
    super.key,
    required this.urls,
    this.onAdd,
    this.onRemove,
    this.maxCount = 6,
    this.uploading = false,
  });

  /// 已挂图片的 URL 列表（network URL 优先；非 network 走 broken 占位）。
  final List<String> urls;

  /// 用户点 ➕。null 时不显示槽位（只读模式）。
  final VoidCallback? onAdd;

  /// 用户点 ✕，回传被删除的索引。null 时缩略图角标隐藏（只读模式）。
  final void Function(int index)? onRemove;

  /// 单条目下挂图上限。
  final int maxCount;

  /// 上传中：➕ 槽位换成转圈，临时禁用点击。
  final bool uploading;

  bool get _readOnly => onAdd == null && onRemove == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (urls.isEmpty && _readOnly) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < urls.length; i++)
          _Thumb(
            url: urls[i],
            onDelete: onRemove == null ? null : () => onRemove!(i),
          ),
        if (onAdd != null && urls.length < maxCount)
          InkWell(
            onTap: uploading ? null : onAdd,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.4),
                ),
              ),
              child: uploading
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 22,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
            ),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.onDelete});

  final String url;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: _safeImage(url, scheme),
          ),
        ),
        if (onDelete != null)
          Positioned(
            right: -4,
            top: -4,
            child: InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _safeImage(String url, ColorScheme scheme) {
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');
    if (!isNetwork) return _errorPlaceholder(scheme);
    // 走 DriveImageCache：用我们已有的 OAuth 客户端（带 Clash 代理）下载文件
    // 字节，写到本地缓存，渲染时用 Image.file —— 绕开 Drive 公开 URL 在国内
    // 不稳的链路。第二次渲染直接命中文件系统，秒开。
    return _DriveImage(url: url, scheme: scheme);
  }

  static Widget _loadingPlaceholder(ColorScheme scheme) => Container(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        alignment: Alignment.center,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: scheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );

  static Widget _errorPlaceholder(ColorScheme scheme) => Container(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          size: 18,
          color: scheme.onSurface.withValues(alpha: 0.4),
        ),
      );
}

/// 内部用：走 [DriveImageCache] 拿本地文件，再用 Image.file 渲染。
class _DriveImage extends ConsumerStatefulWidget {
  const _DriveImage({required this.url, required this.scheme});

  final String url;
  final ColorScheme scheme;

  @override
  ConsumerState<_DriveImage> createState() => _DriveImageState();
}

class _DriveImageState extends ConsumerState<_DriveImage> {
  late Future<File?> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(driveImageCacheProvider).getFile(widget.url);
  }

  @override
  void didUpdateWidget(covariant _DriveImage old) {
    super.didUpdateWidget(old);
    // URL 变了（不太常见，因为 _Thumb 用 url 作 key）才重新拉。
    if (old.url != widget.url) {
      _future = ref.read(driveImageCacheProvider).getFile(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _Thumb._loadingPlaceholder(widget.scheme);
        }
        final file = snap.data;
        if (file == null) return _Thumb._errorPlaceholder(widget.scheme);
        return Image.file(
          file,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}
