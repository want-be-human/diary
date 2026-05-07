import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/utils/text_util.dart';
import '../../models/entry.dart';
import '../../models/search_index.dart';

/// 本地 Isar 搜索 / 离线缓存数据源。
/// 仅持有索引行（[SearchIndex]），不存完整 Entry；
/// 搜索命中后由调用方再去 Firestore 拉详情或走 Firestore 自身的离线缓存。
class IsarSearchDataSource {
  IsarSearchDataSource._(this._isar);

  final Isar _isar;

  static Isar? _cached;

  /// 应用启动时调用一次，单例。
  static Future<IsarSearchDataSource> open() async {
    if (_cached != null) return IsarSearchDataSource._(_cached!);
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [SearchIndexSchema],
      directory: dir.path,
      name: 'diary_search',
    );
    _cached = isar;
    return IsarSearchDataSource._(isar);
  }

  Future<void> upsert(Entry entry) async {
    // bodyTokens 按类目分支：
    // - diary  ：Quill Delta 解析出的纯文本
    // - project：项目名 + 版本号 + 各完成项标题
    // - todo   ：subtask 标题列表
    final searchBody = entry.category == EntryCategory.diary
        ? entry.buildSearchableBody(
            plainBody: TextUtil.extractPlainText(entry.contentDelta),
          )
        : entry.buildSearchableBody();

    final row = SearchIndex.fromEntry(entry, searchableBody: searchBody);
    await _isar.writeTxn(() async {
      // 通过 entryId 唯一索引 upsert。
      // ignore: experimental_member_use
      await _isar.searchIndexs.putByEntryId(row);
    });
  }

  Future<void> remove(String entryId) async {
    await _isar.writeTxn(() async {
      // ignore: experimental_member_use
      await _isar.searchIndexs.deleteByEntryId(entryId);
    });
  }

  Future<void> clear() async {
    await _isar.writeTxn(() => _isar.searchIndexs.clear());
  }

  /// 简易关键字搜索：在 title / body / projectName / tags 上做大小写不敏感的 contains。
  Future<List<String>> searchEntryIds(
    String query, {
    EntryCategory? category,
    int limit = 50,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      final rows = await _isar.searchIndexs
          .where()
          .sortByUpdatedAtDesc()
          .limit(limit)
          .findAll();
      return rows.map((r) => r.entryId).toList();
    }

    final rows = await _isar.searchIndexs
        .filter()
        .titleTokensContains(q, caseSensitive: false)
        .or()
        .bodyTokensContains(q, caseSensitive: false)
        .or()
        .tagsContains(q, caseSensitive: false)
        .or()
        .projectNameContains(q, caseSensitive: false)
        .sortByUpdatedAtDesc()
        .limit(limit)
        .findAll();

    return rows.map((r) => r.entryId).toList();
  }
}
