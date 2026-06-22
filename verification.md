# 验证记录

日期：2026-06-20

## 已完成检查

- `Info.plist` 通过 `plutil -lint`
- `PrivacyInfo.xcprivacy` 通过 `plutil -lint`
- `project.pbxproj` 通过 `plutil -lint`
- `some.xcscheme` 通过 XML parser 校验
- Asset Catalog 的 JSON 文件通过 `python3 -m json.tool`
- App Store 图标 `AppStore/icon-1024.png` 为 1024x1024 RGB PNG
- AppIcon 集合包含 iPhone、iPad 和 iOS marketing 所需尺寸
- 上架文案未把 `flomo` 作为应用名称、关键词或宣传语使用
- 已补充 `research-and-gap-audit.md`，记录 flomo/MoeMemos/usememos 对标与后续差距
- 所有 app Swift 文件均已纳入 Xcode app target
- `SomeTests` 测试 target 已加入工程和共享 scheme
- 已补充 AI 相关单元测试：余弦相似度、AI 洞察 Prompt、归档过滤
- 已新增 AI 模块并确认所有新增 Swift 文件纳入 Xcode app target
- 已扫描 `TODO` / `FIXME` / `try!` / `as!` / 旧 OpenAI 模型名，未发现命中
- `PrivacyInfo.xcprivacy` 已按可选 AI 请求保守披露 Other User Content / App Functionality，并声明 UserDefaults required reason API
- 已按 `openai-docs` 技能安装 OpenAI Docs MCP：`openaiDeveloperDocs`。当前会话需要重启后才会暴露对应工具，本轮代码依据官方网页文档与保守默认模型实现。
- 2026-06-21：已将最新工程从 Codex 历史工作区收拢到 `/Users/wuyongnaren/Documents/some随记`
- 2026-06-21：已新增隐私锁、每日回顾提醒、链接识别与打开
- 2026-06-21：已确认 `AppLockView.swift`、`ReminderManager.swift`、`LinkExtractor.swift` 纳入 Xcode app target
- 2026-06-21：已确认 `LocalAuthentication.framework`、`UserNotifications.framework` 纳入 app target
- 2026-06-21：`Info.plist`、`PrivacyInfo.xcprivacy`、`project.pbxproj` 通过 `plutil -lint`
- 2026-06-21：`some.xcscheme` 通过 `xmllint --noout`
- 2026-06-21：已补充隐私锁默认锁定、每日提醒默认时间、链接去重解析相关单元测试
- 2026-06-21：主存储已从单 JSON 文件升级为 SQLite，旧 JSON / `.bak.json` 会在首次打开时迁移
- 2026-06-21：已确认 `SQLiteMemoDatabase.swift` 纳入 Xcode app target，`libsqlite3.tbd` 纳入 app Frameworks
- 2026-06-21：已补充 SQLite 跨实例持久化与旧 JSON 备份迁移相关单元测试
- 2026-06-21：已新增 Share Extension target，支持从其他 App 分享文本/链接到 some
- 2026-06-21：已新增 App Group entitlements，占位 group 为 `group.com.732642856.some`
- 2026-06-21：已新增共享存储路径与旧 Documents 数据迁移逻辑
- 2026-06-21：已增强快速输入：自动聚焦、保存并继续、标签建议、链接预览
- 2026-06-21：`Info.plist`、`PrivacyInfo.xcprivacy`、主 App/扩展 entitlements、Share Extension `Info.plist`、`project.pbxproj` 通过 `plutil -lint`
- 2026-06-21：已补充分享内容组合/URL 去重相关单元测试
- 2026-06-21：已新增 SQLite FTS5 搜索索引，记录新增、编辑、删除时同步索引
- 2026-06-21：已新增搜索语法解析：`#标签`、`tag:标签`、`is:pinned`、`is:unpinned`、`is:archived`、`is:active`
- 2026-06-21：已补充搜索解析、标签/置顶组合过滤、归档搜索、索引更新删除相关单元测试
- 2026-06-21：已新增 `docs/open-source-reuse-audit.md`，记录 MoeMemos/usememos 与全网开源候选的许可证、可复用范围和下一步优先级
- 2026-06-21：已新增 `MarkdownMemoTextView`，列表和详情页支持系统 Markdown 阅读渲染
- 2026-06-21：已新增 `MemoTaskParser`，支持 `- [ ]` / `- [x]` 任务项识别与详情页勾选写回
- 2026-06-21：已补充任务项解析、切换和 Store 写回相关单元测试
- 2026-06-21：已新增 `SaveMemoIntent` 与 `SomeAppShortcuts`，支持快捷指令保存新随记
- 2026-06-21：已补充 `MemoStore.addMemo` 输入清洗、空内容忽略、标签保留相关单元测试
- 2026-06-21：已新增 `SharedAttachmentStore`，支持 App Group 本地附件保存、引用解析、文件名去重
- 2026-06-21：已扩展 Share Extension 支持图片/文件分享，主 App 列表和详情页展示附件卡片
- 2026-06-21：已补充附件引用解析、链接过滤、文件名去重、任务行号映射相关单元测试
- 2026-06-21：已新增完整备份 `MemoBackupArchive`，导出会把 memo 与本地附件数据一起编码，导入时会恢复附件并重写引用
- 2026-06-21：已修复完整备份导出为文件、设置页识别 `{}` 完整备份、坏附件备份半导入、重复备份生成孤儿附件等数据安全问题
- 2026-06-21：已修复编辑/删除 memo 时误删仍被其他 memo 引用的共享附件问题
- 2026-06-21：已修复完整备份导出在附件文件缺失时静默降级为不完整备份的问题，现在会明确失败并提示用户
- 2026-06-21：已修复快速输入保存失败时清空草稿的问题，现在会保留草稿并提示用户
- 2026-06-21：已修复快捷指令保存失败时误报“空内容”的问题，现在会区分空内容与存储失败
- 2026-06-21：已修复 AI 洞察保存失败时误报“已保存”的问题，现在会按真实写入结果反馈
- 2026-06-21：已将主 App Bundle ID、Share Extension Bundle ID、App Group 抽成 build settings / CI secrets，减少发布签名时多处手改不一致的风险
- 2026-06-21：已更新 TestFlight workflow，支持主 App 和 Share Extension 两套 App Store provisioning profile
- 2026-06-21：已修正 README 附件删除说明，并补充 TestFlight 真机验收清单
- 2026-06-21：已增强 TestFlight workflow 的 macOS 兼容性与失败提示：使用 `base64 -D`、缺少 secrets 时快速失败、设置 keychain partition list、找不到 IPA 时直接报错
- 2026-06-21：已增强 App Group 运行时读取逻辑，`APP_GROUP_IDENTIFIER` 为空字符串时会回退到默认占位值，避免空 group 导致主 App / Share Extension 路径异常
- 2026-06-21：已修正隐私政策中“默认本地保存”和“可选 AI 会发送所需内容”的表述，避免 App Store 审核口径前后冲突
- 2026-06-21：已新增 `.gitignore`，避免 Xcode 本地状态、构建产物、Archive、IPA 和签名材料误提交
- 2026-06-21：已修正文档中的旧工作区路径，并把隐私政策联系方式占位改为 App Store 支持链接口径
- 2026-06-22：已复查当前主仓库、旧 Codex 工作区和已克隆开源参考，未发现当前主仓库外仍需合入的新 some 工程碎片。
- 2026-06-22：已对照 flomo 101 官方功能导航、MoeMemos 与 usememos/memos，确认本轮优先补搜索二期而非继续扩展表面功能。
- 2026-06-22：已新增最近搜索、保存搜索、搜索结果数量和卡片命中摘录。
- 2026-06-22：已补充最近搜索去重/持久化、最近搜索上限、保存搜索持久化/应用、命中摘录相关单元测试。
- 2026-06-22：`Info.plist`、`PrivacyInfo.xcprivacy`、主 App/扩展 entitlements、Share Extension `Info.plist`、`project.pbxproj` 通过 `plutil -lint`。
- 2026-06-22：`some.xcscheme` 通过 `xmllint --noout`。
- 2026-06-22：已扫描 `text.magnifyingglass`、`TODO`、`FIXME`、`try!`、`as!`，未发现命中。
- 2026-06-22：已对照 usememos `MemoRelation` / `REFERENCE` / `COMMENT` 与 flomo 101 引用批注，新增卡片引用 v1。
- 2026-06-22：已新增 `MemoReferenceParser`，并确认纳入主 App 与 Share Extension sources。
- 2026-06-22：已补充内部引用解析、隐藏引用行、添加引用、反向引用、引用去重、普通链接过滤内部引用相关单元测试。
- 2026-06-22：已复查主仓库、未跟踪文件和 Documents 下同名目录，未发现当前主仓库外的活跃 some 工程碎片；外部只看到旧 Codex 会话目录。
- 2026-06-22：已对照 usememos/memos 的 memo relations、link metadata 与内容 payload/filter 思路，新增搜索三期第一段：`has:link`、`has:attachment`、`has:task`、`has:open-task`、`has:completed-task`、`has:reference`、`has:backlink`，并支持 `-has:` / `no:` / `without:` 排除。
- 2026-06-22：已补充结构化搜索解析、未知 `has:` 回落为普通文本、链接/附件/任务/引用/反向引用筛选、排除筛选相关单元测试。
- 2026-06-22：已将 `LinkExtractor.swift` 纳入 Share Extension sources，避免共享 `MemoStore` 使用链接筛选时扩展 target 缺符号。
- 2026-06-22：本轮 `git diff --check`、`plutil -lint`、`xmllint --noout` 通过；旧版 `xcrun swiftc -parse` 已覆盖新增搜索解析器、`MemoStore` 和测试文件的语法层检查。
- 2026-06-22：再次复查主仓库、未跟踪文件和 Documents 下同名目录，未发现当前主仓库外的活跃 some 工程碎片。
- 2026-06-22：已对照 Joplin 搜索文档的 `created:` / `updated:` 日期过滤和错误过滤器回落原则，新增 `created:` / `updated:` 日期筛选，支持年/月/日范围和 `>` / `>=` / `<` / `<=` 边界过滤。
- 2026-06-22：已补充日期筛选解析、无效日期回落普通文本、创建日期范围筛选、更新时间筛选与普通文本组合相关单元测试。
- 2026-06-22：根据用户修订，已确认 some 的目标不再只是 flomo 式轻备忘，而是本地优先个人素材库，覆盖电子手帐、工作日志、网页摘录、图片编辑和电子衣橱。
- 2026-06-22：已补做本地碎片扫描，新增发现并记录 `/Users/wuyongnaren/Documents/Codex/2026-06-20/wo/outputs/some`；与当前主仓库比对后未发现需要补回的独有新功能文件。
- 2026-06-22：已把每轮开发前强制审计流程写入 `research-and-gap-audit.md`：Git 状态、未跟踪文件、全量文件清单、旧窗口目录、Xcode target membership、全网开源检索和许可证记录。
- 2026-06-22：已重新检索并记录新目标相关开源候选：图片裁剪/编辑 `Mantis`、`TOCropViewController`、`HXPhotoPicker`，网页提取 `ReadabilityKit`，OCR `OpenFind` / `SwiftOCRKit`，衣橱参考 `AURA` 等。
- 2026-06-22：已明确图片清理边界：支持用户拥有或获授权图片的修复、对象清理、背景处理和排版，不把移除第三方版权标识、平台水印或规避授权限制作为产品目标。
- 2026-06-22：已更新下一步优先级：先做统一素材模型、多模态采集、网页/OCR 摘录、电子衣橱、电子手帐和图片编辑 MVP，再回补 flomo 小组件、禅定模式、MCP/API、AI 语音和记忆档案等缺口。
- 2026-06-22：已按用户提供的 `/Users/wuyongnaren/Downloads/辰星话本.JPG` 替换 some AppIcon 和 App Store 1024 图标，并把 UI 色系调整为浅粉、雾蓝、淡紫、柔白的小清新方向。
- 2026-06-22：本轮视觉更新前已复查 Git 状态、未跟踪文件、Documents 下 some 相关目录，并做开源检索；图标生成使用用户提供图片和本地 Pillow，不引入第三方运行时代码。

## 未能在当前环境完成

- 当前机器的 `xcode-select` 指向 Command Line Tools，且 `/Applications/Xcode.app` 是 Xcode 13.2.1；当前 iOS 16+ 工程需要 Xcode 16 或更新版本才能可靠编译、测试、模拟器运行、Archive、签名或上传 App Store Connect。
- 当前 Command Line Tools 的 Swift 编译器为旧版 Swift 5.4，无法 typecheck Swift concurrency 代码；本轮只完成了 plist、scheme、target 引用和源码静态扫描。
- 2026-06-22 复查：`xcodebuild -version` 仍失败，提示 active developer directory 为 `/Library/Developer/CommandLineTools`；`xcrun swiftc -version` 为 Apple Swift 5.4。
- Share Extension 的真实分享面板、App Group 容器和签名能力需要在完整 Xcode + Apple Developer Team 环境里实机或模拟器验证。
- 旧版 `xcrun swiftc -parse` 只能做语法层检查，不能替代 Xcode 16 的完整 typecheck、XCTest 或 Share Extension 真机验证。

## 下一步建议

在安装完整 Xcode 的 Mac 上打开 `some.xcodeproj`，设置 Team 和 Bundle ID 后运行一次模拟器，再执行 Product > Archive。
