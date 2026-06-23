# some 项目任务计划

## 目标

把 some 从轻备忘推进为本地优先的个人素材库与创作整理工具，覆盖随手记录、图片/录音/视频/网页/截图采集、电子手帐、工作日志、图片编辑和电子衣橱。

## 当前阶段

阶段 48：TestFlight workflow checkout action 对齐，状态：complete

备注：阶段 47 在工作日志导出中新增可直接发送的本地汇报稿；阶段 48 将 TestFlight workflow 的 `actions/checkout` 与 CI workflow 对齐到 v5，收束 Node 20 deprecation 警告来源。

## 阶段清单

- 阶段 1：全量项目扫描与开源对标，状态：complete
- 阶段 2：统一素材模型，状态：complete
- 阶段 3：多模态采集与 OCR，状态：complete
- 阶段 4：网页摘录 MVP，状态：complete
- 阶段 5：电子衣橱第一段，状态：complete
- 阶段 6：电子手帐图层底座，状态：complete
- 阶段 7：录音本机语音转写，状态：complete
- 阶段 8a：视频缩略图与媒体预览补齐，状态：complete
- 阶段 8b：工作日志 MVP，状态：complete
- 阶段 9：手帐拖拽/缩放编辑器，状态：complete
- 阶段 10：图片编辑 MVP，状态：complete
- 阶段 11：衣橱统计与搭配增强，状态：complete
- 阶段 12：图片自由裁剪与授权清理增强，状态：complete
- 阶段 13：手帐图片素材追加与导出，状态：complete
- 阶段 14：媒体元数据与缩略图缓存，状态：complete
- 阶段 15：网页摘录正文清洗与摘录卡，状态：complete
- 阶段 16：网页摘录片段选择与截图/OCR 合并，状态：complete
- 阶段 17：远端 CI 复验与剩余失败修复，状态：complete
- 阶段 18：穿着记录、成本/次与衣橱洞察增强，状态：complete
- 阶段 19：图片背景画布与轻量抠图底座，状态：complete
- 阶段 20：衣橱洗护状态与旅行打包，状态：complete
- 阶段 21：手帐字体/贴纸/花边可编辑增强，状态：complete
- 阶段 22：手帐 PDF 分享/导出入口，状态：complete
- 阶段 23：衣橱天气推荐、自动打包建议与洗护提醒，状态：complete
- 阶段 24：图片编辑版式模板与导出预设，状态：complete
- 阶段 25：多图拼贴 MVP，状态：complete
- 阶段 26：摘录片段素材索引与搜索，状态：complete
- 阶段 27：多链接批量网页摘录，状态：complete
- 阶段 28：工作日志项目/日期/模板增强，状态：complete
- 阶段 29：截图/OCR 区域识别底座，状态：complete
- 阶段 30：媒体缩略图缓存维护，状态：complete
- 阶段 31：截图/OCR 框选 UI，状态：complete
- 阶段 32：衣橱洗护本地通知，状态：complete
- 阶段 33：图片编辑人物抠图入口，状态：complete
- 阶段 34：图片编辑智能主体抠图，状态：complete
- 阶段 35：衣橱材质/厚薄与行程天数增强，状态：complete
- 阶段 36：可用性收口：URL Scheme、工作日志筛选与按天数打包，状态：complete
- 阶段 37：图片编辑手势裁剪状态统一，状态：complete
- 阶段 38：工作日志 Markdown 导出与分享入口，状态：complete
- 阶段 39：衣橱打包建议优先使用最近行程目的地与天气，状态：complete
- 阶段 40：工作日志本地汇报摘要，状态：complete
- 阶段 41：图片编辑智能主体单实例点选，状态：complete
- 阶段 42：工作日志 CSV 导出与格式选择，状态：complete
- 阶段 43：导入/备份恢复页体验优化，状态：complete
- 阶段 44：URL Scheme 单条记录深链打开，状态：complete
- 阶段 45：图片编辑对象清理样式，状态：complete
- 阶段 46：媒体元数据预热与多 OCR 素材索引，状态：complete
- 阶段 47：工作日志本地汇报稿导出，状态：complete
- 阶段 48：TestFlight workflow checkout action 对齐，状态：complete

## 当前执行原则

- 每个阶段开始前复查 Git 状态、文件清单和相关源码边界。
- 每个功能动手前检索开源候选；只有许可证清晰且适配度高时才复制代码，否则记录原因并复用系统能力或本项目现有抽象。
- 不做破坏性重构，不回滚其他窗口或用户已有修改。
- 完成一个任务后继续分析下一个最高优先级任务。
