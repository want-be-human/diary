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
    Query<Map<String, dynamic>> query =
        _col.orderBy('updatedAt', descending: true);
    if (category != null) {
      query = query.where('category', isEqualTo: category.wireValue);
    }
    return query.snapshots().map(
          (snap) =>
              snap.docs.map(Entry.fromFirestore).toList(growable: false),
        );
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

  Future<void> update(Entry entry) async {
    final patched = entry.copyWith(updatedAt: DateTime.now());
    await _col.doc(entry.id).set(patched.toFirestore());
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
