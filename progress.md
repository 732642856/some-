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
- 在等待 run `27977929014` 时继续处理下一个高优先级警告：`QuickAudioRecorder` 是 `@MainActor` 对象，但 `AVAudioRecorderDelegate` 要求非隔离回调；已把 `audioRecorderEncodeErrorDidOccur` 标记为 `nonisolated`，并在回调中切回 `MainActor` 停止录音，提前消除 Swift 6 编译风险。

## 2026-06-23T15:45:00+08:00

- 进入阶段 22：手帐 PDF 分享/导出入口。开工前复查 README、开源审计、当前缺口、手帐 renderer、编辑器导出入口、`MemoStore.exportScrapbookLayout` 和相关测试。
- 检索 `SwiftUI PDF export share MIT iOS` 未找到可直接复制的成熟项目；本轮继续复用 Apple `UIGraphicsPDFRenderer` 和 some 现有附件存储、备份、素材索引。
- 已把 `ScrapbookRenderer` 的 PDF 能力整理为 `pdfData` / `data(layout:format:)`，PNG 和 PDF 共用统一文件名与导出数据入口。
- `MemoStore.exportScrapbookLayout` 支持 `format: .png/.pdf`，PDF 作为 `UTType.pdf` 本地附件保存，并在手帐 memo 中追加“导出PDF”引用，备份和素材库可继续追踪。
- 手帐编辑器新增 PDF 导出按钮；补充 PDF 数据头、PDF 附件保存、PDF 引用写回和素材索引测试。

## 2026-06-23T16:30:00+08:00

- 进入阶段 23：衣橱天气推荐、自动打包建议与洗护提醒。开工前复查 Git 状态、规划文件、`WardrobeInsightEngine`、衣橱 UI、结构化保存和衣橱相关测试；本地未发现未跟踪文件碎片。
- 按用户要求继续全网/GitHub 检索衣橱、穿搭、打包清单和洗护提醒 Swift/iOS/MIT 候选；`wardrobe outfit planner MIT`、`virtual closet swift MIT`、`outfit planner swift MIT`、`packing list swiftui MIT`、`laundry reminder swift MIT` 均未找到可直接复制的成熟模块。
- 已扩展 `WardrobeInsightEngine`，解析洗护记录为 `WardrobeLaundryLogInsight`，生成 `WardrobeCareReminder` 和 `WardrobePackingSuggestion`，并在天气穿搭/场景/季节/打包建议中避开待清洗、送洗、待熨烫和待修补单品。
- 衣橱洞察 UI 新增提醒数量、洗护提醒和打包建议；穿搭建议仍填入穿搭草稿，打包建议可一键填入旅行打包表单。
- 新增测试覆盖：最近天气生成天气穿搭、待洗/送洗单品不进入推荐、洗护提醒带备注、打包建议复用可用单品且避开不可用单品。

## 2026-06-23T17:05:00+08:00

- 进入阶段 24：图片编辑版式模板与导出预设。开工前复查图片编辑配方、渲染器、编辑器、保存正文和测试边界。
- 尝试联网检索 Swift/iOS 照片拼贴、照片布局、SwiftUI 图片编辑拼贴 MIT 候选时审批服务 503 拦截；按安全规则未继续绕路重复同类 API 请求，结合既有多轮审计记录，继续复用项目内图片编辑管线。
- `ImageEditRecipe` 新增向后兼容的 `layoutPreset`，内置“美食留白、手帐贴纸、胶片边框、故事封面”等导出预设，并提供滤镜、比例、背景、边框、默认文字和贴纸位置。
- 图片编辑器新增模板选择，选择模板会自动填入滤镜、裁剪比例、背景、边框、默认文字/贴纸，并把模板写入保存正文与输出文件名。
- 新增测试覆盖模板编码/解码、旧 JSON 兼容、模板默认值、保存正文模板字段和输出文件名。

## 2026-06-23T17:35:00+08:00

- 进入阶段 25：多图拼贴 MVP。开工前复查手帐图层模型、`ScrapbookRenderer`、附件解析、手帐首页和图片编辑缺口；当前工作树干净。
- 决策复用现有手帐画布和 PNG 导出，不重复建立第二套拼贴渲染器；新增 `ScrapbookPageLayout.photoCollageLayout`，支持 2-6 张图片的自适应拼贴网格、标题、贴纸、备注和边框图层。
- `MemoStore.addPhotoCollage` 会把多张图片渲染为 PNG 附件，同时保存可迁移手帐 JSON 和原图附件引用，后续仍可用手帐编辑器继续调整。
- 手帐首页新增多选图片 chip 和“保存拼贴”按钮，最多选择 6 张图片，保存后进入手帐素材列表。
- 新增测试覆盖拼贴布局图层、PNG 附件生成、原图引用保留和 `scrapbookPage` 素材索引。

## 2026-06-23T04:34:31+08:00

- 接续用户“没有需要询问就持续主动推进”的要求，恢复规划文件、Git 状态和全量文件清单；当前 `master...origin/master` 且工作树干净。
- 远端 GitHub Actions 最新状态查询被审批服务 503 拦截并拒绝升级命令；按安全规则不绕路重复同一外部查询，阶段 17 继续等待后续可用查询窗口。
- 补做阶段 26 开工前审计：读取 `MemoAsset`、`ClipFragmentExtractor`、`MemoSearchQuery`、`MemoStore.matchesContentFilter`、素材库 UI、SQLite asset 存储和相关测试。
- 开源对标结论：`usememos/memos` 可继续参考自有数据与 Markdown 记录理念，但 Go/TypeScript 架构不能直接复制进 SwiftUI 本地索引；Simplenote iOS、Joplin、Zettlr 等不适合直接搬源码。本轮继续复用 some 现有素材索引。
- 进入阶段 26：摘录片段素材索引与搜索，目标是把网页/OCR 勾选后保存的“摘录片段”从纯正文升级为可在素材库筛选、可用 `has:clip` / `has:摘录片段` 检索的独立资产。

## 2026-06-23T04:43:13+08:00

- 完成阶段 26：新增 `MemoAssetKind.clipFragment`、素材库“摘录”标签/图标、`ClipFragmentExtractor.assetSummaries`、摘录片段块解析和 `has:clip` / `has:摘录片段` 搜索筛选。
- 修正别名边界：`has:clip`、`has:clips`、`has:摘录` 归入摘录片段，`has:web` / `has:webclip` 继续只代表网页摘录，避免搜索结果混淆。
- 避免分享扩展 target 风险：`ClipFragmentExtractor` 不再依赖 `ImageTextRecognizer`，分享扩展条件编译解析时不需要 Vision OCR 文件。
- 新增测试覆盖：内容筛选解析、`has:clip` 搜索、摘录片段块反解析、摘录片段素材索引和 `has:摘录片段` 中文搜索。
- 本地验证通过：`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、`xmllint --noout some.xcodeproj/xcshareddata/xcschemes/some.xcscheme`、旧 Swift parser 覆盖 `ClipFragmentExtractor.swift` / `LinkExtractor.swift` / `MemoReferenceParser.swift` / `MemoTaskParser.swift` / `SharedAttachmentStore.swift` / `MemoSearchQuery.swift` / `Memo.swift` / `SomeTests.swift`，并用 `-D SOME_SHARE_EXTENSION` 覆盖 `MemoStore.swift` 分享扩展路径。
- 已提交并推送 `99fd00a Add clip fragment asset indexing`，推送后工作树恢复干净。

## 2026-06-23T04:50:00+08:00

- 进入阶段 27：多链接批量网页摘录。继续前复查 Git 状态、计划/发现/进度文件、QuickCapture 链接摘录链路、`MemoStore.addWebClip` 和网页摘录相关测试。
- 当前现状：输入卡片已能识别多个 URL 并显示 `+N`，但摘录按钮只会处理第一个 URL；这会影响用户一次导入多条网址/链接后的整理效率。
- 因同类外部查询刚被审批服务 503 拦截，本轮不重复联网检索，沿用此前 SwiftSoup、ReadabilityKit、usememos 等开源对标结论；实现继续基于项目现有 `RemoteWebClipFetcher`、`LinkExtractor.webClipText`、`ClipFragmentExtractor` 和 `MemoStore`。
- `MemoStore` 新增 `addWebClip(_:, selectedFragments:)`，单链接和批量入口共用同一套结构化网页摘录/摘录片段保存逻辑。
- `QuickCaptureView` 的摘录按钮现在会在多个 URL 时逐条抓取并分别保存网页摘录；单个 URL 仍保留原来的片段勾选确认卡。批量路径只使用网页片段，避免把草稿里同一段 OCR 文本重复写入每个链接。
- 新增测试覆盖：带选中片段的 `ExtractedWebClip` 保存、未选中重点不写入、摘录片段素材索引，以及多个 `ExtractedWebClip` 分别保存为多条网页素材并可用 `has:web` 检索。

## 2026-06-23T04:50:12+08:00

- 完成阶段 27。为避免 Share Extension 再次出现 target 缺源码问题，已把 `ClipFragmentExtractor.swift` 加入 SomeShareExtension Sources；`MemoAsset.assets` 在主 App 和分享扩展路径都能解析摘录片段素材。
- 本地验证通过：`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、`xmllint --noout some.xcodeproj/xcshareddata/xcschemes/some.xcscheme`、旧 Swift parser 覆盖 `WebClipExtractor.swift` / `LinkExtractor.swift` / `ClipFragmentExtractor.swift` / `MemoReferenceParser.swift` / `MemoTaskParser.swift` / `SharedAttachmentStore.swift` / `MemoSearchQuery.swift` / `Memo.swift` / `MemoStore.swift` / `SomeTests.swift`，并用 `-D SOME_SHARE_EXTENSION` 覆盖分享扩展路径。
- 单独解析 `QuickCaptureView.swift` 仍被本机旧 Swift 5.4 parser 的既有 async/await 与新式 `if let` 语法限制阻止，需要 Xcode 16 / GitHub Actions 做完整 typecheck；核心批量保存逻辑已用 Store 层测试覆盖。

## 2026-06-23T05:05:00+08:00

- 用户指出不应停下；已立即继续推进下一阶段。
- 当前工作树干净，远端同步到 `origin/master`。复查缺口后选择阶段 28：工作日志项目/日期/模板增强，原因是用户明确要求工作日志和汇总能力，且该功能可在本地确定性实现。
- 外部检索 `SwiftUI work log daily report app MIT`、`iOS work log daily report Swift MIT`、`SwiftUI project journal daily report MIT`、`Swift daily standup log app MIT` 未发现可直接复制进当前 SwiftUI/iOS 项目的成熟 MIT 模块；继续复用 some 现有结构化 memo、引用和素材索引。
- `MemoStore.addWorkLog` 向后兼容新增 `project`、`dateRange`、`template` 字段，结构化正文会写入“项目 / 日期 / 模板”。
- 工作日志 UI 新增项目、日期范围、模板按钮；日报、周报、项目汇报和复盘模板会切换范围并自动填充空的进展/问题/下一步/备注字段。
- 新增测试覆盖工作日志项目、日期、模板字段写入，以及 `workLog` 素材摘要包含新字段。

## 2026-06-23T13:05:42+08:00

- 完成阶段 28：工作日志 v2 已支持项目、日期范围和常用模板。
- 本地验证通过：`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、`xmllint --noout some.xcodeproj/xcshareddata/xcschemes/some.xcscheme`、旧 Swift parser 覆盖 `DateFormatters.swift` / `LinkExtractor.swift` / `ClipFragmentExtractor.swift` / `MemoReferenceParser.swift` / `MemoTaskParser.swift` / `SharedAttachmentStore.swift` / `MemoSearchQuery.swift` / `Memo.swift` / `MemoStore.swift` / `SomeTests.swift`，并用 `-D SOME_SHARE_EXTENSION` 覆盖分享扩展路径。

## 2026-06-23T13:12:00+08:00

- 进入阶段 29：截图/OCR 区域识别底座。继续前复查 `ImageTextRecognizer`、详情页附件/OCR/转写链路、图片编辑裁切逻辑和 OCR 相关测试。
- 本轮不引入新第三方依赖，复用 Apple Vision 和 UIKit 裁图能力。
- 新增 `ImageTextRegion`，用归一化 x/y/width/height 表示识别区域，支持裁切 rect 计算和区域摘要。
- `ImageTextRecognizer` 新增按区域裁切后识别的入口，并让 OCR memo 可写入“区域：x.. y.. w.. h..”信息；完整框选 UI 留到后续接入。
- 修复 OCR 素材摘要过滤，避免把“区域”元数据和附件引用混进识别正文摘要。
- 新增测试覆盖区域 memo 文本、区域 rect clamp 和区域 OCR 素材摘要。
- 完成阶段 29。本地验证通过：`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、`xmllint --noout some.xcodeproj/xcshareddata/xcschemes/some.xcscheme`、旧 Swift parser 覆盖 `ImageTextRecognizer.swift` / `Memo.swift` / `SharedAttachmentStore.swift` / `AttachmentReferenceResolver.swift` / `LinkExtractor.swift` / `ClipFragmentExtractor.swift` / `MemoReferenceParser.swift` / `MemoTaskParser.swift` / `MemoSearchQuery.swift` / `SomeTests.swift`，并用 `-D SOME_SHARE_EXTENSION` 覆盖分享扩展路径。

## 2026-06-23T13:24:00+08:00

- 继续阶段 17 远端 CI 复验：最新 GitHub Actions run `28003903915` 对应 HEAD `af34dd7`，Build for simulator 已通过，Run tests 仍在进行中；等待期间不空转，推进当前 findings 第一项本地缺口。
- 进入阶段 30：媒体缩略图缓存维护。复查 `VideoThumbnailGenerator`、`MediaMetadataExtractor`、附件预览列表和视频缩略图测试后确认当前只有单视频按需生成与单项删除，缺批量预热和孤儿缓存清理工具层。
- `VideoThumbnailGenerator` 新增 `CacheMaintenanceResult`、`preheatCache(for:)` 和 `pruneCache(keeping:)`，支持去重预热视频缩略图缓存，并清理不在保留集合里的 `.jpg` 缓存文件。
- 新增测试覆盖缺失视频预热失败统计、重复 URL 去重，以及 prune 保留目标缓存、删除孤儿缓存的行为。
- 完成阶段 30。本地验证通过：`git diff --check`、旧 Swift parser 覆盖 `VideoThumbnailGenerator.swift` / `SharedMemoStorage.swift` / `SomeTests.swift`。

## 2026-06-23T13:38:00+08:00

- 进入阶段 31：截图/OCR 框选 UI。开工前复查 Git 状态、OCR 底座、详情页附件/OCR/转写链路、图片附件展示和素材索引；工作区包含阶段 30 正向缓存维护碎片，继续保留并整合，不回滚。
- 按用户要求补做开源检索：`SwiftUI image cropper MIT OCR selection` 未找到可直接复制模块；`benedom/SwiftyCrop` 为 MIT/SwiftUI/近期活跃，`guoyingtao/Mantis` 为 MIT/Swift/成熟裁剪库，但本阶段只需 OCR 区域矩形框，引入完整裁剪依赖会扩大工程风险。
- `MemoDetailView` 图片附件区域新增“框选识别”入口，打开 `ImageTextRegionPickerView` 后可在图片上拖动选择区域、拖动右下角调整大小，并用当前浅粉/雾蓝风格展示遮罩和选区。
- 区域 OCR 结果会追加回当前 memo；`ImageTextRecognizer.memoText` 新增 `includesAttachmentReference`，追加模式不重复写入同一附件引用。
- 修复 `MemoAsset.imageTextAsset`，让普通图片记录后续追加“图片文字”段落时也能进入 `screenshot` 素材索引并支持 `has:ocr` 搜索。
- 新增测试覆盖可追加区域 OCR 文本、追加后只保留一个附件引用、追加 OCR 后生成 `screenshot` 素材并能用 `has:ocr` 搜索。

## 2026-06-23T13:49:00+08:00

- 进入阶段 32：衣橱洗护本地通知。开工前复查 `ReminderManager`、衣橱洞察 UI、`WardrobeCareReminder` 和洗护提醒测试。
- 按用户要求检索开源候选：`SwiftUI local notification reminder MIT` GitHub 搜索返回 0 个匹配仓库；本轮继续复用项目已有 `ReminderManager` 和 Apple UserNotifications。
- `ReminderManager` 新增洗护提醒状态、稳定通知 identifier、单个 `WardrobeCareReminder` 的本地通知安排/取消入口，复用每日回顾提醒的通知授权流程。
- 衣橱洞察里的洗护提醒从纯文字条升级为可操作列表，可一键为待清洗/送洗/待熨烫/待修补单品安排系统通知。
- 新增测试覆盖洗护提醒通知 identifier 的稳定性。
- 完成阶段 32。补充联网检索确认：`flomo alternative notes license:mit` 未返回可直接复用仓库；`ios swiftui notes app license:mit` 返回 `XunMengWinter/PetNote-oss`、`0si43/PiecesOfPaper` 等 MIT 参考，但业务域与当前素材库/衣橱/图片编辑链路不同；`ios local notification reminder swift license:mit` 返回 `lukeleleh/reminders-app` 等示例，当前实现继续复用项目已有 `ReminderManager`，避免引入 TCA 或示例工程结构。

## 2026-06-23T14:18:00+08:00

- 进入并完成阶段 33：图片编辑人物抠图入口。开工前复查 `ImageEditRecipe`、`ImageEditRenderer`、`ImageEditorView` 和图片编辑测试，发现底层人物抠图已有碎片但 UI 未暴露给用户。
- `ImageEditRecipe` 新增 `subjectExtraction` 配方字段，旧 JSON 会默认解码为关闭状态；摘要会记录“人物抠图”。
- `ImageEditRenderer` 复用 Apple Vision `VNGeneratePersonSegmentationRequest` 生成单人分割 mask，并在导出文件名中追加 `subject` 标记。
- `ImageEditorView` 新增“主体”分段控件，用户可直接选择“无/人物抠图”，预览会跟随刷新。
- 新增测试覆盖人物抠图配方编码/解码、旧配方兼容、摘要和导出文件名。
- 继续修复阶段 17 CI：Run tests 步骤会在测试工作区临时移除 App target 对 `SomeShareExtension` 的嵌入和依赖，保留前置 Build for simulator 对正式 app/extension 的完整构建，降低 XCTest 被 App Intents 元数据处理器误伤的概率。

## 2026-06-23T15:20:00+08:00

- 加载并确认 Superpowers 插件：本地 `superpowers@openai-curated` 已启用，已读取 `using-superpowers`、`test-driven-development` 和 `verification-before-completion`。
- 进入阶段 34：图片编辑智能主体抠图。开工前复查 Git 状态、图片编辑模型/渲染器/UI、测试和当前缺口；最新 CI run `28005117586` 对应 `262d016`，状态仍为 in_progress。
- 按用户要求联网检索 `VNGenerateForegroundInstanceMaskRequest Swift MIT`、`iOS object cutout Vision Swift MIT`，均未找到可直接复制的 Swift/MIT 实现；继续复用 Apple Vision。
- Apple 官方文档显示 `VNGenerateForegroundInstanceMaskRequest` / `VNInstanceMaskObservation` 为 iOS 17+，`VNInstanceMaskObservation` 可生成所有前景实例的 masked image；当前阶段以 iOS 17 渐进增强方式接入，iOS 16 或识别失败时安全回退原图。
- 按 Superpowers/TDD 写入对象主体测试后再实现：`ImageEditRecipe.SubjectExtraction.Mode.object`、摘要“智能主体”、输出文件名 `subject`、图片编辑保存正文“主体：智能主体”。
- 完成阶段 34。本地验证通过：`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、`xmllint --noout some.xcodeproj/xcshareddata/xcschemes/some.xcscheme`、`.github/workflows/ios-ci.yml` YAML 解析、旧 Swift parser 覆盖 `Memo.swift` / `ImageEditRenderer.swift` / `ImageEditorView.swift` / `SomeTests.swift`。

## 2026-06-23T15:24:03+08:00

- 回到阶段 17：远端 CI 复验与剩余失败修复。最新 GitHub Actions run `28009254154` 对应 `82ccb67`，Build and test 仍在 Run tests。
- 开工前复查 Git 状态，发现 `SomeTests/SomeTests.swift` 与 `WardrobeInsightEngine.swift` 已有未提交正向碎片；已逐行读取并保留，不回滚其他窗口可能留下的修复。
- 整合测试兼容性修复：内容筛选断言改为集合比较，避免 `Set` 去重排序实现变动造成测试误报；音频/视频断言改为 UTType conform 检查，兼容系统返回的等价媒体类型；视频缓存 key 测试改为通过取帧时间验证 key 变化，避免依赖临时文件修改时间精度。
- 收窄 `MemoBackupPackage` 的 actor 隔离边界：只把真正触碰 `MemoStore` 的导入/导出方法标记为 `@MainActor`，让 `fileExtension` 保持普通静态常量，避免文档类型静态声明等非隔离上下文触发 Swift 并发隔离报错。
- 衣橱天气洞察改为保留“天气”原始字段，避免 `多云，午后阵雨 22C` 被通用字段拆分逻辑切碎；新增回归测试覆盖天气穿搭、打包建议和说明文案保留完整天气短语。
- 本地验证通过：`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、旧 Swift parser 覆盖 `MemoSearchQuery.swift` / `VideoThumbnailGenerator.swift` / `WardrobeInsightEngine.swift` / `SomeTests.swift`。

## 2026-06-23T15:59:47+08:00

- 继续阶段 17。GitHub Actions run `28010154822` 对应 `8f4d241`，Run tests 失败；annotation 只暴露 `XCTAssertEqual failed: ("false") is not equal to ("true")`，未给具体测试名。
- 按 Superpowers 系统化调试缩小范围：枚举旧提交内所有会产生布尔 `XCTAssertEqual` 的断言，定位最可能失败点为手帐 PNG/PDF 导出附件素材断言。
- 根因：导出标题包含中文时，`SharedAttachment.referenceLine` / `MemoAsset.uri` 会 percent-encode 附件路径；旧断言用 raw `attachment.relativePath` 去 `contains` 编码后的 URI，CI 上稳定得到 `false`。
- 修复断言为按 `attachment.referenceURI` 精确匹配导出附件素材，再检查素材类型；同时保留并整合素材库视频缩略图生命周期改动：`VideoThumbnailGenerator.sourceURLs(in:)` 从素材索引提取、去重、限制视频 URL，素材库出现或变化时后台预热并清理缩略图缓存。

## 2026-06-23T15:43:00+08:00

- 继续阶段 17：GitHub Actions run `28010154822` 的 Build for simulator 已通过，Run tests 失败摘要只剩 `XCTAssertEqual failed: ("false") is not equal to ("true")`，不再是 AppIntents 或测试编译错误。
- 按系统化调试复查失败候选后，修正手帐 PDF 导出附件测试的类型判断：不再要求 `UTType.pdf.identifier` 精确字符串，而是使用 `UTType(...).conforms(to: .pdf)`，兼容不同系统返回的等价 PDF 类型标识；同时给手帐导出附件资产断言补充失败上下文。
- 纳入视频缩略图缓存维护碎片：`VideoThumbnailGenerator.sourceURLs(in:)` 从素材索引中提取、去重并限制视频源；素材库页进入/素材变化时会预热视频缩略图并清理孤儿缓存。
- 本地验证通过：`git diff --check`、`.github/workflows/ios-ci.yml` YAML 解析、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、旧 Swift parser 覆盖 `SharedAttachmentStore.swift` / `AttachmentReferenceResolver.swift` / `VideoThumbnailGenerator.swift` / `ContentView.swift` / `SomeTests.swift`。

## 2026-06-23T16:10:00+08:00

- 完成阶段 17：GitHub Actions run `28011472819` 对应 `3951815` 已通过 Build and test，远端 Xcode 16.4 完整构建和 XCTest 恢复绿色。
- 继续处理 CI 警告：GitHub Actions 仍提示 `actions/checkout@v4` 运行在 Node 20 deprecation 路径；检索官方 `actions/checkout` release，v5 已升级 Node 24，且 GitHub-hosted `macos-15` runner 满足兼容方向。
- `.github/workflows/ios-ci.yml` 升级 `actions/checkout@v5`，用于消除 Node 20 deprecation 警告。

## 2026-06-23T16:18:00+08:00

- 继续主动推进衣橱体验：发现 `SomeTests.swift` 有未提交的衣橱材质/厚薄/旅行天数测试碎片，已保留并补齐生产实现。
- `MemoStore.addWardrobeItem` 支持写入“材质”“厚薄”，`addPackingList` 支持写入“天数”；旧调用保持默认参数向后兼容。
- `WardrobeInsightEngine` 解析衣橱材质和厚薄；炎热/晴天的天气穿搭与打包建议会提高轻薄、棉麻等透气材质单品权重，并在打包说明中提示“优先轻薄、透气材质”。
- 本地验证通过：`git diff --check`、`.github/workflows/ios-ci.yml` YAML 解析、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、旧 Swift parser 覆盖 `MemoStore.swift` / `WardrobeInsightEngine.swift` / `SomeTests.swift`。

## 2026-06-23T16:22:00+08:00

- 补齐衣橱增强的 UI 入口：衣橱单品表单新增“材质”“厚薄”，打包清单表单新增“天数”。
- 保存后会把这些字段传入已实现的结构化存储与洞察逻辑，并清空表单状态。
- 本地验证通过：`git diff --check`、`.github/workflows/ios-ci.yml` YAML 解析、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、`xmllint --noout some.xcodeproj/xcshareddata/xcschemes/some.xcscheme`。
- 本机只有 CommandLineTools，无法运行 Xcode 模拟器 XCTest；旧 Swift parser 检查 `ContentView.swift` 时仍卡在既有 `await reminders.scheduleWardrobeCareReminder(...)`，不是本次 UI 字段改动新增的问题，完整编译继续依赖远端 GitHub Actions。

## 2026-06-23T16:42:00+08:00

- 进入并完成阶段 36：可用性收口。开工前复查 Git 状态、`SomeApp.onOpenURL`、`Info.plist`、`MemoStore.addMemo(from:)`、搜索状态、工作日志来源筛选、衣橱打包建议和相关测试；发现 `SomeTests.swift` 有未提交正向回归测试碎片，已保留并继续整合。
- 按用户要求检索 `SwiftUI onOpenURL custom URL scheme quick note app GitHub MIT`、`iOS notes app URL scheme add note open source MIT SwiftUI`、`MoeMemos iOS URL scheme shortcuts save memo GitHub`；未找到可直接复制进当前 SwiftUI/本地 SQLite 架构的许可清晰实现。本轮继续复用 Apple `onOpenURL` 与项目已有 URL Scheme。
- `MemoStore` 新增可测试的 `handleURL(_:)` 路由：`some://add?text=...` / `some://new?text=...` / `some://memo?text=...` / `some://capture?text=...` 保存新记录，`some://search?q=...` / `some://find?q=...` 打开时间线搜索，并保留旧版未知 host 写入行为。
- 同步收束此前其他窗口留下的正向碎片：`WorkLogSourceFilterEngine.swift` 已被工程文件引用但未进入 Git 跟踪，本轮确认逻辑并纳入提交，避免远端 CI 因缺文件失败；工作日志页新增来源标签、素材类型、时间和关键词筛选。
- 衣橱打包建议会解析最近打包清单的“天数”，按行程天数扩展上装、下装、鞋履和包包数量，并在说明中写明“按 N 天行程”。
- 新增测试覆盖 URL Scheme 保存、搜索不创建记录、空内容和非 `some` scheme 忽略；README 同步补充 `some://search?q=...` 用法。
- 本地验证通过：`git diff --check`、衣橱打包临时探针 red/green、`xcrun swiftc -parse some/Utilities/WorkLogSourceFilterEngine.swift some/Utilities/WardrobeInsightEngine.swift some/Stores/MemoStore.swift SomeTests/SomeTests.swift`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`。

## 2026-06-23T16:58:00+08:00

- 继续可用性收口，优先处理首次打开体验。开工前复查全量文件、最新提交和 GitHub Actions；#91 仍在运行，#90 已通过。
- 按用户要求检索 `SwiftUI notes app onboarding empty state open source MIT GitHub`、`SwiftUI privacy permissions onboarding notes app MIT GitHub`、`Flomo alternative open source iOS SwiftUI onboarding notes MIT`；本轮不引入通用 onboarding/permission 依赖，先复用现有快速输入和空状态组件。
- `MemoStore` 新增 `timelineEmptyState`，首次无记录时提示“写文字、贴链接、导入图片/录音/文件；内容默认只保存在本机”，搜索或筛选无结果时保留“换个关键词/清除筛选”的恢复提示。
- `ContentView` 的时间线和归档列表改为传入完整空状态文案，避免所有空列表都只显示同一标题。
- 新增测试覆盖首次打开空状态和搜索无结果空状态。本地验证通过：`git diff --check`、`xcrun swiftc -parse some/Stores/MemoStore.swift SomeTests/SomeTests.swift`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`。本机缺 iPhone simulator SDK，`ContentView.swift` parse 仍被既有 `await` 语法误判挡住，完整类型检查继续依赖 GitHub Actions。

## 2026-06-23T17:18:00+08:00

- 进入并完成阶段 37：图片编辑手势裁剪状态统一。开工前复查最新提交、任务计划、图片编辑模型/渲染器/UI/测试和当前缺口，发现图片编辑已有手势画布，但拖拽/捏合边界仍分散在 UI 与 renderer 内。
- 按用户要求重新对标图片裁剪开源候选：`Mantis`、`SwiftyCrop`、`TOCropViewController` 仍可作为成熟参考；当前未复制源码，因为 some 已有 `ImageEditRecipe` 持久配方和自建渲染管线，引入新包会增加 Xcode/SPM/桥接和状态同步成本。
- 按 TDD 补 `testImageEditCropAdjustmentAppliesGestureChangesWithinBounds`，随后在 `ImageEditRecipe.CropAdjustment` 中加入 `minimumScale` / `maximumScale`、`clamped()`、`applyingDrag(...)` 和 `applyingMagnification(...)`。
- `ImageCropSelectionCanvas` 的拖拽、捏合和画框计算改为复用同一套 `CropAdjustment` 方法；`ImageEditRenderer` 的导出裁剪也改为使用 `adjustment.clamped()`，避免预览与导出上下限不一致。
- 本地验证通过：`xcrun swiftc -parse some/Models/Memo.swift some/Utilities/ImageEditRenderer.swift some/Views/ImageEditorView.swift SomeTests/SomeTests.swift`、`git diff --check`。

## 2026-06-23T17:28:00+08:00

- 进入并完成阶段 38：工作日志 Markdown 导出与分享入口。开工前发现并行窗口留下 `WorkLogExporter`、日志页导出按钮和 `ExportedDocument` 可见性调整碎片；已逐项阅读后保留并继续验证，不回滚。
- `WorkLogExporter.markdown(memos:assets:)` 会从工作日志素材中筛出未归档记录，按创建时间倒序输出 Markdown，包含范围、项目、日期、模板和原始日志正文；空结果返回“共 0 条日志”。
- `WorkLogView` 在工作日志列表标题栏加入分享图标按钮，只导出当前项目/模板/日期筛选后的日志；复用设置页已有导出目录和系统分享表。
- `SettingsView` 中 `ExportedDocument` 与 `ShareSheet` 从 private 调整为模块内可见，供工作日志页复用，不改变公共数据结构。
- 本地验证通过：`xcrun swiftc -parse some/Models/Memo.swift some/Utilities/DateFormatters.swift some/Utilities/WorkLogSourceFilterEngine.swift some/Utilities/ImageEditRenderer.swift some/Views/ImageEditorView.swift SomeTests/SomeTests.swift`、`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`。裸全量 `swiftc -parse` 仍会因既有 Swift concurrency/async 项目编译设置误判 `await`，不是本轮新增问题；完整 XCTest 仍需远端 Xcode CI。

## 2026-06-23T17:06:00+08:00

- 修复 #92 远端 CI：Run tests 阶段失败，annotation 明确显示 `SomeTests.swift` 找不到 `WorkLogExporter`，根因为工作日志导出测试已进入提交但生产实现未同步进入远端。
- 收束本地正向碎片：`WorkLogExporter` 进入 `WorkLogSourceFilterEngine.swift`，支持按工作日志素材排序导出 Markdown；工作日志页新增导出当前筛选结果按钮，并复用 `ShareSheet` / `ExportedDocument`。
- 图片编辑裁剪手势碎片同步纳入：`ImageEditRecipe.CropAdjustment` 统一处理拖拽、缩放和边界夹取，渲染器与裁剪画布共用同一套夹取规则；新增测试覆盖拖拽/缩放边界。
- 本地验证通过：`git diff --check`、`xcrun swiftc -parse some/Models/Memo.swift some/Utilities/ImageEditRenderer.swift some/Utilities/WorkLogSourceFilterEngine.swift some/Views/ImageEditorView.swift SomeTests/SomeTests.swift`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`。本机旧 Swift parser 单独解析 `ContentView.swift` / `SettingsView.swift` 时仍被既有 async/await 与 `if let` shorthand 语法挡住，完整构建继续以 GitHub Actions 的 Xcode 16.4 为准。

## 2026-06-23T17:18:00+08:00

- 进入并完成阶段 39：衣橱打包建议优先使用最近行程目的地与天气。开工前复查 Git 状态、CI run、衣橱引擎、衣橱 UI、打包清单测试和当前缺口。
- 按用户要求检索 `SwiftUI weather outfit recommendation MIT iOS`、`Swift wardrobe weather API outfit planner MIT`、`iOS WeatherKit SwiftUI outfit recommendation GitHub MIT`、`SwiftUI packing list weather recommendation MIT`，未找到可直接复制进当前 SwiftUI 工程的成熟 MIT 模块；本轮不接真实天气 API、也不需要外部密钥。
- 按 TDD 增加 `testWardrobePackingSuggestionsPreferLatestPackingDestinationAndWeather`，锁定最近打包清单的目的地、天气和天数应优先进入自动打包建议。
- `WardrobeInsightEngine` 的打包建议现在优先使用最近打包清单的 `destination` / `weather` / `tripDays`，并在说明中写入“目的地参考”和“天气参考”；没有打包清单天气时仍回退最近穿着天气。
- 本地验证通过：`xcrun swiftc -parse some/Utilities/WardrobeInsightEngine.swift SomeTests/SomeTests.swift`、`git diff --check`。

## 2026-06-23T17:27:00+08:00

- 进入并完成阶段 40：工作日志本地汇报摘要。开工前复查 Git 状态、CI run、工作日志导出器、AI 洞察边界和工作日志测试。
- 按用户要求检索 `Swift work log summary markdown exporter MIT`、`Swift daily report generator markdown MIT`、`SwiftUI work report summary template GitHub MIT`、`iOS journal summary markdown exporter Swift MIT`，未找到可直接复制候选；本轮不调用 OpenAI API，也不需要用户提供密钥。
- 按 TDD 增加 `testWorkLogExporterAddsLocalReportSummary`，锁定导出 Markdown 顶部应有“汇报摘要”，包含项目、日期、进展、风险/问题和下一步。
- `WorkLogExporter.markdown` 现在会在正文列表前生成本地汇报摘要，并对多条日志的字段去重合并；原始日志正文仍完整保留。
- 同步完善阶段 39：打包建议标题优先使用最近打包清单目的地，例如“厦门 快速打包”。
- 本地验证通过：`xcrun swiftc -parse some/Utilities/WorkLogSourceFilterEngine.swift SomeTests/SomeTests.swift`、`git diff --check`。

## 2026-06-23T17:26:59+08:00

- 进入并完成阶段 41：图片编辑智能主体单实例点选。开工前复查 Git 状态、最新远端 CI、图片编辑模型/渲染器/UI/测试和当前缺口；发现 `SomeTests.swift` 已有单主体点选 RED 测试碎片，已保留并继续实现。
- 按用户要求检索 `VNGenerateForegroundInstanceMaskRequest selected instance Swift GitHub MIT`、`Swift foreground instance mask point selection GitHub MIT`、`iOS object cutout selected instance point Swift MIT`、`Vision foreground instance mask select point Swift`，未找到可直接复制的 Swift/MIT 模块；一次 GitHub API 查询触发 rate limit。本轮复用 Apple Vision 的 `VNInstanceMaskObservation.instanceMask` 和既有图片编辑管线。
- `ImageEditRecipe.SubjectExtraction` 新增可选归一化选点 `selectionX` / `selectionY`、`hasSelectionPoint` 和记录用标题；旧 JSON 没有选点时继续按原有“人物抠图/智能主体”解码。
- `ImageEditRenderer` 在 iOS 17+ 智能主体模式下，会优先读取实例标签图中点选位置的实例编号，并只对该实例调用 `generateMaskedImage`；点在背景或识别失败时回退为全部前景主体。
- `ImageEditorView` 新增“主体”编辑模式和点选画布，选择“智能主体”后可点选单个对象，保存时记录主体点选坐标；切回非对象模式会清空旧坐标。
- 新增测试覆盖点选坐标编解码、摘要/文件名标记和图片编辑记录正文“主体：智能主体（单主体 x/y）”。
- 本地验证通过：`xcrun swiftc -parse some/Models/Memo.swift some/Stores/MemoStore.swift some/Utilities/ImageEditRenderer.swift some/Views/ImageEditorView.swift SomeTests/SomeTests.swift`、`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、`xmllint --noout some.xcodeproj/xcshareddata/xcschemes/some.xcscheme`。远端基线 `cde609d` 和 `f53ee7d` GitHub Actions 均已通过。

## 2026-06-23T17:42:28+08:00

- 进入并完成阶段 42：工作日志 CSV 导出与格式选择。开工前复查 Git 状态、远端 CI、`WorkLogExporter`、工作日志列表 UI 和现有导出测试。
- 按用户要求检索 `Swift CSV export MIT library`、`Swift CSV writer MIT GitHub`、`SwiftUI export CSV share sheet GitHub MIT`、`Swift work log csv exporter MIT GitHub`；通用 MIT CSV 包存在，但当前只需要少量工作日志字段导出，不引入 SPM 依赖，采用项目内最小 CSV 转义。
- 按 TDD 增加 `testWorkLogExporterBuildsCSVWithEscapedFields`，覆盖普通记录排除、固定表头、逗号和双引号转义。
- `WorkLogExporter` 新增 `csv(memos:assets:)`，输出标题、创建时间、范围、项目、日期、模板、进展、问题和下一步字段；工作日志导出按钮改为 Markdown / CSV 菜单，分别生成 `.md` 或 `.csv` 并复用系统分享表。
- 本地验证通过：`xcrun swiftc -parse some/Utilities/WorkLogSourceFilterEngine.swift SomeTests/SomeTests.swift`、`git diff --check`。本机 Swift 5.4 解析 `ContentView.swift` 仍被既有 `await` 语法挡住，完整 UI 类型检查继续依赖 GitHub Actions。

## 2026-06-23T17:45:00+08:00

- 进入阶段 43：导入/备份恢复页体验优化。开工前确认阶段 41 的 #99 远端 CI 已通过，工作区干净。
- 按用户要求检索 `SwiftUI import backup restore feedback open source MIT`、`SwiftUI file importer import result feedback MIT`，GitHub API 返回 0 个可直接复制进当前设置页/本地备份恢复链路的 SwiftUI 模块。
- 复查 `SettingsView.ImportView`、`MemoStore.importJSON` / `importPlainText` / `MemoBackupPackage.importPackage`、App Store 自测清单和导入相关测试；当前导入页只给单行状态，普通用户难以区分完整备份、旧 JSON 和普通文本。
- 按 TDD 增加 `ImportFeedback` 文案测试，覆盖完整备份恢复、普通文本导入和重复/空导入。
- `ImportView` 新增导入说明区，明确 `.somebackup` 会恢复记录、历史版本和本地附件；普通文本按空行拆分，JSON 按旧备份格式导入。
- 导入结果改为结构化反馈卡片：成功时说明下一步检查时间线/附件，0 条导入时解释可能已存在，失败时显示可理解的错误说明。
- 本地验证通过：`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`。裸 `swiftc -parse SettingsView.swift` 仍被既有 `if let` shorthand 和 `await` parser 限制挡住，完整类型检查继续依赖远端 Xcode CI。

## 2026-06-23T17:50:00+08:00

- 进入并完成阶段 44：URL Scheme 单条记录深链打开。开工前复查阶段 36 的 URL Scheme 路由、`MemoStore.handleURL`、`SomeApp.onOpenURL`、`ContentView` 导航栈和 README 快速入口说明。
- 按用户要求检索 `SwiftUI onOpenURL NavigationStack deep link open detail GitHub MIT`、`iOS SwiftUI URL scheme open specific note NavigationStack GitHub MIT`，GitHub API 返回 0 个可直接复制的许可清晰 SwiftUI 模块；阶段 36 已有 URL Scheme 底座，本轮继续复用 Apple `onOpenURL` 与项目内状态流转。
- `some://open?id=<记录UUID>` 和 `some://open/<记录UUID>` 会校验记录存在，清空搜索，回到时间线，并通过 `ContentView` 的显式 `NavigationStack` path 打开记录详情。
- `SomeApp.onOpenURL` 统一交给 `MemoStore.handleURL`，保存、搜索和打开三类路由共用入口；README 和发现记录已同步 `some://open` 用法。
- 新增测试覆盖：打开已有记录不会创建新 memo、缺失记录 ID 会被忽略、query/path 两种 UUID 解析路径可用。
- 本地验证通过：`xcrun swiftc -parse some/Stores/MemoStore.swift SomeTests/SomeTests.swift`、`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`。远端 iOS CI #102 已通过 Build for simulator 和 Run tests。

## 2026-06-23T18:05:00+08:00

- 进入并完成阶段 45：图片编辑对象清理样式。开工前复查 Git 状态、图片编辑配方、渲染器、编辑器、保存正文和本地遗留 RED 测试碎片。
- 按用户要求检索 `Swift image object removal inpainting MIT GitHub`、`iOS image inpainting object removal Swift MIT`、`Core Image object removal cleanup patch Swift MIT`、`SwiftUI photo editor object removal MIT GitHub`，GitHub API 均返回 0 个可直接复制的 Swift/MIT 模块；本轮不引入深度补全或水印移除能力。
- 保留并补完 `SomeTests.swift` 中的 RED 测试：对象清理样式可编码/解码，旧清理 JSON 默认 `softBlend`，对象清理进入输出文件名和图片编辑记录正文。
- `ImageEditRecipe.CleanupPatch` 新增向后兼容的 `style`，支持 `softBlend` 和 `object`；摘要会分别显示“清理N”和“对象清理N”。
- `ImageEditRenderer` 对对象清理使用独立 `objectcleanup` 文件名后缀，并提高贴片半径与过渡强度；普通柔和修补保持旧行为。
- `ImageEditorView` 的授权清理区新增“柔和修补 / 对象清理”分段选择，画布用不同颜色标记清理点；`MemoStore.addImageEdit` 会额外写入“对象清理：N处”。
- 本地验证通过：`xcrun swiftc -parse some/Models/Memo.swift some/Stores/MemoStore.swift some/Utilities/ImageEditRenderer.swift some/Views/ImageEditorView.swift SomeTests/SomeTests.swift`、`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、`xmllint --noout some.xcodeproj/xcshareddata/xcschemes/some.xcscheme`。完整构建和 XCTest 继续以 GitHub Actions 为准。

## 2026-06-23T18:25:00+08:00

- 进入并完成阶段 46：媒体元数据预热与多 OCR 素材索引。开工前复查 Git 状态、素材库生命周期、`MediaMetadataExtractor`、`VideoThumbnailGenerator`、`MemoAsset` 图片文字解析和相关测试；阶段 45 的远端 CI 已触发，当前仍在运行。
- 按用户要求检索 `Swift media metadata cache AVAsset ImageIO MIT GitHub`、`iOS AVAsset metadata cache Swift MIT`、`SwiftUI media asset metadata prefetch cache MIT`、`ImageIO AVFoundation metadata summary Swift GitHub MIT`，GitHub API 均返回 0 个可直接复制的 Swift/MIT 模块。
- 按 TDD 补测试：媒体元数据预热应从素材索引提取图片/音频/视频附件、去重、限制数量，重复附件计入 skipped，缺失文件计入 failed；同一记录追加多个局部 OCR 块时应生成多条截图素材。
- `MediaMetadataExtractor` 新增 `CacheMaintenanceResult`、`sourceAttachments(in:limit:)` 和 `preheatSummaries(for:)`，复用现有内存 summary cache，不新增数据库迁移。
- 素材库的生命周期维护从 `maintainVideoThumbnailCache` 升级为 `maintainMediaCaches`：素材变化时后台预热图片/音频/视频元数据摘要，同时继续预热视频缩略图并清理孤儿缩略图缓存。
- `MemoAsset.assets(in:)` 的图片文字解析从单块改为多块扫描；每个“图片文字/截图文字”块会优先匹配块内附件，其次按标题匹配现有图片附件，避免多图局部 OCR 被折叠成一条截图素材。
- 本地验证通过：`xcrun swiftc -parse some/Utilities/MediaMetadataExtractor.swift some/Utilities/AttachmentReferenceResolver.swift some/Utilities/SharedAttachmentStore.swift some/Utilities/VideoThumbnailGenerator.swift some/Models/Memo.swift SomeTests/SomeTests.swift`、`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、`xmllint --noout some.xcodeproj/xcshareddata/xcschemes/some.xcscheme`。本机旧 Swift 5.4 parser 单独解析 `ContentView.swift` 仍被既有 `await` 语法挡住，完整 UI 类型检查继续依赖 GitHub Actions。

## 2026-06-23T18:40:00+08:00

- 进入并完成阶段 47：工作日志本地汇报稿导出。开工前复查 Git 状态、`WorkLogExporter`、工作日志导出菜单和现有 Markdown/CSV 测试。
- 按用户要求检索 `Swift daily report generator markdown MIT`、`SwiftUI work log report export MIT`、`project status report markdown Swift MIT`，GitHub API 均返回 0 个可直接复制的 Swift/MIT 模块；本轮不调用 OpenAI API，也不需要用户提供密钥。
- 按 TDD 增加 `testWorkLogExporterBuildsShareableReportDraft`，锁定纯文本汇报稿应包含项目、日期、进展、风险/问题和下一步，并按结构化字段去重。
- `WorkLogExporter.reportDraft` 会从当前筛选日志生成可直接发送的“工作汇报”文本；工作日志导出菜单新增“汇报稿”，导出为 `.txt` 并复用系统分享表。
- 本地验证通过：`xcrun swiftc -parse some/Utilities/WorkLogSourceFilterEngine.swift some/Views/ContentView.swift SomeTests/SomeTests.swift`、`git diff --check`。完整 XCTest 继续以 GitHub Actions 为准。

## 2026-06-23T19:05:00+08:00

- 进入并完成阶段 48：TestFlight workflow checkout action 对齐。开工前复查 Git 状态、`ios-ci.yml`、`ios-testflight.yml`、发布文档和既有 CI 警告记录。
- 复查官方 `actions/checkout` 远端 tags，确认 `v5` / `v5.0.1` 存在；本项目 CI workflow 已使用 `actions/checkout@v5`，发布 workflow 仍停在 `v4`。
- `.github/workflows/ios-testflight.yml` 的 Checkout 步骤升级到 `actions/checkout@v5`，并同步更新计划、发现、发布说明和验证记录，明确 CI/TestFlight 两条 workflow 已对齐。
- 本地验证通过：`ruby -e "require 'yaml'; YAML.load_file('.github/workflows/ios-ci.yml'); YAML.load_file('.github/workflows/ios-testflight.yml')"`、`rg -n "actions/checkout@" .github/workflows`、`git diff --check`。实际 TestFlight 上传仍依赖 Apple 签名和 App Store Connect secrets。

## 2026-06-23T19:25:00+08:00

- 进入并完成阶段 49：手帐导出后立即分享。开工前复查 Git 状态、`ScrapbookEditorView`、`ScrapbookRenderer`、`MemoStore.exportScrapbookLayout`、`ShareSheet` / `ExportedDocument` 和手帐导出测试。
- 按用户要求检索 `SwiftUI PDF export share sheet GitHub MIT iOS scrapbook`、`SwiftUI UIActivityViewController share sheet PDF export GitHub MIT`、`SwiftUI collage editor export PDF share GitHub MIT`、`TPPDF Swift PDF generator MIT GitHub`；已有 MIT 通用参考，但当前项目已有渲染、附件存储和系统分享表，不引入新依赖。
- 按 TDD 增加 `testExportScrapbookLayoutForSharingReturnsExistingFileURL`，锁定导出分享时应返回附件和真实存在的文件 URL，并继续把 PNG/PDF 引用回写到 memo。
- `MemoStore.exportScrapbookLayoutForSharing` 复用现有导出逻辑返回 `ScrapbookShareExport`；`ScrapbookEditorView` 在 PNG/PDF 导出成功后把文件 URL 交给 `ShareSheet`，用户可立刻发送或保存。
- 本地验证通过：`xcrun swiftc -parse some/Stores/MemoStore.swift some/Views/ScrapbookEditorView.swift some/Utilities/ScrapbookRenderer.swift SomeTests/SomeTests.swift`、`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、`xmllint --noout some.xcodeproj/xcshareddata/xcschemes/some.xcscheme`。本机缺 iOS/UIKit SDK，`swiftc -typecheck` 会在 `import UIKit` 失败，完整 XCTest 继续以 GitHub Actions 为准。

## 2026-06-23T18:34:53+08:00

- 进入并完成阶段 50：手帐图片构图微调。阶段 49 已在最新历史中完成并同步远端，本轮继续推进照片拼贴/手帐排版缺口。
- 按用户要求检索 `SwiftUI photo collage crop editor open source`、`GitHub iOS image cropper SwiftUI open source`、`GitHub Swift photo editor filter crop frame open source`，并复核 `Mantis`、`TOCropViewController`、`SwiftyCrop` 的 MIT 许可和近期维护状态；当前不引入大型裁剪器，先补 some 内置图片图层取景控制。
- 按 TDD 增加 `testScrapbookImageLayerCompositionRoundTripsAndDefaults`，先确认 `ScrapbookLayer` 尚不支持 `imageCropX` / `imageCropY` / `imageCropScale` 后再实现；同时补照片拼贴默认图片图层的中性构图断言。
- `ScrapbookLayer` 新增向后兼容的图片构图字段，旧手帐 JSON 解码默认居中、原始取景；异常值会限制在安全范围内。
- `ScrapbookRenderer` 导出图片图层时按取景中心和放大倍率做 aspect-fill；`ScrapbookEditorView` 的图片预览也使用同一取景算法，并在图片图层 Inspector 中提供横向取景、纵向取景、取景放大和复位控制。
- 本地验证通过：`xcrun swiftc -parse some/Models/Memo.swift some/Utilities/ScrapbookRenderer.swift some/Views/ScrapbookEditorView.swift SomeTests/SomeTests.swift`、`git diff --check`、`plutil -lint some/Info.plist some.xcodeproj/project.pbxproj`。完整类型检查探针被 `MemoStore` 需要额外数据库/备份类型依赖挡住，完整 XCTest 继续以 GitHub Actions 为准。

## 2026-06-23T19:45:00+08:00

- 回到 CI 阻塞：公开 check-run annotations 显示 `ef86208`、`ac846ab`、`fe06e85` 的 Build for simulator 通过，但 Run tests 因 `appintentsmetadataprocessor --module-name ZIPFoundation` 退出 65；`fe06e85` 另有分享 helper 漏提交问题，已由 `9eafad8` 补齐。
- 按系统化调试确认根因不在业务断言，而是 Xcode 16.4 测试构建对 Swift Package 触发 App Intents metadata processor；正式 Build for simulator 仍要保留 ZIPFoundation，以继续覆盖完整备份真实构建。
- `.github/workflows/ios-ci.yml` 的 Run tests 阶段会临时从 pbxproj 移除 ZIPFoundation package/framework/product 引用，并传入 `-DCI_DISABLE_ZIP_BACKUP`；`MemoBackupPackage` 在该 flag 下提供不导入 ZIPFoundation 的 stub，CI 只跳过 3 个 ZIP 包专属测试，普通 JSON 备份/附件恢复测试继续跑。
- 本地验证通过：CI Ruby 改写后的临时 `project.pbxproj` 通过 `plutil -lint` 且不含 ZIPFoundation 引用，`.github/workflows/ios-ci.yml` YAML 解析通过，`xcrun swiftc -parse -D CI_DISABLE_ZIP_BACKUP some/Utilities/MemoBackupPackage.swift SomeTests/SomeTests.swift` 通过，`git diff --check` 通过。完整远端复验等待新 GitHub Actions run。

## 2026-06-23T19:55:00+08:00

- 进入并完成阶段 51：完整备份导入摘要与附件大小记录。开工前复查 Git 状态、备份 archive、ZIP 包导入、设置页导入反馈和现有导入测试。
- 按用户要求检索 `SwiftUI backup import export notes app MIT`、`iOS notes app backup restore Swift MIT`，GitHub Search 均返回 0 个可直接复制的 SwiftUI/MIT 模块；本轮继续复用 some 的 `MemoBackupArchive` 和 `ImportFeedback`。
- 按 TDD 补测试：`MemoBackupSummary` 应统计记录、历史版本、附件数和附件字节数；完整备份恢复反馈应显示摘要；大小格式化使用确定性 `KB/MB/GB/B`，避免 `ByteCountFormatter` 在 CI/设备区域设置下漂移。
- `MemoBackupAttachment` 新增向后兼容的 `byteCount`；普通 JSON/inline 备份导出记录现有附件大小，ZIP 包导入会以实际解包数据大小回填；旧备份缺字段时按 0 处理。
- 设置页粘贴旧 JSON 时会先识别是否为完整 `MemoBackupArchive`；完整备份 JSON 走“已恢复备份记录”反馈并显示摘要，普通旧 JSON 继续走 JSON 导入说明。

## 2026-06-23T20:05:00+08:00

- 进入并完成阶段 52：手帐照片滤镜与相框收口。开工前复查手帐图片图层模型、编辑器、导出 renderer、Core Image 使用点和 Stage 50 取景控制。
- 按用户要求检索 `SwiftUI Core Image photo filter editor MIT`、`SwiftUI scrapbook collage editor image filter MIT`，GitHub Search 均返回 0 个可直接复制的 SwiftUI/MIT 模块；本轮不引入滤镜/拼贴第三方依赖。
- `ScrapbookLayer.ImageFilter` 增加原图、清新、暖食、胶片、鲜明等照片滤镜；手帐编辑器图片图层 Inspector 增加照片滤镜 chip、相框颜色和相框线宽。
- `ScrapbookRenderer` 导出路径和 `ScrapbookEditorView` 预览路径共用 `ScrapbookImageFilterRenderer`，避免预览与 PNG/PDF 导出滤镜漂移；图片相框会在预览和导出中保持一致。
- 修复阶段 52 的 Swift 编译风险：`Memo.swift` 显式导入 `CoreGraphics`，并把滤镜 helper 私有方法从 `cgImage` 改名为 `renderedCGImage`，避免与局部 `cgImage` 变量同名导致 CI 编译歧义。
- 本地验证通过：`xcrun swiftc -parse some/Models/Memo.swift some/Models/MemoBackupArchive.swift some/Utilities/ScrapbookRenderer.swift some/Views/ScrapbookEditorView.swift SomeTests/SomeTests.swift`、`xcrun swiftc -parse -D CI_DISABLE_ZIP_BACKUP some/Utilities/MemoBackupPackage.swift SomeTests/SomeTests.swift`、`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist`、`xmllint --noout some.xcodeproj/xcshareddata/xcschemes/some.xcscheme`、两个 GitHub workflow 的 Ruby YAML 解析。远端 GitHub API run/check-runs 查询目前返回 unauthenticated rate limit，需后续继续低频复验。

## 2026-06-23T19:39:19+08:00

- 回到远端 CI 收口：run `28022556308` 的 Build for simulator 已通过，Run tests 失败 annotation 只剩一个 `XCTAssertTrue failed`，位置集中在搜索日期解析测试附近。
- 复查未提交碎片时发现 `SomeTests.swift` 已有正向修改：把日期解析断言从只看 `Calendar.current` 的月份/日期，改为完整比较 Gregorian 当前时区下的起始日期；本轮保留该修复方向。
- 根因判断：生产代码创建 `Calendar(identifier: .gregorian)` 后只在 `DateComponents` 上设置 `TimeZone.current`，但 calendar 自身仍可能使用默认时区，导致 CI 模拟器上日期范围起点/测试预期出现漂移。
- 修复：`MemoSearchQueryParser.dateRange` 显式把 Gregorian calendar 的 `timeZone` 设为 `TimeZone.current`，使 `created:2026-06`、`updated:>=2026-06-22` 的 start/end 语义稳定。

## 2026-06-23T19:55:00+08:00

- 进入阶段 53：`.somebackup` 清单摘要与日期 CI 收口。开工前重新复查 Git 状态、全量文件清单、规划/发现/进度/验证记录、`MemoBackupPackage`、`MemoBackupArchive`、`SettingsView.ImportView` 和导入反馈相关测试；工作区中出现的 `MemoSearchQuery` / 文档变更判断为远端 CI 正向修复碎片，已纳入当前验证范围，不回滚。
- 按用户要求补做联网/开源检索：`Swift ZIPFoundation read manifest entry Data ZIP archive summary`、`SwiftUI iOS backup import restore summary .zip notes app MIT GitHub`、`GitHub ZIPFoundation Swift read entry extract data Archive accessMode read`、`GitHub SwiftUI notes backup export restore MIT ZIPFoundation` 未发现可直接复制到当前 SwiftUI 本地备份 UI 的完整 MIT 模块；继续复用已接入的 MIT `ZIPFoundation`。
- 按 TDD 增加 `testBackupPackageSummaryReadsManifestWithoutImporting`，要求 `.somebackup` 可只读 manifest 生成 `MemoBackupSummary`，覆盖记录数、历史版本数、附件数和附件字节数。受本机旧工具链限制，`swiftc -typecheck` 先因缺 ZIPFoundation 模块失败，无法本地跑到缺失 API 红灯；已记录该环境限制，并保持测试先于生产实现。
- `MemoBackupPackage.summary(at:)` 现在只读 ZIP 包 `manifest.json` 并返回 `MemoBackupSummary`；`importPackage` 和 `summary` 共用 manifest 解析 helper，避免导入路径和预览路径漂移。`CI_DISABLE_ZIP_BACKUP` stub 同步增加 `summary(at:)`，CI 测试构建移除 ZIPFoundation 时仍可解析。
- `SettingsView.ImportView.importFile` 在选择 `.somebackup` 后先读取 summary 再执行恢复，恢复成功反馈会显示完整备份摘要，不再只给通用“附件和历史版本会一起恢复”文案。

## 2026-06-23T21:08:37+08:00

- 进入并完成阶段 54：禅定模式快速记录。开工前复查最新 CI、`MemoHomeMode`、首页模式切换、普通快速输入、`MemoStore.addMemo`、标签解析和现有 flomo 对标缺口。
- 按用户要求检索 `SwiftUI zen mode notes MIT`、`SwiftUI focus writing notes MIT`、`SwiftUI distraction free editor MIT`、`SwiftUI quick capture notes focus mode MIT`；未找到可直接复制进当前工程的成熟 SwiftUI/MIT 专注写作模块。
- 按 TDD 保留并实现 `testZenDraftStatsCountsReadableProgress` / `testZenDraftStatsExplainsEmptyDraft`：`ZenDraftStats` 会统计非空白字符、非纯标签内容行、标签数、保存可用性和摘要文案。
- `MemoHomeMode` 新增“专注”模式；首页新增 `ZenCaptureView`，提供大文本输入、自动聚焦、本地 `@AppStorage("some.zenDraft")` 草稿、实时统计、清空和保存按钮。保存复用 `MemoStore.addMemo`，不新增存储格式。
- 复查并行窗口碎片时发现 `ContentView.swift` 同时内联重复 `ZenDraftStats` 和两份 `ZenCaptureView`，已收束为独立 `ZenDraftStats.swift` + 单一 `ZenCaptureView(isModal:)`；首页“专注”模式内嵌使用，全屏叶子按钮使用可关闭的 modal。

## 2026-06-23T21:48:00+08:00

- 进入并完成阶段 55：小组件快照与深链入口。开工前继续复查 Git 状态和并行窗口碎片，发现 `SomeWidget/`、`WidgetSnapshotStore.swift`、小组件 target、`MemoStore` 快照刷新和 URL scheme 扩展已写入工作区。
- 按用户要求检索 SwiftUI/WidgetKit/notes widget 开源参考，存在 MIT 示例项目可参考基础 WidgetKit 和深链写法，但未找到能直接复制到 some 本地 App Group 快照架构的完整笔记小组件模块。
- `WidgetSnapshotStore` 生成 active/today/recent 快照，主 App 保存、批量替换和删除记录后刷新共享 JSON；Widget 扩展读取快照展示今日/全部计数、最近记录和记录/专注/搜索/详情深链。
- 新增 `SomeWidget` target、Info.plist、entitlements、scheme build entry 和 App embed；小组件 UI 使用浅粉、雾蓝、淡紫、柔白的小清新色系。
- 复查并行窗口碎片时发现重复 `SomeWidgetBundle.swift` 也声明 `@main`，已删除，避免未来接入 target 后与 `SomeWidget.swift` 冲突。
- `MemoStore.handleURL` 新增 `some://home` / `some://zen`，并让无查询参数的 `some://search` 回到时间线；测试覆盖小组件快照排序、文件往返和小组件深链入口。
- 远端 run `28029991853` 失败根因确认回到 Xcode 16.4 App Intents metadata processor。CI Run tests 阶段临时 pbxproj 改写升级为直接移除 AppIntents build file 定义与 source 引用，并继续移除 ZIPFoundation、分享扩展和小组件嵌入依赖；正式 Build/TestFlight 不受影响。
- 远端 run `28031203527` 已越过 AppIntents 阻塞，暴露 `testWorkLogExporterBuildsShareableReportDraft` 的真实顺序断言失败；修复为汇报稿按模板优先级排序，项目汇报优先于日报，同时把该测试改成完整文本等值断言，避免后续再只显示裸 `XCTAssertTrue failed`。

## 2026-06-23T21:05:00+08:00

- 继续收口远端 run `28023921262`：Build and test job 仍失败，公开日志只能定位到测试阶段仍有 `XCTAssertTrue failed`，且 GitHub logs API 对当前权限返回 403，无法下载完整日志包。
- 将搜索日期解析的测试断言从闭包式 `XCTAssertTrue` 改为先取出 created/updated filter，再逐项 `XCTNotNil` / `XCTEqual`，让下一次 CI annotation 能直接暴露 operation 或 start 日期差异。
- `MemoSearchQueryParser.dateRange` 抽出 `localGregorianCalendar()`，测试 helper `makeDate` 也改为同样先设置 Gregorian calendar 的 `timeZone` 再调用 `calendar.date(from:)`，进一步消除 `DateComponents.date` 的隐式 calendar 差异。
- 扩大 `.github/workflows/ios-ci.yml` 的测试失败摘要 grep 范围，失败时会附带更多前后相邻 passed/failed test case，避免 GitHub 页面只显示孤立断言。
- 远端 run `28028932398` 仍只暴露一个裸 `XCTAssertTrue failed`，但页面已显示内容类型、日期、搜索索引等相关测试通过。继续把 parser 近邻测试中的裸布尔断言改为 `XCTEqual`，并让 CI 失败摘要额外输出失败前最近 320 条 test case 行。

## 2026-06-23T22:01:03+08:00

- 进入阶段 56：Widget TestFlight 签名链路。阶段 55 的小组件代码已由 `43b0fc6` 提交，文档里程碑由 `b2bcbd8` 同步到 `origin/master`；本轮在该提交之上继续补发布阻塞。
- 复查全量文件清单与工作树，未发现新的未跟踪源码碎片；当前最高风险是 `SomeWidget` 已作为 embedded app extension 加入 app target，但 `.github/workflows/ios-testflight.yml` 仍只安装/映射主 App 与 Share Extension 的 App Store provisioning profile。
- 按用户要求补做 WidgetKit/notes widget 开源检索，精确 GitHub 查询 `SwiftUI WidgetKit widgetURL MIT` 和 `iOS notes WidgetKit SwiftUI MIT` 均返回 0；本轮不复制第三方源码，改发布配置与文档。
- `.github/workflows/ios-testflight.yml` 新增 `WIDGET_EXTENSION_BUNDLE_ID`、`IOS_WIDGET_EXTENSION_APP_STORE_PROVISIONING_PROFILE_BASE64`、`IOS_WIDGET_EXTENSION_APP_STORE_PROVISIONING_PROFILE_NAME`，并在安装 profile、ExportOptions provisioningProfiles 和 `xcodebuild archive` build settings 中传入 widget bundle/profile。
- README、`docs/online-build-and-release.md` 和 `AppStore/submission-checklist.md` 已同步说明 Widget Extension 的 Bundle ID、App Group、App Store provisioning profile secret 和 TestFlight 真机验收项。

## 2026-06-23T22:31:00+08:00

- 远端 GitHub Actions 已确认 `3a2de0b` 与 `37404fe` 均通过 Build and test；`a5545d8` 最新 run `28032434917` 也通过 Build for simulator 和 Run tests，阶段 55-57 的 CI 阻塞已闭环。
- 进入并完成阶段 58：引用批注正文与筛选。开工前复查 `MemoReferenceParser`、`MemoStore.addReference`、`MemoSearchQuery`、`MemoDetailView` 和引用相关测试。
- 按用户要求检索 `SwiftUI notes backlink annotation MIT` 与 `iOS backlink notes annotation Swift MIT`，GitHub Search 精确查询均返回 0；本轮不复制第三方源码，继续沿用 Markdown 可迁移文本格式。
- `MemoReference` 新增向后兼容的 `note`；`MemoReferenceParser` 支持读取/生成 `引用批注：...` + `[引用: ...](some-memo://...)`，并在正文展示时一起隐藏引用行和批注行。
- `MemoStore.addReference` 支持传入批注；搜索新增 `has:引用批注` / `has:reference-note`；工作日志来源筛选也可按引用批注筛选。
- 详情页“引用”卡片会在指向/被引用条目下展示对应批注，保留原有添加引用流程，不新增存储 schema。

## 2026-06-23T22:38:17+08:00

- 进入并完成阶段 59：重复引用批注解析与 CI 预防修复。开工前复查 Git 状态、HEAD `7217f95`、阶段 58 diff、引用解析器、store 关系去重、素材索引和最新 GitHub Actions run。
- 本地红灯探针确认阶段 58 的 `testMemoReferenceParserKeepsDuplicateReferenceNotesInOrder` 会失败：解析器按 memo ID 去重后只返回第一条批注，不能表达同一目标下多条引用依据。
- `MemoReferenceParser.references(in:)` 改为忠实返回文本中的每个引用实例；`MemoStore.referencedMemos(from:)` 在详情关系卡片边界按 memo ID 去重，避免同一目标卡片重复出现。
- `has:引用批注` 与工作日志来源筛选改为按 trim 后非空判断；`MemoAsset.reference` 会把第一条引用批注写入摘要，素材库能看到引用上下文。
- 按 TDD 补 `testDuplicateReferenceNotesKeepOneRelationAndFirstAssetSummary`，覆盖“重复批注保留解析顺序、关系卡片唯一、素材摘要显示第一条批注”。
- 本地验证通过：重复引用批注 Swift 探针、`xcrun swiftc -parse some/Utilities/MemoReferenceParser.swift some/Utilities/MemoSearchQuery.swift some/Stores/MemoStore.swift some/Models/Memo.swift SomeTests/SomeTests.swift`、`xcrun swiftc -parse some/Utilities/WorkLogSourceFilterEngine.swift some/Utilities/MemoReferenceParser.swift SomeTests/SomeTests.swift`、`git diff --check`、plist/scheme/workflow 校验。GitHub 公共 API 已触发 rate limit，最新 run `28033567402` 只能待窗口恢复后继续复验。

## 2026-06-23T22:40:57+08:00

- 进入并完成阶段 60：工作日志团队汇报模板导出。开工前复查 `WorkLogExporter.reportDraft`、工作日志导出菜单、工作日志测试和当前 CI 状态。
- 按用户要求检索 `swift daily standup report template license:mit`、`work log report generator markdown license:mit`、`project status report template markdown license:mit`，GitHub Search 精确查询均返回 0；本轮不复制第三方源码，继续复用项目内导出器。
- 用 TDD 补 `testWorkLogExporterBuildsStandupReportDraft` 和 `testWorkLogExporterBuildsProjectBriefReportDraft`，锁定站会稿与项目简报的纯文本格式。
- `WorkLogExporter.reportDraft` 新增 `ReportDraftStyle`，默认 `standard` 保持原汇报稿不变，新增 `.standup` 输出“昨天/已完成、阻塞、今天/下一步”，新增 `.projectBrief` 输出“本期完成、风险/待协助、后续计划”。
- 工作日志导出菜单新增“站会稿”和“项目简报”，两者复用当前筛选结果和系统分享表，导出为 `.txt`。
- 本地验证通过：`xcrun swiftc -parse some/Utilities/WorkLogSourceFilterEngine.swift SomeTests/SomeTests.swift`、`xcrun swiftc -parse some/Utilities/MemoSearchQuery.swift some/Utilities/MemoReferenceParser.swift some/Utilities/WorkLogSourceFilterEngine.swift some/Models/Memo.swift some/Utilities/SharedAttachmentStore.swift SomeTests/SomeTests.swift`、`git diff --check`、plist/scheme/workflow 校验。

## 2026-06-23T22:52:00+08:00

- 进入并完成阶段 61：本地 AI 记忆档案与禅定偏好。开工前复查 AI 工作台、AI 洞察/语义搜索、禅定记录、当前缺口和 Git 状态；GitHub Actions 公共 API 仍被 rate limit，远端 CI 待窗口恢复后继续查。
- 按用户要求检索 `Swift AI memory journal profile MIT` 与 `SwiftUI personal knowledge memory profile MIT`，GitHub Search 精确查询均返回 0；本轮不复制第三方源码。
- 新增 `AIMemoryProfile` / `AIMemoryProfileBuilder`，从本地活跃记录提炼标签、重复词、未完成/已完成任务、工作日志进展/问题/下一步，输出可保存的 Markdown“AI 记忆档案”；该功能不调用 OpenAI API、不需要 Key。
- AI 工作台新增“记忆”页，可按现有范围生成本地档案，并支持复制、分享或保存为普通记录 `#AI记忆档案`。
- 禅定记录补舒适/大字/紧凑三种文字偏好，使用 `@AppStorage("some.zenWritingPreference")` 保存字号、行距和占位文案。
- 本地验证通过：`xcrun swiftc -parse some/AI/AIMemoryProfile.swift some/AI/AIInsightComposer.swift some/Utilities/DateFormatters.swift some/Utilities/TagParser.swift some/Utilities/MemoTaskParser.swift some/Utilities/MemoReferenceParser.swift some/Utilities/SharedAttachmentStore.swift some/Models/Memo.swift SomeTests/SomeTests.swift`、`git diff --check`、`plutil -lint some.xcodeproj/project.pbxproj some/Info.plist some/PrivacyInfo.xcprivacy SomeShareExtension/Info.plist SomeWidget/Info.plist`。`AIWorkspaceView.swift` 单文件 parse 仍受本机 Swift 5.4 对既有 async/await 和新式 `if let` 语法限制，完整 UI 编译以 GitHub Actions/Xcode 16.4 为准。

## 2026-06-23T23:03:00+08:00

- 进入并完成阶段 62：AI 工作台本地相关搜索。开工前复查 `SemanticSearchEngine`、`AIWorkspaceView`、AI 相关测试和阶段 61 的无 Key 记忆档案。
- 按用户要求检索 Swift 本地模糊搜索/文本相似度开源候选；存在通用库和 NaturalLanguage 示例，但本轮不引入 SPM，先做低风险本地 fallback。
- 按 TDD 增加 `testLocalSemanticSearchWorksWithoutAPIKey`，锁定归档记录排除、相关记录排序、limit 和非零评分。
- `SemanticSearchEngine.localSearch` 新增本地词项重叠评分，中文长词会补二字滑窗，按分数和时间排序；`AIWorkspaceView` 在没有 OpenAI Key 时让“搜索/相关”按钮仍可用并显示“本地找到”状态，配置 Key 后继续走 OpenAI embedding。
- 本地 Swift 5.4 parser 的红灯探针被既有 `try await` 语法挡住，无法跑到缺失 `localSearch` 的真实编译错误；实现后用可解析文件、plist/scheme/workflow 和 diff 检查继续验证，完整 UI 编译仍以 GitHub Actions/Xcode 16.4 为准。

## 2026-06-23T23:12:00+08:00

- 进入并完成阶段 63：语音转写语言选择。开工前复查 `AudioTranscriber`、音频附件详情页、语音转写测试和 README 隐私说明。
- 按用户要求检索 Apple Speech 语言选择相关开源候选；未引入 WhisperKit 等重依赖，本轮继续复用 Apple `SFSpeechRecognizer`。
- 按 TDD 增加 `testAudioTranscriptionLanguageBuildsLocaleAndMemoHeader`，覆盖未知值回退自动、普通话/英语 locale，以及非自动语言的转写标题标注。
- `AudioTranscriptionLanguage` 新增自动、普通话、英语、粤语、日语、韩语；`AudioTranscriber.transcribe(fileURL:language:)` 会把选择映射到 locale，`memoText` 在非自动语言时把语言写入标题。
- 详情页语音转写区新增语言菜单，偏好保存在 `@AppStorage("some.audioTranscriptionLanguage")`，用户转写不同语言音频时不用反复去系统设置。

## 2026-06-23T23:24:00+08:00

- 阶段 62/63 已由提交 `076e5cd`、`439808e`、`776160f` 落地并同步到 `origin/master`；恢复后重新校准 Git 状态，确认主功能代码已进入提交历史。
- 补阶段 63 文档和提示收口：README 将本地语音转写更新为 v2，移除“转写语言选择”路线图项；AI 工作台无 Key banner 改为说明本地 AI 已可用；验证记录改成已经实际执行过的命令与旧 Swift parser 限制说明。
- 远端 run `28035724252` 暴露 `MemoStore.referencedMemos(from:)` 在 Share Extension 编译路径下的闭包返回诊断，已在 `26bfbdb` 给 `compactMap` 闭包显式补 `return`，本地通过 `MemoStore.swift` parse、`git diff --check`、plist/scheme/workflow 校验，等待 run `28035841758` 复验。

## 2026-06-23T23:34:00+08:00

- 进入并完成阶段 64：本地 AI 搜索命中解释。开工前复查阶段 62 的本地搜索、AI 工作台结果卡和模糊搜索开源候选。
- `SemanticMemoResult` 新增 `matchedTerms`；`localSearch` 改为标签、完整词、中日韩片段带权计分，并只对紧凑文字生成二字滑窗，避免英文片段误匹配。
- AI 工作台本地搜索结果会显示最多 4 个命中词，让用户知道为何匹配；配置 OpenAI Key 后 embedding 搜索仍保持原路径。
- 进入并完成阶段 65：连续扫描与扫描页 OCR。复查并行窗口留下的扫描页测试，补 `ImageTextRecognizer.memoText(titlePrefix:pageNumber:)`，让 `MemoAsset` / `ClipFragmentExtractor` 识别“扫描文字：”标题，并在快速输入加入 VisionKit 连续扫描入口。
- 本地验证覆盖：AI/记忆相关可解析文件、`rg` 命中检查、`git diff --check`、plist/scheme/workflow 校验；含 `async` 的文件完整编译继续以 GitHub Actions/Xcode 16.4 为准。

## 2026-06-23T23:40:00+08:00

- 进入并完成阶段 64：本地 AI 搜索命中解释。开工前复查 Git 状态、`SemanticSearchEngine`、AI 工作台结果卡片、AI 搜索测试和当前 CI 状态。
- 按用户要求继续检索本地模糊搜索候选；`fuse-swift` / `Ifrit` 可参考，但本轮不引入依赖，继续复用项目内搜索引擎。
- 按 TDD 增加 `testLocalSemanticSearchWeightsTagsAndReportsMatchedTerms`，锁定标签命中权重优先于普通文本片段，并要求结果返回 `matchedTerms`。
- `SemanticMemoResult` 新增向后兼容的 `matchedTerms`；本地搜索改为标签、完整词和中日韩片段加权评分，英文不再用二字片段误匹配；AI 结果卡片显示最多 4 个命中词。
- 进入并完成阶段 65：连续扫描与扫描页 OCR。快速输入新增 `doc.viewfinder` 扫描按钮，调用系统 `VNDocumentCameraViewController`；扫描完成后逐页保存 JPEG 附件、运行本机 OCR，并写入“扫描文字/扫描页：第 N 页”记录，素材摘要会过滤页码元数据。

## 2026-06-23T23:58:00+08:00

- 继续主动推进阶段 66：AI embedding 缓存与行动复盘导出。开工前重新加载 Superpowers，复查 Git 状态、计划文件、AI 搜索代码、工作日志导出器和旧 Codex 目录。
- 跨目录审计 `/Users/wuyongnaren/Documents/Codex/2026-06-20/some-flomo-app-app-store-1/work/some` 与 `/Users/wuyongnaren/Documents/Codex/2026-06-21/some-flomo-app-app-store-1/work/some`：2026-06-21 嵌套仓库仅有早期 3 个提交，当前主仓库已包含其所有跟踪文件；2026-06-20 为更早快照，没有当前主仓库缺失的功能文件。
- 按用户要求补做开源检索：Swift/OpenAI embedding cache、语义搜索缓存、工作日志行动复盘模板方向未找到可直接复制进当前 SwiftUI/iOS 工程的成熟 MIT 模块；本轮继续复用项目内 `SemanticSearchEngine` 和 `WorkLogExporter`。
- 按 TDD 增加 `testSemanticEmbeddingCacheReusesRepeatedInputs`，实现 `SemanticEmbeddingCache`，对同一模型和同一 memo 文本在本次运行内复用记录 embedding；查询文本仍每次请求，避免把临时问题长期缓存。
- 发现并保留并行/遗留的 `testWorkLogExporterBuildsActionReviewReportDraft` 正向测试，补 `ReportDraftStyle.actionReview` 和工作日志导出菜单“行动复盘”，不回滚其他窗口留下的改动。

## 2026-06-24T00:18:00+08:00

- 进入并完成阶段 67：AI embedding 跨启动本地缓存。开工前补检索持久化 embedding cache、iOS 语义搜索缓存和 Core Spotlight 示例，未找到能直接复制进当前 OpenAI embedding 调用链的轻量模块。
- 按 TDD 增加 `testSemanticEmbeddingCacheSnapshotRestoresWithoutPersistingRawInputs` 和 `testSemanticEmbeddingDiskCacheRoundTripsSnapshot`，先用聚焦 typecheck 探针确认缺少 `snapshot` / `SemanticEmbeddingDiskCache` 的红灯。
- `SemanticEmbeddingCache` 的内部 key 从原文改为模型名 + SHA-256 指纹，支持 `Snapshot` 导出/恢复；新增 `SemanticEmbeddingDiskCache`，把缓存写入 App Group `AICache/semantic-embeddings.json`。
- 语义搜索 actor 初始化时加载本地缓存，成功获取缺失记录 embedding 后写回磁盘；`clearEmbeddingCache()` 同步清理内存和磁盘文件。查询文本仍不缓存，只缓存记录文本 embedding，降低临时搜索词长期留存风险。

## 2026-06-24T00:31:00+08:00

- 进入并完成阶段 68：AI embedding 缓存容量裁剪。阶段 67 已能跨启动复用，但缺少长期增长边界，因此继续主动推进本地 LRU 上限。
- 按 TDD 增加 `testSemanticEmbeddingCachePrunesLeastRecentlyUsedEntries`，先用红灯探针确认 `SemanticEmbeddingCache(maxEntryCount:)` 不存在。
- `SemanticEmbeddingCache.Snapshot` 从旧的 `[key: vector]` 兼容升级为 `[key: Entry]`，新增 `lastAccessedAt` 访问序号；lookup 命中会刷新访问序号，store 后自动裁剪到默认 1000 条。
- 新实现兼容阶段 67 已写出的旧 JSON 缓存格式，旧条目读取后可继续命中并在后续访问/写入时升级。

## 2026-06-24T00:43:00+08:00

- 进入并完成阶段 69：设置页 AI 语义缓存清理入口。阶段 67/68 已让本地 AICache 可跨启动复用并裁剪，本轮补用户可见的清除控制。
- 开工前检索 SwiftUI 设置页清缓存入口和 confirmation dialog 示例，没有找到能直接复制到当前 some 设置页结构的模块；继续复用现有 `SettingsView` 和 `SemanticSearchEngine.clearEmbeddingCache()`。
- 设置页 AI 区域新增“清除 AI 语义缓存”按钮，带 destructive confirmation dialog；确认后只清空本机 embedding 缓存并更新 AI 状态文案，不删除笔记、API Key 或本地 AI 记忆档案。
- 隐私说明同步补充本机 embedding 缓存可在设置里清除。

## 2026-06-24T00:56:00+08:00

- 进入并完成阶段 70：设置页 AI 语义缓存摘要。阶段 69 已能清缓存，本轮继续补透明度，让用户看到当前本机缓存条数和占用大小。
- 按 TDD 增加 `testSemanticEmbeddingDiskCacheReportsSummary`，先用红灯探针确认 `SemanticEmbeddingDiskCache.summary` 缺失。
- `SemanticEmbeddingDiskCache.Summary` 返回条目数和文件字节数；空/已删除缓存返回 0 条 0 bytes，保存快照后可读到真实条目数和非零文件大小。
- 设置页 AI 区域新增“AI 语义缓存：暂无本机缓存 / N 条，X KB”摘要，进入设置页刷新，清除缓存后立即更新。

## 2026-06-24T01:12:00+08:00

- 进入并完成阶段 72：首次记录模板引导。开工前复查 Git 状态、远端 CI、计划文件、快速输入/空状态/设置页，并补做 flomo 快速捕捉体验与 SwiftUI notes onboarding 开源检索。
- 按 TDD 增加 `testQuickCaptureStarterSuggestionsSeedFirstMemo`，锁定模板标题和文字/链接/工作日志三类可保存示例。
- `QuickCaptureView` 新增 `QuickCaptureStarterSuggestion`，空草稿且未导入/摘录/录音时显示“记录想法 / 保存链接 / 写工作日志”三个横向胶囊按钮，点击后填入草稿并聚焦输入框；用户开始输入后模板自动隐藏。

## 2026-06-24T01:10:00+08:00

- 进入并完成阶段 71：App Store 隐私文案同步 AI 本地缓存。阶段 67-70 改变了 AI 语义搜索的本机缓存行为，需要同步上架材料，避免隐私政策和真实功能不一致。
- 复查 `AppStore/privacy-policy.md`、`app-store-metadata.md`、`submission-checklist.md` 和 2026-06-20/21 旧快照；旧文案只写可选 OpenAI API，没有说明本机 `AICache`。
- 隐私政策新增 App Group 本地容器、AI embedding 缓存位置、模型名 + SHA-256 文本指纹 key、1000 条上限、不保存笔记明文、设置页可查看/清除和清除不影响笔记/API Key 的说明。
- App Store metadata 和 submission checklist 同步审核说明、App Privacy 提醒和 TestFlight 自测项。

## 2026-06-24T01:18:00+08:00

- 进入并完成阶段 73：工作日志 AI 润色导出。开工前复查工作日志导出器、AI composer 和当前未提交测试碎片，发现 `WorkLogPolishComposer` 已有测试引用，继续补齐并记录。
- 按 TDD 增加 `testWorkLogPolishPromptPreservesFactsAndStructure`，锁定目标读者、不要编造、保留项目名/日期/数字等约束。
- `WorkLogPolishComposer.prompt` 生成中文工作日志汇报润色 prompt，只基于草稿润色，要求保留原小节结构和事实，信息不足时不补细节；工作日志导出菜单新增“AI 润色汇报”，配置 OpenAI Key 后会生成 txt 导出稿。

## 2026-06-24T01:36:00+08:00

- 进入并完成阶段 74：工作日志团队周报模板。阶段 73 已把 AI 润色接入导出菜单，本轮继续补团队协作场景的确定性导出模板。
- 开工前通过 GitHub API 检索团队状态报告、周报、OKR 周报和事故复盘 Markdown 模板，精确查询没有返回可直接复制进当前 SwiftUI/iOS 工程的模块。
- 按 TDD 增加 `testWorkLogExporterBuildsTeamWeeklyReportDraft`，锁定团队周报应输出项目/日期、本周成果、关键影响、风险/需要协作和下周重点。
- `WorkLogExporter.ReportDraftStyle` 新增 `.teamWeekly`，工作日志导出菜单新增“团队周报”；README、隐私政策、App Store metadata 和上架清单同步补充工作日志 AI 润色会发送工作汇报草稿到 OpenAI API 的说明。

## 2026-06-24T01:48:00+08:00

- 进入并完成阶段 75：本地 AI 搜索 NaturalLanguage 分词增强。阶段 74 推送后最新 CI 仍在运行，本轮继续处理无 Key AI 搜索质量缺口。
- 开工前检索 Swift/NaturalLanguage/本地模糊搜索候选，未找到可直接复制进当前笔记搜索链路的成熟模块；继续复用 Apple 系统 `NaturalLanguage`。
- 按 TDD 增加 `testLocalSemanticSearchTokenizesCompactChinesePhrases`，要求“团队周报模板”能命中“工作日志团队周报导出”，并展示“团队/周报”命中词。
- `SemanticSearchEngine.localSearchTerms` 新增 `NLTokenizer(unit: .word)` 分词结果，连续中文短语会补“团队、周报、模板”这类词；低权重二字碎片仍参与打分，但命中词展示优先隐藏碎片，减少 UI 噪音。

## 2026-06-24T02:18:00+08:00

- 进入并完成阶段 76：App Group 旧存储迁移测试。阶段 75 最新 CI 仍在运行，本轮继续处理 P0 的 Share Extension/App Group 边界测试缺口。
- 开工前检索 App Group 共享容器迁移、Share Extension 数据共享和 SQLite 伴随文件迁移讨论；本轮不引入 GRDB/Realm/CoreData 迁移库，只覆盖项目已有文件拷贝逻辑。
- 按 TDD 增加 `testSharedStorageCopiesLegacyMemoFilesIntoSharedDirectoryWithoutOverwriting`，锁定旧 Documents 中的 JSON 备份、SQLite、WAL、SHM 会迁入共享目录，且已有共享主 JSON 不会被旧文件覆盖。
- `SharedMemoStorage.urls(filename:storageDirectory:standardDirectory:)` 从私有放宽为模块内可见，方便单元测试直接覆盖纯迁移逻辑，不改变主 App/Extension 运行路径。

## 2026-06-24T02:30:00+08:00

- 进入并完成阶段 77：App Shortcuts 打开常用工作区。阶段 76 后继续处理快速入口缺口，让快捷指令不只可保存随记，也能打开高频页。
- 开工前复查 App Intents、URL Scheme、Widget 深链和 `MemoHomeMode`；检索 App Intents 打开指定 tab/route 候选，未找到可直接复制进当前状态模型的模块。
- 新增 `OpenZenIntent`、`OpenWorkLogIntent`、`OpenWardrobeIntent` 和 `OpenAIWorkspaceIntent`，通过 App Group `UserDefaults` 写入待打开目标，App 激活时消费并切换首页模式。
- 新增 `testAppShortcutRouteStoreOpensAndConsumesDestination`，覆盖快捷指令目标只消费一次，并清空旧搜索条件。

## 2026-06-24T03:05:00+08:00

- 进入阶段 78：衣橱真实天气底座。阶段 77 最新提交已推送，前序 74/75/76 的远端 CI 均已成功，最新 App Shortcuts run 仍在运行；本轮继续处理衣橱“真实天气 API”缺口。
- 开工前检索 Swift/Open-Meteo 开源客户端和官方 forecast/geocoding 文档；没有找到比直接调用官方无 Key JSON API 更适合当前本地草稿的可复制模块。
- 按 TDD 增加 `testOpenMeteoWeatherServiceBuildsRequestURLsAndSummary`，锁定 geocoding URL、forecast URL、天气码/温度/降雨概率解析和本地备注文案。
- 新增 `OpenMeteoWeatherService`，衣橱打包页增加“获取天气”按钮；用户主动点击时按目的地查询 Open-Meteo，并把天气摘要和来源备注填入本地打包草稿，不请求持续定位、不后台上传。

## 2026-06-24T03:34:00+08:00

- 进入并完成阶段 79：图片编辑裁剪方向与翻转。阶段 78 收口时发现并行窗口留下的图片裁剪方向正向碎片，本轮继续补齐为独立阶段。
- 开工前复核 Mantis、SwiftyCrop、TOCropViewController、ZLImageEditor 等 MIT 候选；当前项目已有可测试的 `ImageEditRecipe`、裁剪画布与 renderer，直接接大依赖会引入状态迁移和工程风险，本轮先补项目内方向变换。
- 按 TDD 增加 `testImageEditRendererAppliesCropTransformBeforeCropping` 与 `testImageEditRendererBuildsTransformedCropPreviewImage`，锁定裁剪前旋转/翻转、预览尺寸和文件名 token。
- `ImageEditRecipe.CropTransform` 新增 90°/180°旋转、水平翻转、垂直翻转；`ImageEditRenderer` 在裁剪前应用同一变换，`ImageEditorView` 裁剪模式新增方向菜单和翻转按钮，保存后的图片作品正文会记录“方向”。

## 2026-06-24T03:50:00+08:00

- 进入并完成阶段 80：衣橱胶囊打包建议。阶段 78/79 已在当前仓库提交，工作树重新校准为干净；本轮继续处理极简衣橱类应用的胶囊衣橱缺口。
- 开工前检索 `capsule wardrobe app Swift MIT`、`virtual closet Swift outfit planner MIT`、`wardrobe outfit planner SwiftUI MIT` 和 `closet app outfit planner open source MIT`，没有找到能直接复制进当前 SwiftUI/本地素材索引架构的成熟 Swift/MIT 模块。
- 按 TDD 增加 `testWardrobePackingSuggestionsIncludeCapsuleWardrobeSet`，锁定胶囊打包建议应使用最近目的地/天气，优先基础色、跨场景、低重复穿着的单品，并避开不合场景的高饱和单品。
- `WardrobeInsightEngine` 新增 `packing-capsule` 建议：按上装、下装、外套、鞋履、包包、饰品选择胶囊组合，备注中说明基础色、跨场景和可互相搭配；衣橱页继续复用现有“打包建议”卡片，一键填入旅行打包草稿。

## 2026-06-24T04:20:00+08:00

- 进入并完成阶段 81：每日回顾摘要与连续记录。继续补 flomo 类产品的回顾/习惯化体验缺口，让回顾页不只是随机翻旧记录。
- 开工前复查回顾页、统计页、`MemoStore.dailyStats`、阶段 80 CI 状态和历史碎片；发现最新远端 run 在 `Run tests` 12 分钟超时，未出现业务断言 annotation，本轮同步把 CI 测试步骤 timeout 提高到 20 分钟。
- 按 TDD 增加 `testReviewSummaryCountsTodayStreakAndReviewBacklog`，锁定今日记录数、连续记录天数、7 天前可回顾旧记录数量和提示文案。
- 新增 `MemoReviewSummary` 与 `MemoStore.reviewSummary`，回顾页顶部显示“今日/连续/可回顾”三项指标，并保留历史今天、随机回顾和标签入口。

## 2026-06-24T12:42:00+08:00

- 进入并完成阶段 82：旧记录回看入口。阶段 81 已有可回顾数量，本轮让它变成可点击的旧记录列表。
- 开工前继续检索 SwiftUI 日记回顾、streak、spaced repetition 和随机 memo 回顾开源候选；未找到适合直接复制进当前 SwiftUI/本地素材索引架构的许可清晰模块。
- 按 TDD 增加 `testReviewBacklogMemosReturnsOldestActiveCandidates`，锁定 7 天前活跃记录才进入回看列表、归档记录排除、旧记录按创建时间从旧到新展示。
- `MemoStore.reviewBacklogMemos` 新增最多 3 条旧记录候选，`ReviewView` 新增“旧记录回看”区块，复用 `NavigationLink` 与 `MemoRowView` 直接打开详情。

## 2026-06-24T12:58:00+08:00

- 进入并完成阶段 83：链接导入跟踪参数去重。阶段 82 新 CI 已通过 build 并进入 Run tests，本轮继续处理网页摘录/分享导入的重复链接噪音。
- 开工前检索 Swift URL normalization / remove utm 参数候选，GitHub Search 未找到可直接复制的 Swift/MIT 小模块；本轮只做项目内去重 key，不引入依赖。
- 新增 `testLinkExtractorDeduplicatesTrackingParameterVariants` 和 `testSharedMemoComposerDeduplicatesTrackingParameterVariants`，覆盖输入卡片检测与 Share Extension 文本合成两条路径。
- `LinkExtractor.deduplicationKey` 使用 `URLComponents` 去除 fragment、`utm_*`、`fbclid`、`gclid`、`gbraid`、`wbraid`、`yclid`、`mc_cid`、`mc_eid`、`igshid`、`spm` 后排序 query 作为去重 key；保存时仍保留第一条原始 URL。

## 2026-06-24T12:42:21+08:00

- 进入并完成阶段 84：网页摘录卡跟踪参数去重。阶段 83 只覆盖 URL 检测和分享文本合成，本轮继续补同一规则在网页摘录卡素材解析里的遗漏。
- 红灯探针确认旧 `LinkExtractor.webClips(in:)` 会把两个 tracking 变体网页摘录解析成 2 个 clip；绿灯探针确认修复后只保留第一条原始 URL 和摘要。
- 新增 `testLinkExtractorDeduplicatesWebClipTrackingParameterVariants`，锁定网页摘录卡解析复用 `deduplicationKey`，避免素材索引重复生成同一网页。

## 2026-06-24T13:18:00+08:00

- 进入并完成阶段 85：工作日志会议纪要导出。阶段 83/84 的远端 run 仍在运行，本轮继续补工作日志真实办公输出缺口。
- 开工前检索会议纪要 Markdown 模板和 Swift 工作日志会议纪要候选，GitHub Search 没有可直接复制进当前 Swift 导出器的模块。
- 新增 `testWorkLogExporterBuildsMeetingMinutesDraft`，锁定会议纪要输出项目/日期、议题/结论、待确认、行动项和备注。
- `WorkLogExporter.ReportDraftStyle` 新增 `.meetingMinutes`，工作日志导出菜单新增“会议纪要” txt 导出项，复用现有字段抽取和分享文件流程。

## 2026-06-24T13:35:00+08:00

- 进入并完成阶段 86：OCR 置信度保存。开工前检索 Vision OCR confidence Swift/MIT 候选，未找到可直接复制的小模块；Apple Vision 已提供 `VNRecognizedText.confidence`，本轮直接复用系统返回值。
- 红灯探针确认旧 `ImageTextRecognizer` 没有 `RecognizedLine` 置信度模型；新增 `testImageTextRecognizerBuildsMemoTextWithConfidenceSummary`，锁定去重后平均/最低置信度格式。
- `ImageTextRecognizer` 新增 `RecognizedLine`、`recognizeTextLines` 和带置信度的 `memoText` 重载；快速导入图片、连续扫描和详情页框选 OCR 都改为保存平均/最低置信度。

## 2026-06-24T13:45:00+08:00

- 进入并完成阶段 87：衣橱长途天气打包增强。开工前检索 travel packing/weather wardrobe Swift/MIT 候选，未找到适配当前本地素材索引的可复制模块。
- 新增 `testWardrobePackingSuggestionsAddWeatherEssentialsForLongTrips`，覆盖 4 天晴热阵雨旅行应补可替换上装、防水风衣、防水凉鞋、折叠伞和太阳帽。
- `WardrobeInsightEngine` 新增 `PackingWeatherNeeds`，按高温、阵雨、低温扩展打包选择和备注；阶段 85 最新远端 CI run `28075916766` 已 completed/success。

## 2026-06-24T14:02:00+08:00

- 进入并完成阶段 88：OCR 批量校对清单。开工前检索 OCR text correction Swift/MIT 候选，未找到可直接复制的轻量模块。
- 红灯探针确认旧 `ClipFragmentExtractor` 没有 `ocrProofreadingChecklist`；新增 `testClipFragmentExtractorBuildsOCRProofreadingChecklist`，覆盖跳过置信度/扫描页/附件行、多 OCR 块去重和来源聚合。
- `ClipFragmentExtractor.ocrProofreadingChecklist` 复用现有 OCR fragment 解析生成 Markdown 待办清单；详情页图片文字区域新增“生成 OCR 校对清单”按钮，追加到当前记录。

## 2026-06-24T14:28:00+08:00

- 进入并完成阶段 89：低置信度 OCR 待校对筛选。阶段 88 已有校对清单入口，本轮继续让用户能先筛出最需要校对的 OCR 记录。
- 开工前检索 OCR confidence review queue / Vision OCR 校对候选；`SwiftOCRKit` 许可清晰但只是 OCR wrapper，不覆盖 some 的本地 memo 搜索筛选，本轮不引入依赖。
- `MemoContentFilter` 新增 `ocrReview`，搜索支持 `has:ocr-review`、`has:待校对`、`has:低置信度` 等别名。
- `ClipFragmentExtractor.needsOCRReview` 解析 `置信度：平均 XX% · 最低 YY%` 行，最低任一百分比低于 70% 且存在 OCR fragment 时才归入待校对；`MemoStore` 全局搜索和工作日志来源筛选复用该规则。

## 2026-06-24T14:52:00+08:00

- 进入并完成阶段 90：Markdown fenced code block 阅读渲染。当前列表和详情页只有逐行 `AttributedString(markdown:)`，代码块会被拆成普通行，且代码里的 `- [ ]` 有误识别成任务的风险。
- 开工前检索 MarkdownUI / swift-markdown / SwiftUI code block renderer 候选；完整 Markdown 引擎适合后续大改，本轮只补本地轻量块级解析，不引入依赖。
- `MarkdownMemoBlockParser` 会把成对或未闭合的 fenced code block 聚合为代码块，支持可选语言标签；代码块内任务文本不会产生可勾选任务，代码块后的任务继续保留原始行号。
- `MarkdownMemoTextView` 用等宽字体、横向滚动和边框渲染代码块，列表与详情页自动复用。

## 2026-06-24T15:02:00+08:00

- 进入并完成阶段 91：Markdown 标题与引用块阅读渲染。阶段 90 已建立轻量块级解析器，本轮继续补最常见的标题和引用结构。
- 开工前检索 SwiftUI Markdown heading / blockquote 小型渲染模块，未找到可直接复制的 MIT 模块；完整 Markdown 引擎仍留作后续大改候选。
- `MarkdownMemoBlockParser` 新增 heading 和 quote block：标题只识别 `# ` 到 `###### ` 这种带空格 Markdown 语法，`#产品/输入` 仍保持普通正文/标签语义；连续 `>` 行会合并为一个引用块。
- `MarkdownMemoTextView` 用不同字号渲染标题，用左侧色条和浅底色渲染引用块，列表和详情页继续共用。

## 2026-06-24T15:35:00+08:00

- 进入并完成阶段 92：OCR 版面分区摘要。阶段 91 最新提交已在 `origin/master`，阶段 90 远端 CI 已 success，阶段 91 两个 run 仍在运行；等待期间继续处理 README 与 findings 中明确的 OCR 版面分区缺口。
- 开工前检索 Swift Vision OCR layout / boundingBox / document layout analysis 候选，未找到可直接复制进当前 SwiftUI 本地 memo/OCR/素材索引的轻量 MIT 模块；本轮复用 Apple Vision 行框信息。
- 先写 `testImageTextRecognizerBuildsMemoTextWithLayoutSections` 和 `testImageTextRecognizerKeepsOldMemoFormatWithoutLayoutRegions`，锁定有行框位置时输出“版面分区：左栏/右栏/顶部/中部/底部”，无位置数据时继续保持旧 OCR memo 格式。
- `ImageTextRecognizer.RecognizedLine` 新增可选 `region`，Vision OCR 结果从 `VNRecognizedTextObservation.boundingBox` 转成项目已有 `ImageTextRegion`；带置信度的 `memoText` 会在“识别文字”前保存轻量版面分区摘要，不污染后续 OCR fragment、待校对清单或 `has:ocr` 搜索解析。

## 2026-06-24T16:05:00+08:00

- 进入并完成阶段 93：Markdown 表格与分隔线阅读渲染。阶段 92 已提交推送，本轮继续补 README 中 Markdown 表格缺口。
- 开工前检索 MarkdownUI / swift-markdown / SwiftUI Markdown table renderer / 附件卡片候选；完整引擎仍保留为后续候选，但本轮为了不影响任务勾选行号、引用折叠和附件解析，继续扩展项目内轻量块级解析器。
- 新增 `testMarkdownMemoBlockParserGroupsTables`、`testMarkdownMemoBlockParserKeepsPipeTextWithoutTableSeparatorAsLines` 和 `testMarkdownMemoBlockParserExtractsDividers`，覆盖 GFM 风格表头/分隔/数据行、普通管道文本不误判，以及 `---` 分隔线。
- `MarkdownMemoBlockParser` 新增 table/divider block，代码块内表格符号仍保持代码；`MarkdownMemoTextView` 用横向滚动、稳定单元格宽度、表头底色和边框渲染表格，用现有边框色渲染分隔线。

## 2026-06-24T16:24:00+08:00

- 进入并完成阶段 94：Markdown 附件卡片预览。阶段 93 已提交推送，继续处理 Markdown 阅读中附件引用只能以普通预览区堆叠的问题。
- 开工前检索 SwiftUI 附件卡片/Markdown 附件渲染、MarkdownUI、swift-markdown、Textual 和 MoeMemos 附件候选，未找到可直接复制的小型 MIT 模块；本轮复用 some 现有 `AttachmentPreviewList` 和 `SharedAttachmentStore.attachments(in:)`。
- 新增 `testMarkdownMemoBlockParserExtractsAttachmentCards`、`testMarkdownMemoBlockParserKeepsAttachmentReferencesInsideCodeBlocks`、`testMemoReferenceParserKeepsAttachmentReferencesVisibleInReadableText`，覆盖独立附件引用行成为 attachment block，代码块里的附件引用仍保持原样，隐藏引用后附件行和任务行号仍正确。
- `MarkdownMemoTextView` 新增 attachment block 和显式初始化器，列表行直接用完整 memo 文本渲染为紧凑附件卡片；详情页按原文位置渲染附件卡片，并用 `MemoReferenceParser.originalLineIndex` 维持任务勾选映射。

## 2026-06-24T16:52:00+08:00

- 进入并完成阶段 95：OCR 行级阅读顺序整理。继续处理阶段 92 留下的“有行框但识别文字顺序仍可能跟 Vision 返回顺序走”的缺口。
- 开工前检索 Swift Vision OCR reading order / boundingBox 候选，未找到可直接复制进 some 本地 OCR 保存链路的小型 MIT 模块；本轮继续复用 Apple Vision 行框和项目已有 `ImageTextRegion`。
- 新增 `testImageTextRecognizerOrdersRecognizedLinesByLayoutPosition`，覆盖 Vision 返回顺序打乱时，保存的“识别文字”仍按上到下、同一行左到右输出。
- `ImageTextRecognizer` 在去重后仅对全部带 region 的 `RecognizedLine` 做阅读顺序排序；无行框或部分行缺行框时保持旧输入顺序，避免影响旧 OCR 文本。

## 2026-06-24T17:18:00+08:00

- 进入并完成阶段 96：Markdown 脚注定义阅读渲染。阶段 95 已提交到当前 HEAD，本轮继续补 Markdown 阅读里脚注定义仍只是普通正文的问题。
- 开工前检索 SwiftUI Markdown footnote renderer、MarkdownUI footnotes 和 swift-markdown footnote support 候选；完整 Markdown/GFM 引擎仍作为后续候选，本轮不引入大依赖。
- 新增 `testMarkdownMemoBlockParserGroupsFootnotes` 和 `testMarkdownMemoBlockParserKeepsFootnotesInsideCodeBlocks`，覆盖连续脚注定义聚合、后续任务行号保持原始行号，以及代码块内脚注样式不被解析。
- `MarkdownMemoBlockParser` 新增 footnotes block，`MarkdownMemoTextView` 用轻量脚注区展示脚注 id 和正文；README 同步到 Markdown 阅读渲染 v6。

## 2026-06-24T17:45:00+08:00

- 进入并完成阶段 97：OCR 表单字段候选摘要。阶段 96 最新提交已推送，阶段 95 远端 CI 已 success，阶段 96 仍在运行；等待期间继续处理 OCR 表单/字段级校对缺口。
- 开工前检索 Swift Vision OCR key-value extraction、iOS Vision OCR form field extraction、VNRecognizedTextObservation table extraction 和 Swift receipt OCR parser 候选，GitHub Search 均返回 0 个可直接复制的小型 Swift/MIT 模块。
- 新增 `testImageTextRecognizerBuildsFieldCandidatesForFormLikeLines`、`testImageTextRecognizerSkipsFieldCandidatesForSingleLabelLine` 和 `testImageTextRecognizerSkipsURLSchemeFieldCandidates`，覆盖两行以上 `字段：值` / `字段: 值` 才生成“字段候选”，单个提示行和 URL scheme 不误判。
- `ImageTextRecognizer` 在带置信度 OCR memo 里新增字段候选摘要：短字段名去重、最多展示前四项，原始“识别文字”仍完整保留，复杂表格结构和自动字段纠错继续留作后续。

## 2026-06-24T18:10:00+08:00

- 进入并完成阶段 98：工作日志自定义导出模板。阶段 97 已提交推送且远端 CI 正在运行，本轮继续处理工作日志真实团队格式缺口。
- 开工前检索 work log custom report template、Swift markdown template engine、Swift work report template engine 和 daily report custom template 候选，GitHub Search 均返回 0 个可直接复制的小型 Swift/MIT 模块。
- 新增 `testWorkLogExporterBuildsCustomTemplateDraft` 和 `testWorkLogExporterCustomTemplateKeepsUnknownPlaceholdersVisible`，覆盖 `{{项目}}`、`{{日期}}`、`{{进展列表}}`、`{{风险列表}}`、`{{下一步列表}}`、`{{备注列表}}` 渲染，以及未知占位符保留。
- `WorkLogExporter.customReportDraft` 支持可编辑纯文本模板，复用现有工作日志字段抽取、排序和去重；工作日志页新增本机保存的自定义模板编辑区和“自定义模板”导出项。

## 2026-06-24T18:40:00+08:00

- 进入并完成阶段 99：OCR 分隔符表格候选摘要。阶段 98 已由并行流程提交推送并与 `origin/master` 同步，本轮继续处理 OCR 表格扫读缺口。
- 开工前检索 Apple Vision 表格识别、Swift Vision OCR table extraction、VNRecognizedTextObservation table detection 和 Swift receipt OCR table parser 候选；未找到适合直接复制进当前本地 OCR/memo 链路的小型 Swift/MIT 模块。
- 新增 `testImageTextRecognizerBuildsTableCandidateForDelimitedRows` 和 `testImageTextRecognizerSkipsTableCandidateWithoutDataRows`，覆盖 `|` 分隔的表头+数据行会生成“表格候选”，只有表头或无匹配数据行时不误判。
- `ImageTextRecognizer` 新增分隔符型表格候选摘要，支持 `|`、全角 `｜` 和 tab，输出列数、数据行数和前四列表头；原始识别文字仍完整保留，复杂表格结构和自动纠错继续留作后续。

## 2026-06-24T19:05:00+08:00

- 进入并完成阶段 100：素材库媒体摘要缓存只读刷新。继续前复查工作树碎片，发现 `MediaMetadataExtractor`、`AssetLibraryView` 和媒体缓存测试已有正向半成品，先收拢为独立阶段。
- 开工前检索 SwiftUI media metadata prefetch cache、AVAsset/ImageIO metadata cache 和 iOS media asset metadata preheat cache 候选，GitHub Search 均返回 0 个可直接复制的小型 Swift/MIT 模块。
- 新增 `testMediaMetadataCachedSummaryOnlyUsesPreheatedCache`，覆盖素材库行读取的 `cachedSummary` 不会自行解析文件，只有 `preheatSummaries` 后才返回摘要。
- `MediaMetadataExtractor` 抽出统一 summary cache key 并暴露只读 `cachedSummary`；素材库后台预热媒体摘要后递增 `mediaCacheVersion` 刷新行视图，`AssetRowView` 改为只读缓存，避免滚动列表时同步读取图片/音频/视频元数据。

## 2026-06-24T19:35:00+08:00

- 进入并完成阶段 101：禅定字数目标。阶段 100 文档碎片已提交并推送，继续处理 findings 中“可补更多禅定模式偏好”的快速记录缺口。
- 开工前检索 SwiftUI zen writing word goal、distraction free writing word count goal 和 focus editor writing target 候选，GitHub Search 均返回 0 个可直接复制的小型 SwiftUI/MIT 模块。
- 按 TDD 新增 `testZenWritingGoalSummarizesProgress` 和 `testZenWritingGoalClampsProgressFraction`，覆盖未知 raw value 回退、目标标题、进度文案和进度比例 clamp。
- `ZenWritingGoal` 提供无目标、100、300、500、1000 字目标；`ZenCaptureView` 用 `@AppStorage("some.zenWritingGoal")` 保存选择，专注模式顶部新增目标菜单，底部在有目标时显示字数进度和 `ProgressView`。

## 2026-06-24T20:05:00+08:00

- 进入并完成阶段 102：图片附件缩略图缓存。继续处理素材库真实长列表性能缺口，重点是素材库和附件卡片图片预览还会在行渲染时 `UIImage(contentsOfFile:)` 直接解码原图。
- 开工前检索 Swift 本地图片缩略图缓存、ImageIO 下采样、Kingfisher/Nuke/CachedAsyncImage/SDWebImage/AlamofireImage 等候选；这些项目多面向远程图片下载缓存，当前只需要本地附件小图，因此继续复用 Apple ImageIO 和 App Group 本地缓存目录。
- 新增 `testImageThumbnailGeneratorCachesDownsampledImage` 和 `testImageThumbnailPreheatFiltersDeduplicatesAndReportsMissingFiles`，覆盖本地图像下采样、缓存文件写入、只读缓存命中、素材 URL 去重、非图片过滤和缺失文件失败统计。
- 新增 `ImageThumbnailGenerator`，用 `CGImageSourceCreateThumbnailAtIndex` 生成小图并缓存到 `ImageThumbnailCache`；`AttachmentPreviewList` 和素材库 `AssetRowView` 改用异步 `ImageThumbnailPreview`，素材库进入或素材变化时批量预热图片缩略图。

## 2026-06-24T20:30:00+08:00

- 进入并完成阶段 103：手帐列表图片图层缩略图缓存。阶段 102 已提交推送后继续扫描同步原图解码点，确认手帐列表预览仍在 `ScrapbookPagePreview.previewLayer` 里直接 `UIImage(contentsOfFile:)`。
- 开工前复检 SwiftUI 本地文件缩略图缓存、Kingfisher、Nuke、SDWebImageSwiftUI 和 Apple ImageIO 候选；当前缺口只需要复用本项目 App Group 本地缩略图缓存，不引入远程图片库。
- 新增 `ImageThumbnailGenerator.previewMaximumPixelSize(width:height:scale:)` 和 `testImageThumbnailPreviewPixelSizeUsesScaledLayerBounds`，锁定手帐预览按图层显示尺寸生成小图且最低 64px 的策略。
- 新增 `ImageThumbnailFillPreview`，手帐列表图片图层改为异步加载 `ImageThumbnailGenerator` 小图缓存，保持原来的裁切填充和圆角外观，避免列表预览同步解码原图。

## 2026-06-24T20:55:00+08:00

- 进入并完成阶段 104：手帐编辑器图片图层缩略图预览。阶段 103 推送后继续扫描剩余同步解码点，确认手帐编辑器图片图层仍在 SwiftUI body 里 `UIImage(contentsOfFile:)` 读原图并套滤镜。
- 开工前复检 SwiftUI 本地图片缓存、ImageIO 缩略图、Kingfisher 和 Nuke 候选；当前不需要远程图片加载库，继续复用 `ImageThumbnailGenerator` 与 `ScrapbookImageFilterRenderer`。
- `ImageThumbnailGenerator.previewMaximumPixelSize` 新增 `layerScale`，并增加 `testImageThumbnailPreviewPixelSizeIncludesLayerScale`，让编辑器预览按画布缩放和图层缩放计算小图尺寸。
- 新增 `AsyncScrapbookImageLayerPreview`，编辑器图片图层异步读取缩略图缓存并后台套照片滤镜，仍按原有取景位置/放大倍率显示；PNG/PDF 导出 renderer 保留原图路径，避免降低导出清晰度。

## 2026-06-24T21:20:00+08:00

- 进入并完成阶段 105：本地 AI 搜索单字符 typo 容错。阶段 104 文档收口后继续处理 findings 中 AI 本地搜索模糊匹配缺口。
- 开工前检索 Swift fuzzy search / Levenshtein 候选，确认可用库偏完整 fuzzy finder 或多年未维护；当前只需防漏英文/数字关键词单字符 typo，因此不引入依赖。
- 新增 `testLocalSemanticSearchMatchesSingleTypoEnglishTerm`，覆盖 `roadmapp` 能命中正文里的 `roadmap` 且命中词展示为原 memo 词。
- `SemanticSearchEngine.localSearch` 在没有精确共享词时才启用 ASCII 英文/数字编辑距离 1 匹配，并以低权重计分，避免覆盖标签、中文片段和已有精确词排序。

## 2026-06-24T21:45:00+08:00

- 进入并完成阶段 106：图片缩略图缓存孤儿清理。阶段 105 推送后继续处理媒体缓存长期累积缺口，确认视频缩略图已有 prune，图片缩略图还只有生成/预热。
- 开工前检索 Swift 图片缩略图缓存清理候选，未找到可直接复制的小型 Swift/MIT 模块；本轮复用项目内视频缓存维护模式。
- 新增 `testImageThumbnailPruneCacheKeepsExpectedFile`，覆盖删除不再引用的图片缩略图缓存，同时保留当前源图的多个尺寸缓存。
- `ImageThumbnailGenerator` 新增 `pruneCache`，缓存文件名改为源图版本前缀 + 目标尺寸；素材库维护周期在预热图片缩略图后清理 `ImageThumbnailCache` 孤儿 `.jpg`。

## 2026-06-24T22:20:00+08:00

- 进入并完成阶段 107：图片编辑器预览缩略图。继续处理媒体预览性能缺口，复查工作树碎片时发现图片编辑器已有半成品改动，优先收拢而不是丢弃。
- 开工前检索 `Mantis`、`TOCropViewController`、`ZLImageEditor` 和 `FMPhotoPicker` 等开源图片编辑/裁剪项目；这些候选适合替换整套图片编辑器，但当前 some 已有图片编辑菜谱、素材附件、工作流日志和保存复现格式，直接引入会破坏现有数据流。本轮继续复用本项目 `ImageThumbnailGenerator` 和 Apple ImageIO。
- 新增 `testImageThumbnailEditorPreviewDownsamplesLargeSource` 和 `testAddImageEditRendersFromFullResolutionSource`，分别覆盖编辑器预览使用 1600px 缩略图、大图保存仍从原图尺寸渲染。
- `ImageEditorView` 打开时异步加载 `ImageThumbnailGenerator.imageEditorPreviewMaximumPixelSize` 缩略图作为编辑预览，避免在 SwiftUI body/onAppear 同步 `UIImage(contentsOfFile:)` 解码原图；`MemoStore.addImageEdit` 仍在保存时从附件 URL 读取原图渲染，保证导出清晰度。

## 2026-06-24T22:45:00+08:00

- 进入并完成阶段 108：图片缩略图清理保留全集。阶段 107 推送后继续复查媒体缓存生命周期，发现素材库维护把 `ImageThumbnailGenerator.sourceURLs` 的默认 120 个预热上限同时用于 `pruneCache(keeping:)`，真实长列表里第 121 张以后仍被引用的图片缩略图可能被误删。
- 开工前检索 Swift 图片缩略图缓存清理、Kingfisher 和 Nuke 缓存裁剪候选；通用图片库仍不适合直接复制进 some 的 App Group 素材索引清理。本轮按根因修复本项目代码：预热仍限量，清理使用全量引用集。
- 新增 `testImageThumbnailSourceURLsCanReturnAllReferencedImagesForPruning`，覆盖 `limit: 1` 只返回一个预热 URL，但 `limit: nil` 返回所有引用图片 URL。
- `ImageThumbnailGenerator.sourceURLs` 的 `limit` 改为可选；素材库 `maintainMediaCaches` 继续用默认上限预热图片缩略图，同时用 `limit: nil` 的全量图片 URL 调用 `pruneCache`，避免误删仍被引用的小图。

## 2026-06-24T23:10:00+08:00

- 进入并完成阶段 109：OCR 框选预览缩略图。阶段 108 收口后继续扫同步原图读取点，确认详情页 `ImageTextRegionPickerView` 仍在 SwiftUI body 里直接 `UIImage(contentsOfFile:)` 读取原图用于框选预览。
- 开工前复查 Mantis、SwiftyCrop、TOCropViewController 和 SwiftOCRKit。它们都是可继续评估的 MIT 候选，但本轮只是局部预览性能修补，直接引入完整裁剪器或 OCR wrapper 会比复用现有 ImageIO 缩略图更重。
- 新增 `testImageThumbnailTextRegionPreviewMaximumPixelSizeMatchesEditorPreview`，锁定 OCR 框选预览与图片编辑器同用 1600px 大图交互预览上限。
- `ImageTextRegionPickerView` 改为 `onAppear` 后台加载 `ImageThumbnailGenerator.imageTextRegionPreviewMaximumPixelSize` 缩略图，并显示加载态；“识别区域”仍把归一化区域交给外层 `recognizeText`，后者继续读取原始附件数据做 OCR。

## 2026-06-24T23:25:00+08:00

- 进入并完成阶段 110：视频缩略图清理保留全集。阶段 108 修复图片缩略图后继续审计同类代码，确认视频缩略图维护也把默认 60 个预热上限同时用于 `VideoThumbnailGenerator.pruneCache(keeping:)`。
- 开工前复查 Kingfisher/Nuke 缓存裁剪候选和项目内 `VideoThumbnailGenerator`，根因仍是 some 自己的素材引用集合和预热集合混用，不适合引入第三方图片库。
- 新增 `testVideoThumbnailSourceURLsCanReturnAllReferencedVideosForPruning`，覆盖 `limit: 1` 只返回一个预热视频 URL，但 `limit: nil` 返回所有引用视频 URL；用 Swift typecheck 探针确认旧 `Int` limit 对 `nil` 会失败，新 `Int?` 签名通过。
- `VideoThumbnailGenerator.sourceURLs` 的 `limit` 改为可选；素材库 `maintainMediaCaches` 继续用默认上限预热视频缩略图，同时用 `limit: nil` 的全量视频 URL 调用 `VideoThumbnailGenerator.pruneCache`，避免误删仍被引用的视频缩略图。

## 2026-06-24T23:45:00+08:00

- 进入并完成阶段 111：附件预览媒体摘要只读缓存。阶段 110 推送后继续扫描同步媒体读取点，确认 `AttachmentPreviewList.detailText` 在详情附件区和 Markdown 附件卡中直接调用 `MediaMetadataExtractor.summary(for:)`。
- 开工前检索 SwiftUI 附件预览媒体摘要缓存、AVAsset/ImageIO metadata cache 候选；未找到适合直接复制进当前本地附件 UI 的小型模块，本轮继续复用项目内 `MediaMetadataExtractor.cachedSummary` / `preheatSummaries`。
- 新增 `testAttachmentPreviewDetailTextUsesCachedMediaSummaryOnly`，覆盖冷缓存时附件行只显示类型和文件大小，不主动解析图片尺寸；预热后才显示尺寸摘要。
- `AttachmentPreviewList` 改为只读 cached summary，并在出现或附件签名变化时后台预热图片/视频/音频摘要，预热成功后用本地版本号刷新附件行。

## 2026-06-24T23:55:00+08:00

- 进入并完成阶段 112：工作日志自定义模板元信息占位符。阶段 111 推送后继续处理工作区遗留碎片，确认 `WorkLogExporter.customReportDraft` 已有自定义模板但缺少日志总数、项目数、风险数、来源列表、创建时间列表和日期范围等真实汇报常用元信息。
- 开工前检索 Swift/Mustache 模板引擎和工作日志模板候选；GRMustache.swift 与 swift-mustache 都是完整模板引擎，当前需求只需受控占位符替换和未知占位符保留，因此不新增依赖。
- 新增 `testWorkLogExporterCustomTemplateIncludesSummaryMetricsAndSources`，覆盖 `{{日志数}}`、`{{项目数}}`、`{{风险数}}`、`{{下一步数}}`、`{{来源列表}}`、`{{创建时间列表}}` 和 `{{日期范围}}`。
- 默认自定义模板同步展示记录数、日期范围和来源列表；README、任务计划、发现、开源审计和验证记录同步到工作日志 v11。

## 2026-06-24T23:59:00+08:00

- 进入并完成阶段 113：衣橱搭配补齐鞋包饰品。阶段 112 推送后复查衣橱洞察，确认打包建议已经会选鞋履、包包和饰品，但普通天气/场景/季节/低频单品建议仍可能只返回衣服类组合。
- 开工前检索 Swift/iOS/open source wardrobe outfit planner、accessories/bags/shoes recommendation 候选；完整衣橱项目多为 Web/AGPL/后端栈或与当前本地 SwiftUI 模型不匹配，本轮不复制第三方代码。
- 新增 `testWardrobeSceneSuggestionsIncludeShoesBagsAndAccessories`，覆盖通勤场景搭配草稿应同时带出上装、下装、鞋履、包包和饰品。
- `WardrobeInsightEngine` 新增 `outfitBalancedItems`，普通天气、场景、季节和低频单品建议改用 outfit 专用选择器；打包清单仍保留按天数和天气扩展数量的独立选择逻辑。

## 2026-06-24T23:59:30+08:00

- 进入并完成阶段 114：OCR 区域表格与票据行候选。阶段 113 推送后继续复查网页摘录/OCR 缺口，确认阶段 99 只覆盖分隔符表格，尚不能扫读 Vision 拆成独立文本块的简单表格，也不能把餐饮小票的无分隔符金额行提前摘出。
- 开工前检索 `Swift Vision OCR receipt parser line items MIT`、`VNRecognizedTextObservation table extraction Swift GitHub MIT`、`Swift Vision OCR table MIT` 和 Apple Vision 表格/识别文档；GitHub 精确查询未返回可直接复制进当前本地 SwiftUI/OCR memo 链路的小型 Swift/MIT 模块，网页结果多为 LLM/服务端/完整示例项目，本轮继续复用 Apple Vision 行框与项目内轻量规则。
- 收拢并补齐 `testImageTextRecognizerBuildsTableCandidateFromAlignedRegions`，覆盖 Vision 行框按三列三行对齐时生成“表格候选”；新增 `testImageTextRecognizerBuildsReceiptLineCandidatesWithoutDelimiters` 和 `testImageTextRecognizerSkipsReceiptLineCandidatesForSingleAmountLine`，覆盖无分隔符小票行必须至少两条项目金额才生成“票据行候选”。
- `ImageTextRecognizer` 的“表格候选”先识别 `|` / `｜` / tab 分隔符，再退到行框横纵对齐的简单表格；另新增末尾金额行解析，跳过合计/小计/支付/税等汇总行，原始“识别文字”仍完整保留。

## 2026-06-24T23:59:50+08:00

- 进入并完成阶段 115：OCR 表格/票据候选搜索筛选。阶段 114 推送后继续处理同一 OCR 校对闭环，确认“表格候选”和“票据行候选”需要可组合的 `has:*` 语法。
- 先用临时 Swift 探针确认旧 `MemoSearchQueryParser` 会把 `has:ocr-table` / `has:receipt-lines` 留作普通文本；新增 `testSearchQueryParserExtractsOCRTableAndReceiptAliases` 和 store 搜索断言，覆盖英文与中文别名。
- `MemoContentFilter` 新增 `ocrTable`、`receiptLines`，`MemoStore.matchesContentFilter` 基于 OCR memo 中的“表格候选：”和“票据行候选：”摘要行筛选；README 同步 `has:ocr-table` / `has:表格候选`、`has:receipt-lines` / `has:票据行`。

## 2026-06-24T23:59:58+08:00

- 进入并完成阶段 116：OCR 字段候选搜索筛选。阶段 115 后继续复查 OCR 校对闭环，确认阶段 97 生成的“字段候选”仍不能像表格/票据行一样用 `has:*` 集中筛出。
- 开工前检索并复查 Memos、Joplin、macOCR、MiaoYan 等开源笔记/OCR 项目；它们能提供搜索、OCR 可搜索和本地优先笔记方向参考，但没有可直接复制进当前本地 memo/OCR 摘要格式的小型 Swift `has:*` 模块，本轮继续复用项目内 `MemoSearchQueryParser` 和 `MemoStore.matchesContentFilter`。
- 先用临时 Swift 探针确认旧 `MemoSearchQueryParser` 会把 `has:ocr-field` / `has:字段候选` 留作普通文本；新增 `testSearchQueryParserExtractsOCRFieldAliases` 和 store 搜索断言，覆盖英文与中文别名。
- `MemoContentFilter` 新增 `ocrField`，`MemoStore.matchesContentFilter` 基于 OCR memo 中的“字段候选：”摘要行筛选；README 同步 `has:ocr-field` / `has:字段候选`，任务计划、发现、审计和验证记录同步到 OCR v13。

## 2026-06-24T19:38:34+08:00

- 进入并完成阶段 117：工作日志来源支持 OCR 候选筛选。阶段 116 推送后复查日志勾选来源，确认搜索页已经能筛字段/表格/票据候选，但工作日志来源类型仍只露出 OCR 和待校对。
- 开工前检索工作日志来源筛选、OCR candidates 和 memo filter 候选；没有找到可直接复制进当前 SwiftUI 工作日志来源列表的小型 Swift/MIT 模块，本轮继续复用 `WorkLogSourceFilterEngine` 与 OCR 摘要行。
- 红灯探针确认旧 `WorkLogSourceFilterEngine` 在新增 `.ocrField`、`.ocrTable`、`.receiptLines` 后 switch 不穷尽；新增 `testWorkLogSourceFilterEngineCanFilterOCRCandidates`，覆盖字段/表格/票据候选分别筛出。
- 工作日志来源类型下拉新增“字段”“表格”“票据”，筛选引擎按“字段候选：”“表格候选：”“票据行候选：”摘要行匹配，让 OCR 提炼结果可直接进入日报、周报和项目汇总。

## 2026-06-24T23:59:59+08:00

- 复查远端 CI 时发现阶段 115 提交 `63341e3` 的 Build for simulator 失败，公开 annotation 明确指向 `WorkLogSourceFilterEngine.swift:109` 和 `ContentView.swift:1752` 的 `switch must be exhaustive`。
- 根因：新增 OCR 字段/表格/票据行 `MemoContentFilter` 后，主搜索筛选已接线，但工作日志来源筛选和来源标题两个 switch 没同步分支；本地 `swiftc -typecheck` 也复现了缺 `.ocrField`、`.ocrTable`、`.receiptLines`。
- 新增 `testWorkLogSourceFilterEngineCanFilterOCRCandidates`，覆盖工作日志来源筛选能按“字段候选：”“表格候选：”“票据行候选：”筛出对应 OCR memo；`sourceKindOptions` 下拉同步加入字段、表格和票据类型。

## 2026-06-24T23:59:59+08:00

- 进入并完成阶段 118：OCR 版面分区搜索与日志来源筛选。阶段 117 收口后继续复查阶段 92 的 OCR 版面摘要，确认“版面分区：”已经保存到 memo，但搜索和工作日志来源下拉都没有结构化入口。
- 开工前检索 `Swift Vision OCR layout sections search filter GitHub MIT`、`VNRecognizedTextObservation boundingBox layout section Swift GitHub MIT`、`open source notes OCR layout search filter GitHub` 和 `Joplin OCR search filters layout GitHub`；没有找到可直接复制进当前 SwiftUI memo 搜索/日志来源架构的小型模块，本轮继续复用项目内 `MemoSearchQueryParser`、`MemoStore.matchesContentFilter` 和 `WorkLogSourceFilterEngine`。
- 红灯探针确认旧 `MemoContentFilter` 没有 `.ocrLayout`，`has:ocr-layout` / `has:版面分区` 不能被解析为内容筛选；另用旧 `WorkLogSourceFilterEngine` 验证新增枚举会触发 switch 不穷尽。
- 新增 `testSearchQueryParserExtractsOCRLayoutAliases`，扩展内容类型搜索测试和工作日志来源候选测试；搜索语法新增 `has:ocr-layout` / `has:版面分区`，工作日志来源类型下拉新增“版面”，按“版面分区：”摘要行筛选多栏截图和扫描页。
