# some 项目发现记录

## 本地扫描

- 2026-06-22：仓库根目录未发现隐藏的第二套 some 项目或未跟踪文件碎片；核心目录为 `some`、`SomeTests`、`SomeShareExtension`、`AppStore`、`docs` 和 `some.xcodeproj`。
- 2026-06-22：当前已有功能包括素材索引、拍照/拍视频、录音、音频本机语音转写、网页摘录、图片 OCR、电子手帐图层底座、电子衣橱第一段、分享扩展、引用、备份、隐私锁和 AI 洞察。
- 2026-06-22：视频素材已经能通过相机/相册导入并进入 `MemoAsset.video` 索引；已补 `AttachmentPreviewList` 和素材库 `AssetRowView` 的本机视频缩略图 v1，后续缺口转为持久化缩略图缓存和批量媒体元数据。
- 2026-06-22：工作日志 v1 已接入首页“日志”模式、`MemoAsset.workLog` 索引和 `has:worklog` 搜索；可以勾选已有记录、提取已完成/未完成任务，并生成带来源引用的日报/周报/项目日志。

## 开源检索

- 2026-06-22：已通过 GitHub API 检索 `SwiftUI daily journal notes app`、`SwiftUI work log daily report MIT` 等关键词。找到的日记/日志 SwiftUI 项目数量少，且主要无许可证或功能过轻；未发现可直接复制的成熟 MIT SwiftUI 工作日志模块。
- 2026-06-22：工作日志 MVP 决策为复用本项目现有 `Memo`、`MemoAsset`、`MemoTaskParser`、`MemoReferenceParser`、结构化 memo 保存和搜索筛选，不新增第三方依赖。
- 2026-06-22：继续补做 `SwiftUI work log daily report MIT`、`iOS daily work journal SwiftUI MIT`、`SwiftUI daily report work log` GitHub API 检索，均返回 0 个候选；维持不新增依赖决策。
- 2026-06-22：视频缩略图继续检索 `SwiftUI AVAssetImageGenerator video thumbnail MIT`、`iOS video thumbnail AVAssetImageGenerator MIT Swift` 等关键词，GitHub API 未返回可直接复制的成熟 MIT 模块；采用 Apple `AVAssetImageGenerator` 本机取帧，复用现有附件存储和素材索引。

## 当前缺口

- 媒体预览：视频附件已有本地按需缩略图 v1；后续再补持久化缩略图缓存、批量媒体元数据和真实长列表性能验证。
- 工作日志：已有勾选记录生成结构化日志 v1；后续可增强项目字段、周期范围、导出模板、AI 润色和多选筛选。
- 电子手帐：已有图层 JSON 和预览，但缺真正拖拽、缩放、字体、贴纸、花边和导出编辑器。
- 图片编辑：裁剪、滤镜、边框、文字、贴纸、拼贴和用户授权图片清理仍待实现。
