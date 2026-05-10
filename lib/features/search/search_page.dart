import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository_impl.dart';
import '../../shared/utils/date_util.dart';
import '../../shared/utils/snippet.dart';
import '../../shared/utils/text_util.dart';
import '../../shared/widgets/highlighted_text.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Entry> _results = const [];
  String _activeQuery = '';
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(q));
  }

  Future<void> _run(String q) async {
    final repo = ref.read(entryRepositoryProvider);
    if (repo == null) return;
    final query = q.trim();
    setState(() {
      _searching = true;
      _activeQuery = query;
    });
    final results = await repo.search(query);
    if (!mounted) return;
    // 检查是否仍是最新查询（防抖期间用户可能继续打字）
    if (_activeQuery != query) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '搜索标题、正文、标签…',
            border: InputBorder.none,
            filled: false,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  )
                : null,
          ),
          style: theme.textTheme.titleMedium,
          onChanged: (v) {
            setState(() {}); // 让 suffixIcon 跟随
            _onChanged(v);
          },
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_activeQuery.isEmpty) {
      return _Hint(
        icon: Icons.search,
        text: '输入关键词开始搜索',
      );
    }
    if (_results.isEmpty) {
      return _Hint(
        icon: Icons.sentiment_dissatisfied,
        text: '没找到包含"$_activeQuery"的条目',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _SearchResultCard(
        entry: _results[i],
        query: _activeQuery,
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.entry, required this.query});

  final Entry entry;
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 三类条目的"可搜索正文"来源不同：
    // - diary  ：Quill Delta 解析出的纯文本
    // - project：项目名 + 版本号 + 完成项标题（contentDelta 为空）
    // - todo   ：subtask 标题集合
    // 复用 Entry.buildSearchableBody，跟 IsarSearchDataSource 索引时使用同一组文本，
    // 保证"搜得到 → 摘要也能高亮"。
    final plainBody = entry.category == EntryCategory.diary
        ? entry.buildSearchableBody(
            plainBody: TextUtil.extractPlainText(entry.contentDelta),
          )
        : entry.buildSearchableBody();
    final snippets = SnippetExtractor.extract(plainBody, query);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => GoRouter.of(context).push('/entry/${entry.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.isPinned) ...[
                    Icon(Icons.push_pin, size: 14, color: scheme.primary),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: HighlightedText(
                      text: entry.title.isEmpty ? '（无标题）' : entry.title,
                      query: query,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (entry.mood != null) ...[
                    const SizedBox(width: 8),
                    Text(entry.mood!.emoji,
                        style: const TextStyle(fontSize: 16)),
                  ],
                ],
              ),

              // 项目名（命中时显式标）
              if (entry.projectMeta?.projectName.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                HighlightedText(
                  text: '项目：${entry.projectMeta!.projectName}',
                  query: query,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.tertiary,
                  ),
                ),
              ],

              // 正文片段
              if (snippets.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...snippets.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: HighlightedText(
                        text: s,
                        query: query,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.78),
                          height: 1.5,
                        ),
                      ),
                    )),
              ] else if (plainBody.isNotEmpty) ...[
                // 正文未命中，显示前 80 字预览
                const SizedBox(height: 6),
                Text(
                  _previewOf(plainBody),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ],

              // 标签
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.tags.map((t) {
                    final isMatch =
                        t.toLowerCase().contains(query.toLowerCase());
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMatch
                            ? scheme.primary.withValues(alpha: 0.22)
                            : scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: HighlightedText(
                        text: '#$t',
                        query: query,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isMatch
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.65),
                          fontWeight:
                              isMatch ? FontWeight.w600 : FontWeight.w500,
                        ),
                        // 标签内不再加粗显示重复，关掉 boldMatches。
                        boldMatches: false,
                        highlightColor: Colors.transparent,
                      ),
                    );
                  }).toList(),
                ),
              ],

              // 元信息
              const SizedBox(height: 10),
              Row(
                children: [
                  const Spacer(),
                  Text(
                    DateUtil.relative(entry.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewOf(String plain) {
    final flat = plain.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= 80) return flat;
    return '${flat.substring(0, 80)}…';
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: scheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
          ),
        ],
      ),
    );
  }
}
