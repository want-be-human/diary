# 个人日记 App — 项目规格文档
> 将此文档完整粘贴到 Claude Code，作为项目上下文开始开发。

---

## 项目概述

一款**个人单用户**日记与项目日志管理 App，使用 **Flutter** 开发，一份代码同时打包为 Android APK 和 Windows EXE，数据通过 Firebase 实时同步。

---

## 技术栈（已确认）

| 层级 | 技术选型 | 说明 |
|------|---------|------|
| 前端框架 | Flutter (Dart) | 一份代码 → Android + Windows |
| 富文本编辑器 | flutter_quill | 支持图片/视频内嵌 |
| 身份认证 | Firebase Auth + Google Sign-In | 一键登录，支持离线 |
| 云数据库 | Firebase Firestore | 文字/元数据，实时同步 |
| 图片存储 | Firebase Storage | 日记内图片，免费 5GB |
| 视频存储 | Google Drive（用户已有 2TB） | 通过 Drive API 鉴权播放 |
| 本地数据库 | Isar | 全文搜索索引 + 离线缓存 |
| 架构模式 | Repository Pattern | 隔离数据层，方便未来迁移 |

---

## 功能需求

### 核心功能
1. **日记分类**：支持两种类型
   - `diary`：普通日常日记
   - `project`：项目更新日志（有扩展字段）
2. **富文本编辑**：正文中可插入图片（Firebase Storage）和视频（Google Drive 链接，内嵌播放）
3. **深色/浅色模式**：系统跟随 + 手动切换，UI 风格柔和淡雅
4. **全文搜索**：支持按标题和正文内容查询，使用 Isar 本地索引
5. **导出功能**：导出为 zip 包（index.md 或 index.html + images/ 子目录），视频保留 Drive 链接
6. **双端同步**：Firebase 离线持久化，断网可用，联网自动同步
7. **Google 一键登录**，离线时正常使用本地缓存

### 项目日志扩展字段（仅 category = project 时显示）
```
projectName: String    // 项目名称
version: String        // 版本号，如 v1.2.0
completedItems: List<String>  // 本次完成内容列表
status: Enum           // in_progress | done
```

---

## 数据模型

### Entry（通用日记条目）
```dart
class Entry {
  String id;
  String title;
  String contentDelta;   // Quill Delta JSON 字符串
  EntryCategory category; // diary | project
  List<String> tags;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> mediaUrls; // Firebase Storage URL 或 Drive 文件 ID
  ProjectMeta? projectMeta; // 仅 project 类型有值
}
```

### ProjectMeta（项目日志扩展）
```dart
class ProjectMeta {
  String entryId;
  String projectName;
  String version;
  List<String> completedItems;
  ProjectStatus status; // inProgress | done
}
```

### MediaAsset（媒体资产）
```dart
class MediaAsset {
  String id;
  MediaType type;     // image | video
  String url;         // CDN 地址或 Drive 预览链接
  MediaSource source; // firebaseStorage | googleDrive | youtube
  String? localPath;  // 本地缓存路径
  int sizeBytes;
}
```

### SearchIndex（本地 Isar 搜索索引）
```dart
@Collection()
class SearchIndex {
  Id isarId = Isar.autoIncrement;
  String entryId;
  String titleTokens;
  String bodyTokens;
  String? projectName;
  String tags;         // 合并为单字符串便于搜索
}
```

---

## UI 设计要求

- **风格**：简约、柔和、淡雅；大量留白；圆角卡片；无重色块
- **调色板**：主色为低饱和度暖灰/米白（浅色模式）/ 深灰蓝（深色模式），强调色用柔和的 sage green 或 dusty blue
- **交互**：动画丰富但不张扬；列表项入场动画；页面切换用 Hero 过渡；按钮有触感反馈
- **深色模式**：完整支持，可手动切换，记忆用户偏好
- **字体**：正文用衬线字体（日记感），UI 元素用无衬线

---

## 页面结构

```
App
├── 首页（日记列表）
│   ├── 顶部：搜索栏 + 分类筛选 Tab（全部 / 日记 / 项目）
│   ├── 中部：日记卡片列表（带入场动画）
│   └── 底部：浮动新建按钮
├── 编辑页
│   ├── 富文本编辑器（flutter_quill）
│   ├── 工具栏：加粗/斜体/标题/插入图片/插入视频
│   └── 项目字段面板（category = project 时展开）
├── 详情页（只读渲染 + 导出按钮）
├── 搜索页（实时搜索 Isar 索引）
└── 设置页
    ├── 主题切换
    ├── 导出格式（MD / HTML）
    └── 账号 / 同步状态
```

---

## 项目目录结构（推荐）

```
lib/
├── main.dart
├── app.dart                    # MaterialApp + 主题配置
├── core/
│   ├── theme/                  # 浅色/深色主题定义
│   ├── router/                 # go_router 路由配置
│   └── constants/
├── data/
│   ├── models/                 # Entry, ProjectMeta, MediaAsset, SearchIndex
│   ├── repositories/           # 抽象接口（EntryRepository 等）
│   ├── datasources/
│   │   ├── remote/             # Firestore, Firebase Storage, Drive API
│   │   └── local/              # Isar 实现
│   └── services/
│       ├── auth_service.dart   # Google Sign-In + Firebase Auth
│       ├── drive_service.dart  # Google Drive 上传/播放
│       └── export_service.dart # MD/HTML/zip 导出
├── features/
│   ├── home/                   # 列表页
│   ├── editor/                 # 富文本编辑页
│   ├── detail/                 # 详情只读页
│   ├── search/                 # 搜索页
│   └── settings/               # 设置页
└── shared/
    ├── widgets/                # 通用组件
    └── utils/
```

---

## 关键依赖包（pubspec.yaml）

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_storage: ^12.0.0

  # Google 登录 & Drive
  google_sign_in: ^6.0.0
  googleapis: ^13.0.0          # Drive API

  # 富文本编辑器
  flutter_quill: ^10.0.0

  # 本地数据库（全文搜索）
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0

  # 视频播放
  video_player: ^2.0.0
  youtube_player_flutter: ^9.0.0  # YouTube 链接播放

  # 路由
  go_router: ^14.0.0

  # 导出
  archive: ^3.0.0              # 生成 zip
  path_provider: ^2.0.0

  # 状态管理
  flutter_riverpod: ^2.0.0

  # 动画
  animations: ^2.0.0           # Material 页面过渡动画
```

---

## 开发顺序建议

1. `flutter create` 项目初始化，配置 pubspec.yaml
2. Firebase 项目创建 + android/windows 配置文件下载
3. Google Sign-In 登录流程
4. Entry 数据模型 + Firestore CRUD + Repository 接口
5. Isar 本地搜索索引同步逻辑
6. 主题系统（浅色/深色）+ 基础路由
7. 首页列表 + 动画
8. 富文本编辑器页面 + 图片上传（Firebase Storage）
9. Google Drive 视频上传 + 内嵌播放
10. 项目日志扩展字段 UI
11. 搜索页
12. 导出模块（zip + MD/HTML）
13. 双端打包测试（`flutter build apk` + `flutter build windows`）

---

## 给 Claude Code 的初始指令示例

将上方文档粘贴后，可用以下指令开始：

```
请按照上方规格文档，从第一步开始：
1. 生成完整的 pubspec.yaml
2. 生成 lib/core/theme/ 下的浅色和深色主题（柔和淡雅风格）
3. 生成 lib/data/models/ 下所有数据模型类
```
