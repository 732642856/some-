# 地毯式探索与功能差距审计

日期：2026-06-20，更新：2026-06-22

## 本地碎片盘点

已搜索 `/Users/wuyongnaren/Documents/Codex` 下的相关关键词、工程文件、README、许可证和 Git 仓库。

直接相关：

- `/Users/wuyongnaren/Documents/some随记`：当前主仓库与唯一继续开发入口
- `outputs/some`：早期输出目录名称，当前有效工程已收拢到主仓库
- `work/open-source/MoeMemos`：已克隆，SwiftUI iOS memos 客户端，MPLv2
- `work/open-source/memos`：已克隆，usememos 服务端/Web，MIT

旧窗口遗留：

- `2026-06-18/new-chat-4/work/starcanvas-active`：StarCanvas 项目，含 memory/supermemory 方向，但不是 iOS 备忘 App 可直接迁移代码
- `2026-06-18/new-chat-4/work/agent-tools/taste-skill`：审美/品味技能材料，可用于后续 UI 评审，不是功能代码

2026-06-22 复查：

- 当前主仓库：`/Users/wuyongnaren/Documents/some随记`，Git 工作区在开工前干净，分支为 `master`，远端为 `https://github.com/732642856/some-.git`。
- 旧 Codex 工作区：`/Users/wuyongnaren/Documents/Codex/2026-06-20/some-flomo-app-app-store-1`、`/Users/wuyongnaren/Documents/Codex/2026-06-21/some-flomo-app-app-store-1`。二者主要是早期工程快照，当前主仓库已包含其后续功能补齐内容。
- 旧输出碎片：`/Users/wuyongnaren/Documents/Codex/2026-06-20/wo/outputs/some`。这是本轮新增发现的早期输出目录，不是 Git 仓库；与当前主仓库比对后，未发现当前主仓库缺失的更新功能文件。
- 已克隆开源参考仍在 `/Users/wuyongnaren/Documents/Codex/2026-06-20/wo/work/open-source/MoeMemos` 与 `/Users/wuyongnaren/Documents/Codex/2026-06-20/wo/work/open-source/memos`。
- 额外用 `/Users/wuyongnaren` 有限深度搜索 `some.xcodeproj`、`SomeTests.swift`、`SomeShareExtension`、`research-and-gap-audit.md`，未发现除当前主仓库以外的新工程碎片。
- Xcode 工程引用已覆盖当前新增过的核心文件；网页摘录阶段只修改已有 target 内文件，图片 OCR 阶段新增 `some/Utilities/ImageTextRecognizer.swift` 并已加入主 App target。

结论：此前确实遗漏了 `2026-06-20/wo/outputs/some` 这个旧输出目录的文档记录；本轮已经纳入碎片清单。实际代码比对显示，当前主仓库是几个旧 some 目录的功能超集，未发现需要从旧目录补回的独有新功能。

## 当前代码资产盘点

当前仓库的主要代码模块：

- App 入口与主界面：`some/SomeApp.swift`、`some/Views/ContentView.swift`
- 记录模型与历史：`some/Models/Memo.swift`、`some/Models/MemoRevision.swift`
- 存储与迁移：`some/Stores/MemoStore.swift`、`some/Stores/SQLiteMemoDatabase.swift`
- 备份与附件：`some/Models/MemoBackupArchive.swift`、`some/Utilities/MemoBackupPackage.swift`、`some/Utilities/SharedAttachmentStore.swift`
- 媒体理解：`some/Utilities/ImageTextRecognizer.swift`、`some/Utilities/AudioTranscriber.swift`、`some/Utilities/VideoThumbnailGenerator.swift`
- 搜索与解析：`some/Utilities/MemoSearchQuery.swift`、`some/Utilities/TagParser.swift`、`some/Utilities/LinkExtractor.swift`、`some/Utilities/MemoTaskParser.swift`、`some/Utilities/MemoReferenceParser.swift`
- 分享与快捷入口：`SomeShareExtension/ShareViewController.swift`、`some/AppIntents/SaveMemoIntent.swift`、`some/AppIntents/SomeAppShortcuts.swift`
- 隐私与提醒：`some/Views/AppLockView.swift`、`some/Stores/ReminderManager.swift`
- AI：`some/AI/OpenAIClient.swift`、`some/AI/SemanticSearchEngine.swift`、`some/AI/AIInsightComposer.swift`、`some/AI/KeychainStore.swift`
- UI：快速输入、列表、详情、回顾、统计、设置、Markdown 渲染和附件预览分布在 `some/Views/`
- 测试：`SomeTests/SomeTests.swift`
- 发布/说明文档：`README.md`、`AppStore/`、`docs/`、`verification.md`

当前明显缺口：已有 `MemoAsset` 索引表作为素材入口，已补图片 OCR、音频本机转写和视频按需缩略图；但还没有独立媒体资产表、网页摘录实体表、图片编辑管线、完整手帐画布、音视频长内容处理、衣橱单品/搭配统计模型。这些缺口已提升为下一轮优先级。

## 开工前强制审计流程

后续每一轮功能开发前，必须先完成并在本文件或 `docs/open-source-reuse-audit.md` 留痕：

1. 执行 `git status --short --branch`，确认当前分支、远端和未提交文件。
2. 执行 `git ls-files --others --exclude-standard` 与 `rg --files -uu`，确认未跟踪碎片和实际文件清单。
3. 在 `/Users/wuyongnaren/Documents` 下搜索 `some`、`some.xcodeproj`、`SomeShareExtension`、`SomeTests.swift`、核心文档名，发现旧窗口/旧输出目录后用 `diff -qr` 或 Git 状态比对。
4. 检查 `some.xcodeproj/project.pbxproj` 的 target membership，防止新增 Swift 文件只存在磁盘、不进 App 或 Extension target。
5. 先做全网/GitHub 开源检索，记录候选项目、许可证、语言、维护状态和可复用边界。
6. 优先复用系统框架或 MIT / Apache-2.0 / BSD Swift Package；无许可证、GPL/AGPL/MPL 项目不得直接复制进当前工程。
7. 若直接引入代码或依赖，先记录来源、许可证、文件范围和替代方案，再写实现。
8. 开发结束必须更新验证记录，说明哪些能力已实现，哪些只是路线目标。

## 新产品目标（2026-06-22 用户修订）

some 不再只是 flomo 式轻备忘，而是本地优先的个人生活与工作素材库。核心目标如下：

- 捕捉层：文字、想法、待办、工作记录、图片、截图、录音、视频、文件、网址、网页内容、衣服、饰品、包包、穿搭灵感。
- 理解层：标签、全文搜索、OCR、网页正文提取、链接摘要、音频转写、图片/视频描述、关键信息提炼、相关素材查找。
- 电子手帐：用户选择日记/手帐素材后，系统辅助排版成电子手帐页面；贴纸、字体、花边、装饰、边框、背景、图片位置都应可编辑。
- 工作日志：用户勾选输入内容后，生成类似工作记录和工作汇总的日志，支持项目、日期、任务、进展、问题、下一步和复盘。
- 网页摘录：用户导入网址、链接、截图等信息后，提炼重点、摘要、引用和摘录卡，方便后续整理。
- 图片编辑：吃饭、出游、穿搭等照片需要滤镜、边框、裁剪、抠图、贴纸、文字、拼贴、页面排版；只做用户拥有或获授权图片的修复与清理，不把规避第三方版权/平台水印作为产品目标。
- 电子衣橱：像极简衣橱类应用一样，整理衣服、饰品、包包、鞋履、颜色、材质、季节、场景、穿着次数、搭配组合、旅行清单和灵感板。
- 私有优先：用户当前目标是自己使用，不以上架为第一目标；但仍保持隐私、备份、可迁移和权限边界清晰。

## 视觉基准（2026-06-22 用户指定）

用户指定 `/Users/wuyongnaren/Downloads/辰星话本.JPG` 可作为 some 头像与视觉方向。后续 UI 色系应靠近这张图的简约小清新风格：浅粉背景、雾蓝主体、淡紫点缀、柔白高光、低饱和边框。不要再使用深绿/金色作为主品牌调性。

## 官方 flomo 功能对标

从 flomo 官网与 flomo 101 帮助页提取到的主要能力：

- 快速记录：聊天式输入、低排版负担、文字/拍照/扫描/语音、多平台输入
- 微信输入：服务号输入
- 禅定模式
- 多级标签
- 每日回顾
- 热力图与统计
- 快捷搜索
- 引用批注/卡片连接
- 历史版本
- 存储与导出
- 密码锁
- 小组件
- API 与 URL Scheme
- 扩展中心
- AI 语音输入、自然语言搜索、相关笔记、AI 洞察、AI 记忆档案、MCP

flomo 对标结论：

- 已覆盖：快速文字记录、多级标签、每日回顾、热力图/统计、快捷搜索、历史版本基础、存储导出、密码锁基础、URL Scheme、Share Extension、AI 洞察、自然语言搜索、相关记录。
- 部分覆盖：引用批注目前只有内部引用和反向引用，缺批注正文、关系图、引用筛选和摘录型引用工作流。
- 未覆盖：微信服务号输入、禅定模式、小组件、公开 API、MCP 读写接口、AI 语音输入、AI 记忆档案、多端同步/自托管同步。
- 超出 flomo 的新目标：电子手帐、图片编辑、网页/截图提炼、工作日志生成、电子衣橱和穿搭搭配。

## 开源项目对标

更完整的全网检索、许可证评估与复用决策见 `docs/open-source-reuse-audit.md`。后续每轮开发前应先检查该文档，优先使用 MIT / Apache / BSD 等宽松许可证项目或 Swift Package，避免重复手写成熟能力。

### MoeMemos

仓库：<https://github.com/mudkipme/MoeMemos>

许可证：MPLv2。可以参考和按许可证复用，但不适合无说明地整段混入本项目。

值得参考：

- 本地存储或自托管 memos 服务两种模式
- 离线可用与恢复网络后同步
- Markdown 扩展
- 图片/视频/附件
- 标签、置顶、搜索、归档
- 进度图/热力图
- iPhone/iPad、多任务、深色模式、动态字体
- Share Extension、App Intents、Widgets

### usememos/memos

仓库：<https://github.com/usememos/memos>

许可证：MIT。

值得参考：

- quick capture 产品定位
- Markdown-native 与数据可迁移
- REST/gRPC API
- memo relation、memo share、inbox、reaction、attachment
- Web 侧过滤、标签树、分享图片、Memo Explorer

### 其他 GitHub 候选

- `glushchenko/fsnotes`：MIT，成熟 macOS/iOS notes manager，但更偏文件型笔记，不是 flomo 式卡片流
- `heckj/swiftui-notes`：MIT，主要是 Combine/SwiftUI 学习材料，不适合作为产品基座
- `buddax2/tmpNote`：MIT，较旧，价值低于 MoeMemos
- `blinkospace/blinko`：GPL-3.0，开源自托管 AI 笔记，适合作为 AI 搜索/洞察/自托管方向参考；许可证不适合直接混入当前 iOS 工程

## 本轮已补齐

- 统一素材模型 v1：新增 `MemoAsset` 底层模型和 SQLite `memo_assets` 索引表，现有 memo 会自动解析为文本、链接、附件、任务、内部引用等素材；已预留网页摘录、图片编辑、手帐页面、衣橱单品、穿搭、音频、视频、截图等类型
- 多模态采集入口 v1：输入卡片新增拍照、录音、相册图片/视频导入和文件导入，导入内容会保存到本地附件目录并生成附件 memo
- 素材库视图 v1：首页新增“素材”模式，可按文本、链接、附件、任务、引用等类型筛选素材，图片附件显示缩略图并可跳回来源记录
- 多级标签解析：支持 `#项目/子类`
- 主导航：记录 / 回顾 / 统计 / 归档
- 草稿自动保存
- 归档与恢复
- 卡片长按菜单：置顶、归档、复制、分享、删除
- 随机回顾
- 历史今天
- 统计仪表盘
- 记录热力图
- 高频标签
- 完整备份导出：记录 + 本地附件数据
- JSON / 普通文本导入
- URL Scheme：`some://add?text=...`
- OpenAI API Key 本机 Keychain 保存
- AI 自然语言语义搜索
- AI 相关记录查找
- AI 洞察：周期复盘 / 困惑破局 / 自我觉察 / 主题研究 / 写作灵感
- SQLite 主存储，旧 JSON / `.bak.json` 自动迁移
- 隐私锁：Face ID / Touch ID / 设备密码
- 每日回顾本地通知
- 链接识别与详情页打开
- Share Extension：从其他 App 分享文本/链接进入 some
- App Group 共享存储：主 App 与 Share Extension 共用 SQLite
- 快速输入增强：自动聚焦、保存并继续、标签建议、链接预览
- SQLite FTS 搜索索引：正文/标签全文检索
- 搜索语法：`#标签`、`tag:标签`、`is:pinned`、`is:archived`、`is:active`、`has:link` / `has:attachment` / `has:task` / `has:reference`、`created:` / `updated:`
- Markdown 阅读渲染：列表与详情页使用系统 Markdown 富文本展示
- Markdown 任务项：识别 `- [ ]` / `- [x]`，详情页可直接勾选并写回 SQLite
- App Intents / Shortcuts：快捷指令可保存新随记，复用本地 SQLite 存储
- Share Extension 附件 v1：支持图片/文件分享，本地 App Group 附件目录保存，列表/详情展示附件卡片
- 历史版本：编辑前保存旧正文，详情页可查看并恢复，完整备份会包含历史版本及其附件
- 搜索二期：提交搜索会记录最近搜索，可保存常用组合筛选，首页显示搜索结果数量，卡片显示命中摘录
- 搜索三期第一段：参考 usememos 的关系、链接元数据与内容 payload/filter 思路，新增 `has:*` 结构化筛选；覆盖链接、附件、任务、未完成/已完成任务、正向引用和反向引用，并支持 `-has:` / `no:` / `without:` 排除
- 搜索三期第二段：参考 Joplin `created:` / `updated:` 日期过滤思路，新增创建/更新时间筛选，支持年、月、日精确范围与 `>` / `>=` / `<` / `<=` 边界过滤
- 卡片引用 v1：详情页可添加内部 `some-memo://UUID` 引用，并展示正向引用与反向引用；引用保存在正文中，随导出、备份和历史版本迁移
- 网页摘录 MVP：快速输入识别到链接后可一键摘录网页，使用 `URLSession` 抓取 HTML 标题、description 和段落候选，失败时回退 `LinkPresentation` 标题或 URL；保存为正文内 `[网页摘录: 标题](URL)`、摘要和重点，并进入 `webClip` 素材索引
- 网页素材搜索：新增 `has:web` / `has:webclip` / `has:网页摘录` 等筛选，素材库可按“网页”筛选并直接打开原链接
- 图片/截图 OCR MVP：拍摄或导入图片后使用 Apple Vision `VNRecognizeTextRequest` 在本机异步识别文字，识别成功会生成“图片文字”记录并保留原附件引用
- 图片文字素材搜索：OCR 记录会进入 `screenshot` 素材索引，并支持 `has:ocr` / `has:screenshot` / `has:图片文字` 等筛选
- 录音 MVP：快速输入新增麦克风按钮，可录制本地 m4a 音频并保存为附件 memo；记录会进入 `audio` 素材索引，并支持 `has:audio` / `has:录音` 搜索筛选
- 视频拍摄 MVP：快速输入新增视频按钮，可调用系统相机录制 movie 文件并保存为附件 memo；记录会进入 `video` 素材索引，并支持 `has:video` / `has:视频` 搜索筛选
- 本地语音转写 MVP：音频详情页可主动触发 Apple Speech 本机识别，识别结果会追加为“语音转写”段落；当前不上传原始音频到 OpenAI 或第三方服务
- 电子手帐 MVP：已完成首页“手帐”模式、手帐页面结构化记录、可迁移图层 JSON、手帐列表页面预览，以及详情页图层拖拽/缩放/旋转后保存回原 memo
- 电子衣橱 MVP 第一段：首页新增“衣橱”模式，可保存衣橱单品和穿搭组合，单品可绑定已有图片附件；记录会进入 `wardrobeItem` / `outfit` 素材索引，并支持 `has:wardrobe` / `has:outfit` 搜索筛选

## AI 对标补充

usememos 当前开源实现的 AI 主线是 BYOK provider 配置与语音转写接口；`proto/api/v1/ai_service.proto` 暴露 `Transcribe`，Web 设置页支持 OpenAI / Gemini provider 和 transcription 参数。本项目本轮没有直接复制这些 GPL/MPL 风险代码，而是按同类 BYOK 思路做了 iOS 本地 Keychain 配置，并补上 flomo AI 洞察方向更相关的周期复盘、困惑破局、自我觉察、主题研究、写作灵感、语义搜索和相关记录。

OpenAI 接口依据 2026-06-20 官方 API 文档接入：文本生成使用 Responses API `POST /v1/responses`，语义向量使用 Embeddings API，默认 embedding 模型为 `text-embedding-3-small`，Responses 模型可在设置中修改，默认 `gpt-4o-mini`。本轮已添加 OpenAI Docs MCP，但需要重启 Codex 后才会暴露工具；当前代码先采用稳定可配置默认值。

## 仍未完成但应排优先级

P0：

- 用完整 Xcode 编译运行，修掉真实编译错误
- 增加基础单元测试：继续补 SQLite 迁移边界、Share Extension 端保存流程、App Group 真机验证
- 在 Apple Developer / Xcode Signing & Capabilities 中为主 App 和 Share Extension 配好同一个 App Group
- 设计统一素材模型：文字、图片、截图、音频、视频、链接、网页摘录、衣橱单品都不能继续只塞进 memo 正文
- 设计本地媒体存储与备份策略：原图、编辑版本、缩略图、音视频、抠图透明图、手帐页面导出都要可追踪、可恢复

P1：

- 多模态采集 MVP：相机拍照、视频拍摄、录音、相册图片/视频导入、文件导入、图片 OCR 和本机语音转写已完成 v1；转写语言选择、长音频处理、批量元数据和缩略图缓存仍待补
- 网页摘录 MVP：链接标题/description/段落候选提取、摘要和重点保存已完成 v1；正文清洗质量、引用片段选择、批量网页导入、扫描校正和区域 OCR 仍待补
- 电子衣橱 MVP：单品和穿搭记录入口已完成第一段；分类/颜色/季节/场景、图片附件、穿着频率、旅行打包、搭配推荐和灵感板仍待补
- 电子手帐 MVP：页面结构化记录、图层 JSON、列表预览和详情页拖拽/缩放/旋转画布已完成 v1；图片/文字/贴纸/边框/背景工具栏、字体与装饰编辑、图层层级管理、导出图片/PDF 仍待补
- 工作日志 MVP：已完成首页“日志”模式、勾选记录生成日报/周报/项目日志、进展/问题/下一步字段、来源引用、素材索引和 `has:worklog` 搜索；后续增强项目字段、周期模板、导出和 AI 润色
- 图片编辑 MVP：裁剪、滤镜、边框、文字、贴纸、基础拼贴；抠图/背景移除作为下一阶段
- 电子衣橱 MVP：单品建档、分类、颜色/季节/场景标签、搭配组合、穿着日历和使用统计

P2：

- 小组件
- 引用批注二期：批注正文、关系图、引用搜索筛选、网页摘录引用链
- Markdown 二期：完整块级渲染、代码块、引用批注、附件卡片
- 历史版本二期：差异对比、版本备注、按版本复制
- 导出 zip，按年月/项目/手帐页拆分 Markdown、图片和附件
- 自托管 usememos API 同步
- AI 图片/网页/音频理解：OCR 和本机语音转写已完成 v1；图片描述、视频摘要、素材自动标签和长音频摘要仍待补
- 衣橱搭配建议：按天气、场景、颜色、穿着频率、旅行清单推荐组合

P3：

- flomo 缺口：禅定模式、微信输入替代方案、小组件、公开 API、MCP 读写接口、AI 记忆档案
- 高级图片编辑：抠图精修、背景替换、对象清理、模板化拼贴、批量导出
- 高级手帐：模板市场/个人模板、贴纸库、字体库、花边库、跨页相册
- 高级衣橱：购买清单、闲置提醒、成本/次统计、胶囊衣橱、行李箱打包
- AI 洞察周报 / 月报
- 本地向量缓存，减少重复 embedding 调用
- 多 provider 支持：Gemini、OpenAI 兼容 endpoint、自托管模型

## 复用策略

- 直接复制或引入依赖：仅限 MIT / Apache-2.0 / BSD 等宽松许可证且模块边界清楚的代码。优先引入 Swift Package，而不是复制源码文件。
- 借鉴结构：MoeMemos 的热力图、归档、Share Extension、App Intents、小组件、本地导出流程。
- 避免复制：MoeMemos 的 MPLv2 源码、Blinko 的 GPL-3.0 源码暂不整段混入，除非后续明确接受对应开源义务。
- 重点候选：Markdown 渲染用 `Textual` / `MarkdownUI` / `swift-markdown`，zip 导出用 `ZIPFoundation`，复杂 SQLite 用 `GRDB.swift`，自托管同步参考 usememos MIT API。
