import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/local/isar_search_datasource.dart';
import '../datasources/remote/firestore_entry_datasource.dart';
import '../models/entry.dart';
import '../services/auth_service.dart';
import '../services/drive_image_cache.dart';
import '../services/image_upload_service.dart';
import 'entry_repository.dart';

/// 默认实现：Firestore 为真源（带离线持久化），Isar 仅作搜索索引。
/// 任何写入都会双写：先 Firestore，成功后同步本地索引。
class EntryRepositoryImpl implements EntryRepository {
  EntryRepositoryImpl({
    required this.remote,
    required this.searchSource,
    required this.uploader,
    required this.imageCache,
  });

  final FirestoreEntryDataSource remote;
  final IsarSearchDataSource searchSource;
  final ImageUploadService uploader;
  final DriveImageCache imageCache;

  @override
  Stream<List<Entry>> watchAll({EntryCategory? category}) {
    return remote.watchAll(category: category).map((list) {
      // 顺手把最新结果灌入 Isar，让搜索保持新鲜。
      // fire-and-forget，索引失败不影响 UI。
      unawaited(_reindexAll(list));
      return list;
    });
  }

  @override
  Stream<Entry?> watchById(String id) => remote.watchById(id);

  @override
  Future<Entry?> findById(String id) => remote.findById(id);

  @override
  Future<Entry> create(Entry entry) async {
    final saved = await remote.create(entry);
    await searchSource.upsert(saved);
    return saved;
  }

  @override
  Future<void> update(Entry entry) async {
    await remote.update(entry);
    await searchSource.upsert(entry);
  }

  @override
  Future<void> delete(String id) async {
    // 先把 entry 拉一份，记下所有挂的图片 URL —— 删完 Firestore 就拿不到了。
    final entry = await remote.findById(id);
    await remote.delete(id);
    await searchSource.remove(id);

    if (entry != null) {
      // 清掉 Drive 上的图片 + 本地缓存。best-effort：失败不阻塞，
      // 反正 entry 已经从 Firestore / Isar 删了，孤儿图片下次清理也行。
      for (final url in _collectImageUrls(entry)) {
        unawaited(uploader.deleteByUrl(url));
        unawaited(imageCache.remove(url));
      }
    }
  }

  /// 把 entry 里所有"我们管"的图片 URL 收齐：
  /// - subtasks[*].imageUrls    （todo 类目）
  /// - projectMeta.completedItems[*].imageUrls （project 类目）
  /// - mediaUrls                （diary 富文本里的图，将来日记接图片管线时复用）
  Iterable<String> _collectImageUrls(Entry e) sync* {
    yield* e.mediaUrls;
    for (final t in e.subtasks) {
      yield* t.imageUrls;
    }
    final pm = e.projectMeta;
    if (pm != null) {
      for (final c in pm.completedItems) {
        yield* c.imageUrls;
      }
    }
  }

  @override
  Future<List<Entry>> search(String query, {EntryCategory? category}) async {
    final ids = await searchSource.searchEntryIds(query, category: category);
    if (ids.isEmpty) return const <Entry>[];
    final entries = await Future.wait(ids.map(remote.findById));
    return entries
        .whereType<Entry>()
        .where((e) => !e.isArchived) // 默认搜索不返回归档
        .where((e) => category == null || e.category == category)
        .toList(growable: false);
  }

  @override
  Stream<List<Entry>> watchArchived() => remote.watchArchived();

  @override
  Future<void> archive(String id) async {
    final entry = await remote.findById(id);
    if (entry == null) return;
    await remote.update(entry.copyWith(isArchived: true));
    await searchSource.upsert(entry.copyWith(isArchived: true));
  }

  @override
  Future<void> unarchive(String id) async {
    final entry = await remote.findById(id);
    if (entry == null) return;
    await remote.update(entry.copyWith(isArchived: false));
    await searchSource.upsert(entry.copyWith(isArchived: false));
  }

  @override
  String newId() => remote.newId();

  Future<void> _reindexAll(List<Entry> list) async {
    for (final e in list) {
      try {
        await searchSource.upsert(e);
      } catch (_) {
        // 索引失败忽略，下次读取再试
      }
    }
  }
}

// ===== Riverpod providers =====

/// 应用启动时初始化的 Isar 数据源。需在 main 中 override。
final isarSearchProvider = Provider<IsarSearchDataSource>((ref) {
  throw UnimplementedError(
    'isarSearchProvider must be overridden in ProviderScope after Isar.open().',
  );
});

/// 当前用户的 Entry 仓库；未登录时为 null。
final entryRepositoryProvider = Provider<EntryRepository?>((ref) {
  final auth = ref.watch(authStateProvider);
  final user = auth.asData?.value;
  if (user == null) return null;
  final search = ref.watch(isarSearchProvider);
  return EntryRepositoryImpl(
    remote: FirestoreEntryDataSource(uid: user.uid),
    searchSource: search,
    uploader: ref.watch(imageUploadServiceProvider),
    imageCache: ref.watch(driveImageCacheProvider),
  );
});
