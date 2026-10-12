# 数据模型

## 一、BusinessCard

    BusinessCard {
      id: UUID
      originalImageFileName: String
      processedImageFileName: String
      name: String?
      company: String?
      jobTitle: String?
      mobile: String?
      phone: String?
      fax: String?
      email: String?
      website: String?
      address: String?
      department: String?
      postalCode: String?
      notes: String?
      tags: [String]
      createdAt: Date
      updatedAt: Date
      ocrRawText: String?
    }

### 规则

- 所有可空字段必须为 Optional。
- 不允许用空字符串代替“无此信息”。
- 不允许写入名片原图上不存在的值。
- `originalImageFileName` 和 `processedImageFileName` 只存文件名，不存绝对路径。
- 图片文件存 `Documents/Images/`。
- 元数据存 `Documents/businesscards.json`。
- `tags` 使用字符串数组，便于 Codable 与搜索。
- `ocrRawText` 保存 OCR 原始输出，用于追溯与错误分析。

## 二、Tag

    Tag {
      id: UUID
      name: String
      createdAt: Date
    }

### 规则

- 标签名唯一。
- 删除标签时，必须同步从所有名片的 `tags` 中移除。
- 标签可用于筛选。

## 三、CardField

用于字段解析与人工校正。

    CardField {
      key: FieldKey
      value: String?
      confidence: Double?
      source: FieldSource
    }

    FieldKey {
      name, company, jobTitle, mobile, phone, fax,
      email, website, address, department, postalCode, notes
    }

    FieldSource {
      ocr, user, empty
    }

### 规则

- `value` 为 nil 表示该字段在名片上不存在或无法确认。
- 不允许把“猜测值”写入 `value`。
- `source` 用于追溯字段来源：来自 OCR、用户修改、或为空。
- 人工校正后，`source` 变为 `user`。

## 四、GroundTruth

    GroundTruth {
      id: String
      name: String?
      company: String?
      jobTitle: String?
      mobile: String?
      phone: String?
      fax: String?
      email: String?
      website: String?
      address: String?
      department: String?
      postalCode: String?
      notes: String?
    }

### 规则

- 每张测试名片对应一个 Ground Truth JSON。
- 字段不存在时写 null 或不写该字段。
- 用于计算字段级准确率。
- 不允许在 Ground Truth 中写入测试名片上不存在的值。

## 五、OCRResult

    OCRResult {
      rawText: String
      observations: [OCRObservation]
      createdAt: Date
    }

    OCRObservation {
      text: String
      confidence: Double
      boundingBox: CGRect
    }

### 规则

- `rawText` 是 OCR 的完整原始输出。
- `observations` 用于字段解析与错误分析。
- OCR 原始结果必须保存，不允许只保存最终字段。

## 六、持久化格式

`Documents/businesscards.json`：

    {
      "version": 1,
      "cards": [ BusinessCard, ... ],
      "tags": [ Tag, ... ]
    }

### 规则

- 顶层包含版本号，便于后续迁移。
- 所有写入走 `BusinessCardStore`。
- 写入采用原子写，避免崩溃导致数据损坏。
- 图片与元数据分开存储，元数据引用图片文件名。
- Kill App 后重新启动必须能完整恢复。

## 七、导出模型

    ContactExportPayload {
      name: String?
      company: String?
      jobTitle: String?
      phones: [String]
      emails: [String]
      website: String?
      address: String?
    }

### 规则

- 导出到系统联系人 / VCF 时，仅映射存在的字段。
- 不存在字段不写入。
- 多电话、多 Email 必须全部导出。
- 导出失败必须返回明确错误。
