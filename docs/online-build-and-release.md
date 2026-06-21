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

1. 把 `work/some` 推到你的线上仓库。
2. 在 Xcode 工程里确认 scheme `some` 是 shared scheme，当前已包含。
3. 在 Apple Developer 后台创建唯一 Bundle ID。
4. 在 App Store Connect 创建同 Bundle ID 的 App。
5. 在 GitHub 仓库 Settings > Secrets and variables > Actions 添加以下 secrets。

## CI workflow

`.github/workflows/ios-ci.yml` 会使用 GitHub macOS runner 默认的稳定 Xcode，并在日志里打印实际版本：

- 编译模拟器版本
- 运行 `SomeTests`
- 禁用签名，所以不需要证书

如果 GitHub runner 上的模拟器名称变化，先打开 Actions 日志，根据可用 destination 调整 workflow 中的 `iPhone 16 Pro`。

## TestFlight secrets

`ios-testflight.yml` 需要这些 secrets：

- `APPLE_TEAM_ID`：Apple Developer Team ID
- `APP_BUNDLE_ID`：正式 Bundle ID，例如 `com.yourname.some`
- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`：Apple Distribution `.p12` 文件的 base64
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`：导出 `.p12` 时设置的密码
- `IOS_SIGNING_KEYCHAIN_PASSWORD`：CI 临时 keychain 密码，可自定义一个强密码
- `IOS_APP_STORE_PROVISIONING_PROFILE_BASE64`：App Store provisioning profile 的 base64
- `IOS_APP_STORE_PROVISIONING_PROFILE_NAME`：profile 在 Apple Developer 后台显示的名称
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

## 当前工程注意事项

- 本地 `CFBundleDisplayName` 仍是 `some`。
- 默认 Bundle ID 仍是示例值，CI 上传时可用 `APP_BUNDLE_ID` 覆盖，但最好最终也在 Xcode 工程里改成正式值。
- AI 功能是用户自带 OpenAI API Key。保留 AI 功能时，App Privacy 和审核说明需要披露：用户主动触发 AI 时，相关笔记文本会发送给 OpenAI API 用于 App 功能。
