import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/oauth_config.dart';
import 'core/util/windows_env.dart';
import 'data/datasources/local/isar_search_datasource.dart';
import 'data/repositories/entry_repository_impl.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 必须在 Firebase.initializeApp() 之前完成：Firebase C++ SDK 在 Windows
  // 用静态 curl 访问 Google API，curl 只读环境变量，不知道 Dart 端 http
  // client 上的代理设置。把代理注入当前进程的环境块即可，不污染系统。
  if (Platform.isWindows) {
    final proxy = OAuthConfig.httpProxy.trim();
    if (proxy.isNotEmpty) {
      final url = proxy.startsWith('http') ? proxy : 'http://$proxy';
      WindowsEnv.setEnv('HTTPS_PROXY', url);
      WindowsEnv.setEnv('HTTP_PROXY', url);
    }
  }

  // Firebase 初始化：配置占位时容忍失败，App 仍可启动并显示登录页错误。
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('Firebase 初始化失败（占位配置预期）：$e\n$st');
  }

  final search = await IsarSearchDataSource.open();

  runApp(
    ProviderScope(
      overrides: [
        isarSearchProvider.overrideWithValue(search),
      ],
      child: const DiaryApp(),
    ),
  );
}
