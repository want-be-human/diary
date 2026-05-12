import 'dart:io' show HttpClient;

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// 构造一个**绕开 HTTPS_PROXY / Clash** 的 http 客户端。
///
/// 背景：[main.dart] 在 Windows 上装了 [HttpOverrides.global]，每个新建的
/// HttpClient 默认通过 `findProxyFromEnvironment` 走 Clash（为了让 Firebase /
/// Google 各服务能通）。但定位/天气服务（Open-Meteo / BigDataCloud）我们
/// 希望直连——一来这些站点本身国内可达，二来走代理会让出口 IP 跑到
/// 海外节点，影响 IP-based 地理推断。
///
/// 实现：HttpOverrides.global 仍会被调用（它是进程级），它给我们一个
/// 已经 `findProxy = findProxyFromEnvironment` 的 HttpClient；我们随后把
/// `findProxy` 重写为永远返回 `'DIRECT'`，覆盖代理决策。这样既不影响其他
/// 调用 Firebase / Drive 的客户端，也确保本服务的请求走直连。
http.Client createDirectHttpClient() {
  final inner = HttpClient();
  inner.findProxy = (_) => 'DIRECT';
  return IOClient(inner);
}
