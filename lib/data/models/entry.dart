import 'package:cloud_firestore/cloud_firestore.dart';

import 'project_meta.dart';

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

/// 通用日记条目。
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
    bool clearProjectMeta = false,
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
      projectMeta: data['projectMeta'] is Map<String, dynamic>
          ? ProjectMeta.fromMap(
              Map<String, dynamic>.from(data['projectMeta'] as Map))
          : null,
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
