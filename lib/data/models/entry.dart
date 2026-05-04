import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/utils/text_util.dart';
import 'entry_location.dart';
import 'mood.dart';
import 'project_meta.dart';
import 'task_item.dart';
import 'weather_snapshot.dart';

enum EntryCategory { diary, project }

extension EntryCategoryX on EntryCategory {
  String get wireValue => name; // 'diary' | 'project'

  static EntryCategory fromWire(String? raw) {
    switch (raw) {
      case 'project':
        return EntryCategory.project;
      case 'diary':
      default:
        return EntryCategory.diary;
    }
  }
}

/// 通用日记条目（v2，含心情/置顶/字数/位置/天气/子任务）。
/// `contentDelta` 存 flutter_quill 的 Delta JSON 字符串。
/// `mediaUrls` 既可是 Firebase Storage URL，也可是 Drive 文件 ID。
class Entry {
  final String id;
  final String title;
  final String contentDelta;
  final EntryCategory category;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> mediaUrls;
  final ProjectMeta? projectMeta;

  // === v2 新增 ===
  final Mood? mood;
  final bool isPinned;
  final int wordCount;
  final EntryLocation? location;
  final WeatherSnapshot? weather;
  final List<TaskItem> subtasks;

  /// 归档状态：归档的条目不出现在主列表，可在"归档"页查看 / 还原。
  /// 与"删除"区别：归档可逆，删除不可逆。
  final bool isArchived;

  const Entry({
    required this.id,
    required this.title,
    required this.contentDelta,
    required this.category,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.mediaUrls,
    this.projectMeta,
    this.mood,
    this.isPinned = false,
    this.wordCount = 0,
    this.location,
    this.weather,
    this.subtasks = const <TaskItem>[],
    this.isArchived = false,
  });

  Entry copyWith({
    String? id,
    String? title,
    String? contentDelta,
    EntryCategory? category,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? mediaUrls,
    ProjectMeta? projectMeta,
    Mood? mood,
    bool? isPinned,
    int? wordCount,
    EntryLocation? location,
    WeatherSnapshot? weather,
    List<TaskItem>? subtasks,
    bool? isArchived,
    bool clearProjectMeta = false,
    bool clearMood = false,
    bool clearLocation = false,
    bool clearWeather = false,
  }) {
    return Entry(
      id: id ?? this.id,
      title: title ?? this.title,
      contentDelta: contentDelta ?? this.contentDelta,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      projectMeta:
          clearProjectMeta ? null : (projectMeta ?? this.projectMeta),
      mood: clearMood ? null : (mood ?? this.mood),
      isPinned: isPinned ?? this.isPinned,
      wordCount: wordCount ?? this.wordCount,
      location: clearLocation ? null : (location ?? this.location),
      weather: clearWeather ? null : (weather ?? this.weather),
      subtasks: subtasks ?? this.subtasks,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  /// 给定 [contentDelta]（Quill JSON），计算字数后返回新副本。
  /// 编辑器在保存前调一次，避免到处分散计数逻辑。
  Entry withRecomputedWordCount([String? newDelta]) {
    final delta = newDelta ?? contentDelta;
    return copyWith(
      contentDelta: delta,
      wordCount: TextUtil.countWordsInDelta(delta),
    );
  }

  /// 写入 Firestore 的 Map（DateTime 转为 Timestamp）。
  Map<String, dynamic> toFirestore() => {
        'title': title,
        'contentDelta': contentDelta,
        'category': category.wireValue,
        'tags': tags,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'mediaUrls': mediaUrls,
        'projectMeta': projectMeta?.toMap(),
        // v2
        'mood': mood?.toMap(),
        'isPinned': isPinned,
        'wordCount': wordCount,
        'location': location?.toMap(),
        'weather': weather?.toMap(),
        'subtasks': subtasks.map((t) => t.toMap()).toList(),
        'isArchived': isArchived,
      };

  factory Entry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Entry(
      id: doc.id,
      title: data['title'] as String? ?? '',
      contentDelta: data['contentDelta'] as String? ?? '',
      category: EntryCategoryX.fromWire(data['category'] as String?),
      tags: (data['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      createdAt: _readDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(data['updatedAt']) ?? DateTime.now(),
      mediaUrls:
          (data['mediaUrls'] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[],
      projectMeta: data['projectMeta'] is Map
          ? ProjectMeta.fromMap(
              Map<String, dynamic>.from(data['projectMeta'] as Map))
          : null,
      mood: data['mood'] is Map
          ? Mood.fromMap(Map<String, dynamic>.from(data['mood'] as Map))
          : null,
      isPinned: data['isPinned'] as bool? ?? false,
      wordCount: (data['wordCount'] as num?)?.toInt() ?? 0,
      location: data['location'] is Map
          ? EntryLocation.fromMap(
              Map<String, dynamic>.from(data['location'] as Map))
          : null,
      weather: data['weather'] is Map
          ? WeatherSnapshot.fromMap(
              Map<String, dynamic>.from(data['weather'] as Map))
          : null,
      subtasks: (data['subtasks'] as List?)
              ?.whereType<Map>()
              .map((m) => TaskItem.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          const <TaskItem>[],
      isArchived: data['isArchived'] as bool? ?? false,
    );
  }

  static DateTime? _readDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }
}
