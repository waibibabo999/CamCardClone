# 架构设计

## 一、总体架构

采用 SwiftUI + MVVM 分层架构。

    App
     ↓
    Features (View + ViewModel)
     ↓
    Core/Services
     ↓
    Core/Persistence
     ↓
    Core/Models

### 原则

- View 只负责展示与交互，不直接访问文件系统、联系人、OCR。
- ViewModel 调用 Store 与 Service。
- Service 负责单一能力，接口稳定。
- Persistence 统一走 BusinessCardStore 与 ImageStore。
- 导航统一走 NavigationStack。
- 所有状态变化可测试。

## 二、目录结构

    src/CamCardClone/
      App/
        CamCardCloneApp.swift
        AppRouter.swift
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
          BusinessCard.swift
          Tag.swift
          CardField.swift
          OCRResult.swift
          GroundTruth.swift
        Persistence/
          BusinessCardStore.swift
          ImageStore.swift
        Services/
          CameraService.swift
          CardDetectionService.swift
          OCRService.swift
          FieldParserService.swift
          ExportService.swift
          PermissionService.swift
      Resources/
        Theme.swift
      Tests/
        UnitTests/
        UITests/

## 三、模块职责

### App

- 应用入口
- 全局导航
- 依赖注入

### Features/CardHolder

- 名片夹空状态与列表
- 搜索入口、扫描入口
- 删除名片
- 列表更新

### Features/Scanner

- 扫描入口
- 选择拍摄或相册导入
- 权限处理

### Features/Capture

- 相机预览、快门、重拍、取消
- 相册导入

### Features/Detection

- 调用 CardDetectionService
- 显示检测结果
- 失败处理

### Features/Correction

- 四角调整
- 透视校正
- 旋转
- 确认、取消、重拍

### Features/OCR

- 调用 OCRService
- 显示处理中状态
- 显示 OCR 原始文本

### Features/Extraction

- 调用 FieldParserService
- 显示结构化字段
- 字段缺失处理

### Features/Verification

- 人工校正
- 保存前确认

### Features/Detail

- 名片详情
- 编辑、删除、导出
- 点击电话/Email/Website

### Features/Search

- 搜索框
- 结果列表
- 空结果状态

### Features/Tags

- 标签列表
- 创建、删除、筛选

### Features/Export

- 导出到系统联系人 / VCF
- 成功与失败反馈

## 四、Core/Services 接口约定

### CameraService

    protocol CameraService {
      func requestPermission() async -> PermissionStatus
      func startSession() async throws
      func stopSession()
      func capturePhoto() async throws -> Data
    }

### CardDetectionService

    protocol CardDetectionService {
      func detectCard(in image: UIImage) async throws -> CardDetectionResult
    }

    CardDetectionResult {
      corners: [CGPoint]
      confidence: Double
    }

### OCRService

    protocol OCRService {
      func recognizeText(in image: UIImage, languages: [String]) async throws -> OCRResult
    }

规则：

- OCRService 只返回 OCR 原始文本与观察结果。
- OCRService 不做字段解析。
- 接口一旦确定，AI 不得随意修改。

### FieldParserService

    protocol FieldParserService {
      func parse(ocrResult: OCRResult) -> [CardField]
    }

规则：

- 只负责把 OCR 原始文本映射为结构化字段。
- 无法确认的字段返回 value = nil。
- 不允许虚构原图中不存在的信息。
- 不修改 BusinessCard 数据模型。

### ExportService

    protocol ExportService {
      func exportToContacts(_ card: BusinessCard) async throws
      func exportToVCard(_ card: BusinessCard) throws -> Data
    }

### PermissionService

    protocol PermissionService {
      func cameraStatus() -> PermissionStatus
      func photoLibraryStatus() -> PermissionStatus
      func requestCamera() async -> PermissionStatus
      func requestPhotoLibrary() async -> PermissionStatus
    }

## 五、Core/Persistence

### BusinessCardStore

    protocol BusinessCardStore {
      func load() throws -> [BusinessCard]
      func save(_ cards: [BusinessCard]) throws
      func add(_ card: BusinessCard) throws
      func update(_ card: BusinessCard) throws
      func delete(id: UUID) throws
      func search(keyword: String) -> [BusinessCard]
      func filter(tag: String) -> [BusinessCard]
    }

### ImageStore

    protocol ImageStore {
      func saveOriginal(_ data: Data, cardID: UUID) throws -> String
      func saveProcessed(_ data: Data, cardID: UUID) throws -> String
      func loadImage(fileName: String) throws -> UIImage
      func deleteImage(fileName: String) throws
    }

规则：

- View 不直接访问文件系统。
- 所有写入走 Store。
- 元数据与图片分离。
- 写入采用原子写。

## 六、导航

- 使用 NavigationStack。
- 路由集中在 AppRouter。
- 页面跳转由 ViewModel 触发。
- 返回、取消、确认行为必须与 `design/state-model.md` 一致。
- 不允许 AI 随意修改导航结构。

## 七、依赖注入

- Service 与 Store 通过构造函数注入 ViewModel。
- 便于测试时替换 Mock。
- 禁止在 View 中直接创建 Service。

## 八、测试策略

### 单元测试

- BusinessCardStore：增删改查、搜索、标签筛选、持久化
- ImageStore：保存、读取、删除
- FieldParserService：字段解析、缺失字段、多电话、多 Email
- ExportService：字段映射
- 状态转换：每个状态进入与退出

### UI 测试

- T01–T20 全部覆盖
- 空状态、列表、扫描入口、详情、编辑、搜索、标签、导出

### 截图对比

- 至少 20 个关键 UI 状态
- 存 `references/screenshots/`

## 九、架构稳定性规则

- AI 不得为了小功能进行大规模重构。
- 修改 Service 接口必须更新本文件并评估影响。
- 修改数据模型必须更新 `design/data-model.md`。
- 修改状态必须更新 `design/state-model.md`。
- 所有修改必须跑回归测试。
