import 'package:isar/isar.dart';

import 'entry.dart';

part 'search_index.g.dart';

/// 本地 Isar 全文搜索 + 筛选索引。
///
/// 与远端 Firestore 中的 [Entry] 一一对应（通过 [entryId] 关联）。
/// 标题、正文等字段做小写化 + 空白折叠后存入字符串字段，配合 contains 查询。
/// v2 增加 createdAt / moodScore / isPinned / wordCount 用于：
/// - 搜索页按心情 / 日期区间过滤
/// - 首页热力图按当日字数着色
/// - 列表把置顶条目顶到最前
@Collection()
class SearchIndex {
  Id isarId = Isar.autoIncrement;

  /// Firestore 中 Entry 的文档 ID。需要唯一以便 upsert。
  @Index(unique: true, replace: true, caseSensitive: true)
  late String entryId;

  /// Entry 类目：'diary' | 'project'。索引用于按类目快速过滤。
  @Index(caseSensitive: true, type: IndexType.value)
  late String category;

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

  /// 用于按时间排序。
  late DateTime updatedAt;

  // === v2 索引字段 ===

  /// 创建时间（用于热力图按日聚合 / 搜索页日期区间过滤）。
  @Index()
  late DateTime createdAt;

  /// 心情分（1-5），无心情时为 null。供搜索页心情过滤。
  @Index()
  int? moodScore;

  /// 是否置顶。列表渲染时 isPinned == true 的条目排在最前。
  @Index()
  late bool isPinned;

  /// 字数（纯文本字符数+英文词数），热力图按此着色，统计页累加。
  @Index()
  late int wordCount;

  SearchIndex();

  /// 由 [Entry] 构建索引行。
  /// [searchableBody] 是各类目下"可被搜到的正文"——
  /// - diary  ：Quill Delta 解析后的纯文本
  /// - project：项目名 + 版本号 + 各完成项标题
  /// - todo   ：subtask 标题列表
  /// 由 [Entry.buildSearchableBody] 拼接。
  factory SearchIndex.fromEntry(Entry entry, {required String searchableBody}) {
    return SearchIndex()
      ..entryId = entry.id
      ..category = entry.category.wireValue
      ..titleTokens = _tokenize(entry.title)
      ..bodyTokens = _tokenize(searchableBody)
      ..projectName = entry.projectMeta?.projectName.toLowerCase()
      ..tags = entry.tags.map((t) => t.toLowerCase()).join(' ')
      ..updatedAt = entry.updatedAt
      ..createdAt = entry.createdAt
      ..moodScore = entry.mood?.score
      ..isPinned = entry.isPinned
      ..wordCount = entry.wordCount;
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
