/// 桌面 Google 登录配置。
///
/// **重要**：Client ID / Secret 不再写死在源码里——通过 Dart 的编译期
/// `--dart-define` 环境变量注入。
///
/// 使用步骤：
/// 1. `flutterfire configure` 生成 firebase_options.dart 后，登录 GCP 控制台
///    （https://console.cloud.google.com/）选择当前 Firebase 项目。
/// 2. 进入 "APIs & Services" → "Credentials" → "Create Credentials" →
///    "OAuth client ID"，类型选 **Desktop app**。
/// 3. 在 "OAuth consent screen" 把 `email` `profile` `openid` 与
///    `https://www.googleapis.com/auth/drive.file` 加入 scopes。
/// 4. 跑 / 打包时通过 dart-define 注入：
///    ```
///    flutter run -d windows \
///      --dart-define=DESKTOP_CLIENT_ID=xxxxxxx.apps.googleusercontent.com \
///      --dart-define=DESKTOP_CLIENT_SECRET=GOCSPX-xxxxxxxxxx
///    ```
///    或在 `.vscode/launch.json` / `--dart-define-from-file=secrets.json`
///    （文件加 .gitignore）里持久化。
///
/// 没注入时 `isDesktopConfigured` 返回 false，桌面端"使用 Google 登录"按钮
/// 会抛错并提示去配置；邮箱密码登录不受影响。
class OAuthConfig {
  /// 桌面端 OAuth client ID。
  /// 通过 `--dart-define=DESKTOP_CLIENT_ID=...` 注入；未注入时为空串。
  static const String desktopClientId = String.fromEnvironment(
    'DESKTOP_CLIENT_ID',
  );

  /// 桌面端 OAuth client secret。
  /// 通过 `--dart-define=DESKTOP_CLIENT_SECRET=...` 注入；未注入时为空串。
  ///
  /// 注：Google 官方文档明确说桌面 OAuth 流程的 client secret 不算严格的
  /// 机密（会被打包进客户端，任何人都能反编译拿到）；但仍不该提交进公开 repo
  /// —— 一来 GitHub Push Protection 会拦，二来便于将来集中轮换。
  static const String desktopClientSecret = String.fromEnvironment(
    'DESKTOP_CLIENT_SECRET',
  );

  /// 桌面端访问 Google API（oauth2.googleapis.com / firebase 域）使用的 HTTP 代理。
  /// 中国大陆环境必填——Dart 的 http.Client 不会读系统代理，直连这些域会超时。
  /// 格式 'host:port'（不带 http://）。
  ///
  /// 默认 `127.0.0.1:7897`（Clash 默认端口），可通过
  /// `--dart-define=HTTPS_PROXY=host:port` 覆盖；置空串时让 windows_env 注入的
  /// HTTPS_PROXY 环境变量生效（或直连）。
  static const String httpProxy = String.fromEnvironment(
    'HTTPS_PROXY',
    defaultValue: '127.0.0.1:7897',
  );

  static bool get isDesktopConfigured =>
      desktopClientId.isNotEmpty && desktopClientSecret.isNotEmpty;
}
