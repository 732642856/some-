# some

一个 SwiftUI 写的本地优先 iOS 个人素材库。目标是让用户随时捕捉文字、图片、录音、视频、链接、截图、衣橱单品、饰品和包包，并把这些素材按场景整理成电子手帐、工作日志、网页摘录卡片、图片排版作品和穿搭衣橱记录。

当前代码仍处在“随记/素材库底座”阶段：已经完成文字记录、标签、搜索、附件、拍照/拍视频/相册/文件导入、录音 v1、本地语音转写 v1、网页摘录 v1、图片/截图 OCR v1、素材索引、素材库视图、手帐页面 v1、电子衣橱 v1、分享扩展、引用、备份、隐私锁和可选 AI 洞察；图片编辑、完整衣橱统计与推荐等仍在路线图中。

项目仍避免使用 flomo、极简衣橱等应用的名称、Logo、素材与品牌表达。后续只复用许可证清晰的开源代码或系统能力；无许可证、GPL/AGPL/MPL 代码默认只做产品与架构参考。

## 产品目标

### 输入素材

- 随时记录想法、摘录、待办、工作记录
- 拍摄或导入图片、视频、截图、文件；拍摄/导入图片时会尝试本地 OCR 提取文字
- 后续补连续扫描增强、转写语言选择、视频缩略图和批量媒体元数据
- 导入网址和链接，提炼标题、摘要、正文重点和可摘录片段
- 建立电子衣橱：衣服、饰品、包包、鞋履、穿搭组合、使用记录

### 输出场景

- 电子手帐：把选中的记录、图片、截图、贴纸、字体、花边、边框、背景和装饰排版成可编辑页面
- 工作日志：勾选输入内容，按日期、项目、任务、进展、问题、下一步生成工作记录和汇总
- 网页摘录：从链接、网页、截图中提炼关键信息，形成摘要、引用、摘录卡和待办
- 图片编辑：滤镜、边框、裁剪、抠图、拼贴、贴纸、文字、排版；图片清理只面向用户拥有或获授权的图片，不把“移除第三方版权/平台水印”作为产品目标
- 穿搭衣橱：像极简衣橱类应用一样管理单品、搭配、场景、季节、颜色、材质、穿着频率、旅行打包和灵感板

## 已实现底座

- 快速输入卡片
- 快速导入入口 v1：可从输入卡片拍照、拍视频，或导入相册图片/视频和文件，保存为本地附件素材
- 录音入口 v1：快速输入卡片可录制本地 m4a 音频，保存为音频附件素材
- 本地语音转写 v1：详情页对音频附件提供“语音转写”，通过系统 Speech 识别后追加到原记录正文
- 网页摘录入口 v1：输入卡片识别到链接后可一键保存标题、摘要和重点候选
- 图片/截图 OCR v1：拍摄或导入图片后用 Apple Vision 在本机识别文字，识别结果随附件保存为“图片文字”记录
- 电子手帐 v1：首页新增“手帐”模式，可保存手帐页面结构化记录、生成可迁移图层 JSON，并在手帐列表显示页面预览
- 电子衣橱 v1：首页新增“衣橱”模式，可快速保存单品和穿搭组合，单品可绑定已有图片附件，并进入衣橱/穿搭素材索引
- `#标签` 自动识别
- 支持 `#项目/子类` 多级标签
- 标签筛选
- SQLite FTS 全文搜索
- 搜索语法：`#标签`、`tag:标签`、`is:pinned`、`is:archived`、`is:active`、`has:link`、`has:web`、`has:ocr`、`has:audio`、`has:video`、`has:scrapbook`、`has:wardrobe`、`has:outfit`、`created:2026-06`
- 搜索增强：最近搜索、保存搜索、结果数量、命中摘录、链接/附件/任务/引用/日期结构化筛选
- 置顶
- 编辑和删除
- 本地 SQLite 持久化
- Markdown 导出
- App 内隐私说明
- AppIcon 全尺寸资源
- `PrivacyInfo.xcprivacy` 隐私清单
- 旧 JSON 数据自动迁移，主文件损坏时可从 `.bak.json` 兜底迁移
- 记录 / 素材 / 手帐 / 衣橱 / AI / 回顾 / 统计 / 归档八视图
- 草稿自动保存
- 随机回顾与历史今天
- 记录热力图与高频标签
- 完整备份导出与导入：包含记录和本地附件
- URL Scheme：`some://add?text=...`
- 可选 OpenAI API Key，保存在 iOS Keychain
- AI 洞察：周期复盘、困惑破局、自我觉察、主题研究、写作灵感
- AI 自然语言语义搜索
- AI 相关记录查找
- 隐私锁：支持 Face ID / Touch ID / 设备密码解锁
- 每日回顾提醒：本地通知，可设置提醒时间
- 链接识别：卡片显示链接，详情页可直接打开
- Share Extension：可从其他 App 分享文本或链接到 some
- Share Extension 附件：支持从其他 App 分享图片或文件到 some
- 共享 App Group 存储：主 App 与 Share Extension 共用 SQLite 数据库
- 快速输入增强：打开自动聚焦、保存并继续、标签建议、链接预览
- Markdown 阅读渲染：列表和详情页支持加粗、链接等系统 Markdown 样式
- Markdown 任务项：识别 `- [ ]` / `- [x]`，详情页可直接勾选并写回
- App Intents / Shortcuts：支持通过快捷指令保存新随记
- 卡片引用：详情页可添加 `some-memo://` 内部引用，并显示正向引用与反向引用
- 统一素材索引 v1：现有记录会同步索引为文本、链接、网页摘录、图片文字、附件、音频、视频、任务、内部引用、手帐页面、衣橱单品和穿搭素材，为后续图片编辑和电子衣橱打底
- 素材库 v1：首页可按文本、链接、网页、图片文字、附件、音频、视频、任务、引用、手帐、衣橱、穿搭等类型筛选素材，附件图片支持缩略图预览，网页素材可直接打开原链接

## 搜索语法

- 普通文字：搜索正文和标签，例如 `读书 摘录`
- `#标签` 或 `tag:标签`：按标签过滤，支持匹配子标签，例如 `#产品`
- `is:pinned` / `is:unpinned`：只看置顶或未置顶
- `is:archived` / `is:active`：只看归档或当前记录
- `has:link`：只看包含普通网页链接的记录
- `has:web` / `has:webclip` / `has:网页摘录`：只看已经保存为网页摘录的记录
- `has:ocr` / `has:screenshot` / `has:图片文字`：只看导入图片后识别出文字的记录
- `has:audio` / `has:录音` / `has:音频`：只看音频附件记录
- `has:video` / `has:视频` / `has:录像`：只看视频附件记录
- `has:scrapbook` / `has:手帐` / `has:拼贴`：只看手帐页面记录
- `has:wardrobe` / `has:衣橱` / `has:单品`：只看衣橱单品记录
- `has:outfit` / `has:穿搭` / `has:搭配`：只看穿搭组合记录
- `has:attachment`：只看包含本地附件引用的记录
- `has:task` / `has:open-task` / `has:completed-task`：只看包含任务、未完成任务或已完成任务的记录
- `has:reference` / `has:backlink`：只看引用了其他记录或被其他记录引用的记录
- `created:2026` / `created:2026-06` / `created:2026-06-22`：按创建年、月或日过滤
- `updated:>=2026-06-22` / `created:<2026-06`：按更新时间或创建时间做边界过滤，支持 `>`、`>=`、`<`、`<=`
- `-has:link` / `no:task` / `without:attachment`：排除对应类型，能和普通文字、标签、置顶、归档筛选组合使用
- 双引号：把空格内容作为一个搜索词，例如 `"输入体验"`
- 提交搜索后会进入“最近”，也可以把常用组合保存成快捷筛选。

## 打开工程

1. 安装 Xcode 16 或更新版本。
2. 打开 `some.xcodeproj`。
3. 在 target `some` 的 Signing & Capabilities 中选择你的 Apple Developer Team。
4. 把 Bundle Identifier 从 `com.732642856.some` 改成你账号下可用的唯一 ID。
5. 在 target `some` 和 `SomeShareExtension` 中启用同一个 App Group，默认占位为 `group.com.732642856.some`，需要按你的 Bundle ID 改成账号下可用的 group。工程通过 build setting `APP_GROUP_IDENTIFIER` 同步写入 entitlements 和运行时配置。
6. 选择模拟器或真机运行。

## 如以后上架要替换的信息

- App 名称：默认 `some`
- Bundle ID：默认 `com.732642856.some`
- Share Extension Bundle ID：默认 `com.732642856.some.share`
- App Group：默认 `group.com.732642856.some`
- Copyright：在 App Store Connect 中填你的个人或公司主体
- 支持 URL：需要一个公开网页
- 隐私政策 URL：需要一个公开网页，可先用 `AppStore/privacy-policy.md` 的内容发布

## 技术说明

当前版本不接入账号、云同步、广告或第三方分析。笔记内容默认以 SQLite 保存在用户设备本地；启用 App Group 后，主 App 与 Share Extension 会共用同一个本地 SQLite 数据库。Markdown 导出和完整备份导出由用户主动触发系统分享表。

附件当前保存在 App Group 的本地 `Attachments` 目录，memo 正文只保存轻量引用。删除或编辑 memo 时，只会删除已不再被任何 memo 引用的本地附件文件，避免多个 memo 共用同一附件时误删。

签名和发布相关 ID 已抽成 build settings：`APP_BUNDLE_ID`、`SHARE_EXTENSION_BUNDLE_ID`、`APP_GROUP_IDENTIFIER`。本机 Xcode 可在 Build Settings 中修改；GitHub Actions 可通过 secrets 注入。

AI 功能是可选能力：只有在设置里保存 OpenAI API Key，并主动点击 AI 洞察、AI 搜索或相关记录时，应用才会把本次操作需要的文本直接发送到 OpenAI API。API Key 保存在本机 Keychain，不写入完整备份。

Markdown 阅读渲染当前使用 iOS 系统 `AttributedString(markdown:)`，任务项勾选使用项目内轻量解析器。后续若要做完整块级渲染、代码块、引用批注和附件卡片，优先接入 `Textual`、`MarkdownUI` 或 `swift-markdown` 这类 MIT / Apache Swift Package。

快捷指令能力通过 App Intents 实现，默认提供“存到 some / 新建随记”入口；内容仍保存在本机 SQLite，不需要账号或云同步。

Share Extension 对网页标题的支持依赖系统分享项提供的标题/摘要；主 App 快速输入里的网页摘录会主动抓取网页 HTML 的标题、description 和段落候选，失败时回退系统链接元数据或原 URL。当前还不是完整 Readability 正文提取，也不会绕过登录、付费墙或网站访问限制。

相机拍照和拍视频当前使用系统 `UIImagePickerController`，分别保存为本地 JPEG / movie 附件；需要用户授权相机权限，拍视频如录入声音也需要麦克风权限。录音当前使用 Apple `AVAudioRecorder` / `AVAudioSession` 保存本地 m4a 附件，需要用户授权麦克风权限；音频详情页可用 Apple Speech 做系统语音识别并把转写结果追加到原记录，需要用户授权语音识别权限，识别可用性和质量取决于系统服务、设备和语言。图片 OCR 当前使用 Apple Vision `VNRecognizeTextRequest` 在设备本地处理拍摄或导入图片，不需要把图片上传到第三方服务。没有识别出文字时仍会按普通图片附件保存；连续扫描、批量 OCR、版面分区和置信度展示仍属于后续阶段。

卡片引用当前用 Markdown 链接格式写入 memo 正文，例如 `[引用: 目标](some-memo://UUID)`；这样导出、备份、历史版本和普通文本迁移都能保留关系。阅读详情页会把独立引用行折叠到“引用”区域展示。

## 对标审计

功能对标、开源项目检索和差距清单见 `research-and-gap-audit.md`。

## 线上构建

如果本机无法安装新版 Xcode，可以把仓库推到 GitHub，通过 `.github/workflows/ios-ci.yml` 在线编译和跑测试，并在配置 Apple 证书、Provisioning Profile 和 App Store Connect API Key 后，用 `.github/workflows/ios-testflight.yml` 手动上传 TestFlight。

详细步骤见 `docs/online-build-and-release.md`。

## 重要限制

本目录已经是可打开的 iOS 工程。当前目标可以先按个人自用推进；如果以后要上传 App Store，还需要你的 Apple Developer 账号、有效证书、App Store Connect app 记录以及新版 Xcode 构建环境。旧 Mac 可以只负责提交代码，Archive、签名和上传交给 GitHub Actions 或 Xcode Cloud。
