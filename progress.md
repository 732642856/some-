# some 项目进度日志

## 2026-06-22T13:59:23Z

- 恢复当前任务：用户要求继续下一步，不停等确认。
- 读取项目文件清单、Git 状态和最近提交，确认工作树干净且 `origin/master` 同步到 `e55ded2`。
- 执行本地扫描，确认没有隐藏的第二套 some 项目或未跟踪文件碎片。
- 检索工作日志/日报相关开源 SwiftUI 项目，未找到许可证清晰且可直接复用的成熟实现。
- 决定进入阶段 8：工作日志 MVP。

## 2026-06-22T14:15:00Z

- 接续用户要求“继续”，重新检查视频缩略图相关代码和项目文件登记。
- 确认 `AttachmentPreviewList` 与素材库 `AssetRowView` 仅显示视频图标，README 仍把视频缩略图列为后续缺口。
- 继续检索视频缩略图开源候选，未发现适合直接复制的清晰 MIT SwiftUI 模块；决定使用 Apple `AVAssetImageGenerator` 本机生成预览。
- 将当前阶段调整为阶段 8a：视频缩略图与媒体预览补齐；工作日志 MVP 顺延为阶段 8b。

## 2026-06-22T14:45:00Z

- 新增 `VideoThumbnailGenerator`，使用 Apple `AVAssetImageGenerator` 本机取帧并加入主 App target。
- `AttachmentPreviewList` 与素材库 `AssetRowView` 共用 `VideoThumbnailPreview`，视频附件后台生成画面预览，失败时回退视频图标。
- 补充缺失视频文件返回 nil 的单元测试，并更新 README、开源审计、差距清单和验证记录。
- 复核工作日志 MVP 半成品，确认首页“日志”模式、`MemoAsset.workLog`、`has:worklog`、来源引用和单元测试已接通。
- 继续补做工作日志 GitHub API 检索，未找到可直接复制的 SwiftUI/MIT 模块；维持复用项目现有 memo/search/task/reference 结构。
- 静态验证通过：`git diff --check`、`plutil -lint`、`xmllint --noout`、旧 Swift parser 覆盖 `VideoThumbnailGenerator`、`AttachmentPreviewList`、`ContentView`、`Memo`、`MemoStore`、`MemoSearchQuery` 和 `SomeTests`。

## 2026-06-22T15:10:00Z

- 进入阶段 9：手帐拖拽/缩放编辑器。
- 复查 Git 状态、未跟踪文件、全量文件清单和现有手帐源码；当前工作区开工前干净。
- 读取 `ScrapbookPageLayout` / `ScrapbookLayer`、`ScrapbookView`、手帐列表预览、`MemoStore.addScrapbookPage` 和相关测试。
- GitHub API 检索 SwiftUI/Swift 拖拽缩放旋转贴纸/拼贴编辑器，未找到可直接复制的成熟 MIT SwiftUI 模块；决定复用现有结构化 JSON 自建编辑器。
- 新增详情页手帐画布编辑 v1：读取图层 JSON，支持拖拽、缩放、旋转并保存回原 memo。
- 补充 `ScrapbookPageLayout.replacingLayout` 和替换/追加 JSON 单元测试。

## 2026-06-22T16:05:00Z

- 进入阶段 10：图片编辑 MVP。
- 复查 Git 状态、未跟踪文件、规划文件、全量文件清单、附件/素材模型、素材库 UI、手帐/衣橱图片绑定入口和相关测试；当前工作区开工前干净。
- 确认 `MemoAssetKind.imageEdit` 已预留，但没有结构化正文解析、保存路径、UI 入口或搜索筛选。
- GitHub API 检索 `SwiftUI photo editor crop filter sticker MIT`、`iOS photo editor Swift CoreImage MIT`、`SwiftUI image editor CoreImage MIT` 均返回 0 个可直接复制的完整 SwiftUI 图片编辑器候选。
- 复查 `guoyingtao/Mantis` 和 `TimOliver/TOCropViewController`：二者均为 MIT 且仍活跃，适合后续 Xcode 16/SPM 环境做裁剪依赖评估；本轮不直接复制源码。
- `SilenceLove/HXPhotoPicker` 仓库 API 请求超过一分钟未返回，按失败记录为网络/接口超时；本轮不把它作为直接依赖。
- 本轮决策：先复用 Apple Core Image / UIKit 渲染实现滤镜、边框、文字贴纸和导出为新附件，接入现有 memo、附件、备份、搜索和素材索引；裁剪/高级编辑后续再评估 Mantis 或 TOCropViewController。
- 新增 `ImageEditRecipe` 和 `ImageEditRenderer`，支持预设比例中心裁剪、Core Image 滤镜、边框、文字和贴纸渲染。
- 新增 `ImageEditorView`，素材库图片附件可打开编辑器，保存后生成新的本地 PNG 附件和结构化“图片编辑”记录。
- 新增 `imageEdit` 素材解析、`has:image-edit` 搜索筛选和相关单元测试。

## 2026-06-22T16:45:00Z

- 进入阶段 11：衣橱统计与搭配增强。
- 复查 Git 状态、全量文件清单、衣橱/穿搭模型、`WardrobeView`、素材索引、搜索筛选和现有测试；开工前远端同步且工作区干净。
- GitHub API 继续检索 SwiftUI/iOS/virtual closet/outfit planner 候选；未找到可直接复制进当前 SwiftUI 工程的现代 MIT 模块。`MyFitZ` 为 MIT 但 Swift4/iOS10 且停更，`VirtualClosetAI` 无许可证，`AURA` 为 MIT Kotlin/Android，均只做产品结构参考。
- 新增 `WardrobeInsightEngine`，从现有 `MemoAsset` 解析单品和穿搭，计算分类、颜色、季节、场景、未搭配单品、常用单品和搭配建议。
- 更新衣橱页，展示洞察面板，并支持把建议一键填入穿搭草稿；穿搭表单补季节字段。
- 补充衣橱洞察统计和建议单元测试。
- 发现并收拢阶段 10 文件碎片：`some/Utilities/ImageEditRenderer.swift` 与 `some/Views/ImageEditorView.swift` 已存在于磁盘但未被 Git 跟踪；本轮已确认二者纳入 Xcode app target 并加入 Git 索引。
- 静态验证通过：`git diff --check`、`plutil -lint`、`xmllint --noout`、旧 Swift parser 覆盖 `ImageEditRenderer.swift`、`ImageEditorView.swift`、`Memo.swift`、`MemoStore.swift`、`MemoSearchQuery.swift`、`ContentView.swift` 和 `SomeTests.swift`。

## 2026-06-23T00:30:00Z

- 进入阶段 12：图片自由裁剪与授权清理增强。
- 复查 Git 状态、规划文件、全量文件清单、图片编辑 `ImageEditRecipe`、`ImageEditRenderer`、`ImageEditorView`、`MemoStore.addImageEdit` 和相关测试；开工前工作区干净且远端同步。
- GitHub API 复查 `Mantis`、`TOCropViewController`，二者均为 MIT 且适合后续完整裁剪器候选；对象移除/修复类 SwiftUI MIT 搜索返回 0。当前环境缺完整 Xcode/iOS SDK，暂不引入 SPM/ObjC 依赖。
- 扩展 `ImageEditRecipe`，新增向后兼容的 `CropAdjustment` 与 `CleanupPatch`，旧图片编辑 JSON 缺少新字段时仍可解码。
- 更新 `ImageEditRenderer`，预设比例裁剪支持中心点和缩放微调，新增基于模糊贴片的授权图片瑕疵清理渲染。
- 更新 `ImageEditorView`，新增裁剪微调控制和最多 6 处授权清理点，保存摘要记录裁剪微调与授权清理数量。
- 补充新字段编解码、旧 JSON 兼容、渲染保存和素材搜索测试。
- 调整 Share Extension 构建策略：扩展 target 使用 `SOME_SHARE_EXTENSION` 编译旗标，`MemoStore.addImageEdit` 仅在主 App 编译，避免分享扩展继续依赖图片渲染器。

## 2026-06-23T00:00:00Z

- 接续用户“下一步”要求，开工前复查 Git 状态、项目文件清单、任务计划和进度日志；确认本地工作树干净且处于 `master...origin/master`。
- 通过 GitHub API 读取最新 CI run `27962981148`，确认 HEAD `5184f50` 在 Build for simulator 阶段失败，测试阶段未运行。
- 按用户要求继续检索阶段 12 图片裁剪开源候选：`Mantis` 与 `TOCropViewController` 均为 MIT 且仍活跃，适合后续自由裁剪集成评估；通用 `SwiftUI image crop editor MIT` 搜索未找到更轻量可直接复制模块。
- 修复 P1 构建阻塞：`SomeShareExtension` 会编译 `MemoStore.swift`，而 `MemoStore.addImageEdit` 引用的 `ImageEditRenderer` 未加入扩展 target；已把 `ImageEditRenderer.swift` 加入 Share Extension Sources。
- 本地验证通过：`git diff --check`、`plutil -lint`、`xmllint --noout`、旧 Swift parser 覆盖 `Memo.swift`、`SharedAttachmentStore.swift`、`ImageEditRenderer.swift` 和 `MemoStore.swift`。

## 2026-06-23T01:10:00Z

- 进入阶段 13：手帐图片素材追加与导出。
- 开工前复查 Git 状态、未提交文件碎片、`ScrapbookEditorView`、`ScrapbookPageLayout`、`MemoStore.updateScrapbookLayout`、素材引用解析和相关测试；发现阶段 13 半成品已在本地出现并收拢。
- GitHub API 检索 `SwiftUI scrapbook collage export image MIT` 与 `iOS collage editor Swift MIT export`，未找到可直接复制进当前 SwiftUI 工程的成熟 MIT 模块；继续复用现有手帐图层 JSON、附件存储和 UIKit 渲染。
- 新增 `ScrapbookRenderer`，支持把手帐图层渲染为 PNG 数据，并预留 PDF 临时导出能力。
- 新增 `AttachmentReferenceResolver`，统一解析 `some-attachment://` 引用，替换 `ContentView` 内部重复 resolver。
- 手帐编辑器新增图片素材选择、添加图片图层和导出 PNG 操作；`MemoStore.exportScrapbookLayout` 可把渲染结果保存为本地图片附件。
- 补充 PNG 渲染和导出附件测试；本地 `git diff --check`、`plutil -lint`、`xmllint --noout`、旧 Swift parser 覆盖新增手帐导出路径。

## 2026-06-23T09:30:00+08:00

- 进入阶段 14：媒体元数据与缩略图缓存。
- 开工前复查 Git 状态、最近提交、规划文件、全量文件清单和媒体预览相关源码；确认阶段 13 已通过 `a679ca8` / `6cd2154` 落地且当前工作树干净。
- 联网检索 `SwiftUI video thumbnail cache MIT`、`AVAssetImageGenerator thumbnail cache Swift`、`Swift media metadata AVAsset MIT iOS` 等关键词，精确查询均未找到可直接复用的成熟 SwiftUI/MIT 模块。
- 放宽检索后找到 `HHK1/PryntTrimmerView`、`luispadron/LPThumbnailView`、`krad/memento` 等可参考项目；它们偏视频裁剪、旧 UIKit 预览或独立 CLI/示例，不适合直接复制进当前本地附件索引链路。
- 已新增 `MediaMetadataExtractor`，本机读取图片尺寸、音视频时长/分辨率和文件大小摘要。
- 已升级 `VideoThumbnailGenerator`，视频缩略图会写入 App Group 本地 `ThumbnailCache`，缓存 key 绑定文件路径、大小、修改时间、取帧时间和目标尺寸。
- 详情附件区和素材库视频/媒体条目已展示媒体摘要；补充时长格式、图片元数据、缓存 key 失效和缓存删除测试。
- 本轮 `git diff --check`、`plutil -lint`、`xmllint --noout`、旧 Swift parser 主 App 路径与 `SOME_SHARE_EXTENSION` 路径均通过。

## 2026-06-23T10:15:00+08:00

- 进入阶段 15：网页摘录正文清洗与摘录卡。
- 开工前复查 Git 状态、网页摘录保存格式、`LinkExtractor`、`QuickCaptureView` 抓取链路、`webClip` 素材索引和现有测试。
- GitHub API 复查 `scinfu/SwiftSoup` 与 `exyte/ReadabilityKit`；SwiftSoup 为 MIT 且活跃，ReadabilityKit 为 MIT 但已归档。
- 检索 `Swift readability html article extractor MIT` 与 `SwiftSoup readability article extractor` 未找到更适合直接复制的 Swift 项目；当前环境也无法可靠做 Xcode 16/SPM 验证。本轮先扩展本地 HTML 清洗和摘录卡格式，不新增依赖。
- 新增 `WebClipExtractor`，把 HTML 清洗、正文段落抽取、噪音过滤、实体解码和段落评分从 `QuickCaptureView` 中拆到可测试工具层。
- `LinkExtractor.webClipText` 新增来源与摘录卡行；旧网页摘录解析仍按原 marker/摘要/重点兼容。
- 补充正文清洗、去重、噪音过滤、摘要回退和摘录卡格式单元测试。

## 2026-06-23T11:15:00+08:00

- 接续用户要求持续主动推进，开工前复查 Git 状态、全量文件清单、规划文件、阶段 14/15 相关源码和最新 GitHub Actions 状态。
- GitHub Actions run `27971176783` 构建通过但测试失败；公开 annotation 显示失败集中在视频附件素材、手帐导出附件引用、图片编辑渲染和媒体元数据测试。
- GitHub job logs 下载需要仓库管理员权限返回 403；已改用 check-run annotations 和本地代码审计定位。
- 补充检索 `SwiftUI notes app attachments tags MIT iOS`、`AVAssetImageGenerator thumbnail cache Swift MIT`，均未找到可直接复制候选；继续小范围修本项目实现。
- 修复视频缩略图缺失文件边界：`VideoThumbnailGenerator.image` 在进入 AVFoundation 前先确认文件存在，避免不存在 URL 触发不稳定取帧。
- 修复媒体元数据 byteCount 兜底：`MediaMetadataExtractor` 在 `resourceValues.fileSize` 为空时使用 `FileManager.attributesOfItem`。
- 修复 CI 脆弱测试：视频素材测试改用真实 `SharedAttachmentStore.save` 文件；图片元数据测试固定 renderer scale=1；图片编辑渲染断言改为不依赖模拟器默认 scale；缩略图缓存 key 测试移除不必要的 `sleep(1)`。

## 2026-06-23T11:45:00+08:00

- 进入阶段 16：网页摘录片段选择与截图/OCR 合并。
- 开工前复查 Git 状态、OCR 文本生成、网页摘录格式、素材索引、搜索筛选和相关测试；确认当前工作树干净且本地与 `origin/master` 同步。
- GitHub API 检索 `SwiftUI text highlight selection annotation MIT`、`iOS OCR text selection Vision Swift MIT`、`SwiftUI web clip article highlight MIT`、`VisionKit document scanner SwiftUI MIT` 等关键词，未找到可直接复制的成熟 SwiftUI/MIT 模块。
- 决策：先做项目内可迁移的“摘录片段”结构层，把网页重点和 OCR 行统一成候选片段；后续 UI 勾选与截图/OCR 合并可以直接复用，不先大改交互。
- 新增 `ClipFragment` / `ClipFragmentExtractor`，可从网页摘录和 OCR memo 中抽取统一片段，并生成“摘录片段”合并文本。
- `QuickCaptureView` 的网页摘录保存前新增片段选择卡；网页摘要/重点和当前草稿里的 OCR 行会合并为可勾选候选，保存时只写选中片段。
- `ImageTextRecognizer` 新增 `extractedHighlights`，为 OCR 摘录片段和后续截图/OCR 合并复用去重行提取。
- 复查阶段 16 提交时发现标准 OCR memo 会被空行切块影响，已改为按“图片文字/截图文字”标题扫描完整 OCR 块，并补充多截图 OCR 块单元测试。

## 2026-06-23T12:20:00+08:00

- 进入阶段 17：远端 CI 复验与剩余失败修复。
- 会话恢复报告显示上轮已完成 commit/push 并停在查询 GitHub Actions；本轮重新读取规划文件、`findings.md`、`verification.md` 和 Git 状态。
- 当前 `master` 与 `origin/master` 同步到 `14201345c80e4646a6a35fd89164cf8e0b278a2c`；工作树中存在两个上一轮遗留的正向修复碎片：`ClipFragmentExtractor` 对 OCR block 按标题行分段，`SomeTests` 增加多 OCR block 跨空行测试。
- 已按“不回滚其他窗口改动”的原则把这些碎片纳入当前阶段验证范围，再继续查询最新提交对应的远端 CI。
- GitHub Actions run `27972559437` 公开 annotation 显示 `ClipFragmentExtractor.swift:96` 因 `SharedAttachment` 无 `map` 成员导致 Build for simulator 失败；已在后续提交中改为显式 `attachmentURI(for:)`，run `27972990477` / `27973215557` 的 Build for simulator 均已通过并进入 Run tests。
- 审查最新片段保存逻辑时发现混源问题：选中 OCR 片段会被写成网页 highlights。已新增 `SelectedWebClipContent`，网页 memo 只保存选中的网页摘要/重点，网页+OCR 选中片段另写入“摘录片段”合并块，保证 UI 勾选语义与保存结果一致。

## 2026-06-23T12:45:00+08:00

- 进入阶段 18：穿着记录、成本/次与衣橱洞察增强。
- 收拢并补全并行窗口留下的衣橱数据层碎片：新增 `wearLog` 素材类型、`addWearLog` 结构化保存、`has:wear-log` 搜索筛选、`wardrobeDay` 日期格式和衣橱洞察中的穿着次数、最近穿着、价格解析与成本/次。
- 修复衣橱洞察回归风险：没有穿着记录时，常用单品仍按历史穿搭次数显示；有穿着记录时再显示真实穿着次数、最近穿着和成本/次。
- 衣橱页已补穿着记录表单、单品价格字段、穿着统计 badge、最近穿着和成本/次展示，并把穿着记录纳入衣橱素材列表。
- 本轮新增测试覆盖：穿着记录 memo/素材生成、`has:wear-log` 查询、穿着次数/成本/次/最近穿着洞察，以及网页/OCR 片段保存时 OCR 不混入网页 highlights。
- 已提交并推送 `9eb65bf Add wear logs and preserve selected clip sources`；推送后 GitHub 公共 API 返回 rate limit，暂时无法读取新 CI run 详情，下一步继续低频查询远端状态。

## 2026-06-23T13:20:00+08:00

- 进入阶段 19：图片背景画布与轻量抠图底座。
- 开工前复查 Git 状态、任务计划、图片编辑模型/渲染器/UI、`MemoStore.addImageEdit` 和相关测试；确认阶段 18 已通过 `9eb65bf` 落地，随后文档提交 `8af1423` 推送到远端。
- GitHub 公共 API 仍返回 rate limit，阶段 17 远端 CI 暂不能读取最新 run 详情；本轮不空等，先推进本地 P1 缺口。
- 检索 Vision 背景移除、前景分割和 SwiftUI background remover 候选，未找到可直接复制进当前 iOS 16 SwiftUI 工程的成熟 MIT 模块；决定继续复用本项目 Core Image/UIKit 图片渲染管线。
- 已扩展 `ImageEditRecipe`，新增向后兼容的背景模式：原背景、柔化背景、纯色背景，并记录背景色、柔化半径、留白和圆角。
- 已更新 `ImageEditRenderer`，在裁剪后、滤镜前应用背景画布，支持柔化背景和纯色画布输出，并把背景处理写入输出文件名。
- 已更新 `ImageEditorView`，新增背景控制区、模式切换、色板、柔化强度、留白和圆角控制。
- 已更新 `MemoStore.addImageEdit` 和测试，保存正文会记录背景处理，测试覆盖背景配方编解码、旧 JSON 兼容、背景画布渲染和文件名。

## 2026-06-23T13:50:00+08:00

- 进入阶段 20：衣橱洗护状态与旅行打包。
- 阶段开始前复查衣橱素材模型、搜索筛选、结构化保存、衣橱页和测试；确认本轮可继续复用 `MemoAsset`，不需要数据库迁移。
- 检索 SwiftUI 衣橱洗护、旅行打包、capsule wardrobe packing list 等候选，未找到可直接复制的成熟 Swift/iOS MIT 模块；本轮继续自建轻量结构化记录。
- 新增 `laundryLog` 与 `packingList` 素材类型、`has:laundry-log` / `has:packing-list` 搜索筛选、`addLaundryLog` 和 `addPackingList` 结构化保存。
- 衣橱页新增洗护状态表单、旅行打包表单、洗护/打包统计 badge，并把洗护和打包记录纳入衣橱素材列表。
- 补充结构化保存和搜索测试，覆盖洗护记录、旅行打包清单和内容筛选。

## 2026-06-23T14:35:00+08:00

- 接续用户“不要停下，持续主动推进”的要求，重新复查 Git 状态、任务计划、发现记录、进度日志、全量文件清单和最新 GitHub Actions 状态；开工前本地 `master...origin/master` 且工作树干净。
- GitHub Actions run `27975351182` 已从 in_progress 变成 failure；Build for simulator 成功，Run tests 失败。公开 annotation 未暴露具体 XCTest 断言失败，显示 `appintentsnltrainingprocessor` 无法解析 `extract.actionsdata`，本轮按 CI 工具链问题处理。
- 为阶段 17 增加 CI 兜底：`xcodebuild test` 传入 `CI_DISABLE_APP_INTENTS`，并通过 `EXCLUDED_SOURCE_FILE_NAMES` 排除 `SaveMemoIntent.swift` / `SomeAppShortcuts.swift`；`SomeApp` 初始化对该 flag 做条件保护，正式 App build 不关闭 App Intents。
- 进入阶段 21：手帐字体/贴纸/花边可编辑增强。开工前读取 `ScrapbookEditorView`、`ScrapbookRenderer`、`ScrapbookPageLayout` / `ScrapbookLayer`、手帐列表缩略图和相关测试。
- 按用户要求继续联网检索 `SwiftUI scrapbook sticker font border MIT`、`iOS collage editor stickers fonts Swift MIT`、`Swift sticker view font border editor MIT`、`IRSticker Swift MIT`、`SwiftStickerView iOS MIT` 等候选；未找到适合直接复制的成熟 SwiftUI/MIT 模块，继续复用 some 现有图层 JSON。
- 新增 `ScrapbookStyleCatalog`，集中管理简约小清新画布色、文字色、填充色、边框色、字体预设、贴纸预设和花边预设，并支持中文自然输入如“圆体”“纸本”“胶片”的匹配。
- 手帐编辑器新增可换行工具栏、花边图层按钮、画布底色色板、字体预设、贴纸预设、花边预设、文字/底色/边框色板、字号/圆角/线宽滑块；列表缩略图和 PNG renderer 同步使用同一套字体风格。
- 默认手帐创建入口也复用样式目录，`font` / `border` / `decorations` 不再只是正文字段，会实际影响初始图层样式。
- 新增测试覆盖手帐样式目录、预设应用、默认手帐胶片框匹配和带样式图层 PNG 渲染。

## 2026-06-23T15:20:00+08:00

- 继续阶段 17：远端 CI 复验与剩余失败修复；开工前复查 Git 状态、CI workflow、规划/发现/验证记录和 AppIntents 相关引用。
- GitHub Actions run `27976760975` 显示 Build for simulator 通过，但 Run tests 仍失败；公开 annotation 继续出现 `appintentsmetadataprocessor` / `appintentsnltrainingprocessor`，且提示测试构建没有 AppIntents.framework dependency，说明上一轮只排除测试源码仍不足。
- 重新分析 CI 步骤后定位新的高概率原因：正常 Build for simulator 阶段会先生成 App Intents 派生元数据，Run tests 阶段虽然排除 AppIntents 源，但仍可能复用同一默认 DerivedData 中的 `extract.actionsdata`。
- 已更新 iOS CI：正常模拟器 build 使用 `${RUNNER_TEMP}/DerivedData-build`，继续验证正式 App + 快捷指令编译；测试阶段使用 `${RUNNER_TEMP}/DerivedData-test` 并执行 `clean test`，同时保留 `CI_DISABLE_APP_INTENTS` / `EXCLUDED_SOURCE_FILE_NAMES`，避免复用正式构建的 AppIntents 派生数据。
