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
- 2026-06-23：阶段 12 开工前复查 Git 状态、全量文件清单、图片编辑模型/渲染器/UI/测试边界；再次通过 GitHub API 确认 `guoyingtao/Mantis` 为 MIT/Swift/活跃、`TimOliver/TOCropViewController` 为 MIT/Objective-C/成熟，但直接接入需要完整 Xcode/SPM 或 ObjC 桥接验证。`SwiftUI image inpainting object removal MIT` 搜索返回 0；本轮继续复用 Core Image/UIKit 自建可调裁剪与授权清理贴片。
- 2026-06-23：阶段 12 前继续核验图片裁剪开源候选。`guoyingtao/Mantis` 为 MIT、Swift、SwiftUI topic、2026-06 仍有推送，适合作为后续自由裁剪依赖候选；`TimOliver/TOCropViewController` 为 MIT、成熟 Objective-C/UIKit 裁剪器、2026-04 有推送，适合作为备选但会增加桥接与工程维护成本。GitHub 搜索 `SwiftUI image crop editor MIT` 未找到比二者更适合直接复制进当前工程的轻量模块。
- 2026-06-23：最新 GitHub Actions run `27962981148` 在 Build for simulator 阶段失败。日志 annotation 只显示 Share Extension 编译退出 65，但本地 cross-target 扫描发现 `SomeShareExtension` 编译 `MemoStore.swift`，而 `MemoStore.addImageEdit` 引用了 `ImageEditRenderer`；`ImageEditRenderer.swift` 只在主 App target 中，属于 P1 构建阻塞。修复策略是把 `ImageEditRenderer.swift` 补入 Share Extension Sources，不改公共数据结构。
- 2026-06-23：阶段 13 开工前检索 `SwiftUI scrapbook collage export image MIT` 与 `iOS collage editor Swift MIT export`，GitHub API 均返回 0 个可直接复用候选；本轮不新增第三方依赖，继续基于本项目 `ScrapbookPageLayout` 和 UIKit renderer 自建导出。
- 2026-06-23：阶段 14 开工前检索 `SwiftUI video thumbnail cache MIT`、`AVAssetImageGenerator thumbnail cache Swift`、`Swift media metadata AVAsset MIT iOS`、`iOS local video thumbnail Swift MIT` 等关键词，精确查询均返回 0。放宽到 `video thumbnail swift` 后发现 `HHK1/PryntTrimmerView`（MIT、Swift、视频裁剪/帧选择）、`luispadron/LPThumbnailView`（MIT、Swift/UIKit、已归档）、`krad/memento`（MIT、小型 Swift 视频缩略图工具）等候选；这些项目不覆盖 some 当前“本地附件 URI、素材索引、详情页/素材库复用、离线缓存失效”的架构，不直接复制源码。本轮优先复用 Apple AVFoundation 与现有 `SharedAttachmentStore` / `VideoThumbnailGenerator`，自建小型持久缩略图缓存和媒体元数据摘要。
- 2026-06-23：阶段 15 开工前复查网页摘录链路并检索网页正文清洗候选。`scinfu/SwiftSoup` 为 MIT、Swift、2026-06 仍活跃，适合作为后续完整 HTML DOM 解析依赖候选；`exyte/ReadabilityKit` 为 MIT、Swift，但仓库已归档且 2023 后未推送；`Swift readability html article extractor MIT` 与 `SwiftSoup readability article extractor` 搜索未找到更合适的可复制模块。本轮不复制第三方源码、不引入 SPM，先扩展 some 内置的轻量 HTML 清洗、段落评分和摘录卡结构。
- 2026-06-23：阶段 16 开工前检索 SwiftUI 文本高亮/摘录选择、Vision OCR 文本选择、网页文章 highlight、VisionKit 文档扫描等候选，GitHub API 多轮搜索均返回 0 个可直接复用模块。当前先不引入 UI 高亮依赖，优先建立 `ClipFragment` 纯模型，把网页摘录重点、摘要和 OCR 行统一成可勾选/可合并候选。
- 2026-06-23：阶段 19 开工前检索 Vision 背景移除、前景分割和 SwiftUI background remover 候选；未找到适合直接复制进当前 iOS 16 SwiftUI 工程的成熟 MIT 模块。当前先把背景柔化/纯色画布纳入本项目图片编辑配方与渲染管线，为后续 Apple Vision 前景分割、衣橱抠图和拼贴排版打底。
- 2026-06-23：阶段 20 开工前检索 SwiftUI 衣橱洗护、旅行打包和 capsule wardrobe packing list 候选；未找到可直接复制的成熟 Swift/iOS MIT 模块。当前继续复用 some 结构化 memo 与素材索引，先落地洗护记录和旅行打包清单。
- 2026-06-23：阶段 21 开工前复查 Git 状态、计划文件、手帐模型、编辑器、渲染器、列表缩略图和相关测试；本地未发现未跟踪碎片。检索 `SwiftUI scrapbook sticker font border MIT`、`iOS collage editor stickers fonts Swift MIT`、`Swift sticker view font border editor MIT`、`IRSticker Swift MIT`、`SwiftStickerView iOS MIT` 等候选均未找到可直接复制进当前 SwiftUI/素材索引架构的成熟 MIT 模块；此前 UIKit 贴纸项目继续只做交互参考。本轮复用现有 `ScrapbookLayer` 字体、颜色、边框、圆角和阴影字段，新增项目内样式目录与编辑入口。
- 2026-06-23：GitHub Actions run `27975351182` 的 Build for simulator 通过，但 Run tests 失败。公开 annotation 未显示业务 XCTest 断言失败，最后可见测试均通过，失败线集中在 `appintentsnltrainingprocessor` 的 `Unable to parse extract.actionsdata`。当前判断为 Xcode 16 CI App Intents 元数据训练工具链问题；修复策略是在 CI 的 `xcodebuild test` 构建中排除 AppIntents 源文件并加 `CI_DISABLE_APP_INTENTS` 条件，正式 App build 不关闭快捷指令功能。

## 当前缺口

- 媒体预览：视频附件已有本地缩略图缓存与媒体元数据摘要 v1；后续需用真实长列表验证滚动性能，并按需要补批量预热/清理策略。
- 工作日志：已有勾选记录生成结构化日志 v1；后续可增强项目字段、周期范围、导出模板、AI 润色和多选筛选。
- 电子手帐：已有图层 JSON、预览、详情页拖拽/缩放/旋转、独立编辑器图层新增/复制/删除/层级调整、图片素材追加、画布底色、字体/贴纸/花边预设、颜色/字号/圆角/线宽编辑、PNG 导出和保存回原 memo；后续缺 PDF 分享入口、真实图片排版长页性能和真机手势验证。
- 图片编辑：已完成素材库图片编辑入口、预设比例裁剪、可调裁剪中心/缩放、背景柔化/纯色画布、授权图片瑕疵清理贴片、Core Image 滤镜、边框、文字、贴纸、输出 PNG 附件、`imageEdit` 素材索引和 `has:image-edit` 搜索；完整手势裁剪器、人物/物体抠图、对象级修复、模板拼贴和导出预设仍待补。
- 电子衣橱：已完成衣橱洞察 v3，可从现有素材索引统计分类、颜色、季节、场景、未进入穿搭组合单品、常用单品、穿着次数、最近穿着和成本/次，并记录洗护状态与旅行打包清单；天气推荐、自动打包建议和洗护提醒仍待补。
- 网页摘录：已有标题/description、正文清洗、段落评分、来源、摘录卡、重点候选、网页/OCR 统一摘录片段和快速输入片段勾选；后续再做批量网页导入、截图/OCR 区域选择和摘录片段独立素材索引。
- CI 测试稳定性：GitHub iPhone 16 Pro 模拟器默认图片 renderer scale 可能不是 1，像素尺寸测试必须显式设置 `UIGraphicsImageRendererFormat.scale = 1` 或断言比例；视频/媒体测试应使用真实保存文件，不应手工构造不存在的 `SharedAttachment`。App Intents 元数据训练在 CI 测试阶段可能触发 `extract.actionsdata` 解析失败，当前测试构建通过条件编译和 `EXCLUDED_SOURCE_FILE_NAMES` 暂避，待远端复验。
