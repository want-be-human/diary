import 'package:isar/isar.dart';

import 'entry.dart';

part 'search_index.g.dart';

/// 本地 Isar 全文搜索索引。
///
/// 与远端 Firestore 中的 [Entry] 一一对应（通过 [entryId] 关联）。
/// 标题、正文等字段均预先做 token 拆分后用空格拼接成单字符串，
/// 配合 `caseSensitive: false` 索引可走 startsWith / contains 加速。
@Collection()
class SearchIndex {
  Id isarId = Isar.autoIncrement;

  /// Firestore 中 Entry 的文档 ID。需要唯一以便 upsert。
  @Index(unique: true, replace: true, caseSensitive: true)
  late String entryId;

  @Index(caseSensitive: false, type: IndexType.value)
  late String titleTokens;

  @Index(caseSensitive: false, type: IndexType.value)
  late String bodyTokens;

  /// project 类型时的项目名（diary 类型为 null）。
  @Index(caseSensitive: false, type: IndexType.value)
  String? projectName;

  /// 所有 tag 用空格拼接（spec 要求合并为单字符串便于搜索）。
  @Index(caseSensitive: false, type: IndexType.value)
  late String tags;

  /// 用于按时间排序的副本（避免再去查 Firestore）。
  late DateTime updatedAt;

  SearchIndex();

  /// 由 [Entry] 构建索引行。
  /// [plainBody] 是去掉 Quill Delta 富文本格式后的纯文本。
  factory SearchIndex.fromEntry(Entry entry, {required String plainBody}) {
    return SearchIndex()
      ..entryId = entry.id
      ..titleTokens = _tokenize(entry.title)
      ..bodyTokens = _tokenize(plainBody)
      ..projectName = entry.projectMeta?.projectName.toLowerCase()
      ..tags = entry.tags.map((t) => t.toLowerCase()).join(' ')
      ..updatedAt = entry.updatedAt;
  }

  /// 简单 tokenize：转小写 + 折叠空白。
  /// 中文按字符存储依赖 Isar 自身的索引前缀匹配。
  static String _tokenize(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
