import 'dart:async';
import 'dart:io' show HttpClient, Platform, Process;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/oauth_config.dart';

/// 登录服务：邮箱密码 + Google 一键登录。
/// - Android: google_sign_in 原生流程。
/// - Windows / macOS / Linux: googleapis_auth 桌面 OAuth2 流程（浏览器跳转 + 本地回调）。
/// - 邮箱密码：Firebase Auth 全平台支持。
/// - Firebase Auth 默认会持久化会话；登录一次后重启 App 自动恢复。
class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: _mobileScopes);

  static const List<String> _mobileScopes = <String>[
    'email',
    'https://www.googleapis.com/auth/drive.file',
  ];

  static const List<String> _desktopScopes = <String>[
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.file',
  ];

  static const String _kRememberedEmail = 'auth.remembered_email';
  static const String _kDesktopRefreshToken = 'auth.desktop_refresh_token';

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  /// 桌面 Google 登录的取消信号；点击 UI 上的"取消"会 complete 它。
  Completer<void>? _desktopGoogleCancel;

  /// 桌面端 Google 凭证缓存：登录成功后存这里，供 [getAuthedClient] 反复构建
  /// 自动续期的 http.Client（用于 Drive API 上传等）。
  /// 重启 App 时会从 SharedPreferences 的 refresh_token 恢复一次。
  gauth.AccessCredentials? _desktopCreds;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  // ===== 邮箱密码 =====

  Future<User?> signInWithEmail(String email, String password) async {
    final result = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return result.user;
  }

  Future<User?> registerWithEmail(String email, String password) async {
    final result = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return result.user;
  }

  Future<void> sendPasswordReset(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  // ===== Google 一键登录 =====

  Future<User?> signInWithGoogle() async {
    final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return isDesktop ? _signInWithGoogleDesktop() : _signInWithGoogleMobile();
  }

  Future<User?> _signInWithGoogleMobile() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // 用户取消
    final googleAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _firebaseAuth.signInWithCredential(credential);
    return result.user;
  }

  Future<User?> _signInWithGoogleDesktop() async {
    if (!OAuthConfig.isDesktopConfigured) {
      throw StateError(
        '桌面 Google 登录尚未配置：请按 lib/core/config/oauth_config.dart 注释步骤'
        '在 GCP 控制台创建 Desktop OAuth Client，并填入 ID/Secret。',
      );
    }
    final clientId = gauth.ClientId(
      OAuthConfig.desktopClientId,
      OAuthConfig.desktopClientSecret,
    );
    _desktopGoogleCancel = Completer<void>();
    final httpClient = _createProxiedHttpClient();
    try {
      // 三路竞速：拿到凭据 / 用户点取消 / 5 分钟硬超时。
      // 注意：取消和超时无法真正中止 googleapis_auth 内部的本地 HTTP 监听，
      // 但能让 UI 立刻恢复；进程退出时端口会一并释放。
      final credentials = await Future.any<gauth.AccessCredentials?>([
        gauth.obtainAccessCredentialsViaUserConsent(
          clientId,
          _desktopScopes,
          httpClient,
          _launchBrowser,
        ),
        _desktopGoogleCancel!.future.then<gauth.AccessCredentials?>((_) => null),
        Future<gauth.AccessCredentials?>.delayed(
          const Duration(minutes: 5),
          () => throw TimeoutException('Google 登录超时（5 分钟未完成授权）。'),
        ),
      ]);
      if (credentials == null) return null; // 用户取消
      final idToken = credentials.idToken;
      if (idToken == null) {
        throw StateError('Google 未返回 idToken — 检查 OAuth scopes 是否包含 openid。');
      }
      // 持久化：内存里留一份给 Drive 上传用，refresh_token 写到 prefs 让 App 重启后还能续期。
      _desktopCreds = credentials;
      final rt = credentials.refreshToken;
      if (rt != null && rt.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kDesktopRefreshToken, rt);
      }
      final firebaseCred = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: credentials.accessToken.data,
      );
      // Firebase C++ SDK 在 Windows 用原生 curl 访问 Google API。
      // 代理已通过 WindowsEnv（main.dart 启动时）注入进程环境，curl 能读到。
      // 仍加超时是兜底：万一 OAuthConfig.httpProxy 配错或 Clash 没开。
      final result = await _firebaseAuth
          .signInWithCredential(firebaseCred)
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'Firebase 凭证校验超时（30s）。请检查 Clash 是否在运行，'
          '以及 OAuthConfig.httpProxy 端口是否正确。',
        ),
      );
      return result.user;
    } finally {
      _desktopGoogleCancel = null;
      httpClient.close();
    }
  }

  /// 取消正在进行的桌面 Google 登录（点击 UI 取消按钮时调用）。
  void cancelDesktopGoogleSignIn() {
    final c = _desktopGoogleCancel;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// 中国大陆访问 Google API 必走代理。Dart http.Client 默认不读系统代理，
  /// 这里统一加一层 IOClient + findProxy，让 token 交换不卡死。
  http.Client _createProxiedHttpClient() {
    final configured = OAuthConfig.httpProxy.trim();
    final fromEnv = (Platform.environment['HTTPS_PROXY'] ??
            Platform.environment['HTTP_PROXY'] ??
            '')
        .trim();
    final proxy = configured.isNotEmpty ? configured : fromEnv;
    if (proxy.isEmpty) return http.Client();
    final hostPort = proxy.replaceFirst(RegExp(r'^https?://'), '').replaceAll('/', '');
    // 顺序很重要：lambda body 是 greedy 的，把 connectionTimeout 放前面，
    // 否则它会被当成 lambda 表达式的一部分。
    // cascade + 单表达式 lambda 是 greedy 的：findProxy 必须放最后，
    // 否则它会把后续 ..badCertificateCallback 吞进 lambda body。
    final inner = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      // 中国大陆 Clash/Surge 等代理常做 TLS MITM，根证书装在 Windows
      // 证书库里浏览器认，但 Dart 的 BoringSSL 不读 Windows 证书库，
      // 会以 HandshakeException 结束握手。这里只放过 googleapis / google
      // 域，其它域照常校验；该 client 仅在 OAuth 流程内用，结束即关闭。
      ..badCertificateCallback = ((cert, host, port) =>
          host.endsWith('.googleapis.com') ||
          host.endsWith('.google.com') ||
          host == 'googleapis.com')
      ..findProxy = (_) => 'PROXY $hostPort';
    return http_io.IOClient(inner);
  }

  Future<void> _launchBrowser(String url) async {
    if (Platform.isWindows) {
      // 不能用 `cmd /c start` —— cmd 会把 URL 里的 `&` 当作命令分隔符，
      // 导致 OAuth 参数（response_type / scope / state 等）被截断。
      // rundll32 直接调用 Shell 打开协议，绕过 cmd 解析。
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    } else {
      throw UnsupportedError('当前平台不支持自动打开浏览器：$defaultTargetPlatform');
    }
  }

  Future<void> signOut() async {
    _desktopCreds = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDesktopRefreshToken);
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut().catchError((_) => null),
    ]);
  }

  // ===== Drive API 用的 authed http.Client =====

  /// 返回一个已经带 Google OAuth Authorization 头的 http.Client，
  /// 调用方拿到后可以直接喂给 `drive_v3.DriveApi(client)`。
  /// 未登录或 scope 不足时返回 null。
  ///
  /// **调用方拿到后必须 close()**——内部会带一个 proxied http.Client，
  /// 不 close 会泄漏 socket。
  Future<http.Client?> getAuthedClient() async {
    final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (isDesktop) {
      // 内存里没有就尝试从 prefs 的 refresh_token 恢复一次。
      var creds = _desktopCreds ?? await _restoreDesktopCreds();
      if (creds == null) return null;
      _desktopCreds = creds;

      final clientId = gauth.ClientId(
        OAuthConfig.desktopClientId,
        OAuthConfig.desktopClientSecret,
      );
      final base = _createProxiedHttpClient();
      // autoRefreshingClient 会在 access token 过期时自动用 refresh token 续期。
      // close() 会把 base 一起 close 掉。
      return gauth.autoRefreshingClient(clientId, creds, base);
    }

    // Mobile：google_sign_in 自己管理 token；从 currentUser / silent sign-in 拿 headers。
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    if (account == null) return null;
    final headers = await account.authHeaders;
    return _AuthHeaderClient(headers);
  }

  /// 从 SharedPreferences 的 refresh_token 重建一份 AccessCredentials。
  /// 没存过 / OAuth 未配置 / 网络错误时返回 null。
  Future<gauth.AccessCredentials?> _restoreDesktopCreds() async {
    if (!OAuthConfig.isDesktopConfigured) return null;
    final prefs = await SharedPreferences.getInstance();
    final rt = prefs.getString(_kDesktopRefreshToken);
    if (rt == null || rt.isEmpty) return null;

    final clientId = gauth.ClientId(
      OAuthConfig.desktopClientId,
      OAuthConfig.desktopClientSecret,
    );
    final base = _createProxiedHttpClient();
    try {
      // 构造一个"已过期的占位 access token"+真实 refresh token 的 stub，
      // refreshCredentials 会用 refresh_token 走一次刷新拿到全新凭证。
      final stub = gauth.AccessCredentials(
        gauth.AccessToken(
          'Bearer',
          '',
          DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        ),
        rt,
        _desktopScopes,
      );
      return await gauth.refreshCredentials(clientId, stub, base);
    } catch (_) {
      // refresh token 可能已被 revoke / 过期；清掉，让用户重新登录。
      await prefs.remove(_kDesktopRefreshToken);
      return null;
    } finally {
      base.close();
    }
  }

  // ===== 记住邮箱（仅记账号，不存密码；会话持久化由 Firebase Auth 自身负责）=====

  Future<void> setRememberedEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null || email.isEmpty) {
      await prefs.remove(_kRememberedEmail);
    } else {
      await prefs.setString(_kRememberedEmail, email);
    }
  }

  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRememberedEmail);
  }
}

/// 给 Android 端的 google_sign_in `authHeaders` 包一层 BaseClient，
/// 让它能像 googleapis_auth 的 authedClient 一样直接喂给 `drive_v3.DriveApi`。
class _AuthHeaderClient extends http.BaseClient {
  _AuthHeaderClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

// ===== Riverpod providers =====

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// 当前登录用户流。Firebase 未初始化时降级为永远空。
final authStateProvider = StreamProvider<User?>((ref) {
  try {
    return ref.watch(authServiceProvider).authStateChanges();
  } catch (_) {
    return Stream<User?>.value(null);
  }
});
