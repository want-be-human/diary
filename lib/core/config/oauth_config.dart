/// 桌面 Google 登录配置。
///
/// 使用步骤：
/// 1. `flutterfire configure` 生成 firebase_options.dart 后，登录 GCP 控制台
///    （https://console.cloud.google.com/）选择当前 Firebase 项目。
/// 2. 进入 "APIs & Services" → "Credentials" → "Create Credentials" →
///    "OAuth client ID"，类型选 **Desktop app**。
/// 3. 把生成的 Client ID 与 Client Secret 填入下方常量。
/// 4. 在 "OAuth consent screen" 把 `email` `profile` `openid` 与
///    `https://www.googleapis.com/auth/drive.file` 加入 scopes。
///
/// 没填以前，桌面端"使用 Google 登录"按钮会抛错并提示去配置；
/// 邮箱密码登录不受影响。
class OAuthConfig {
  static const String desktopClientId =
      'YOUR_DESKTOP_CLIENT_ID';
  static const String desktopClientSecret = 'YOUR_DESKTOP_CLIENT_SECRET';

  /// 桌面端访问 Google API（oauth2.googleapis.com / firebase 域）使用的 HTTP 代理。
  /// 中国大陆环境必填——Dart 的 http.Client 不会读系统代理，直连这些域会超时。
  /// 格式 'host:port'（不带 http://）。空串时回退到环境变量 HTTPS_PROXY/HTTP_PROXY，
  /// 仍为空则直连。
  static const String httpProxy = '127.0.0.1:7897';

  static bool get isDesktopConfigured =>
      !desktopClientId.startsWith('YOUR_') &&
      !desktopClientSecret.startsWith('YOUR_');
}
