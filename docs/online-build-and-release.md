# 线上构建与上架流程

本项目可以不依赖本地 Xcode 构建。2015 年 Mac 可以继续负责改代码、提交 Git；编译、测试、Archive、上传 TestFlight 放到 GitHub Actions 或 Xcode Cloud。

## 推荐路径

首选 GitHub Actions：

- `iOS CI`：每次 push / PR 在线编译并跑测试，不需要证书。
- `iOS TestFlight`：手动触发 Archive、导出 IPA、上传 App Store Connect，需要证书和 App Store Connect API Key。

备选 Xcode Cloud：

- 适合仓库已经托管在 GitHub/GitLab/Bitbucket，且你愿意在 App Store Connect 里完成 Xcode Cloud 配置。
- 优点是 Apple 官方链路更省心；缺点是初次配置仍需要 App Store Connect 权限、签名和工作流设置。

## GitHub 仓库准备

1. 把本仓库根目录推到你的线上仓库。
2. 在 Xcode 工程里确认 scheme `some` 是 shared scheme，当前已包含。
3. 在 Apple Developer 后台创建唯一主 App Bundle ID。
4. 创建 Share Extension Bundle ID，建议格式为主 App ID 加 `.share`。
5. 创建 Widget Extension Bundle ID，建议格式为主 App ID 加 `.widget`。
6. 创建 App Group，并同时勾选主 App、Share Extension 与 Widget Extension。
7. 在 App Store Connect 创建同主 App Bundle ID 的 App。
8. 在 GitHub 仓库 Settings > Secrets and variables > Actions 添加以下 secrets。

## CI workflow

`.github/workflows/ios-ci.yml` 会使用 GitHub macOS runner 默认的稳定 Xcode，并在日志里打印实际版本：

- 编译模拟器版本
- 运行 `SomeTests`
- 禁用签名，所以不需要证书
- 使用 `actions/checkout@v5`
- 测试构建会通过 `CI_DISABLE_APP_INTENTS` 和 `EXCLUDED_SOURCE_FILE_NAMES` 临时排除 App Intents 源文件，绕开 GitHub runner 上 App Intents 元数据训练偶发解析 `extract.actionsdata` 失败；正式 App build / TestFlight workflow 不使用这个排除

如果 GitHub runner 上的模拟器名称变化，先打开 Actions 的 `Resolve simulator destination` 日志；CI 会自动选择第一个可用 iPhone simulator。

## TestFlight secrets

`ios-testflight.yml` 需要这些 secrets：

发布 workflow 也使用 `actions/checkout@v5`，与 CI workflow 保持一致。

- `APPLE_TEAM_ID`：Apple Developer Team ID
- `APP_BUNDLE_ID`：正式 Bundle ID，例如 `com.yourname.some`
- `SHARE_EXTENSION_BUNDLE_ID`：分享扩展 Bundle ID，例如 `com.yourname.some.share`；不填时 workflow 默认使用 `${APP_BUNDLE_ID}.share`
- `WIDGET_EXTENSION_BUNDLE_ID`：小组件扩展 Bundle ID，例如 `com.yourname.some.widget`；不填时 workflow 默认使用 `${APP_BUNDLE_ID}.widget`
- `APP_GROUP_IDENTIFIER`：App Group，例如 `group.com.yourname.some`
- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`：Apple Distribution `.p12` 文件的 base64
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`：导出 `.p12` 时设置的密码
- `IOS_SIGNING_KEYCHAIN_PASSWORD`：CI 临时 keychain 密码，可自定义一个强密码
- `IOS_APP_STORE_PROVISIONING_PROFILE_BASE64`：App Store provisioning profile 的 base64
- `IOS_APP_STORE_PROVISIONING_PROFILE_NAME`：profile 在 Apple Developer 后台显示的名称
- `IOS_SHARE_EXTENSION_APP_STORE_PROVISIONING_PROFILE_BASE64`：Share Extension App Store provisioning profile 的 base64
- `IOS_SHARE_EXTENSION_APP_STORE_PROVISIONING_PROFILE_NAME`：Share Extension profile 在 Apple Developer 后台显示的名称
- `IOS_WIDGET_EXTENSION_APP_STORE_PROVISIONING_PROFILE_BASE64`：Widget Extension App Store provisioning profile 的 base64
- `IOS_WIDGET_EXTENSION_APP_STORE_PROVISIONING_PROFILE_NAME`：Widget Extension profile 在 Apple Developer 后台显示的名称
- `ASC_API_KEY_ID`：App Store Connect API Key ID
- `ASC_API_ISSUER_ID`：Issuer ID
- `ASC_API_PRIVATE_KEY_BASE64`：`AuthKey_XXXX.p8` 的 base64

macOS / Linux 生成 base64 常用命令：

```bash
base64 -i file.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
base64 -i AuthKey_XXXX.p8 | pbcopy
```

## 上架前仍需人工完成

- App Store Connect 元数据、分类、年龄分级、隐私问卷
- 支持 URL 和隐私政策 URL
- 截图和审核说明
- TestFlight 自测通过后选择 build 提交审核

## TestFlight 真机验收清单

- 首次启动能创建、编辑、置顶、归档、删除随记。
- 快速输入保存失败时不会丢草稿。
- 标签筛选、FTS 搜索、`tag:` / `is:` 搜索语法正常。
- 从 Safari、照片、文件 App 分享文本、链接、图片和文件到 some。
- 分享扩展保存后，主 App 立即能看到同一条记录和附件。
- 桌面小组件能显示最新记录计数，点击首页、专注、搜索和单条记录入口能回到 App。
- 删除其中一条引用附件的 memo，不会误删仍被其他 memo 引用的附件。
- 完整备份导出、删除 App 后重装、导入完整备份，记录和附件都能恢复。
- 隐私锁、每日提醒、快捷指令保存新随记均能在真机运行。
- AI 未配置 Key 时不发起请求；配置 Key 后 AI 洞察、AI 搜索有明确成功/失败提示。

## 当前工程注意事项

- 本地 `CFBundleDisplayName` 仍是 `some`。
- 默认主 App Bundle ID、Share Extension Bundle ID、Widget Extension Bundle ID 和 App Group 仍是示例值，CI 上传时可用 `APP_BUNDLE_ID`、`SHARE_EXTENSION_BUNDLE_ID`、`WIDGET_EXTENSION_BUNDLE_ID`、`APP_GROUP_IDENTIFIER` 覆盖，但最好最终也在 Xcode 工程 Build Settings 里改成正式值。
- AI 功能是用户自带 OpenAI API Key。保留 AI 功能时，App Privacy 和审核说明需要披露：用户主动触发 AI 时，相关笔记文本会发送给 OpenAI API 用于 App 功能。
