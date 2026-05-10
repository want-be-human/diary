import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/entry.dart';

/// 远端 Firestore 数据源。集合路径：`users/{uid}/entries/{entryId}`
/// 单用户应用，[uid] 由调用方在登录后注入。
class FirestoreEntryDataSource {
  FirestoreEntryDataSource({
    required this.uid,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users').doc(uid).collection('entries');

  Stream<List<Entry>> watchAll({EntryCategory? category}) {
    // 故意不在 Firestore 端加 where：where + orderBy 跨字段需要复合索引
    // (category, updatedAt)，没建索引时返回空且报 FAILED_PRECONDITION。
    // 单用户应用条目量小（千级），客户端过滤足够，省掉运维索引的负担。
    return _col.orderBy('updatedAt', descending: true).snapshots().map((snap) {
      var all = snap.docs.map(Entry.fromFirestore);
      // 默认主列表过滤掉归档；归档条目走 watchArchived。
      all = all.where((e) => !e.isArchived);
      if (category != null) all = all.where((e) => e.category == category);
      return all.toList(growable: false);
    });
  }

  /// 监听归档列表（isArchived == true）。
  Stream<List<Entry>> watchArchived() {
    return _col.orderBy('updatedAt', descending: true).snapshots().map((snap) {
      return snap.docs
          .map(Entry.fromFirestore)
          .where((e) => e.isArchived)
          .toList(growable: false);
    });
  }

  Stream<Entry?> watchById(String id) {
    return _col.doc(id).snapshots().map(
          (doc) => doc.exists ? Entry.fromFirestore(doc) : null,
        );
  }

  Future<Entry?> findById(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? Entry.fromFirestore(doc) : null;
  }

  Future<Entry> create(Entry entry) async {
    final ref = entry.id.isEmpty ? _col.doc() : _col.doc(entry.id);
    final saved = entry.copyWith(id: ref.id, updatedAt: DateTime.now());
    await ref.set(saved.toFirestore());
    return saved;
  }

  /// 生成一个尚未写到服务器的 docId（Firestore 客户端本地随机生成，免费）。
  String newId() => _col.doc().id;

  Future<void> update(Entry entry) async {
    final patched = entry.copyWith(updatedAt: DateTime.now());
    await _col.doc(entry.id).set(patched.toFirestore());
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
