# some

一个 SwiftUI 写的 iOS 轻量备忘应用，定位是“快速捕捉闪念、用标签自然整理、用 AI 洞察反复出现的主题”。项目避免使用 flomo 的名称、Logo、素材与品牌表达，便于作为原创应用提交 App Store。

## 已实现

- 快速输入卡片
- `#标签` 自动识别
- 支持 `#项目/子类` 多级标签
- 标签筛选
- SQLite FTS 全文搜索
- 搜索语法：`#标签`、`tag:标签`、`is:pinned`、`is:archived`、`is:active`
- 置顶
- 编辑和删除
- 本地 SQLite 持久化
- Markdown 导出
- App 内隐私说明
- AppIcon 全尺寸资源
- `PrivacyInfo.xcprivacy` 隐私清单
- 旧 JSON 数据自动迁移，主文件损坏时可从 `.bak.json` 兜底迁移
- 记录 / AI / 回顾 / 统计 / 归档五视图
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

## 搜索语法

- 普通文字：搜索正文和标签，例如 `读书 摘录`
- `#标签` 或 `tag:标签`：按标签过滤，支持匹配子标签，例如 `#产品`
- `is:pinned` / `is:unpinned`：只看置顶或未置顶
- `is:archived` / `is:active`：只看归档或当前记录
- 双引号：把空格内容作为一个搜索词，例如 `"输入体验"`

## 打开工程

1. 安装 Xcode 16 或更新版本。
2. 打开 `some.xcodeproj`。
3. 在 target `some` 的 Signing & Capabilities 中选择你的 Apple Developer Team。
4. 把 Bundle Identifier 从 `com.732642856.some` 改成你账号下可用的唯一 ID。
5. 在 target `some` 和 `SomeShareExtension` 中启用同一个 App Group，默认占位为 `group.com.732642856.some`，需要按你的 Bundle ID 改成账号下可用的 group。工程通过 build setting `APP_GROUP_IDENTIFIER` 同步写入 entitlements 和运行时配置。
6. 选择模拟器或真机运行。

## 上架前要替换的信息

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

Share Extension 对网页标题的支持依赖系统分享项提供的标题/摘要；当前不会主动联网抓取网页 HTML。

## 对标审计

功能对标、开源项目检索和差距清单见 `research-and-gap-audit.md`。

## 线上构建

如果本机无法安装新版 Xcode，可以把仓库推到 GitHub，通过 `.github/workflows/ios-ci.yml` 在线编译和跑测试，并在配置 Apple 证书、Provisioning Profile 和 App Store Connect API Key 后，用 `.github/workflows/ios-testflight.yml` 手动上传 TestFlight。

详细步骤见 `docs/online-build-and-release.md`。

## 重要限制

本目录已经是可打开的 iOS 工程，但真正上传 App Store 需要你的 Apple Developer 账号、有效证书、App Store Connect app 记录以及新版 Xcode 构建环境。旧 Mac 可以只负责提交代码，Archive、签名和上传交给 GitHub Actions 或 Xcode Cloud。
