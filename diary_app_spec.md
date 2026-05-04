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
4. **全文搜索**：支持按标题和正文内容查询，使用 Isar 本地索引；可叠加心情 / 日期区间 / 标签筛选
5. **多视图浏览**：首页可切换三种视图
   - 列表（默认）
   - 时间线（按日/月分组的垂直时间轴）
   - 日历热力图（GitHub 贡献图风格，年度方格按当日字数着色，点格子展开当日条目）
6. **条目元数据**（所有条目通用）：
   - **心情 mood**：5 档 emoji（😢 😔 😐 🙂 😊）+ 可选自定义短词（如"充实"）
   - **置顶**：pin 重要条目到列表顶部
   - **字数统计**：编辑时实时计算并写入元数据，供热力图/统计页使用
   - **位置**：移动端可一键 GPS + 反向地理编码；桌面端手填城市/地点
   - **天气**：创建时自动抓一次（Open-Meteo HTTP，免 key），亦可手填覆盖
7. **项目模式增强**：详见下方"项目日志扩展字段"
8. **统计仪表盘**：总条目 / 总字数 / 活跃天数 / 月度柱图 / 星期分布 / 标签云 / 心情分布
9. **年度回顾**：按自然年汇总（最长一篇、字数总计、Top 标签、心情趋势曲线、最常写月份/星期），可一键导出为 PDF
10. **导出功能**：详见下方"导出"章节
11. **双端同步**：Firebase 离线持久化，断网可用，联网自动同步
12. **登录方式**：Google 一键登录（Android 用 Play Services，Windows 用 OAuth2 桌面流程）+ 邮箱密码（带"记住邮箱"），离线时正常使用本地缓存
13. **归档**：左滑卡片归档（带 Undo），归档条目从主列表消失但保留在"归档"页可还原；与"删除"区分（归档可逆，删除不可逆）
14. **每日一言**：首页顶部展示一句格言，数据源 [UAPI `/api/v1/saying`](https://uapis.cn/api/v1/saying)，按天缓存到 SharedPreferences，点击卡片重新拉取
15. **快捷搜索栏**：首页 AppBar 中央是搜索 pill，点击进入搜索页（替代独立搜索图标按钮）

### 项目日志扩展字段（仅 category = project 时显示）
```
projectName: String           // 项目名称
version: String               // 版本号，如 v1.2.0
completedItems: List<String>  // 本次完成内容列表（描述性，与 subtasks 区分）
status: Enum                  // in_progress | done
isMilestone: bool             // 是否里程碑（首发版本 / 重大功能等），影响项目时间轴渲染
```

**项目聚合页**：按 `projectName` 自动归集所有相关 entry，呈现为：
- 项目卡列表（项目名 / 最新版本 / 状态 / 条目数 / 最近更新时间）
- 项目详情页：里程碑时间轴（`isMilestone == true` 节点放大显示）+ 全部相关条目倒序列表

**子任务清单**（任意 entry 都可加，与 `completedItems` 区分用途）：
- 勾选式 todo（`text` + `done`），编辑器内可增删改排序
- 详情页展示进度条："3 / 7 完成"
- 不参与全文搜索索引

---

## 数据模型

### Entry（通用日记条目）
```dart
class Entry {
  String id;
  String title;
  String contentDelta;       // Quill Delta JSON 字符串
  EntryCategory category;    // diary | project
  List<String> tags;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> mediaUrls;    // Firebase Storage URL 或 Drive 文件 ID
  ProjectMeta? projectMeta;  // 仅 project 类型有值

  // 增强元数据（v2 补充）
  Mood? mood;                // 心情，可空
  bool isPinned;             // 置顶
  int wordCount;             // 字数（写入时计算，纯文本）
  EntryLocation? location;   // 位置，可空
  WeatherSnapshot? weather;  // 创建时刻天气，可空
  List<TaskItem> subtasks;   // 子任务清单，默认空数组
  bool isArchived;           // 归档状态，默认 false
}
```

### Mood（心情）
```dart
class Mood {
  int score;       // 1..5（用于统计趋势，1=最差，5=最好）
  String emoji;    // 😢 😔 😐 🙂 😊 之一，或用户自定义
  String? label;   // 可选短词，如 "充实" / "焦虑"
}
```

### EntryLocation（位置）
```dart
class EntryLocation {
  double latitude;
  double longitude;
  String? placeName;   // 反向地理编码结果或手填，如 "杭州市西湖区"
}
```

### WeatherSnapshot（天气快照）
```dart
enum WeatherCondition { sunny, cloudy, rainy, snowy, fog, windy, unknown }

class WeatherSnapshot {
  WeatherCondition condition;
  double tempCelsius;
  String? cityName;
}
```

### TaskItem（子任务条目）
```dart
class TaskItem {
  String id;
  String text;
  bool done;
}
```

### ProjectMeta（项目日志扩展）
```dart
class ProjectMeta {
  String entryId;
  String projectName;
  String version;
  List<String> completedItems;
  ProjectStatus status;  // inProgress | done
  bool isMilestone;      // 是否里程碑节点
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

  // 用于搜索页过滤（Isar 索引字段，无需 token 化）
  @Index() DateTime createdAt;
  @Index() int? moodScore;   // null 表示无心情
  @Index() bool isPinned;
  @Index() int wordCount;    // 字数；热力图渲染从这里取
}
```

> 同步规则：每次 Entry 写入 Firestore 后，本地异步重建对应 SearchIndex；离线时也写本地索引，联网后再补 Firestore。

---

## 导出

### 范围（四选一）
| 范围 | 触发方式 | 说明 |
|------|---------|------|
| **单条** | 详情页右上角"导出"按钮 | 当前条目本身 |
| **当前筛选** | 首页右上角"导出当前结果" | 应用当前 Tab + 搜索词 + 心情/标签/日期过滤后的结果集 |
| **日期区间** | 导出页 DateRangePicker | 选 from-to，包含两端 |
| **多选** | 首页长按进入多选模式，勾完后点"导出选中" | 任意手动挑选的条目 |

### 格式（多选一）
| 格式 | 输出 | 用途 |
|------|------|------|
| **Markdown**（默认） | `index.md` + `images/` 目录，打包 zip | 通用、Obsidian/typora 友好 |
| **HTML** | `index.html` 单文件（自包含 CSS）+ `images/`，打包 zip | 浏览器直接看 |
| **PDF** | 单一 `.pdf` 文件 | 纸本感、归档、年度回顾导出 |
| **JSON 备份** | `backup.json`（结构化全量数据，含元数据） | 跨设备恢复 / 迁移 |

### 资源处理（图片）
| 选项 | 说明 |
|------|------|
| 内联 base64 | 单文件可移植；体积大 |
| 外链 | 保留 Firebase Storage URL；体积小但依赖网络 |
| 打包到 `images/` | 默认；下载图片放进 zip 子目录，离线可看 |

视频统一保留 Drive 链接（不下载视频文件，避免巨大体积）。

### 默认偏好
首选项写入设置页：默认导出格式、默认图片处理方式、默认 PDF 是否包含封面页。

---

## UI 设计要求

- **风格**：简约、柔和、淡雅；大量留白；圆角卡片；无重色块
- **调色板**：主色为低饱和度暖灰/米白（浅色模式）/ 深灰蓝（深色模式），强调色用柔和的 sage green 或 dusty blue
- **交互**：动画丰富但不张扬；列表项入场动画；页面切换用 Hero 过渡；按钮有触感反馈
- **深色模式**：完整支持，可手动切换，记忆用户偏好
- **字体**：正文用衬线字体（日记感），UI 元素用无衬线
- **多视图**：首页支持列表 / 时间线 / 热力图三视图切换，切换有渐变过渡，不重新加载数据
- **元数据可视化**：心情用 emoji 徽章；天气用图标 + 温度；位置用小地图标 + 文字；这些徽章在卡片角落统一排版，留白优先

---

## 页面结构

```
App
├── 首页（方案 A：单 Feed + 过滤芯片）
│   ├── AppBar
│   │   ├── 中央：搜索 pill（点击 → /search 搜索页）
│   │   └── 右侧：设置图标
│   ├── 每日一言卡片（顶部）
│   │   ├── 调用 UAPI `/api/v1/saying`，结果 `{"text": "..."}`
│   │   ├── 按"YYYY-MM-DD"键缓存到 SharedPreferences，每日换一句
│   │   ├── 失败/无数据时显示骨架或重试提示
│   │   └── 点击卡片重新拉取
│   ├── 过滤芯片：[全部] [日记] [项目]
│   │   └── "全部"是默认选中，无 stats / streak 等额外占位
│   ├── 三种视图切换（v3 添加；目前仅列表）：
│   │   ├── 列表：卡片纵向滚动，置顶条目固定在顶部，带入场动画
│   │   ├── 时间线：垂直时间轴，按"日 → 月"两级分组
│   │   └── 热力图：年度方格，格子深浅按当日字数 quantile 着色，点格子展开当日条目浮层
│   ├── 卡片支持手势：
│   │   ├── 左滑（endToStart）→ 归档，SnackBar 出现"撤销"按钮（4s）
│   │   └── 长按进入多选模式（用于批量导出）
│   └── 浮动新建按钮：
│       ├── 当前过滤为"日记"或"项目"时，直接以该类目新建（"写日记" / "记项目"）
│       └── 当前过滤为"全部"时，弹底部表单让用户选类目
├── 编辑页
│   ├── 富文本编辑器（flutter_quill）
│   ├── 工具栏：加粗 / 斜体 / 标题 / 列表 / 勾选列表 / 插入图片 / 插入视频
│   ├── 元数据栏（紧贴标题下方折叠条）：
│   │   ├── 心情选择器（5 档 emoji + 自定义短词）
│   │   ├── 标签输入
│   │   ├── 位置：移动端"一键定位"按钮 + 反向地理编码；桌面端手填
│   │   ├── 天气：默认隐藏自动抓取，可点开手动覆盖
│   │   └── 置顶切换
│   ├── 子任务面板（可展开）：勾选式 todo，进度自动计算
│   ├── 字数实时显示（角标）
│   └── 项目字段面板（category = project 时展开）：
│       projectName / version / completedItems / status / **isMilestone**
├── 详情页（只读渲染）
│   ├── 元数据徽章区：心情 / 位置 / 天气 / 字数 / 创建-更新时间
│   ├── 富文本只读
│   ├── 子任务进度条（如有）
│   ├── 关联媒体快速跳转
│   └── 操作：编辑 / 导出当前条目 / 删除 / 置顶切换
├── 项目聚合页（仅 project 类目可见入口）
│   ├── 项目列表：按 projectName 自动归集
│   │   └── 项目卡：项目名 / 最新版本 / 状态 / 条目数 / 最近更新
│   └── 项目详情：
│       ├── 顶部里程碑时间轴（isMilestone == true 节点放大；其余为小节点）
│       └── 全部相关条目倒序列表
├── 搜索页
│   ├── 实时搜索 Isar 索引
│   └── 过滤栏：心情 / 日期区间 / 标签
├── 统计页
│   ├── 总览卡：总条目 / 总字数 / 活跃天数 / 当月较上月 Δ
│   ├── 月度柱图（fl_chart）
│   ├── 星期分布
│   ├── 标签云
│   ├── 心情分布饼图
│   └── "查看年度回顾"入口
├── 年度回顾页
│   ├── 关键数字（条目 / 字数 / 活跃天数）
│   ├── 心情趋势曲线
│   ├── Top 标签 / 最常写月份 & 星期
│   ├── 最长一篇直达
│   └── "导出本年回顾 PDF"按钮
├── 导出页
│   ├── 范围选择：全部 / 当前筛选 / 日期区间 / 多选
│   ├── 格式：Markdown / HTML / PDF / JSON
│   ├── 资源处理：内联 base64 / 外链 / 打包到 images/
│   ├── 进度提示（导出大批量条目时分批运行）
│   └── 完成后给出本地文件路径，并提供"打开所在文件夹"按钮（桌面）/ 系统分享（移动）
├── 归档页
│   ├── 列表：所有 isArchived == true 的条目（倒序）
│   └── 每行右侧"还原"按钮 → 切回主列表
└── 设置页
    ├── 主题切换
    ├── 默认导出偏好（格式 + 图片处理）
    ├── 默认天气城市（位置权限关闭时手填）
    ├── 账号 / 同步状态
    ├── 归档（入口 → 归档页）
    └── 数据备份（一键 JSON 备份到本地或 Drive）
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

  # === v2 新增 ===

  # 图表（统计仪表盘 / 年度回顾）
  fl_chart: ^0.69.0

  # PDF 导出
  pdf: ^3.11.1
  printing: ^5.13.4

  # 位置（GPS + 反向地理编码；移动端用，桌面 fallback 手填）
  geolocator: ^13.0.1
  geocoding: ^3.0.0

  # 日期 / 区域格式化
  intl: ^0.19.0

  # FFI（Windows 端在 Firebase init 前注入 HTTPS_PROXY 环境变量）
  ffi: ^2.1.3

  # SharedPreferences（已用于主题，复用于"记住邮箱"和导出偏好）
  shared_preferences: ^2.3.5
```

> 天气：调用 [Open-Meteo](https://open-meteo.com/) 免费 HTTP API，无需 API key；不引专门 SDK，用 `package:http` 直接发请求。
> 日历热力图：自定义 Grid 实现，不引第三方包；色阶按全部条目的字数 quantile 计算。

---

## 开发顺序建议

> 已完成的阶段标记 ✅；剩余按本表推进。

1. ✅ `flutter create` 项目初始化，配置 pubspec.yaml
2. ✅ Firebase 项目创建 + Windows 配置（Android 注册待补）
3. ✅ 登录流程（邮箱密码 + Google 一键，含中国大陆代理 + 桌面 OAuth2）
4. ✅ 主题系统（浅色 / 深色）+ 基础路由
5. **Entry 数据模型 v2**（含 mood / isPinned / wordCount / location / weather / subtasks）+ Firestore CRUD + Repository
6. Isar 本地搜索索引同步（含 createdAt / moodScore / wordCount 索引字段）
7. 首页 v1：列表视图 + 入场动画 + 置顶顶部固定
8. 富文本编辑器 + 元数据栏（心情 / 标签 / 置顶 / 字数实时显示）+ 图片上传（Firebase Storage）
9. 子任务面板（勾选 todo + 进度条）
10. 项目扩展字段 UI（含 isMilestone）
11. 位置 + 天气：移动端 GPS + 反向地理编码；桌面端手填；天气走 Open-Meteo
12. Google Drive 视频上传 + 内嵌播放
13. 项目聚合页（项目卡列表 + 项目详情含里程碑时间轴）
14. 时间线视图（按日 / 月分组）
15. 日历热力图视图（年度方格 + quantile 着色）
16. 搜索页（叠加心情 / 日期 / 标签筛选）
17. 统计仪表盘（fl_chart）
18. 年度回顾页（含 PDF 导出）
19. 导出模块：
    - 范围：全部 / 当前筛选 / 日期区间 / 多选
    - 格式：MD / HTML / PDF / JSON 备份
    - 资源处理：内联 / 外链 / 打包到 images/
20. 设置页 + 数据备份
21. Android 打包测试 + Firebase Android 注册补齐
22. Windows 打包测试 + 验证打包产物的代理注入逻辑

---

## 给 Claude Code 的初始指令示例

将上方文档粘贴后，可用以下指令开始：

```
请按照上方规格文档，从第一步开始：
1. 生成完整的 pubspec.yaml
2. 生成 lib/core/theme/ 下的浅色和深色主题（柔和淡雅风格）
3. 生成 lib/data/models/ 下所有数据模型类
```
