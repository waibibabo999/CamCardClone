# 变更记录

本文件记录所有数据模型、Service 接口、目录结构等影响架构的变更。每次变更须注明原因、影响与回归情况。

## 2026-10-13

### 数据模型：BusinessCard 增加多邮箱 / 多电话字段

- 原因：参考 App 实测支持多个邮箱 / 电话（`references/screenshots/reference/17_extract_multi_phone_email.png`），原有单 `email` 字段无法承载，作业 7.4 又要求处理多 Email。决议 D5 落地。
- 变更：`BusinessCard` 新增 `additionalEmails: [String]` 与 `additionalPhones: [String]`（默认空数组）；`GroundTruth` 新增同名的可选数组字段；`design/data-model.md` 同步更新。
- 影响：`BusinessCard` 的 Codable 兼容旧数据（新字段有默认值）；导出时需把主字段与附加字段合并。
- 回归：批次 A 的 `BusinessCardStoreTests` 覆盖增删改查、搜索、标签、持久化，待机房跑 XCTest 验证。

### 架构：OCRResult 的 boundingBox 改为归一化矩形

- 原因：`CGRect` 的 Codable 表示不稳定，改用自建 `NormalizedRect`（x/y/width/height: Double，左下原点，0...1）。
- 影响：`OCRService` 后续实现需用 `NormalizedRect` 而非 `CGRect`。

### 批次 B：权限 / 相机 / 相册导入 / 区域检测 / 校正

- 新增 `PermissionService`（相机 + 相册写入权限）、`CameraService`（AVFoundation 后置相机）、`CardDetectionService`（Vision 矩形检测）、`CardGeometry`（纯坐标换算，可单测）。
- 新增 `CaptureView`、`DetectionView`、`CorrectionView` 及各自 ViewModel，`ScannerView` 改为流程编排（拍摄 → 检测 → 校正 → 结果）。
- 接口调整：`CameraService` 不再负责权限，新增 `session` / `makePreviewLayer`，`capturePhoto` 改为回调式。
- 坐标约定：检测结果与 Core Image 同为**左下原点**归一化坐标，显示层再翻转到左上原点，换算集中在 `CardGeometry`。

### 批次 C：OCR / 字段解析 / 人工确认 / 保存

- 新增 `VisionOCRService`（Vision `VNRecognizeTextRequest`，zh-Hans + en-US，返回 `OCRResult`）。
- 新增 `RuleBasedFieldParser`：标签 + 正则的确定性解析，无法确认的字段返回 nil；多邮箱 / 多电话进 `ParsedFields.additionalEmails / additionalPhones`。
- 新增 `VerificationView` / `VerificationViewModel`：OCR 处理中 → 可编辑字段表单（含 OCR 原文展示）→ 保存。
- `ScannerView` 主链补全：拍摄 → 检测 → 校正 → OCR → 人工确认 → 保存 → 返回名片夹。保存时把原图 / 处理图写入 `ImageStore`，元数据写入 `BusinessCardStore`。
- 接口调整：`FieldParserService.parse` 返回 `ParsedFields`（原为 `[CardField]`）。
- 新增 `FieldParserServiceTests`：中英文标签卡、缺失字段不虚构、多邮箱、多电话。
- 目录简化：`PROJECT_RULES.md` 里的 `Features/OCR`、`Features/Extraction` 暂不单设页面，OCR 与字段解析并入 `Features/Verification`（识别中状态 → 可编辑字段表单），服务仍按约定放 `Core/Services`。

### 扫描流程增加入口页

- 原因：模拟器没有摄像头，原先"从相册导入"的入口藏在相机页内，导致模拟器上无法验证检测 → 校正 → OCR → 保存主链；真机上相机不可用时同样会被堵死。
- 变更：`ScannerView` 增加 `.entry` 步骤，入口页并列提供「拍摄名片」与「从相册导入」，两条路径都汇入检测流程。
- 与 D8 的关系：参考 App 是按底部相机键直达拍摄，本项目的入口页属于合理简化；现在它同时承担"相机不可用时的兜底入口"。

## 2026-10-18

### 工程化

- 新增 `src/CamCardClone.xcodeproj`、共享 scheme、`Info.plist`。
- 新增 `CamCardCloneTests` 与 `CamCardCloneUITests` 两个 target。
- Info.plist 配置相机、相册读取/写入、联系人权限描述。
- App 支持 `-ui-testing-reset` 启动参数，用于 T01/T02 UI 测试清空本地数据。

### 管理闭环

- 新增 `CardDetailView` / `CardDetailViewModel`：原图、处理图、全部字段、标签、备注、编辑、删除、电话/Email/Website 跳转。
- 新增 `EditCardView`：编辑主字段、附加电话、附加邮箱、备注和标签。
- 新增 `SearchView`：按姓名、公司、职位、电话、Email、附加电话/邮箱、标签、备注搜索。
- 新增 `TagManagementView` / `TagResultsView`：创建、删除、按标签筛选。
- 新增 `ExportService`：VCF 生成与系统联系人保存，包含多电话/多邮箱。
- 列表页新增缩略图、修改时间、排序、删除确认和图片文件清理。

### 识别与异常

- 图片在拍摄/导入后统一 `normalizedUp`，Vision 检测与 OCR 传入正确 `CGImagePropertyOrientation`。
- 矩形检测宽高比从 `0.4...1.0` 放宽到 `0.3...3.0`，适配横向名片。
- 重写 `RuleBasedFieldParser`：标签优先、整行判断、多词公司不截断、职位/公司歧义处理、附加电话/邮箱。
- `VerificationView` 新增无结果状态、手动录入、取消、恢复识别结果、附加电话/邮箱编辑。
- `BusinessCardStore` 新增 `loadError`、损坏 JSON 可见错误、空标签错误和完整搜索字段。

### 回归

- `build-for-testing` 通过（App + 单元测试 + UI 测试 target）。
- 逻辑回归 30/30 通过。
- 42 张 Ground Truth 理想 OCR 解析 100%，0 幻觉，0 漏识别。
- UI/真机测试受本机 CoreSimulator 版本阻塞，详见 `verify/test-results.md`。

### 名片检测框修复

- 现象：真实导入 `zh_01.jpg` 时，黄色检测框套在名片上的圆形 Logo，而不是整张名片。
- 原因：`VNDetectRectanglesRequest` 默认 `maximumObservations = 1`，原实现直接取 `results.first`，高对比度 Logo 可能抢先返回。
- 修复：请求最多 20 个候选，过滤过小/比例异常的矩形，选择面积最大的候选；若最大候选仍明显过小，则回退到整张图片并提示用户手动调整四角。
- 验证：`build-for-testing` 通过，待模拟器重新运行确认检测框。

### 真机 UI 自动化验收

- 新增 `UITestSupport`：仅在 `DEBUG` 且带 `-ui-testing-seed` 时生成两张测试名片和图片。
- 新增 `ManagementFlowUITests`：覆盖 T13/T14/T15/T16/T17/T18。
- 为列表、搜索、标签、编辑、详情菜单补充 accessibility identifier。
- 修复测试 target 的签名 Team：`CamCardCloneTests` 与 `CamCardCloneUITests` 使用 `3X6HQ5S92X`。
- 结果：iPhone 真机 `Cmd+U` 执行 8 个测试，0 失败，109.729 秒。

### 首页第一版 UI 复刻

- 首页改为参考 App 的结构：顶部消息/搜索/加号、四个快捷入口、“名片 (n张)”区域、底部四 Tab + 中央扫描 FAB。
- App 固定浅色外观，匹配 `references/screenshots/reference` 的浅色参考环境。
- 列表缩略图改用 `processedImage`，详情页处理图放在第一页；底部栏背景延伸至 Home Indicator 下方。
- 为扫描、搜索、标签、详情菜单补充 accessibility identifier。
- 状态：`build-for-testing` 通过；UI 测试需在本次首页改版后重新回归。

### 首页/扫描页复刻细化

- 首页名片区改为参考图的全宽上方圆角面板，按日期分组，缩略图放大并使用处理图。
- App 固定浅色外观；首页底部栏背景延伸到安全区。
- 扫描流程从白色入口页改为直接进入相机取景页，加入基础/AI 识别切换、取景框、拍摄模式、相册入口和快门。
- 相机权限被拒绝时仍保留相册导入入口。
- 状态：`build-for-testing` 通过；UI 测试需在本次 UI 改版后重新回归。
