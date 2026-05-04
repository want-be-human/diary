import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_provider.dart';
import '../../data/services/auth_service.dart';

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
