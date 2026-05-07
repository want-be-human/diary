/// 子任务清单条目（Entry 内嵌）。
/// 用于"待办事项"类目下的可勾选项，每条可挂多张图片（截图/凭证）。
class TaskItem {
  final String id;
  final String text;
  final bool done;

  /// 这条 subtask 上挂的图片 URL（Firebase Storage 下载地址）。
  /// 上传管线后续接入；现阶段允许空列表。
  final List<String> imageUrls;

  const TaskItem({
    required this.id,
    required this.text,
    required this.done,
    this.imageUrls = const <String>[],
  });

  TaskItem copyWith({
    String? id,
    String? text,
    bool? done,
    List<String>? imageUrls,
  }) {
    return TaskItem(
      id: id ?? this.id,
      text: text ?? this.text,
      done: done ?? this.done,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'done': done,
        'imageUrls': imageUrls,
      };

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      done: map['done'] as bool? ?? false,
      imageUrls: (map['imageUrls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
    );
  }
}
