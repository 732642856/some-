# some 本地安装与首用路径

## 结论

some 现在可以进入个人自用试用：仓库是完整 iOS 工程，主 App、Share Extension、Widget、CI workflow 和主要功能模块都已经在版本库里。你真正用上它通常只差本机运行环境或真机签名配置，而不是还停在产品概念阶段。

最快路径：

1. 在 Mac 上安装 Xcode 16 或更新版本。
2. 在仓库根目录执行 `bash scripts/check-local-readiness.sh`，先区分“项目缺文件”和“本机环境缺 SDK/签名”。
3. 打开 `some.xcodeproj`，选择 scheme `some`。
4. 先选 iPhone Simulator，点 Run。模拟器跑通后再上真机。
5. 真机自用时，在 `some`、`SomeShareExtension`、`SomeWidget` 三个 target 的 Signing & Capabilities 里选择你的 Team，并把 Bundle ID / App Group 改成你账号下唯一可用的值。

如果不配置 Apple 证书、Provisioning Profile、App Store Connect API Key，就不要走 TestFlight/App Store；直接用 Xcode 本机运行到模拟器或自己的设备上即可。

## 当前可用状态

- 代码层：最近的 GitHub Actions iOS CI 已通过，当前仓库结构完整。
- 本机层：当前这台机器若仍是旧 Xcode 或没有 iPhone Simulator SDK，只能做语法/脚本检查，不能代表 App 不能用。
- 真机层：需要你的 Apple ID/Developer Team、唯一 Bundle ID、Share Extension/Widget 对应 Bundle ID，以及同一个 App Group。
- 发布层：TestFlight/App Store 需要证书、profiles 和 App Store Connect 密钥，属于后续发布链路，不影响本地自用试跑。

## 20 分钟首用验收

先跑通这些路径，就算真正可用了：

1. 启动 App，保存一条文字随记。
2. 用快速输入分别试一次相册、拍照或扫描、录音、文件、网页摘录入口。
3. 打开素材库，确认图片、音频、视频、网页摘录和 OCR 记录能被筛选到。
4. 选一张图片进入图片编辑，保存一份带滤镜或边框的作品。
5. 进入手帐，创建一页，调整文字、贴纸、花边或图片图层，并导出 PNG/PDF。
6. 进入日志，勾选几条记录，生成工作日志并导出汇报稿。
7. 进入衣橱，新增单品、穿搭或穿着记录，查看洞察和打包建议。
8. 打开设置，试一次 Markdown 导出或完整备份导出。

如果第 1 到 8 项都跑通，some 就已经可以开始作为个人工具使用；后续优化会围绕真机视觉、性能和更细的工作流继续推进。

## Xcode 配置

1. 打开 `some.xcodeproj`。
2. 选择 scheme `some`。
3. 模拟器优先选择当前 Xcode 可用的最新 iPhone simulator。
4. 真机运行时，给三个 target 配置同一个 Apple Team：
   - `some`
   - `SomeShareExtension`
   - `SomeWidget`
5. Bundle ID 建议改成你自己的唯一前缀：
   - App：`com.yourname.some`
   - Share Extension：`com.yourname.some.share`
   - Widget：`com.yourname.some.widget`
6. App Group 建议改成同一组：
   - `group.com.yourname.some`
7. 确认三个 target 都使用同一个 App Group，否则主 App、分享扩展和小组件不会读到同一份本地数据。

## 常见卡点

- `No signing certificate` / `No profiles`：不是代码问题，是 Team、Bundle ID、证书或 provisioning profile 没配置。
- `Bundle identifier is not available`：默认 ID 已经被占用，需要改成你自己的唯一 ID。
- Share Extension 或 Widget 看不到数据：三个 target 的 App Group 不一致，或真机没有重新安装最新构建。
- 相机、麦克风、语音识别不可用：第一次使用时需要允许系统权限；模拟器上的部分媒体能力也可能弱于真机。
- 网页摘录失败：登录页、付费墙、反爬或网站限制不会被绕过；失败时会保留原链接。
- AI 功能无响应：本地 AI 记忆/搜索不需要 Key；OpenAI 洞察、语义搜索和日志 AI 润色需要你在设置里填写自己的 API Key。

## 参考

- Apple：[`Running your app on simulated or physical devices`](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
- Apple：[`Distributing your app to registered devices`](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)
- Apple：[`Adding capabilities to your app`](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app)
- Apple：[`Configuring app groups`](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- Apple：[`Register an App ID`](https://developer.apple.com/help/account/identifiers/register-an-app-id)
- Apple：[`Create a development provisioning profile`](https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile)
