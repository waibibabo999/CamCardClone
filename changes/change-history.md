# 变更记录

本文件记录所有数据模型、Service 接口、目录结构等影响架构的变更。每次变更须注明原因、影响与回归情况。

## 2026-10-13

### 数据模型：BusinessCard 增加多邮箱 / 多电话字段

- 原因：参考 App 实测支持多个邮箱 / 电话（`references/screenshots/reference/17_extract_multi_phone_email.png`），原有单 `email` 字段无法承载，作业 7.4 又要求处理多 Email。决议 D5 落地。
- 变更：`BusinessCard` 新增 `additionalEmails: [String]` 与 `additionalPhones: [String]`（默认空数组）；`GroundTruth` 新增同名的可选数组字段；`design/data-model.md` 同步更新。
- 影响：`BusinessCard` 的 Codable 兼容旧数据（新字段有默认值）；导出时需把主字段与附加字段合并。
- 回归：批次 A 的 `BusinessCardStoreTests` 覆盖增删改查、搜索、标签、持久化，待机房跑 XCTest 验证。

### 架构：OCRResult 的 boundingBox 改为归一化矩形

- 原因：`CGRect` 的 Codable 表示不稳定，改用自建 `NormalizedRect`（x/y/width/height: Double，左上原点，0...1）。
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
