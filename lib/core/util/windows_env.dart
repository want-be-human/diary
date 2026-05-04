import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

/// Windows 进程级环境变量注入。
///
/// 用途：Firebase C++ SDK 在 Windows 用静态 curl 访问 Google API，
/// curl 只认 `HTTPS_PROXY` / `HTTP_PROXY` 环境变量，不知道 Dart 端代理。
/// 在 `Firebase.initializeApp()` 之前调用 [setEnv]，把代理写进**当前进程**的
/// 环境块；不修改系统环境变量、不持久化、单进程作用域，进程退出即消失。
///
/// 双写：
/// - `SetEnvironmentVariableW` 写 Win32 进程环境块（Win32 API 看到）
/// - `_putenv_s` 写 CRT 环境块（CRT getenv 看到）
/// 两者在不同 CRT 链接策略下都能被读到。
class WindowsEnv {
  WindowsEnv._();

  static final _setEnvW = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<Int32 Function(Pointer<Utf16>, Pointer<Utf16>),
          int Function(Pointer<Utf16>, Pointer<Utf16>)>(
    'SetEnvironmentVariableW',
  );

  // _putenv_s 在 ucrtbase.dll（Win10+）；老系统回退到 msvcrt.dll。
  static final _putenvS = _resolvePutenvS();

  static int Function(Pointer<Utf8>, Pointer<Utf8>)? _resolvePutenvS() {
    for (final name in const ['ucrtbase.dll', 'msvcrt.dll']) {
      try {
        return DynamicLibrary.open(name).lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
            int Function(Pointer<Utf8>, Pointer<Utf8>)>('_putenv_s');
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// 设置当前进程的环境变量。非 Windows 平台直接 no-op。
  static void setEnv(String name, String value) {
    if (!Platform.isWindows) return;

    final wn = name.toNativeUtf16();
    final wv = value.toNativeUtf16();
    try {
      _setEnvW(wn, wv);
    } finally {
      malloc.free(wn);
      malloc.free(wv);
    }

    final put = _putenvS;
    if (put != null) {
      final un = name.toNativeUtf8();
      final uv = value.toNativeUtf8();
      try {
        put(un, uv);
      } finally {
        malloc.free(un);
        malloc.free(uv);
      }
    }
  }
}
