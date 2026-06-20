# 地毯式探索与功能差距审计

日期：2026-06-20

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
- JSON 备份导出
- JSON / 普通文本导入
- URL Scheme：`some://add?text=...`
- OpenAI API Key 本机 Keychain 保存
- AI 自然语言语义搜索
- AI 相关记录查找
- AI 洞察：周期复盘 / 困惑破局 / 自我觉察 / 主题研究 / 写作灵感

## AI 对标补充

usememos 当前开源实现的 AI 主线是 BYOK provider 配置与语音转写接口；`proto/api/v1/ai_service.proto` 暴露 `Transcribe`，Web 设置页支持 OpenAI / Gemini provider 和 transcription 参数。本项目本轮没有直接复制这些 GPL/MPL 风险代码，而是按同类 BYOK 思路做了 iOS 本地 Keychain 配置，并补上 flomo AI 洞察方向更相关的周期复盘、困惑破局、自我觉察、主题研究、写作灵感、语义搜索和相关记录。

OpenAI 接口依据 2026-06-20 官方 API 文档接入：文本生成使用 Responses API `POST /v1/responses`，语义向量使用 Embeddings API，默认 embedding 模型为 `text-embedding-3-small`，Responses 模型可在设置中修改，默认 `gpt-4o-mini`。本轮已添加 OpenAI Docs MCP，但需要重启 Codex 后才会暴露工具；当前代码先采用稳定可配置默认值。

## 仍未完成但应排优先级

P0：

- 用完整 Xcode 编译运行，修掉真实编译错误
- 改成 SwiftData 或 SQLite，替代单 JSON 文件
- 增加基础单元测试：标签解析、导入导出、搜索过滤、归档过滤

P1：

- Share Extension：从其他 App 分享文本/链接进来
- App Intent / Shortcuts：快捷指令新增记录
- 本地通知回顾
- Face ID / 密码锁
- Markdown 渲染与任务项勾选
- 历史版本

P2：

- 图片附件
- 小组件
- 引用批注/卡片连接
- 导出 zip，按年月拆分 Markdown
- 自托管 usememos API 同步

P3：

- AI 语音输入 / 语音转写
- AI 洞察周报 / 月报
- 本地向量缓存，减少重复 embedding 调用
- MCP 读写接口
- 多 provider 支持：Gemini、OpenAI 兼容 endpoint、自托管模型

## 复用策略

- 直接复制：仅限 MIT 且模块边界清楚的代码；当前 Swift 端暂未直接复制 MIT 项目代码。
- 借鉴结构：MoeMemos 的热力图、归档、Share Extension、App Intents、小组件、本地导出流程。
- 避免复制：MoeMemos 的 MPLv2 源码、Blinko 的 GPL-3.0 源码暂不整段混入，除非后续明确接受对应开源义务。
