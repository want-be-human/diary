import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/entry.dart';
import '../../data/services/auth_service.dart';
import '../../features/archive/archive_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/detail/detail_page.dart';
import '../../features/editor/editor_dispatcher.dart';
import '../../features/home/home_page.dart';
import '../../features/project/project_detail_page.dart';
import '../../features/project/project_list_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/video/video_player_page.dart';

/// go_router 全局配置。
/// 登录守卫：未登录时强制跳到 /login；登录后从 /login 自动回到 /。
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final loggedIn = auth.asData?.value != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn && !atLogin) return '/login';
      if (loggedIn && atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: '/editor',
        builder: (context, state) {
          final qp = state.uri.queryParameters;
          return EditorDispatcher(
            entryId: qp['id'],
            initialCategory: _parseCategory(qp['category']),
          );
        },
      ),
      GoRoute(
        path: '/entry/:id',
        builder: (context, state) =>
            DetailPage(entryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(
        path: '/archive',
        builder: (_, __) => const ArchivePage(),
      ),
      // 项目聚合：所有 project 类目按 projectName 归集。
      GoRoute(
        path: '/projects',
        builder: (_, __) => const ProjectListPage(),
      ),
      // 项目详情：里程碑时间轴 + 该项目全部条目倒序列表。
      // projectName 走 query 而不是 path——名字可能含 `/`、`%`、空格、emoji
      // 等任意字符，path 段的 URL 编码语义在 go_router 各版本里行为不一致
      // （pathParameters 有时返回原始串、有时已自动解码），手动 decode 一次
      // 就会撞「Illegal percent encoding in URI」。query 走标准的 form-urlencoded
      // 处理，框架那边一次性解码、稳定可预测。
      GoRoute(
        path: '/project',
        builder: (context, state) {
          return ProjectDetailPage(
            projectName: state.uri.queryParameters['name'] ?? '',
          );
        },
      ),
      // 应用内视频播放：?id=<driveFileId>&name=<可选标题>。
      // 仅 Android/iOS 入口会跳过来（video_player 不支持 Windows）；
      // 桌面端的「点击播放」会直接走 url_launcher 拉 Drive 预览页。
      GoRoute(
        path: '/video',
        builder: (context, state) {
          final qp = state.uri.queryParameters;
          return VideoPlayerPage(
            fileId: qp['id'] ?? '',
            title: qp['name'],
          );
        },
      ),
    ],
  );
});

EntryCategory? _parseCategory(String? raw) {
  switch (raw) {
    case 'diary':
      return EntryCategory.diary;
    case 'project':
      return EntryCategory.project;
    case 'todo':
      return EntryCategory.todo;
    default:
      return null;
  }
}

/// 把 Riverpod 的 auth 状态变化转成 Listenable，喂给 GoRouter.refreshListenable。
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen<AsyncValue<Object?>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
