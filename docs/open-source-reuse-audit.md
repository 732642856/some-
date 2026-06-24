# 开源对标与复用审计

日期：2026-06-21，更新：2026-06-22

## 审计原则

- 先找成熟项目或库，再决定是否手写。
- 可直接复制或作为依赖优先级：MIT、Apache-2.0、BSD 等宽松许可证。
- MPL-2.0 可参考架构；如果复制单个文件，必须保留 MPL 文件级开源义务和版权声明，当前项目默认避免直接复制。
- GPL / AGPL / 无许可证项目只做产品和实现思路参考，不拷贝代码。
- 涉及 App Store 发布的代码，优先用 Swift Package Manager 依赖；只有小而稳定、许可证清晰的文件才考虑 vendoring。
- 每轮开发前必须重新检索本轮涉及的产品域和开源库，把候选、许可证、维护状态、是否可直接复制写入本文件；没有记录不得直接开写成熟功能。
- 直接复制代码前必须先记录来源 URL、许可证、版权声明、复制文件范围和本项目修改点；默认优先依赖系统框架或 SPM，而不是把大段源码混进仓库。

## 已深入对标项目

### MoeMemos

- 仓库：<https://github.com/mudkipme/MoeMemos>
- 许可证：MPL-2.0
- 状态：iOS 原生 memos 客户端，App Store 上架，维护活跃。
- 关键功能：本地/自托管两种模式、离线可用、自动同步、扩展 Markdown、图片/视频/文件附件、标签/置顶/搜索/归档、热力图、iPad/动态字体/深色模式、Share Extension、App Intents、Widgets。
- 本地已读源码位置：`/Users/wuyongnaren/Documents/Codex/2026-06-20/wo/work/open-source/MoeMemos`
- 可复用策略：不直接复制源码；参考模块边界和用户体验，尤其是 Share Extension 附件处理、App Intents、Widget、附件本地文件存储、导出 zip、memos API 同步。

### usememos/memos

- 仓库：<https://github.com/usememos/memos>
- 许可证：MIT
- 状态：自托管 memos 服务端/Web，生态核心。
- 关键功能：Markdown-native、memo relation、memo share、inbox、reaction、attachment、API、标签树、过滤、Memo Explorer。
- 本地已读源码位置：`/Users/wuyongnaren/Documents/Codex/2026-06-20/wo/work/open-source/memos`
- 可复用策略：可以参考/复制 MIT 许可下的 API schema、数据模型思想和导入导出格式；Web/Go 代码不能直接进入 iOS，但接口设计可作为 self-host sync 的目标。

## 可直接作为依赖的候选库

### Markdown / 富文本

- `gonzalezreal/textual`：<https://github.com/gonzalezreal/textual>，MIT，SwiftUI rich text / Markdown，较新，适合优先评估。
- `gonzalezreal/swift-markdown-ui`：<https://github.com/gonzalezreal/swift-markdown-ui>，MIT，成熟但已维护模式，仍可用于 Markdown 渲染。
- `swiftlang/swift-markdown`：<https://github.com/swiftlang/swift-markdown>，Apache-2.0，官方 Markdown AST 解析/改写，适合标签链接、任务项、批注/引用解析。
- `chrisdhaan/CDMarkdownKit`：<https://github.com/chrisdhaan/CDMarkdownKit>，MIT，UIKit/TextView 取向，可作备选。

建议：下一步做 Markdown 渲染时优先用 `Textual` 或 `MarkdownUI`；如果只需要解析和改写，优先用官方 `swift-markdown`。

2026-06-21 本轮实现决策：当前工作环境只有 Xcode 13.2.1，无法可靠验证 iOS 16+ 工程和 Swift Package 依赖；为避免手改 SPM 配置导致工程不稳定，先使用 iOS 系统 `AttributedString(markdown:)` 完成 Markdown 阅读渲染，并仅为 `- [ ]` / `- [x]` 任务项补一个很小的本地解析器。后续进入 Xcode 16 或更新环境后，完整块级 Markdown、引用、代码块和附件卡片仍优先评估 `Textual` / `MarkdownUI` / `swift-markdown`。

### SQLite / 存储

- `groue/GRDB.swift`：<https://github.com/groue/GRDB.swift>，MIT，成熟 SQLite toolkit，支持迁移、FTS、数据库观察，适合后续替换手写 SQLite 层。
- `stephencelis/SQLite.swift`：<https://github.com/stephencelis/SQLite.swift>，MIT，类型安全 SQLite 封装，星标高但 issue 较多。

建议：当前 `some` 已有可用 SQLite + FTS，短期不迁移；如果要做附件、历史版本、同步和复杂查询，优先引入 GRDB，而不是继续扩大手写 sqlite3 封装。

### Zip / 备份导出

- `weichsel/ZIPFoundation`：<https://github.com/weichsel/ZIPFoundation>，MIT，Swift-native ZIP 处理，SPM 友好。
- `ZipArchive/ZipArchive`：<https://github.com/ZipArchive/ZipArchive>，MIT，老牌 zip/unzip，C/Obj-C 依赖更多。

建议：做“导出 zip，按年月拆分 Markdown + 附件”时优先用 `ZIPFoundation`。

### 应用级对标但不宜直接复制

- `adamrdrew/TakeNote`：Markdown note app，许可证为 Other / NOASSERTION，不复制。
- `CodyBontecou/GitSync.md`：MIT，Git 同步 Markdown vault，可参考 Git/文件同步方向，但不是 flomo 式 memo 核心。
- `dscyrescotti/Memola`：MIT，iOS/macOS note app，可参考产品形态，但偏 Metal/通用笔记。
- `kg54ktdvxx-gif/Flash-Note`：无许可证，不复制；可参考 quick-capture、watch、Spotlight、voice notes 的功能方向。
- `carlomigueldy/NoteGraph`：无许可证，不复制；可参考 backlinks/knowledge graph 思路。

## 2026-06-22 新目标补充检索

用户已把 some 目标扩展为个人素材库、电子手帐、工作日志、网页摘录、图片编辑和电子衣橱。以下是本轮全网/GitHub 检索后的复用判断。

### 图片、视频、裁剪和编辑

- `guoyingtao/Mantis`：<https://github.com/guoyingtao/Mantis>，MIT，Swift，维护活跃，iOS 图片裁剪库，支持 SwiftUI 方向；做裁剪 MVP 时优先评估 SPM 接入。
- `TimOliver/TOCropViewController`：<https://github.com/TimOliver/TOCropViewController>，MIT，成熟 iOS 图片裁剪控件，Objective-C 为主但 Swift 可用；如果 Mantis 不适合，再评估它。
- `SilenceLove/HXPhotoPicker`：<https://github.com/SilenceLove/HXPhotoPicker>，MIT，Swift，图片/视频选择、预览、编辑能力很全；适合评估“相册选择 + 图片/视频编辑”大模块，但体量较大，不应盲目全量接入。
- `bevy/photo-editor`、`jogendra/phimpme-iOS`、`sprint84/PhotoCropEditor` 等 MIT 项目可做历史参考，但部分维护较旧；除非具体文件仍适配当前 iOS/Swift，否则不优先复制。
- 系统能力：PhotosUI / PHPicker、AVFoundation、Core Image、Vision、VisionKit 应优先使用。滤镜、边框、裁剪、基础拼贴可先靠系统框架实现；抠图/背景移除优先评估 Vision 前景分割能力。
- 2026-06-22 图片编辑 MVP 决策：阶段 10 开工前重新检查 Git 状态、全量文件清单、`imageEdit` 素材预留、附件存储和素材库边界，并通过 GitHub API 复查 `Mantis`、`TOCropViewController`、`SwiftUI Core Image photo editor MIT`。Mantis 与 TOCropViewController 均为 MIT 且适合后续自由裁剪；本轮为了控制工程风险，不引入 SPM/Objective-C 依赖，先用 Core Image + UIKit 绘制实现预设比例裁剪、滤镜、边框、文字和贴纸，输出为本地 PNG 附件。
- 2026-06-23 图片编辑增强决策：阶段 12 开工前再次复查 `Mantis`（MIT、Swift、活跃）和 `TOCropViewController`（MIT、成熟 ObjC），并检索 `SwiftUI image inpainting object removal MIT`，对象移除方向返回 0 个可直接复用候选。当前环境缺完整 Xcode/iOS SDK，不适合引入新 SPM 或 ObjC 桥接；本轮继续在现有 Core Image/UIKit 管线中增加裁剪中心/缩放微调和授权图片瑕疵清理贴片，后续完整手势裁剪器再接入 Mantis 优先评估。
- 2026-06-23 图片背景/抠图底座决策：阶段 19 开工前复查 `ImageEditRecipe`、`ImageEditRenderer`、`ImageEditorView`、`MemoStore.addImageEdit` 和相关测试，并检索 `Swift Vision person segmentation background removal GitHub MIT`、`VNGeneratePersonSegmentationRequest Swift background removal GitHub`、`VNGenerateForegroundInstanceMaskRequest SwiftUI` 等关键词。未找到可直接复制进当前 iOS 16 SwiftUI 工程的成熟 MIT 模块；部分通用对象移除项目偏扩散模型或桌面管线，不适合本地轻量 App。本轮先扩展项目内 Core Image/UIKit 管线，增加背景柔化和纯色画布，作为后续 Vision 前景分割/衣橱抠图的输出底座。

水印/清理边界：本项目可以做用户拥有或获授权图片的瑕疵修复、对象清理、背景处理和排版，不把移除第三方版权标识、平台水印或规避授权限制作为产品目标。

### 网页摘录、截图 OCR 和链接理解

- `exyte/ReadabilityKit`：<https://github.com/exyte/ReadabilityKit>，MIT，Swift，网页预览/正文提取，但仓库已归档；可参考算法或少量隔离代码，正式接入前要验证现代网页、中文内容和 iOS 兼容性。
- `scinfu/SwiftSoup`：<https://github.com/scinfu/SwiftSoup>，MIT，Swift HTML parser，维护活跃；适合后续需要可靠 DOM/CSS selector 时作为 SPM 依赖评估，不建议复制 parser 源码。
- `aheze/OpenFind`：<https://github.com/aheze/OpenFind>，MIT，Swift/SwiftUI，Vision OCR 实际 App，可参考 OCR 工作流和交互；不需要复制完整 App。
- `DrcKarim/SwiftOCRKit`：<https://github.com/DrcKarim/SwiftOCRKit>，MIT，较新的 Vision OCR Swift Package，可作为 OCR 封装候选；仍需验证 API 稳定性。
- 系统能力：Vision OCR、LinkPresentation、WKWebView、URLSession、Share Extension 是网页和截图摘录的首选底座。

2026-06-22 本轮网页摘录 / OCR MVP 检索决策：重新通过 GitHub API 检查 `ReadabilityKit`、`SwiftSoup`、`OpenFind`、`SwiftOCRKit` 的许可证与维护状态。`ReadabilityKit` 为 MIT 但已归档且依赖 Ji；`SwiftSoup` 为 MIT 且活跃，但当前机器仍无法可靠做 Xcode 16/SPM 完整验证；`OpenFind` / `SwiftOCRKit` 可参考 Vision OCR 工作流。本轮不复制第三方源码，也不引入 SPM，先用 Apple `URLSession`、`LinkPresentation`、`Vision` 与本地轻量 HTML 元数据/段落提取实现网页摘录和导入图片 OCR v1。后续若要做复杂正文清洗、中文网页适配和批量离线抓取，优先评估 `SwiftSoup` 作为依赖，而不是继续扩大正则解析。

2026-06-23 网页摘录正文清洗与摘录卡检索决策：阶段 15 继续前复查 `LinkExtractor`、`QuickCaptureView`、`webClip` 素材索引和现有测试，并通过 GitHub API 核验 `scinfu/SwiftSoup` 与 `exyte/ReadabilityKit`。`SwiftSoup` 仍为 MIT 且 2026-06 活跃，适合作为后续 DOM/CSS selector 依赖候选；`ReadabilityKit` 为 MIT 但已归档，当前不作为直接依赖。继续检索 `Swift readability html article extractor MIT` 与 `SwiftSoup readability article extractor` 未找到更合适可复制模块。本轮未复制第三方源码，新增项目内 `WebClipExtractor`，用本地 HTML 清洗、段落评分、噪音过滤和摘录卡文本扩展现有可迁移网页摘录格式。

2026-06-23 网页/OCR 摘录片段检索决策：阶段 16 继续前检索 `SwiftUI text highlight selection annotation MIT`、`iOS OCR text selection Vision Swift MIT`、`SwiftUI web clip article highlight MIT`、`VisionKit document scanner SwiftUI MIT` 等关键词，多轮 GitHub API 查询均返回 0 个可直接复用模块。本轮未复制第三方代码，先新增项目内 `ClipFragment` / `ClipFragmentExtractor` 纯模型，把网页摘要、网页重点和 OCR 行统一成可勾选片段；快速输入的网页摘录卡已可选择片段后保存。

2026-06-23 摘录片段素材索引检索决策：恢复后尝试查询 GitHub Actions 最新状态时审批服务 503 拦截，未继续绕路重复外部查询。随后补做开源对标：`usememos/memos` 为 MIT，可继续参考 memo/Markdown/自有数据产品思路，但 Go/TypeScript 服务端架构不能直接复制到当前 SwiftUI 本地素材索引；Simplenote iOS、Joplin、Zettlr 等项目许可证或技术栈不适合直接搬源码。本轮继续扩展 some 现有 `MemoAsset` 和 SQLite `memo_assets` 字符串类型索引，新增摘录片段素材和 `has:clip` 搜索。

2026-06-22 本轮图片/截图 OCR MVP 检索决策：再次检索 `VNRecognizeTextRequest`、`OpenFind`、`SwiftOCRKit` 和 Swift Vision OCR MIT 候选。`OpenFind` 是完整 App，可参考工作流但不适合复制进当前项目；`SwiftOCRKit` 是较新的 MIT 封装，仍需在 Xcode 16/SPM 环境验证 API、维护性和体量。本轮不复制第三方 OCR 源码，也不新增依赖，直接使用 Apple Vision `VNRecognizeTextRequest` 在本机识别导入图片文字，并把结果复用现有 memo、附件、备份、搜索和 `MemoAsset.screenshot` 索引。后续如要做批量 OCR、框选区域、置信度、语言配置和扫描校正，再评估是否引入 `SwiftOCRKit` 或参考 `OpenFind` 的交互。

### 电子手帐、贴纸和画布

- 本轮搜索 `SwiftUI canvas drag resize sticker license:mit` 未找到成熟且直接可用的 MIT SwiftUI 手帐/贴纸画布库。
- 初步策略：先用本地页面模型加 SwiftUI 手势实现素材拖拽、缩放、旋转、层级、字体、边框、背景和贴纸；每个子能力开工前再检索专门库，例如图片裁剪、文本排版、PDF/图片导出。
- 复用边界：可参考设计工具、拼贴工具和画布编辑器的交互，不复制无许可证项目素材、贴纸、模板和 UI 资源。

### 电子衣橱和穿搭规划

- `Jean-Regis-M/AURA`：<https://github.com/Jean-Regis-M/AURA>，MIT，Kotlin/Jetpack Compose，离线优先 AI 衣橱规划，包含天气、场景、颜色/材质、搭配推荐方向；可做产品结构参考，不能直接移植 iOS UI 代码。
- `denzariu/outfit-planner`、`DaveShaffer/WDI6-outfttr`、`taliacs22/Capsule---Outfit-Planner` 等搜索结果多为旧项目、Web/React Native/Ruby 或无许可证；只做产品参考，不复制代码。
- 初步策略：some 自建 Swift 数据模型：衣物、饰品、包包、鞋履、品牌/购买信息、颜色、材质、季节、场景、照片、抠图版本、搭配组合、穿着日期、旅行清单和统计。实现前继续搜索可用的 Swift 图像抠图、颜色提取、标签选择和日历组件。
- 2026-06-22 阶段 11 复查：GitHub API 检索 `SwiftUI wardrobe outfit planner MIT`、`wardrobe outfit planner ios swift` 返回 0；`virtual closet swift ios` 返回 `upandey3/VirtualClosetAI`（Objective-C、无许可证、2017 年停更）和 `thankmelater23/MyFitZ`（MIT、Swift4/iOS10、2017 年停更）。再次复查 `Jean-Regis-M/AURA`，MIT、Kotlin/Android、2026-06 新建，适合参考“颜色/场景/天气/穿着平衡”产品思路，但不直接复制代码。本轮继续自建 Swift 洞察层。
- 2026-06-23 阶段 23 复查：继续检索 `wardrobe outfit planner MIT`、`virtual closet swift MIT`、`outfit planner swift MIT`、`packing list swiftui MIT`、`laundry reminder swift MIT` 等关键词，GitHub API 返回 0 个可直接复制进当前 SwiftUI/iOS 工程的成熟 MIT 模块。当前功能继续复用 some 的结构化 memo、`MemoAsset` 和 `WardrobeInsightEngine`：从最近穿着天气、最新洗护状态、场景/季节统计和已有穿搭中推导天气穿搭、打包草稿和洗护提醒，不新增第三方依赖。

### 工作日志和 flomo 补漏

- 工作日志生成更像本项目已有 memo/搜索/AI 洞察的组合，不需要先找大型开源 App；应复用现有保存搜索、日期过滤、任务项、标签、引用和 AI composer。
- 2026-06-22 工作日志 MVP 检索决策：继续前复查 Git 状态、未跟踪文件、当前文件清单和已有工作日志半成品；GitHub API 检索 `SwiftUI work log daily report MIT`、`iOS daily work journal SwiftUI MIT`、`SwiftUI daily report work log` 均返回 0 个候选。本轮不复制第三方源码，直接复用 `Memo`、`MemoAsset.workLog`、`MemoTaskParser`、`MemoReferenceParser` 和 `has:worklog` 搜索，生成可迁移的结构化正文。
- flomo 仍有未覆盖能力：禅定模式、小组件、公开 API、MCP 读写接口、AI 语音输入、AI 记忆档案、微信服务号输入替代方案。后续每项开工前继续单独检索可复用实现。

### 统一素材模型（2026-06-22 实现决策）

- 本轮继续检索 Swift/iOS 媒体素材模型、附件模型、衣橱模型和 SQLite/GRDB 方案。直接可复制的成熟“个人素材库数据模型”没有找到；衣橱和媒体项目多数不是 Swift/iOS、无许可证或偏完整 App，不适合直接搬。
- `groue/GRDB.swift`：<https://github.com/groue/GRDB.swift>，MIT，成熟 SQLite toolkit，后续数据关系变复杂时仍是首选迁移目标。
- 本轮未引入 GRDB：当前机器无法可靠完成 Xcode/SPM 依赖验证，而且项目已有 sqlite3 层。为减少依赖和返工，先在现有 SQLite 中新增 `memo_assets` 索引表。
- 实现边界：`MemoAsset` 先索引现有 memo 中的文本、链接、附件、任务和内部引用；预留 `webClip`、`imageEdit`、`scrapbookPage`、`wardrobeItem`、`outfit`、`audio`、`video`、`screenshot` 等类型，供后续网页摘录、图片编辑、电子手帐和电子衣橱扩展。

### 多模态采集入口和素材库（2026-06-22 实现决策）

- 本轮工作前已重新扫描主仓库、未跟踪文件、Documents 下 some 相关旧目录，并检索 `SwiftUI PhotosPicker sample`、`SwiftUI fileImporter sample`、`SwiftUI journal photo attachments`、`SwiftUI memo attachment app`、`SwiftUI asset library PhotosPicker` 等关键词。
- GitHub API 检索到的 `drawrs/PhotosPicker-PhotoUI` 是无许可证示例仓库，不能直接复制；其他 SwiftUI 附件/素材导入检索未找到成熟、许可证清晰且可直接搬进本项目的模块。
- 本轮采用 Apple 系统能力 `PhotosUI.PhotosPicker` 和 SwiftUI `.fileImporter`，并复用项目已有 `SharedAttachmentStore`、`SharedMemoTextComposer`、`MemoAsset` 索引，不引入第三方运行时代码。
- 实现边界：已支持从输入卡片拍照、拍视频、录音、导入相册图片/视频和文件，保存为本地附件 memo；图片导入会尝试本地 Vision OCR 并生成“图片文字”素材；音频附件会进入 `audio` 素材索引，视频附件会进入 `video` 素材索引；音频详情页可用 Apple Speech 本机识别追加转写文本；视频缩略图已缓存到本地 `ThumbnailCache`，图片/音视频附件会展示本机媒体摘要。批量扫描、转写语言选择、批量媒体元数据刷新和长列表性能验证仍属于后续多模态采集二期。

2026-06-22 相机拍照入口检索决策：本轮继续前已重新检查 Git 状态、未跟踪文件、当前文件清单和 Documents 下旧 some 目录。联网检索 `SwiftUI camera UIImagePickerController MIT`、`SwiftUI AVCapturePhotoOutput camera MIT`、`iOS document scanner VisionKit MIT SwiftUI`，GitHub API 返回 0 个可直接复用的成熟候选；Apple 系统能力 `UIImagePickerController` / `AVCapturePhotoOutput` / VisionKit 仍是首选。本轮不复制第三方源码，也不新增 SPM，先用 `UIImagePickerController` 的系统相机做拍照导入 v1，拿到 JPEG 后复用现有 `SharedAttachmentStore`、本地 OCR 和 `MemoAsset` 索引。后续如果要做自定义取景框、连续拍摄、扫描边缘校正或实时 OCR，再评估 AVFoundation / VisionKit 二期。

2026-06-22 视频拍摄入口检索决策：继续前已复查 Git 状态、文件清单和 Documents 下 some 相关旧目录，并检索 `SwiftUI video recorder AVFoundation MIT`、`UIImagePickerController video capture SwiftUI MIT`。GitHub API 只返回一个 macOS 屏幕录制项目 `alibahrawy/SmoothyREC`，不是 iOS 相机拍摄模块；另一个查询返回 0。Apple 官方 `UIImagePickerController` 与 `InfoKey.mediaURL` 文档可达，本轮沿用已有 UIKit bridge，增加 `.video` 模式，拿到系统相机返回的 movie URL 后复制进本地附件目录，未复制第三方源码。

2026-06-22 录音与手帐入口检索决策：本轮继续前已复查 Git 状态、未提交碎片、全量文件清单和 Documents 下旧 some 目录，并重新检索 Stylebook/Whering 等衣橱产品能力、`SwiftUI audio recorder AVFoundation MIT`、`SwiftUI scrapbook journal canvas MIT`、`SwiftUI wardrobe outfit planner MIT`。未找到可直接复制进当前 iOS 工程的成熟 MIT SwiftUI 手帐/衣橱模块；录音采用 Apple `AVAudioRecorder` / `AVAudioSession` 系统能力，手帐先使用正文内可迁移的 `手帐页面：标题` 结构化 memo 与 `scrapbookPage` 素材索引，不引入第三方依赖。

2026-06-22 语音转写入口检索决策：继续前已复查 Git 状态、未跟踪文件和现有音频附件链路，并检索 `iOS SFSpeechRecognizer audio file transcription Swift MIT`、`SFSpeechURLRecognitionRequest Swift MIT`。GitHub API 两个查询均返回 0，Apple `SFSpeechRecognizer` 与 `SFSpeechURLRecognitionRequest` 官方文档可达。本轮不复制第三方代码，不把原始音频发送到 OpenAI，采用 Apple Speech 的 `requiresOnDeviceRecognition` 本机识别；设备或语言不支持本机识别时直接提示不可用。

2026-06-22 视频缩略图检索决策：继续前已复查 Git 状态、未跟踪文件、当前文件清单和视频附件展示链路，并检索 `SwiftUI AVAssetImageGenerator video thumbnail MIT`、`iOS video thumbnail AVAssetImageGenerator MIT Swift`、`SwiftUI video thumbnail open source GitHub`。GitHub API 未返回可直接复制的成熟 MIT SwiftUI 模块，网页检索也未发现比系统能力更适合当前架构的独立库；本轮采用 Apple `AVAssetImageGenerator` 在本机按需取帧，不新增第三方依赖，失败时保留原视频图标回退。

2026-06-23 媒体元数据与缩略图缓存检索决策：阶段 14 继续前已复查 Git 状态、最近提交、文件清单和媒体预览链路，并检索 `SwiftUI video thumbnail cache MIT`、`AVAssetImageGenerator thumbnail cache Swift`、`Swift media metadata AVAsset MIT iOS`、`iOS local video thumbnail Swift MIT`。精确查询均返回 0；放宽到 `video thumbnail swift` 后找到 `HHK1/PryntTrimmerView`、`luispadron/LPThumbnailView`、`krad/memento` 等 MIT 候选，但它们偏视频裁剪、旧 UIKit 预览或独立小工具，不覆盖 some 的本地附件 URI、素材索引、详情页/素材库复用和缓存失效边界。本轮未复制第三方源码，继续使用 Apple AVFoundation / ImageIO，并基于现有 `SharedAttachmentStore`、`VideoThumbnailGenerator` 和 `MemoAsset.summary` 自建小型缓存与摘要层。

2026-06-22 手帐/贴纸画布补充检索：继续通过 GitHub API 搜索 `SwiftUI sticker drag resize rotate MIT`、`SwiftUI collage editor MIT`、`StickerView iOS Swift`、`DraggableResizableView SwiftUI`、`SwiftUI canvas layers editor`。可参考候选包括 `irons163/IRSticker-swift`、`artemnovichkov/StickerViewExample`、`native-mobile-app-developers/SwiftStickerView` 等 MIT 项目，但核心多为 UIKit 贴纸视图或背景移除示例，不是当前 SwiftUI 首页/素材索引可直接复制的完整手帐画布。本轮仅记录其拖拽、缩放、旋转和背景移除方向，未复制第三方源码；当前先自建可迁移 `ScrapbookPageLayout` / `ScrapbookLayer` JSON 底座，下一步做真正画布时再针对具体类文件做许可证头、依赖体量和 iOS 版本验证。

2026-06-22 手帐画布 v1 实现决策：阶段 9 继续前补检索 `SwiftUI draggable resizable rotatable view MIT`、`SwiftUI sticker drag resize rotate MIT`、`iOS sticker view drag resize rotate Swift MIT`、`SwiftUI collage editor drag resize rotate`，GitHub API 均未返回可直接复制的成熟 SwiftUI/MIT 模块。本轮未复制 UIKit 贴纸项目源码，改为复用 some 已有 `ScrapbookPageLayout` / `ScrapbookLayer`，在详情页自建 SwiftUI 画布，实现图层拖拽、缩放、旋转和保存回正文 JSON。

## some 当前缺口与复用优先级

P0 验证：

- 完整 Xcode 编译、单元测试、模拟器/真机运行。
- App Group、Share Extension、FTS 搜索在真机/模拟器上验证。
- 统一素材模型：v1 已建立 `MemoAsset` 索引，网页摘录、手帐页面、衣橱和穿搭已有轻量正文结构；编辑版本、穿着记录、手帐图层等仍需要独立实体和关系。
- 本地媒体存储与备份：原始素材、编辑版本、导出版本、衣橱抠图和手帐页面需要可追踪；视频缩略图已支持本地持久缓存，后续还需批量媒体元数据刷新、缓存清理策略和真实长列表性能验证。

P1 优先复用：

- 多模态采集：PhotosUI / PHPicker、AVFoundation、Share Extension、Files importer。
- 图片裁剪/编辑：优先评估 `Mantis`、`TOCropViewController`、`HXPhotoPicker` 与系统 Core Image / Vision；背景画布已内置，人物/物体前景分割后续优先接 Apple Vision。
- 网页和截图摘录：网页摘录 v2 与图片 OCR v1 已用系统能力落地，并已有网页/OCR 统一摘录片段候选；后续完整 DOM/CSS selector、阅读模式质量和批量离线网页导入优先评估 SwiftSoup，批量/交互式 OCR 再评估 OpenFind / SwiftOCRKit 的可复用部分。
- 电子手帐：先建本地页面/图层模型，画布交互每个子能力单独检索，不复制无许可证素材。
- 电子衣橱：先建 Swift 数据模型和本地存储；Android/Web 衣橱项目只做产品参考。
- 工作日志：复用现有任务项、日期筛选、保存搜索、引用和 AI composer。
- Markdown 二期：完整块级渲染、引用、代码块和附件卡片，优先评估 `Textual` / `MarkdownUI` / `swift-markdown`。
- Widget 快速入口：参考 MoeMemos 的 Widget 结构，重新实现。
- Share Extension 二期附件：参考 MoeMemos 附件处理流程，重写本项目的本地附件存储。

P2 优先复用：

- Zip 备份：引入 `ZIPFoundation`。
- 数据层复杂化：引入 `GRDB.swift`，替代继续扩展手写 sqlite3。
- 自托管 memos API 同步：按 usememos MIT API/模型设计适配器。

P3 只参考：

- AI 语音输入 / 转写：音频附件转写 v1 已用 Apple Speech 本机识别落地；后续若做跨语言、长音频或云端 provider，再单独评估 OpenAI/Gemini BYOK 转写接口。
- Backlinks / graph：参考无许可证项目和 MoeMemos relation 思路，不复制。

## 下一步建议

2026-06-21 本轮实现决策：已参考 MoeMemos 的 `SaveMemoIntent` / `AppShortcuts` 结构，但未复制 MPL 源码；本项目重新实现 `SaveMemoIntent` 和 `SomeAppShortcuts`，直接调用本地 `MemoStore` 写 SQLite。

2026-06-21 本轮实现决策：已参考 MoeMemos 的 Share Extension 附件处理边界，但未复制 MPL 源码；本项目重新实现本地附件保存，图片/文件写入 App Group `Attachments` 目录，memo 正文保存 `some-attachment://` 引用，主 App 列表和详情展示附件卡片。

2026-06-22 本轮实现决策：复查 flomo 101 官方导航与 MoeMemos/usememos 仓库结构后，优先补搜索二期。最近搜索、保存搜索、结果数量和命中摘录属于本地状态与 SwiftUI 交互，不适合直接复制 MoeMemos 的 MPL 源码，也没有必要把 usememos Web/Go 代码移植进 iOS；本项目按同类产品行为重新实现，并用单元测试覆盖持久化、去重、上限和摘录。

2026-06-22 本轮实现决策：对照 usememos 的 `MemoRelation` / `REFERENCE` / `COMMENT` API 和 Web 端 link memo 插入流程后，some 先做轻量本地 `REFERENCE`：用 `[引用: 标题](some-memo://UUID)` 写入正文，详情页展示正向/反向引用。没有复制 usememos 的 MIT Web/Go/Proto 代码，也没有复制 MoeMemos 的 MPL 源码；选择正文内链接是为了让现有 SQLite、备份、历史版本和 Markdown 导出无需 schema 大迁移即可保留关系。

2026-06-22 本轮实现决策：继续对照 usememos/memos 的 memo relations、link metadata 和内容 payload/filter 思路，补 some 搜索三期第一段。新增 `has:*` / `-has:*` 语法复用本项目已有 `LinkExtractor`、`SharedAttachmentStore`、`MemoTaskParser`、`MemoReferenceParser`，没有复制 usememos 的 MIT 代码；选择文本语法是为了让保存搜索、最近搜索和现有 FTS 查询链都能直接组合使用。

2026-06-22 本轮实现决策：继续补搜索三期第二段，参考 Joplin `created:` / `updated:` 日期过滤与“错误过滤器按普通文本处理”的交互原则。some 重新实现本地日期解析，只支持清晰的 `yyyy` / `yyyy-MM` / `yyyy-MM-dd` 和 `>` / `>=` / `<` / `<=` 边界语法，避免引入模糊自然语言日期依赖，也没有复制 Joplin 源码。

2026-06-22 本轮实现决策：多模态采集入口 v1 采用 Apple `PhotosUI.PhotosPicker`、SwiftUI `.fileImporter` 和 UIKit `UIImagePickerController`，没有复制无许可证 PhotosPicker 示例，也没有新增第三方依赖。导入结果复用现有 App Group 附件目录、memo 正文附件引用和 `MemoAsset` 索引；首页新增素材库视图作为素材整理入口。拍照导入保存 JPEG，并复用图片 OCR 生成“图片文字”素材；拍视频导入保存系统相机返回的 movie 文件，并进入 `video` 素材索引。

2026-06-22 本轮实现决策：网页摘录 MVP 采用正文内可迁移格式 `[网页摘录: 标题](URL)` 加摘要/重点，复用现有 memo、SQLite、备份、历史版本、搜索和素材索引；新增 `webClip` 素材与 `has:web` / `has:webclip` 精准筛选。没有复制 `ReadabilityKit` / `SwiftSoup` / OCR 项目源码；当前只抓标题、description 和段落候选，失败时回退 `LinkPresentation` 标题，再失败仍保存 URL。

2026-06-22 本轮实现决策：图片/截图 OCR MVP 采用 Apple Vision `VNRecognizeTextRequest`，导入图片后异步识别文字，识别成功则保存为“图片文字” memo 并保留原附件引用；素材索引新增 `screenshot` 类型，搜索新增 `has:ocr` / `has:screenshot` / `has:图片文字`。没有复制 `OpenFind` 或 `SwiftOCRKit` 源码，也没有引入未验证的 SPM 依赖。

2026-06-24 本轮实现决策：阶段 92 继续补 OCR 版面分区摘要前，检索 `Swift Vision OCR text blocks layout segmentation GitHub MIT`、`VNRecognizedTextObservation boundingBox reading order Swift MIT`、`iOS OCR layout analysis Swift Vision GitHub MIT` 和 `Swift OCR document layout analysis Vision license MIT`，未找到可直接复制进 some 当前本地 memo/OCR/素材索引架构的轻量 MIT 模块。Apple Vision 已在 `VNRecognizedTextObservation.boundingBox` 提供文字行框位置，本轮不引入第三方 OCR 引擎或文档分析依赖，只把行框转换为已有 `ImageTextRegion`，保存左/右栏与顶部/中部/底部行数摘要；后续表格、表单字段和阅读顺序校正再单独评估。

2026-06-24 本轮实现决策：阶段 93 继续补 Markdown 表格和分隔线前，检索 `SwiftUI Markdown table renderer MIT GitHub`、`MarkdownUI SwiftUI tables GitHub MIT`、`swift-markdown table support GitHub Apache 2.0` 和 `SwiftUI Markdown attachment card renderer MIT`。`MarkdownUI` / `swift-markdown` 仍适合未来完整 Markdown 引擎，但本轮需求只覆盖 memo 阅读里最常见的 pipe table 与 horizontal rule，直接复用项目内 `MarkdownMemoBlockParser` 能保留任务勾选行号、代码块隔离和引用解析边界，不新增第三方依赖；附件卡片后续优先复用本项目 `AttachmentPreviewList`。

2026-06-22 产品目标修订后，下一轮不应继续只补 memo 表层小功能。应先补能支撑手帐、工作日志、网页摘录、图片编辑和电子衣橱的底层模型与入口，因为继续扩展单一 memo 正文会增加返工。

推荐路线：

1. 统一素材模型与媒体存储：扩展 SQLite schema 或迁移到更适合复杂关系的 GRDB，覆盖文本、图片、音频、视频、链接、网页、衣橱单品、手帐页面。
2. 多模态采集入口：相机/相册/录音/视频/文件/截图/网页分享统一进入素材库。
3. 网页摘录与截图 OCR 二期：已完成标题/摘要/段落候选和图片 OCR v1；下一步补引用片段选择、正文清洗、批量网页导入、扫描校正和区域 OCR。
4. 电子衣橱 MVP：单品建档、分类、颜色/季节/场景、饰品/包包、搭配组合、穿着记录。
5. 电子手帐与图片编辑 MVP：素材选择、页面画布、裁剪、滤镜、边框、文字、贴纸、基础排版。
6. 再回补 flomo 缺口：MCP/API、AI 语音、AI 记忆档案；小组件、禅定模式和引用批注正文已在后续阶段落地，后续只需继续做真实使用验证和细节增强。
