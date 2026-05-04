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

/// 项目日志扩展元数据，仅当 Entry.category == project 时存在。
class ProjectMeta {
  final String entryId;
  final String projectName;
  final String version;
  final List<String> completedItems;
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
    List<String>? completedItems,
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
        'completedItems': completedItems,
        'status': status.wireValue,
        'isMilestone': isMilestone,
      };

  factory ProjectMeta.fromMap(Map<String, dynamic> map) {
    return ProjectMeta(
      entryId: map['entryId'] as String? ?? '',
      projectName: map['projectName'] as String? ?? '',
      version: map['version'] as String? ?? '',
      completedItems: (map['completedItems'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      status: ProjectStatusX.fromWire(map['status'] as String?),
      isMilestone: map['isMilestone'] as bool? ?? false,
    );
  }
}
