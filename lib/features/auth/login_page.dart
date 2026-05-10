import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/auth_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _busy = false;
  bool _googleBusy = false;
  bool _isRegister = false;
  bool _rememberEmail = true;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreEmail();
  }

  Future<void> _restoreEmail() async {
    final saved = await ref.read(authServiceProvider).getRememberedEmail();
    if (saved != null && mounted) {
      setState(() => _emailCtrl.text = saved);
    }
  }

  Future<void> _persistRememberedEmail() async {
    final auth = ref.read(authServiceProvider);
    await auth.setRememberedEmail(
      _rememberEmail ? _emailCtrl.text.trim() : null,
    );
  }

  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '邮箱和密码不能为空');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      if (_isRegister) {
        await auth.registerWithEmail(email, password);
      } else {
        await auth.signInWithEmail(email, password);
      }
      await _persistRememberedEmail();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapAuthError(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _googleBusy = true;
      _error = null;
    });
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (user == null) {
        // 用户取消（关闭浏览器或点 UI 取消按钮）。
        if (mounted) setState(() => _error = '已取消 Google 登录');
        return;
      }
      await _persistRememberedEmail();
    } catch (e) {
      if (mounted) setState(() => _error = '登录失败：${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _googleBusy = false;
        });
      }
    }
  }

  void _cancelGoogle() {
    ref.read(authServiceProvider).cancelDesktopGoogleSignIn();
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '请先填邮箱再请求重置链接');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已向 $email 发送重置邮件')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapAuthError(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return '邮箱格式不正确';
      case 'user-not-found':
        return '账号不存在';
      case 'wrong-password':
      case 'invalid-credential':
        return '邮箱或密码错误';
      case 'email-already-in-use':
        return '邮箱已被注册';
      case 'weak-password':
        return '密码强度不足（至少 6 位）';
      case 'network-request-failed':
        return '网络请求失败，检查代理或网络';
      case 'too-many-requests':
        return '尝试过于频繁，稍后再试';
      case 'operation-not-allowed':
        return '邮箱密码登录未启用，去 Firebase Console → Authentication → Sign-in method 打开 Email/Password';
      case 'user-disabled':
        return '账号被禁用，去 Firebase Console → Authentication → Users 检查';
      default:
        // 把 code 显式带上：Firebase 的 .message 有时是 "An internal error has occurred"
        // 这种笼统话，code 才有信息量（如 internal-error / app-not-authorized 等）。
        return '[${e.code}] ${e.message ?? "未知错误"}';
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '日记',
                    style: theme.textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '记录每一天与每一次进展',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  // Windows 桌面端：Firebase Auth C++ SDK 对邮箱密码错误码映射不
                  // 完整，所有 4xx 都报 `unknown-error`，UX 极差；又因为我们已经
                  // 提供了稳定的 Google 一键登录，索性在 Windows 上隐藏整个邮箱
                  // 登录区域，只露 Google 按钮。Android / iOS 走 Native SDK 错
                  // 误码完整，保持邮箱密码登录可用。
                  if (!Platform.isWindows) ...[
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        prefixIcon: Icon(Icons.mail_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _busy ? null : _submitEmail(),
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberEmail,
                          onChanged: (v) =>
                              setState(() => _rememberEmail = v ?? false),
                        ),
                        const Text('记住邮箱'),
                        const Spacer(),
                        if (!_isRegister)
                          TextButton(
                            onPressed: _busy ? null : _resetPassword,
                            child: const Text('忘记密码？'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FilledButton(
                      onPressed: _busy ? null : _submitEmail,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_busy
                          ? '处理中…'
                          : (_isRegister ? '注册并登录' : '登录')),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _isRegister = !_isRegister;
                                _error = null;
                              }),
                      child: Text(_isRegister ? '已有账号？返回登录' : '还没有账号？注册'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('或', style: theme.textTheme.bodySmall),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_googleBusy)
                    OutlinedButton.icon(
                      onPressed: _cancelGoogle,
                      icon: const Icon(Icons.close),
                      label: const Text('取消 Google 登录'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: theme.colorScheme.error,
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _signInWithGoogle,
                      icon: const Icon(Icons.login),
                      label: const Text('使用 Google 一键登录'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  if (_googleBusy) ...[
                    const SizedBox(height: 8),
                    Text(
                      '已在浏览器打开授权页面，完成后会自动返回。\n'
                      '如果浏览器无反应或已关闭，请点上方"取消"。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    '登录后会保持登录状态，下次启动无需再次验证。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
