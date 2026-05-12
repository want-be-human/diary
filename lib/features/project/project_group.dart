import '../../data/models/entry.dart';
import '../../data/models/project_meta.dart';

/// 项目聚合：把一堆 `category == project` 的 [Entry] 按 [ProjectMeta.projectName]
/// 归一成一张项目卡。纯计算，无副作用，方便 UI 直接拿来 render 或排序。
class ProjectGroup {
  ProjectGroup({
    required this.projectName,
    required this.entries,
  })  : assert(entries.isNotEmpty, 'ProjectGroup 至少要一条条目'),
        latestEntry = _pickLatest(entries),
        milestones = entries
            .where((e) => e.projectMeta?.isMilestone == true)
            .toList(growable: false)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// 项目名；为空字符串时由 [groupAll] 标记为 [unnamed]。
  final String projectName;

  /// 该项目下的全部条目（未按特定顺序，调用方按需 sort）。
  final List<Entry> entries;

  /// 「最新版本」基准：按 updatedAt 降序排第一条。
  /// 注意区分 createdAt：项目卡列表里要展示「最近活动」，应该用 updatedAt。
  final Entry latestEntry;

  /// 里程碑条目，按 createdAt 升序——时间轴左→右。
  final List<Entry> milestones;

  /// 占位项目名（[Entry.projectMeta?.projectName] 为空时归到这里）。
  static const String unnamed = '__unnamed__';

  /// 该项目最新版本号（latestEntry 的 version 字段；可能为空）。
  String get latestVersion => latestEntry.projectMeta?.version ?? '';

  /// 该项目当前状态：取 latestEntry 的 status；缺失时按 inProgress。
  ProjectStatus get currentStatus =>
      latestEntry.projectMeta?.status ?? ProjectStatus.inProgress;

  /// 最近活动时间——给项目卡列表排序用。
  DateTime get lastActivity => latestEntry.updatedAt;

  /// 全部"本次完成"项的累计条数——给项目卡副标题展示。
  int get totalCompletedItems {
    var n = 0;
    for (final e in entries) {
      n += e.projectMeta?.completedItems.length ?? 0;
    }
    return n;
  }

  /// 给定一组任意 entry，过滤出 project 类目并按 projectName 归集。
  /// 自动跳过 isArchived 的条目——聚合页不应该看见归档内容。
  /// 没有 projectName（或空字符串 trim 后为空）的归到 [unnamed]。
  /// 结果按 lastActivity 降序——最近活跃的项目排前面。
  static List<ProjectGroup> groupAll(Iterable<Entry> all) {
    final byName = <String, List<Entry>>{};
    for (final e in all) {
      if (e.category != EntryCategory.project) continue;
      if (e.isArchived) continue;
      final raw = (e.projectMeta?.projectName ?? '').trim();
      final key = raw.isEmpty ? unnamed : raw;
      byName.putIfAbsent(key, () => []).add(e);
    }
    final groups = byName.entries
        .map((kv) => ProjectGroup(projectName: kv.key, entries: kv.value))
        .toList();
    groups.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return groups;
  }

  static Entry _pickLatest(List<Entry> entries) {
    var latest = entries.first;
    for (final e in entries.skip(1)) {
      if (e.updatedAt.isAfter(latest.updatedAt)) latest = e;
    }
    return latest;
  }
}
