# 开源对标与复用审计

日期：2026-06-21，更新：2026-06-22

## 审计原则

- 先找成熟项目或库，再决定是否手写。
- 可直接复制或作为依赖优先级：MIT、Apache-2.0、BSD 等宽松许可证。
- MPL-2.0 可参考架构；如果复制单个文件，必须保留 MPL 文件级开源义务和版权声明，当前项目默认避免直接复制。
- GPL / AGPL / 无许可证项目只做产品和实现思路参考，不拷贝代码。
- 涉及 App Store 发布的代码，优先用 Swift Package Manager 依赖；只有小而稳定、许可证清晰的文件才考虑 vendoring。

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

## some 当前缺口与复用优先级

P0 验证：

- 完整 Xcode 编译、单元测试、模拟器/真机运行。
- App Group、Share Extension、FTS 搜索在真机/模拟器上验证。

P1 优先复用：

- Markdown 二期：完整块级渲染、引用、代码块和附件卡片，优先评估 `Textual` / `MarkdownUI` / `swift-markdown`。
- Widget 快速入口：参考 MoeMemos 的 Widget 结构，重新实现。
- Share Extension 二期附件：参考 MoeMemos 附件处理流程，重写本项目的本地附件存储。

P2 优先复用：

- Zip 备份：引入 `ZIPFoundation`。
- 数据层复杂化：引入 `GRDB.swift`，替代继续扩展手写 sqlite3。
- 自托管 memos API 同步：按 usememos MIT API/模型设计适配器。

P3 只参考：

- AI 语音输入 / 转写：参考 usememos AI/transcription API 形态，具体实现走 OpenAI 官方 API。
- Backlinks / graph：参考无许可证项目和 MoeMemos relation 思路，不复制。

## 下一步建议

2026-06-21 本轮实现决策：已参考 MoeMemos 的 `SaveMemoIntent` / `AppShortcuts` 结构，但未复制 MPL 源码；本项目重新实现 `SaveMemoIntent` 和 `SomeAppShortcuts`，直接调用本地 `MemoStore` 写 SQLite。

2026-06-21 本轮实现决策：已参考 MoeMemos 的 Share Extension 附件处理边界，但未复制 MPL 源码；本项目重新实现本地附件保存，图片/文件写入 App Group `Attachments` 目录，memo 正文保存 `some-attachment://` 引用，主 App 列表和详情展示附件卡片。

2026-06-22 本轮实现决策：复查 flomo 101 官方导航与 MoeMemos/usememos 仓库结构后，优先补搜索二期。最近搜索、保存搜索、结果数量和命中摘录属于本地状态与 SwiftUI 交互，不适合直接复制 MoeMemos 的 MPL 源码，也没有必要把 usememos Web/Go 代码移植进 iOS；本项目按同类产品行为重新实现，并用单元测试覆盖持久化、去重、上限和摘录。

2026-06-22 本轮实现决策：对照 usememos 的 `MemoRelation` / `REFERENCE` / `COMMENT` API 和 Web 端 link memo 插入流程后，some 先做轻量本地 `REFERENCE`：用 `[引用: 标题](some-memo://UUID)` 写入正文，详情页展示正向/反向引用。没有复制 usememos 的 MIT Web/Go/Proto 代码，也没有复制 MoeMemos 的 MPL 源码；选择正文内链接是为了让现有 SQLite、备份、历史版本和 Markdown 导出无需 schema 大迁移即可保留关系。

2026-06-22 本轮实现决策：继续对照 usememos/memos 的 memo relations、link metadata 和内容 payload/filter 思路，补 some 搜索三期第一段。新增 `has:*` / `-has:*` 语法复用本项目已有 `LinkExtractor`、`SharedAttachmentStore`、`MemoTaskParser`、`MemoReferenceParser`，没有复制 usememos 的 MIT 代码；选择文本语法是为了让保存搜索、最近搜索和现有 FTS 查询链都能直接组合使用。

2026-06-22 本轮实现决策：继续补搜索三期第二段，参考 Joplin `created:` / `updated:` 日期过滤与“错误过滤器按普通文本处理”的交互原则。some 重新实现本地日期解析，只支持清晰的 `yyyy` / `yyyy-MM` / `yyyy-MM-dd` 和 `>` / `>=` / `<` / `<=` 边界语法，避免引入模糊自然语言日期依赖，也没有复制 Joplin 源码。

下一轮开发建议做引用批注二期或搜索三期，因为：

- Share Extension 附件 v1 已完成，主动网页标题抓取可后置到联网能力更明确时。
- 搜索二期已完成基础版，搜索三期已补结构化筛选和日期筛选；下一步应继续做命中高亮、保存筛选重命名。
- 历史版本基础版已完成；下一步应做差异对比、版本备注、按版本复制。
- 卡片引用 v1 已完成；下一步应补批注正文、关系图和引用搜索筛选。
- 两者都不依赖签名证书，适合在当前环境继续推进。

推荐路线：

1. 引用批注二期：批注正文、关系图、引用搜索筛选。
2. 搜索三期：命中高亮、保存筛选重命名。
3. 历史版本二期：差异对比、版本备注、按版本复制。
4. 附件后续：如需按年月拆分 Markdown 和附件目录，再引入 ZIPFoundation 做 zip 包导出。
5. 网页后续：在明确网络策略后再做标题抓取。
