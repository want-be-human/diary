import 'package:flutter/material.dart';

/// 表单内的"图片挂件"网格 —— 显示已挂图片的缩略图 + 一个 ➕ 上传槽。
///
/// 当前为 UI 占位：
/// - 已上传图片：渲染为缩略图（network 优先，回退到 file://）+ 角标可删除
/// - ➕ 槽位：现阶段弹 SnackBar 提示"图片上传管线下一刀接入"
///
/// 真正的上传管线（image_picker / file_picker + Firebase Storage）作为下一刀单独做，
/// 那时把 `_pickAndUpload()` 换成实际实现即可，调用方不需要改。
class ImageAttachmentGrid extends StatelessWidget {
  const ImageAttachmentGrid({
    super.key,
    required this.urls,
    required this.onChanged,
    this.maxCount = 6,
  });

  /// 已挂图片的 URL 列表（network URL 或 file:// 本地路径都行，目前只用作展示）。
  final List<String> urls;

  /// 用户增删后回调新的列表。
  final void Function(List<String>) onChanged;

  /// 单条目下挂图上限。
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < urls.length; i++)
          _Thumb(
            url: urls[i],
            onDelete: () {
              final next = List<String>.from(urls)..removeAt(i);
              onChanged(next);
            },
          ),
        if (urls.length < maxCount)
          InkWell(
            onTap: () => _pickAndUpload(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 22,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    // TODO: 接入 image_picker / file_picker + Firebase Storage 上传，
    //       拿到 download URL 后 onChanged([...urls, url])。
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('图片上传将在下一阶段接入')),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.onDelete});

  final String url;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: _safeImage(url, scheme),
          ),
        ),
        Positioned(
          right: -2,
          top: -2,
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
    final placeholder = Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        size: 18,
        color: scheme.onSurface.withValues(alpha: 0.4),
      ),
    );
    if (!isNetwork) return placeholder;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
