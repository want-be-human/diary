import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/auth_service.dart';
import '../../features/auth/login_page.dart';
import '../../features/detail/detail_page.dart';
import '../../features/editor/editor_page.dart';
import '../../features/home/home_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';

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
        builder: (context, state) =>
            EditorPage(entryId: state.uri.queryParameters['id']),
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
    ],
  );
});

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
