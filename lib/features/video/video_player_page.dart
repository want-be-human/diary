import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/services/drive_video_cache.dart';

/// 视频应用内播放页（**仅 Android/iOS 走这里**——video_player 不支持 Windows）。
///
/// 流程：
/// 1. 进入页面 → 先看 [DriveVideoCache] 有没有本地缓存
/// 2. 没有 → 走 Drive API（OAuth + 代理）流式下载到缓存目录，期间显示进度条
/// 3. 拿到本地文件 → [VideoPlayerController.file] 初始化 + 自动播放
/// 4. 用户离开 / dispose → 释放 controller，本地文件保留供下次秒播
///
/// 异常路径（下载失败、未登录、文件被回收）→ 显示"无法播放"+ 重试按钮。
class VideoPlayerPage extends ConsumerStatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.fileId,
    this.title,
  });

  final String fileId;
  final String? title;

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  VideoPlayerController? _ctrl;
  bool _loading = true;
  String? _error;

  /// 下载进度（0..1）；total 未知时为 null（无法画百分比，画 indeterminate）。
  double? _downloadProgress;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cache = ref.read(driveVideoCacheProvider);
      // 先查本地缓存——上传设备这一步就直接命中。
      var file = await cache.getCachedFile(widget.fileId);
      if (file == null) {
        // 跨设备查看：走 Drive 拉一次，期间画进度条。
        setState(() => _downloading = true);
        file = await cache.ensureLocal(
          widget.fileId,
          onProgress: (sent, total) {
            if (!mounted) return;
            setState(() {
              _downloadProgress = total > 0 ? (sent / total).clamp(0, 1) : null;
            });
          },
        );
        if (!mounted) return;
        setState(() => _downloading = false);
        if (file == null) {
          setState(() {
            _loading = false;
            _error = '下载失败（未登录 / 网络异常 / 文件被删）';
          });
          return;
        }
      }

      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      ctrl.setLooping(false);
      ctrl.play();
      setState(() {
        _ctrl = ctrl;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '播放器初始化失败：$e';
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title ?? '视频',
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _downloading ? '下载中…' : '准备中…',
            style: const TextStyle(color: Colors.white70),
          ),
          if (_downloading) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 240,
              child: LinearProgressIndicator(
                value: _downloadProgress,
                minHeight: 4,
              ),
            ),
            if (_downloadProgress != null) ...[
              const SizedBox(height: 4),
              Text(
                '${(_downloadProgress! * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ],
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: Colors.white70),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _bootstrap,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final ctrl = _ctrl;
    if (ctrl == null) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: ctrl.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(ctrl),
          _ControlsOverlay(ctrl: ctrl),
          VideoProgressIndicator(
            ctrl,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: theme.colorScheme.primary,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}

/// 简易播放控制：点击中央切换播放/暂停。VideoPlayer 本身不带 UI 控件，
/// 这里只做最基础的，没必要重造一个 chewie。
class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({required this.ctrl});
  final VideoPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (ctrl.value.isPlaying) {
          ctrl.pause();
        } else {
          ctrl.play();
        }
      },
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            reverseDuration: const Duration(milliseconds: 200),
            child: ctrl.value.isPlaying
                ? const SizedBox.shrink()
                : Container(
                    color: Colors.black26,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 80,
                    ),
                  ),
          );
        },
      ),
    );
  }
}
