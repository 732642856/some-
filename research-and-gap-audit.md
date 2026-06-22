# 地毯式探索与功能差距审计

日期：2026-06-20，更新：2026-06-22

## 本地碎片盘点

已搜索 `/Users/wuyongnaren/Documents/Codex` 下的相关关键词、工程文件、README、许可证和 Git 仓库。

直接相关：

- `outputs/some`：当前 iOS 工程
- `work/open-source/MoeMemos`：已克隆，SwiftUI iOS memos 客户端，MPLv2
- `work/open-source/memos`：已克隆，usememos 服务端/Web，MIT

旧窗口遗留：

- `2026-06-18/new-chat-4/work/starcanvas-active`：StarCanvas 项目，含 memory/supermemory 方向，但不是 iOS 备忘 App 可直接迁移代码
- `2026-06-18/new-chat-4/work/agent-tools/taste-skill`：审美/品味技能材料，可用于后续 UI 评审，不是功能代码

未发现此前已存在的 flomo/iOS 备忘 App 工程碎片。

2026-06-22 复查：

- 当前主仓库：`/Users/wuyongnaren/Documents/some随记`，Git 工作区在开工前干净，分支为 `master`，远端为 `https://github.com/732642856/some-.git`。
- 旧 Codex 工作区：`/Users/wuyongnaren/Documents/Codex/2026-06-20/some-flomo-app-app-store-1`、`/Users/wuyongnaren/Documents/Codex/2026-06-21/some-flomo-app-app-store-1`。二者主要是早期工程快照，当前主仓库已包含其后续功能补齐内容。
- 已克隆开源参考仍在 `/Users/wuyongnaren/Documents/Codex/2026-06-20/wo/work/open-source/MoeMemos` 与 `/Users/wuyongnaren/Documents/Codex/2026-06-20/wo/work/open-source/memos`。
- 额外用 `/Users/wuyongnaren` 有限深度搜索 `some.xcodeproj`、`SomeTests.swift`、`SomeShareExtension`、`research-and-gap-audit.md`，未发现除当前主仓库以外的新工程碎片。
- Xcode 工程引用已覆盖当前新增过的核心文件；本轮未新增 Swift 文件，只修改已有 target 内文件。

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
- 搜索语法：`#标签`、`tag:标签`、`is:pinned`、`is:archived`、`is:active`、`has:link` / `has:attachment` / `has:task` / `has:reference`
- Markdown 阅读渲染：列表与详情页使用系统 Markdown 富文本展示
- Markdown 任务项：识别 `- [ ]` / `- [x]`，详情页可直接勾选并写回 SQLite
- App Intents / Shortcuts：快捷指令可保存新随记，复用本地 SQLite 存储
- Share Extension 附件 v1：支持图片/文件分享，本地 App Group 附件目录保存，列表/详情展示附件卡片
- 历史版本：编辑前保存旧正文，详情页可查看并恢复，完整备份会包含历史版本及其附件
- 搜索二期：提交搜索会记录最近搜索，可保存常用组合筛选，首页显示搜索结果数量，卡片显示命中摘录
- 搜索三期第一段：参考 usememos 的关系、链接元数据与内容 payload/filter 思路，新增 `has:*` 结构化筛选；覆盖链接、附件、任务、未完成/已完成任务、正向引用和反向引用，并支持 `-has:` / `no:` / `without:` 排除
- 卡片引用 v1：详情页可添加内部 `some-memo://UUID` 引用，并展示正向引用与反向引用；引用保存在正文中，随导出、备份和历史版本迁移

## AI 对标补充

usememos 当前开源实现的 AI 主线是 BYOK provider 配置与语音转写接口；`proto/api/v1/ai_service.proto` 暴露 `Transcribe`，Web 设置页支持 OpenAI / Gemini provider 和 transcription 参数。本项目本轮没有直接复制这些 GPL/MPL 风险代码，而是按同类 BYOK 思路做了 iOS 本地 Keychain 配置，并补上 flomo AI 洞察方向更相关的周期复盘、困惑破局、自我觉察、主题研究、写作灵感、语义搜索和相关记录。

OpenAI 接口依据 2026-06-20 官方 API 文档接入：文本生成使用 Responses API `POST /v1/responses`，语义向量使用 Embeddings API，默认 embedding 模型为 `text-embedding-3-small`，Responses 模型可在设置中修改，默认 `gpt-4o-mini`。本轮已添加 OpenAI Docs MCP，但需要重启 Codex 后才会暴露工具；当前代码先采用稳定可配置默认值。

## 仍未完成但应排优先级

P0：

- 用完整 Xcode 编译运行，修掉真实编译错误
- 增加基础单元测试：继续补 SQLite 迁移边界、Share Extension 端保存流程、App Group 真机验证
- 在 Apple Developer / Xcode Signing & Capabilities 中为主 App 和 Share Extension 配好同一个 App Group

P1：

- Share Extension 二期：主动网页标题抓取、保存后自动返回来源 App 的体验验证
- 搜索三期：命中高亮、按日期筛选、保存筛选重命名；附件/任务/引用结构化筛选已先完成
- Markdown 二期：完整块级渲染、代码块、引用批注、附件卡片
- 历史版本二期：差异对比、版本备注、按版本复制

P2：

- 小组件
- 引用批注二期：批注正文、关系图、引用搜索筛选
- 导出 zip，按年月拆分 Markdown
- 自托管 usememos API 同步

P3：

- AI 语音输入 / 语音转写
- AI 洞察周报 / 月报
- 本地向量缓存，减少重复 embedding 调用
- MCP 读写接口
- 多 provider 支持：Gemini、OpenAI 兼容 endpoint、自托管模型

## 复用策略

- 直接复制或引入依赖：仅限 MIT / Apache-2.0 / BSD 等宽松许可证且模块边界清楚的代码。优先引入 Swift Package，而不是复制源码文件。
- 借鉴结构：MoeMemos 的热力图、归档、Share Extension、App Intents、小组件、本地导出流程。
- 避免复制：MoeMemos 的 MPLv2 源码、Blinko 的 GPL-3.0 源码暂不整段混入，除非后续明确接受对应开源义务。
- 重点候选：Markdown 渲染用 `Textual` / `MarkdownUI` / `swift-markdown`，zip 导出用 `ZIPFoundation`，复杂 SQLite 用 `GRDB.swift`，自托管同步参考 usememos MIT API。
