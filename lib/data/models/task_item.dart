/// 子任务清单条目（Entry 内嵌）。
/// 与 ProjectMeta.completedItems 区分：
/// - completedItems 是项目本次已完成内容的描述列表（只读式）
/// - TaskItem 是 entry 内的勾选式 todo（可勾可改）
class TaskItem {
  final String id;
  final String text;
  final bool done;

  const TaskItem({
    required this.id,
    required this.text,
    required this.done,
  });

  TaskItem copyWith({
    String? id,
    String? text,
    bool? done,
  }) {
    return TaskItem(
      id: id ?? this.id,
      text: text ?? this.text,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'done': done,
      };

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      done: map['done'] as bool? ?? false,
    );
  }
}
