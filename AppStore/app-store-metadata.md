# App Store 元数据草稿

## 基本信息

- App 名称：some
- 副标题：快速记录，反复洞察
- 类别：效率
- 年龄分级建议：4+
- 价格建议：免费首发

## Promotional Text

把突然冒出来的想法先放进来，再用标签、搜索和 AI 洞察慢慢看清它们。

## Description

some 是一款本地优先的个人素材库，适合记录灵感、摘录、待办片段、图片、录音、视频和日常观察。

打开应用即可输入内容，用 `#标签` 自动归类；之后可以通过标签筛选、全文搜索和置顶，把重要的念头重新找回来。

如果你愿意配置自己的 OpenAI API Key，还可以使用 AI 洞察、自然语言搜索和相关记录查找。AI 洞察支持周期复盘、困惑破局、自我觉察、主题研究和写作灵感，把零散闪念整理成更有解释力的问题和下一步。语义搜索会在本机缓存最近使用的记录 embedding，设置里可查看条数/大小并随时清除。

主要功能：

- 快速记录文字闪念
- 自动识别 `#标签`
- 支持 `#项目/子类` 多级标签
- 标签筛选与全文搜索
- 重要内容置顶
- 随机回顾、历史今天和记录热力图
- 归档与恢复
- 编辑、删除和本地保存
- Markdown 导出与包含附件的完整备份
- 拍照、拍视频、录音和本地音频转写
- 可选 AI 洞察、语义搜索和相关记录
- 本机 AI 语义缓存查看与清除

适合：

- 写作者记录句子和素材
- 产品、设计、运营同学记录碎片想法
- 学习者保存读书摘录
- 想要一个安静本地备忘工具的人

## Keywords

备忘录,灵感,笔记,标签,摘录,写作,效率,markdown,memo,notes,ai

## What's New 1.0

首个版本上线：支持快速记录、多级标签、搜索、置顶、归档、随机回顾、记录热力图、本地保存、Markdown 导出、包含附件的完整备份，以及可选 AI 洞察。

## Review Notes

This app is a local-first memo and personal asset capture utility. It does not require login, ads, or analytics. Users can create text memos, attach local media, record audio, transcribe selected audio with the iOS Speech framework, organize content with inline hashtags, search, pin, edit, delete, and export their memos through the native iOS share sheet.

The app includes optional BYOK AI features. Users can enter their own OpenAI API key in Settings. The key is stored in iOS Keychain. AI actions are user initiated and send only the text needed for the selected insight generation, semantic search, or related memo lookup request to OpenAI API. For semantic search, the app stores recently used memo embeddings in the local App Group `AICache` container to reduce repeated embedding requests. The local cache uses model names and SHA-256 text fingerprints as keys, does not store memo plaintext, is capped at 1,000 entries, and can be viewed and cleared in Settings.

No demo account is required.

## App Privacy 建议填写

- Data Collected: Other User Content, used for App Functionality, not linked to user identity, not used for tracking. If optional OpenAI API features are enabled, user-initiated AI requests send the needed memo text or prompt to OpenAI API.
- Permissions used when the user chooses the related feature: Camera, Microphone, Photo Library, Speech Recognition, Face ID, Notifications
- Tracking: No
- Third-party advertising: No
- Third-party analytics: No

如果保留 AI API 功能上架，需要根据 OpenAI API 调用和你的账号设置重新核对 App Privacy；如果移除 AI 功能且没有其他第三方上传，才可继续选择不收集数据。
