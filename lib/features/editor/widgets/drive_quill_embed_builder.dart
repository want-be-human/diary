import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/drive_image_cache.dart';

/// Quill 富文本里的 `image` 节点渲染器：把图片走 [DriveImageCache]，
/// 用我们已有的 OAuth + Clash 代理客户端下载到本地，再用 `Image.file` 渲染。
///
/// 跟 [ImageAttachmentGrid] 用的是同一份缓存——日记里插入的图、详情页只读
/// 渲染、project / todo 表单的挂图，全部命中同一份本地缓存目录，秒开。
///
/// 注册方式：`QuillEditor.basic(config: QuillEditorConfig(embedBuilders: [...]))`
/// 把这个 builder 实例放进去即可。Quill 遇到 `{insert: {image: 'url'}}` op
/// 就调用我们的 builder 而不是默认（默认在 11.x 没了）。
class DriveQuillImageEmbedBuilder extends EmbedBuilder {
  const DriveQuillImageEmbedBuilder();

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final url = embedContext.node.value.data as String? ?? '';
    if (url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _DriveQuillImage(url: url),
        ),
      ),
    );
  }
}

/// Riverpod 化的 Image.file widget。从 [DriveImageCache] 拉本地路径，
/// 拉到再渲染；拉的过程显示骨架占位。
class _DriveQuillImage extends ConsumerStatefulWidget {
  const _DriveQuillImage({required this.url});
  final String url;

  @override
  ConsumerState<_DriveQuillImage> createState() => _DriveQuillImageState();
}

class _DriveQuillImageState extends ConsumerState<_DriveQuillImage> {
  late Future<File?> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(driveImageCacheProvider).getFile(widget.url);
  }

  @override
  void didUpdateWidget(covariant _DriveQuillImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _future = ref.read(driveImageCacheProvider).getFile(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<File?>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            height: 200,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final f = snap.data;
        if (f == null) {
          return Container(
            height: 120,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
          );
        }
        return Image.file(f, fit: BoxFit.contain, gaplessPlayback: true);
      },
    );
  }
}
