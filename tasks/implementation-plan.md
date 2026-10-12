# 实施计划

本项目原计划 6 周，压缩为 3 周完成，最多 5 次机房。机房只做 Xcode 编译、真机调试、跑测试、截图、导出、Git 提交。机房外完成规格、设计、测试用例、参考截图、测试名片、Ground Truth、TRAE 提示词、AI 记录、报告。

## 一、总体里程碑

| 周 | 阶段 | 目标 |
|---|---|---|
| 第 1 周 | 规格 + 骨架 | spec、design、测试用例、Xcode 项目、名片夹空状态、真机部署 |
| 第 2 周 | 核心流程 | 拍摄/导入、区域检测、校正、OCR、字段解析、人工校正、保存 |
| 第 3 周 | 管理 + 验收 | 详情、编辑、搜索、标签、导出、持久化、回归、截图对比、最终演示 |

## 二、机房任务卡

### 机房 1：环境 + 骨架

目标：
- 创建 Xcode 项目 `CamCardClone`
- Git 连接远程仓库
- 目录结构就位
- 真机部署成功
- 名片夹空状态
- 扫描入口占位页
- 第一次截图与提交

产出：
- Xcode 项目
- CardHolderView 空状态
- ScannerPlaceholderView
- 真机运行截图
- commit push

对应验收：T01、T02 部分。

### 机房 2：拍摄 + 导入 + 检测

目标：
- 相机权限申请
- 相机预览与快门
- 相册导入
- 结果预览、确认、重拍、取消
- 名片区域检测（Vision）
- 检测结果显示

产出：
- CameraService
- PermissionService
- CardDetectionService
- CaptureView、DetectionView
- 真机测试

对应验收：T03、T04、T05、T06。

### 机房 3：校正 + OCR + 字段解析

目标：
- 四角调整
- 透视校正
- 顺时针/逆时针旋转
- OCRService（Vision VNRecognizeTextRequest）
- OCR 原始文本显示
- FieldParserService 字段结构化
- 缺失字段返回 nil

产出：
- CorrectionView
- OCRProcessingView
- OCRRawTextView
- ExtractionView
- 单元测试：FieldParserService

对应验收：T07、T08、T09、T10。

### 机房 4：人工校正 + 保存 + 管理 + 导出

目标：
- 人工校正表单
- BusinessCardStore 持久化
- 名片详情
- 编辑、删除
- 搜索
- 标签
- 导出到系统联系人 / VCF

产出：
- VerificationView
- DetailView
- SearchView
- TagsView
- ExportService
- BusinessCardStore、ImageStore
- 单元测试：Store、Export

对应验收：T11、T12、T13、T14、T15、T16、T17、T19。

### 机房 5：回归 + 截图 + 最终演示

目标：
- 跑完整 T01–T20
- Kill App 持久化测试
- 20 组 UI 截图对比
- 修 UI 差异
- 修边界情况
- 代码清理
- SDD 文档归档
- AI 记录归档
- 最终演示

产出：
- 测试报告
- 回归报告
- UI 对比报告
- AI 反思报告
- 最终演示

对应验收：全部。

## 三、机房外任务

### 第 1 周机房外
- 写 spec 三件套
- 写 design 三件套
- 写 PROJECT_RULES
- 写 T01–T20
- Figma 9 个核心页面
- 用 iPhone 装 CamCard 截 20 张参考图
- 准备 8–12 张测试名片
- 写 Ground Truth JSON
- 写 TRAE 提示词

### 第 2 周机房外
- 审查 AI 代码
- 整理 AI 失败案例
- 准备下次机房提示词
- 更新 change-history
- 更新差异分析
- 整理截图

### 第 3 周机房外
- 写测试报告
- 写回归报告
- 写 20 组 UI 对比报告
- 写 AI 协作记录
- 写 AI 开发反思报告
- 整理 Git 历史
- 准备最终演示稿

## 四、AI 使用规则

每次 AI 交互只做一个小任务。

推荐任务顺序：
1. BusinessCard 模型 + BusinessCardStore
2. CardHolderView 空状态
3. CardHolderView 列表
4. NavigationStack 路由
5. PermissionService
6. CameraService
7. CaptureView
8. PhotosPicker 导入
9. CardDetectionService
10. CorrectionView 四角调整
11. 旋转与透视校正
12. OCRService
13. OCR 原始文本页
14. FieldParserService
15. ExtractionView
16. VerificationView
17. DetailView
18. SearchView
19. TagsView
20. ExportService
21. 持久化整合
22. UI 测试
23. 回归修复

每次任务必须包含：
- 明确范围
- 不得修改的接口
- 边界条件
- 失败处理
- 测试要求
- 输出格式

## 五、风险与应对

| 风险 | 应对 |
|---|---|
| 机房时间不足 | 机房外完成所有文档与测试素材 |
| 模拟器不能拍照 | 用 iPhone 真机 |
| OCR 中文识别不准 | 使用 Vision 中文语言包，允许人工校正 |
| AI 大改架构 | PROJECT_RULES 限制，每次只做小任务 |
| 数据丢失 | 图片与元数据分离，原子写，Git push |
| 免费签名过期 | 7 天内重新 Run 一次 |
| 机房电脑重置 | 所有代码与文档 push 到 GitHub |

## 六、每日机房流程

- 0–10 分钟：`git pull`，连接 iPhone，跑已有测试，确认基线
- 10–30 分钟：让 TRAE 生成一个小模块
- 30–120 分钟：粘贴进 Xcode，编译，真机调试，修错误
- 120–180 分钟：手动测试、截图、跑回归
- 最后 15 分钟：`git add/commit/push`，记录问题与截图

## 七、完成标准

- 确定性 T01–T20 100% 通过
- 概率性 OCR / 字段识别有字段准确率统计
- 20 组 UI 截图对比完成
- SDD 文档齐全
- AI 协作记录齐全
- AI 反思报告完成
- 最终演示通过
