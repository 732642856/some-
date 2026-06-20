# some

一个 SwiftUI 写的 iOS 轻量备忘应用，定位是“快速捕捉闪念、用标签自然整理、用 AI 洞察反复出现的主题”。项目避免使用 flomo 的名称、Logo、素材与品牌表达，便于作为原创应用提交 App Store。

## 已实现

- 快速输入卡片
- `#标签` 自动识别
- 支持 `#项目/子类` 多级标签
- 标签筛选
- 全文搜索
- 置顶
- 编辑和删除
- 本地 JSON 持久化
- Markdown 导出
- App 内隐私说明
- AppIcon 全尺寸资源
- `PrivacyInfo.xcprivacy` 隐私清单
- 记录 / AI / 回顾 / 统计 / 归档五视图
- 草稿自动保存
- 随机回顾与历史今天
- 记录热力图与高频标签
- JSON 备份导出与导入
- URL Scheme：`some://add?text=...`
- 可选 OpenAI API Key，保存在 iOS Keychain
- AI 洞察：周期复盘、困惑破局、自我觉察、主题研究、写作灵感
- AI 自然语言语义搜索
- AI 相关记录查找

## 打开工程

1. 安装 Xcode 16 或更新版本。
2. 打开 `some.xcodeproj`。
3. 在 target `some` 的 Signing & Capabilities 中选择你的 Apple Developer Team。
4. 把 Bundle Identifier 从 `com.732642856.some` 改成你账号下可用的唯一 ID。
5. 选择模拟器或真机运行。

## 上架前要替换的信息

- App 名称：默认 `some`
- Bundle ID：默认 `com.732642856.some`
- Copyright：在 App Store Connect 中填你的个人或公司主体
- 支持 URL：需要一个公开网页
- 隐私政策 URL：需要一个公开网页，可先用 `AppStore/privacy-policy.md` 的内容发布

## 技术说明

当前版本不接入账号、云同步、广告或第三方分析。笔记内容默认保存在用户设备的 app sandbox 中，导出由用户主动触发系统分享表。

AI 功能是可选能力：只有在设置里保存 OpenAI API Key，并主动点击 AI 洞察、AI 搜索或相关记录时，应用才会把本次操作需要的文本直接发送到 OpenAI API。API Key 保存在本机 Keychain，不写入 JSON 备份。

## 对标审计

功能对标、开源项目检索和差距清单见 `research-and-gap-audit.md`。

## 重要限制

本目录已经是可打开的 iOS 工程，但真正上传 App Store 需要你的 Apple Developer 账号、有效证书、App Store Connect app 记录以及本机完整 Xcode。当前机器只有 Command Line Tools，没有完整 Xcode，因此这里无法执行 Archive、签名和上传。
