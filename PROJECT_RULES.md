# PROJECT_RULES

本文件是 CamCardClone 的项目宪法。所有由 TRAE 或其他 AI 生成的代码，都必须遵守本文件的约定。若 AI 输出违反本文件，必须拒绝合并。

---

## 一、技术栈

- UI：SwiftUI + MVVM
- 部署目标：iOS 17 优先，真机不支持则 iOS 16
- 导航：NavigationStack
- 相机：AVFoundation
- 相册：PhotosPicker
- 名片区域检测：Vision VNDetectRectanglesRequest
- 透视校正：Core Image CIPerspectiveCorrection
- OCR：Vision VNRecognizeTextRequest，支持中英文
- 图片处理：Core Image
- 持久化：FileManager + Codable JSON，图片存 Documents/Images，元数据存 Documents/businesscards.json
- 联系人导出：Contacts 框架 / CNContactVCardSerialization
- 测试：XCTest + XCUITest

禁止引入第三方库，除非教师明确同意。

---

## 二、目录约定

    src/CamCardClone/
      App/
      Features/
        CardHolder/
        Scanner/
        Capture/
        Detection/
        Correction/
        OCR/
        Extraction/
        Verification/
        Detail/
        Search/
        Tags/
        Export/
      Core/
        Models/
        Persistence/
        Services/
      Resources/
      Tests/

- 每个 Feature 目录包含 View、ViewModel、以及必要的子组件。
- 通用能力放在 Core。
- 测试放在 Tests。

---

## 三、命名约定

- View：`XxxView`
- ViewModel：`XxxViewModel`
- Model：`BusinessCard`、`CardField`、`Tag`
- Service：`XxxService`
- Store：`XxxStore`
- 测试：`XxxTests`、`XxxUITests`
- 图片文件：`<cardID>_original.jpg`、`<cardID>_processed.jpg`

---

## 四、数据模型

`BusinessCard` 至少包含：

- id: UUID
- originalImageFileName: String
- processedImageFileName: String
- name: String?
- company: String?
- jobTitle: String?
- mobile: String?
- phone: String?
- fax: String?
- email: String?
- website: String?
- address: String?
- department: String?
- postalCode: String?
- notes: String?
- tags: [String]
- createdAt: Date
- updatedAt: Date
- ocrRawText: String?

规则：

- 所有可空字段必须保持 Optional。
- 不允许用空字符串代替“无此信息”。
- 不允许写入名片原图上不存在的值。
- 修改数据模型前必须更新 `design/data-model.md` 并评估影响。

---

## 五、状态管理

- 使用 `@Observable`（iOS 17+）或 `ObservableObject`。
- 页面状态至少包含：loading, empty, scanning, detecting, correcting, ocrProcessing, extracting, editing, saved, error, permissionDenied, noResult。
- 所有状态转换必须可测试。
- 状态定义必须与 `design/state-model.md` 保持一致。

---

## 六、持久化

- 图片存 `Documents/Images/`。
- 元数据存 `Documents/businesscards.json`。
- 使用 `Codable` 编解码。
- 所有写操作走 `BusinessCardStore`，View 不直接访问文件系统。
- 必须保证：Kill App → Relaunch → 名片、原图、修改字段、标签、备注全部保留。

---

## 七、AI 服务边界

- `OCRService` 只负责返回 OCR 原始文本。
- `FieldParserService` 只负责把 OCR 原始文本映射为结构化字段。
- `CardDetectionService` 只负责区域检测。
- `ExportService` 只负责导出到系统联系人 / VCF。
- 各 Service 接口一旦确定，AI 不得随意修改。
- 若确需修改接口，必须：
  1. 更新 `design/architecture.md`
  2. 更新 `changes/change-history.md`
  3. 评估影响
  4. 跑回归测试

---

## 八、AI 使用规则

- 每次只做一个明确小任务。
- 禁止大规模重构。
- 不得随意修改导航结构、数据模型、Service 接口、ViewModel 公共方法。
- 每个 AI 任务必须给出：输入、输出、边界条件、失败处理、测试要求。
- AI 代码必须经过：编译 → 单元测试 → 手动验证 → 才合并。
- 若 AI 生成“看起来可以工作”的实现，必须检查边界条件。
- 字段解析无法确认时必须返回 nil，不允许虚构名片上不存在的信息。

---

## 九、测试规则

- 每完成一个功能必须补测试。
- 修改已有功能必须跑回归测试。
- 确定性 T01–T20 必须 100% 通过。
- 概率性 OCR / 字段识别必须用固定名片集 + Ground Truth 计算字段准确率。
- 每个 Reference Test 至少对应一个 XCTest 或 XCUITest 用例。
- 测试结果写入 `verify/test-results.md`，回归结果写入 `verify/regression-results.md`。

---

## 十、UI 约定

- 遵循 Apple Human Interface Guidelines。
- 字体、间距、圆角、颜色统一走 Theme 常量，不允许散落魔法数字。
- 关键页面必须与参考 App 截图对比。
- 至少 20 个关键 UI 状态需要截图对比，存 `references/screenshots/`。

---

## 十一、版本控制

- 使用 Git。
- 每次小任务一个 commit。
- commit message 格式：

      feat: 添加名片夹空状态
      fix: 修复字段解析误判
      test: 添加OCR解析单元测试
      docs: 更新数据模型说明
      chore: 目录调整

- 每天结束必须 push。
- 禁止把 `build/`、`DerivedData/`、`.DS_Store`、用户数据提交到仓库。

---

## 十二、代码漂移控制

不允许为了一个小功能进行大规模架构重构。

大规模重构仅当满足以下全部条件时才允许：

1. 已识别明确的架构问题
2. 已创建设计变更说明
3. 已更新 SDD 文档
4. 已评估影响
5. 已完成回归测试

若 AI 曾经进行大规模重构，必须在最终报告中记录原因与后果。

---

## 十三、禁止事项

- 禁止“一个 Prompt 生成整个 App”。
- 禁止直接接受未编译、未测试的 AI 代码。
- 禁止 AI 虚构名片上不存在的信息。
- 禁止未经允许引入第三方库。
- 禁止在 View 中直接读写文件或联系人。
- 禁止把可空字段用空字符串替代。
- 禁止在未评估影响的情况下修改数据模型或 Service 接口。

---

## 十四、最终目标

让 AI 在明确的规格、受控的上下文和严格的测试下，持续产出可验证的软件。
