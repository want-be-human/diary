import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_provider.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/settings_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    final user = ref.watch(authStateProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('外观'),
          RadioGroup<ThemeMode>(
            groupValue: mode,
            onChanged: (m) {
              if (m != null) {
                ref.read(themeProvider.notifier).setMode(m);
              }
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('跟随系统'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('浅色'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('深色'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('天气'),
          const _DefaultCityTile(),
          const Divider(),
          const _SectionHeader('账号'),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(user?.displayName ?? user?.email ?? '未登录'),
            subtitle: user == null ? null : Text(user.email ?? ''),
          ),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () => ref.read(authServiceProvider).signOut(),
            ),
          const Divider(),
          const _SectionHeader('数据'),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('归档'),
            subtitle: const Text('查看已归档条目，可还原'),
            onTap: () => context.push('/archive'),
          ),
          const Divider(),
          const _SectionHeader('导出'),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('导出全部为 ZIP'),
            subtitle: const Text('阶段四接入'),
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// "默认天气城市"——位置权限关闭 / 桌面端不愿开定位时的兜底。
/// 编辑器在 GPS 拿不到坐标的情况下，会用这里的城市去 forward-geocode
/// 抓天气；首页 / 详情页不直接用。
class _DefaultCityTile extends ConsumerWidget {
  const _DefaultCityTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(defaultCityProvider);
    final value = async.asData?.value ?? '';

    return ListTile(
      leading: const Icon(Icons.location_city_outlined),
      title: const Text('默认天气城市'),
      subtitle: Text(
        value.isEmpty ? '未设置（位置权限关闭时不会自动抓天气）' : value,
      ),
      onTap: () => _edit(context, ref, value),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('默认天气城市'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '如：杭州 / Beijing / Tokyo',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          // 用 sentinel 串区分"清空"和"取消"——清空走空字符串，
          // 取消走 null。
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('清空'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    await ref.read(defaultCityProvider.notifier).set(result);
  }
}
