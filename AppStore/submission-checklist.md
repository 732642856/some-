# App Store 上架清单

## 账号与工程

- 加入 Apple Developer Program。
- 在 App Store Connect 创建新 App。
- 在 Apple Developer 后台创建或确认 Bundle ID。
- 为 Share Extension 创建独立 Bundle ID，建议为主 App Bundle ID 加 `.share`。
- 为 Widget Extension 创建独立 Bundle ID，建议为主 App Bundle ID 加 `.widget`。
- 创建 App Group，并确认主 App、Share Extension 和 Widget Extension 都启用同一个 group。
- 用 Xcode 打开 `some.xcodeproj`。
- 修改 Bundle Identifier，不能继续使用示例 ID `com.732642856.some`，除非它已属于你的 Apple Developer 账号。
- 修改 Share Extension Bundle Identifier，不能继续使用示例 ID `com.732642856.some.share`。
- 修改 Widget Extension Bundle Identifier，不能继续使用示例 ID `com.732642856.some.widget`。
- 修改 `APP_GROUP_IDENTIFIER`，不能继续使用示例 group `group.com.732642856.some`，除非它已属于你的 Apple Developer 账号。
- 在 Signing & Capabilities 选择你的 Team。
- 真机和模拟器都跑一遍核心流程。

## 隐私与合规

- 发布一个公开可访问的隐私政策页面。
- App Store Connect 的 Privacy Policy URL 填入该页面。
- App Privacy 需要按实际上架版本填写：如果保留 AI 功能，需披露用户主动发送给 OpenAI API 的文本处理；如果移除 AI 功能且没有任何网络上传，才可选择不收集数据。
- 如果保留 AI 语义搜索，需要在隐私政策和审核说明中写明本机 App Group `AICache` 会保存最近使用的记录 embedding 缓存：key 使用模型名和文本 SHA-256 指纹、最多 1000 条、不额外保存笔记明文、设置页可查看条数/大小并清除。
- Export Compliance：当前版本只使用 Apple 系统框架和本地存储，通常可选择不使用专门加密功能；最终仍按 App Store Connect 的问卷如实回答。
- 不要在应用名、描述、截图中使用 flomo 品牌词、Logo 或暗示从属关系。

## 构建与上传

### 本机新 Xcode 路径

- 在 Xcode 中选择 `Any iOS Device`。
- Product > Archive。
- Organizer 中选择 Distribute App。
- 选择 App Store Connect。
- 完成签名、验证和上传。

### 线上 GitHub Actions 路径

- 把当前工程推到 GitHub 仓库。
- 先运行 `iOS CI` workflow，确认模拟器编译和测试通过。
- 在 GitHub Actions secrets 配置 Apple Team、主 App Bundle ID、Share Extension Bundle ID、Widget Extension Bundle ID、App Group、Distribution 证书、主 App 和两个扩展的 App Store provisioning profile、App Store Connect API Key。
- 手动触发 `iOS TestFlight` workflow。
- 等 App Store Connect 处理 build。
- 等 Apple 处理 build，处理完成后在 App Store Connect 选择该 build。
- 填元数据、截图、年龄分级、隐私信息、审核说明。
- Submit for Review。

详细配置见 `docs/online-build-and-release.md`。

## 截图建议

至少准备 iPhone 6.7 英寸和 6.5 英寸截图。首版建议 3 张：

- 快速记录页：展示输入框和卡片流。
- 标签筛选页：展示标签和搜索。
- AI 洞察页：展示周期复盘、困惑破局或写作灵感结果，避免截图中出现真实 API Key。
- 编辑/导出页：展示编辑、置顶和 Markdown 导出。

## TestFlight 自测

- 快速输入保存并继续、失败保留草稿。
- 搜索、标签、归档、置顶、编辑、删除。
- Safari 分享链接到 some。
- 照片 App 分享图片到 some。
- 文件 App 分享文件到 some。
- 桌面小组件显示记录计数，并能打开首页、专注页、搜索页和单条记录。
- 设置页保存/删除 OpenAI API Key；AI 语义缓存显示条数/大小，点击清除后摘要归零且不删除笔记。
- 完整备份导出后，重装 App 再导入恢复。
- 快捷指令保存随记。
- 隐私锁和每日提醒。

## 官方参考

- Apple App Store Connect 上传构建：<https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/>
- Apple App Store 隐私信息字段：<https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy>
- Apple App Review Guidelines：<https://developer.apple.com/app-store/review/guidelines/>
