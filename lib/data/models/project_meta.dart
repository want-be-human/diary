/// 项目状态枚举。
enum ProjectStatus { inProgress, done }

extension ProjectStatusX on ProjectStatus {
  String get wireValue {
    switch (this) {
      case ProjectStatus.inProgress:
        return 'in_progress';
      case ProjectStatus.done:
        return 'done';
    }
  }

  String get displayLabel {
    switch (this) {
      case ProjectStatus.inProgress:
        return '进行中';
      case ProjectStatus.done:
        return '已完成';
    }
  }

  static ProjectStatus fromWire(String? raw) {
    switch (raw) {
      case 'done':
        return ProjectStatus.done;
      case 'in_progress':
      default:
        return ProjectStatus.inProgress;
    }
  }
}

/// 项目"本次完成"列表项：标题 + 可挂多张图。
class CompletedItem {
  final String title;
  final List<String> imageUrls;

  const CompletedItem({
    required this.title,
    this.imageUrls = const <String>[],
  });

  CompletedItem copyWith({String? title, List<String>? imageUrls}) {
    return CompletedItem(
      title: title ?? this.title,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'imageUrls': imageUrls,
      };

  factory CompletedItem.fromMap(Map<String, dynamic> map) {
    return CompletedItem(
      title: map['title'] as String? ?? '',
      imageUrls: (map['imageUrls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
    );
  }
}

/// 项目日志扩展元数据，仅当 Entry.category == project 时存在。
class ProjectMeta {
  final String entryId;
  final String projectName;
  final String version;
  final List<CompletedItem> completedItems;
  final ProjectStatus status;

  /// 是否里程碑节点（首发版本 / 重大功能 / 重要修复）。
  /// 项目详情页时间轴上里程碑节点放大显示。
  final bool isMilestone;

  const ProjectMeta({
    required this.entryId,
    required this.projectName,
    required this.version,
    required this.completedItems,
    required this.status,
    this.isMilestone = false,
  });

  ProjectMeta copyWith({
    String? entryId,
    String? projectName,
    String? version,
    List<CompletedItem>? completedItems,
    ProjectStatus? status,
    bool? isMilestone,
  }) {
    return ProjectMeta(
      entryId: entryId ?? this.entryId,
      projectName: projectName ?? this.projectName,
      version: version ?? this.version,
      completedItems: completedItems ?? this.completedItems,
      status: status ?? this.status,
      isMilestone: isMilestone ?? this.isMilestone,
    );
  }

  Map<String, dynamic> toMap() => {
        'entryId': entryId,
        'projectName': projectName,
        'version': version,
        'completedItems': completedItems.map((c) => c.toMap()).toList(),
        'status': status.wireValue,
        'isMilestone': isMilestone,
      };

  /// 兼容老数据：旧版 `completedItems` 是 `List<String>`，
  /// 新版是 `List<{title, imageUrls}>`。两种都能读。
  factory ProjectMeta.fromMap(Map<String, dynamic> map) {
    final raw = map['completedItems'] as List? ?? const [];
    final items = raw.map((e) {
      if (e is Map) {
        return CompletedItem.fromMap(Map<String, dynamic>.from(e));
      }
      return CompletedItem(title: e.toString());
    }).toList();

    return ProjectMeta(
      entryId: map['entryId'] as String? ?? '',
      projectName: map['projectName'] as String? ?? '',
      version: map['version'] as String? ?? '',
      completedItems: items,
      status: ProjectStatusX.fromWire(map['status'] as String?),
      isMilestone: map['isMilestone'] as bool? ?? false,
    );
  }
}
