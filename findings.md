# some 项目发现记录

## 本地扫描

- 2026-06-22：仓库根目录未发现隐藏的第二套 some 项目或未跟踪文件碎片；核心目录为 `some`、`SomeTests`、`SomeShareExtension`、`AppStore`、`docs` 和 `some.xcodeproj`。
- 2026-06-22：当前已有功能包括素材索引、拍照/拍视频、录音、音频本机语音转写、网页摘录、图片 OCR、电子手帐图层底座与详情页画布编辑、电子衣橱第一段、分享扩展、引用、备份、隐私锁和 AI 洞察。
- 2026-06-22：视频素材已经能通过相机/相册导入并进入 `MemoAsset.video` 索引；已补 `AttachmentPreviewList` 和素材库 `AssetRowView` 的本机视频缩略图 v1，后续缺口转为持久化缩略图缓存和批量媒体元数据。
- 2026-06-22：工作日志 v1 已接入首页“日志”模式、`MemoAsset.workLog` 索引和 `has:worklog` 搜索；可以勾选已有记录、提取已完成/未完成任务，并生成带来源引用的日报/周报/项目日志。

## 开源检索

- 2026-06-22：已通过 GitHub API 检索 `SwiftUI daily journal notes app`、`SwiftUI work log daily report MIT` 等关键词。找到的日记/日志 SwiftUI 项目数量少，且主要无许可证或功能过轻；未发现可直接复制的成熟 MIT SwiftUI 工作日志模块。
- 2026-06-22：工作日志 MVP 决策为复用本项目现有 `Memo`、`MemoAsset`、`MemoTaskParser`、`MemoReferenceParser`、结构化 memo 保存和搜索筛选，不新增第三方依赖。
- 2026-06-22：继续补做 `SwiftUI work log daily report MIT`、`iOS daily work journal SwiftUI MIT`、`SwiftUI daily report work log` GitHub API 检索，均返回 0 个候选；维持不新增依赖决策。
- 2026-06-22：视频缩略图继续检索 `SwiftUI AVAssetImageGenerator video thumbnail MIT`、`iOS video thumbnail AVAssetImageGenerator MIT Swift` 等关键词，GitHub API 未返回可直接复制的成熟 MIT 模块；采用 Apple `AVAssetImageGenerator` 本机取帧，复用现有附件存储和素材索引。
- 2026-06-22：阶段 9 继续前检索 `SwiftUI draggable resizable rotatable view MIT`、`SwiftUI sticker drag resize rotate MIT`、`iOS sticker view drag resize rotate Swift MIT`、`SwiftUI collage editor drag resize rotate`，GitHub API 均返回 0；此前记录的 UIKit 贴纸项目只做交互参考，本轮继续基于现有 SwiftUI 与 `ScrapbookPageLayout` JSON 自建编辑器。
- 2026-06-22：阶段 10 开工前复查全量文件清单、图片/附件/素材索引边界和 `imageEdit` 预留类型；GitHub API 确认 `guoyingtao/Mantis` 与 `TimOliver/TOCropViewController` 均为 MIT 且活跃，但本轮 MVP 先用 Core Image、UIKit 绘制和现有附件存储自建，避免引入 SPM/Objective-C 桥接带来的工程变更。

## 当前缺口

- 媒体预览：视频附件已有本地按需缩略图 v1；后续再补持久化缩略图缓存、批量媒体元数据和真实长列表性能验证。
- 工作日志：已有勾选记录生成结构化日志 v1；后续可增强项目字段、周期范围、导出模板、AI 润色和多选筛选。
- 电子手帐：已有图层 JSON、预览、详情页拖拽/缩放/旋转、独立编辑器图层新增/复制/删除/层级调整和保存回原 memo；后续缺更丰富字体/贴纸/花边、图片素材追加、导出图片/PDF 和真机手势验证。
- 图片编辑：已完成素材库图片编辑入口、预设比例裁剪、Core Image 滤镜、边框、文字、贴纸、输出 PNG 附件、`imageEdit` 素材索引和 `has:image-edit` 搜索；自由裁剪、抠图、对象清理、模板拼贴和导出预设仍待补。
- 电子衣橱：已完成衣橱洞察 v1，可从现有素材索引统计分类、颜色、季节、场景、未搭配单品、常用单品，并生成可填入穿搭表单的建议；穿着日历、成本/次、洗护状态、天气与旅行打包仍待补。
