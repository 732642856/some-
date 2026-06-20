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

## 未能在当前环境完成

- 当前机器没有完整 Xcode，`xcodebuild` 指向 Command Line Tools，因此无法在这里执行编译、测试运行、模拟器运行、Archive、签名或上传 App Store Connect。
- 当前 Command Line Tools 的 Swift 编译器为旧版 Swift 5.4，无法 typecheck Swift concurrency 代码；本轮只完成了 plist、scheme、target 引用和源码静态扫描。

## 下一步建议

在安装完整 Xcode 的 Mac 上打开 `some.xcodeproj`，设置 Team 和 Bundle ID 后运行一次模拟器，再执行 Product > Archive。
