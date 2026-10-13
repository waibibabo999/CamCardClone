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
