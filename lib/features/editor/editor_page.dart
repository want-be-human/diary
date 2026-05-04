import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 富文本编辑页占位。阶段三接入 flutter_quill + 项目字段面板。
class EditorPage extends ConsumerWidget {
  const EditorPage({super.key, this.entryId});

  final String? entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entryId == null ? '新建' : '编辑'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(
        child: Text('编辑器（阶段三接入 flutter_quill）'),
      ),
    );
  }
}
