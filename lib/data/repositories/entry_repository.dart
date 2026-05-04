import '../models/entry.dart';

/// Entry 数据仓库抽象。
/// 实现者负责协调 Firestore（远端真源）和 Isar（本地搜索/离线缓存）。
abstract class EntryRepository {
  /// 监听全部条目，按 [Entry.updatedAt] 倒序。
  Stream<List<Entry>> watchAll({EntryCategory? category});

  /// 单条监听。条目不存在时发出 null。
  Stream<Entry?> watchById(String id);

  /// 获取一次（不订阅）。
  Future<Entry?> findById(String id);

  /// 创建条目，返回写入后带 id 的对象。
  Future<Entry> create(Entry entry);

  /// 更新（按 id），自动刷新 updatedAt。
  Future<void> update(Entry entry);

  Future<void> delete(String id);

  /// 全文搜索；命中按相关度+时间近似排序。
  /// [query] 为空时返回最近条目。
  Future<List<Entry>> search(String query, {EntryCategory? category});
}
