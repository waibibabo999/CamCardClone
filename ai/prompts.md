# TRAE 提示词

本文件保存 TRAE 提示词模板与每次任务的提示词。所有 AI 生成或修改的代码必须经过编译、单元测试、人工验证后才能合并。

## 一、通用原则

- 每次只做一个明确小任务
- 明确范围、输入、输出、边界、失败处理、测试要求
- 明确不得修改的接口与文件
- 要求 AI 输出完整代码与测试
- 不允许多个任务合并
- 不允许大规模重构
- 不允许虚构名片上不存在的信息

## 二、模板

    当前项目是 SwiftUI iOS 应用，采用 MVVM 架构。
    已有：{已有模块}

    不要修改：{不得修改的接口与文件}
    不要重构其他组件。

    任务：{一个明确的小任务}

    要求：
    1. {要求1}
    2. {要求2}
    3. {失败处理}
    4. {边界条件}
    5. {测试要求}
    6. 不修改其他文件

    输出：完整代码 + 单元测试。

## 三、任务清单

### 任务 1：BusinessCard 模型

    当前项目是 SwiftUI iOS 应用，采用 MVVM 架构。
    不要修改现有导航结构与目录结构。

    任务：新增 BusinessCard 数据模型与 BusinessCardStore。

    要求：
    1. 字段包含 id, originalImageFileName, processedImageFileName,
       name, company, jobTitle, mobile, phone, fax, email, website,
       address, department, postalCode, notes, tags, createdAt,
       updatedAt, ocrRawText；
    2. 所有可空字段为 Optional；
    3. 实现 add / update / delete / search / filter(tag)；
    4. 使用 Codable；
    5. 写单元测试：新增后 count +1，删除后 count -1，搜索正确；
    6. 不要实现 OCR、UI、相机。

    输出完整代码与测试。

### 任务 2：名片夹空状态

    当前项目已有 BusinessCardStore。
    不要修改 BusinessCardStore 接口。

    任务：实现 CardHolderView 空状态。

    要求：
    1. 无名片时显示“暂无名片”；
    2. 显示“扫描名片”按钮；
    3. 点击跳转 ScannerPlaceholderView；
    4. 有名片时切换到列表视图（列表可先占位）；
    5. 写一个 UI 测试或 Preview；
    6. 不修改其他文件。

    输出完整代码。

### 任务 3：名片夹列表

    当前项目已有 BusinessCardStore 与 CardHolderView。
    不要修改 BusinessCardStore 接口。

    任务：实现名片列表。

    要求：
    1. 显示缩略图、姓名、公司、标签、修改时间；
    2. 点击进入详情占位页；
    3. 删除名片后列表更新；
    4. 空列表时显示空状态；
    5. 写单元测试验证排序与删除；
    6. 不修改其他文件。

    输出完整代码与测试。

### 任务 4：权限服务

    当前项目已有基础目录。
    不要修改现有 View。

    任务：实现 PermissionService。

    要求：
    1. 提供 cameraStatus / photoLibraryStatus；
    2. 提供 requestCamera / requestPhotoLibrary；
    3. 返回 PermissionStatus；
    4. 写单元测试（使用 Mock）；
    5. 不修改其他文件。

    输出完整代码与测试。

### 任务 5：相机服务

    当前项目已有 PermissionService。
    不要修改 PermissionService 接口。

    任务：实现 CameraService。

    要求：
    1. 使用 AVFoundation；
    2. startSession / stopSession；
    3. capturePhoto 返回 Data；
    4. 处理权限拒绝；
    5. 不修改其他文件。

    输出完整代码。

### 任务 6：拍摄页

    当前项目已有 CameraService、PermissionService。
    不要修改这两个 Service 的接口。

    任务：实现 CaptureView。

    要求：
    1. 相机预览；
    2. 快门按钮；
    3. 返回、取消、重拍；
    4. 权限拒绝时显示设置入口；
    5. 确认后回调图片数据；
    6. 不实现检测、OCR、保存。

    输出完整代码。

### 任务 7：相册导入

    当前项目已有 CaptureView。
    不要修改 CameraService。

    任务：在 CaptureView 中加入相册导入。

    要求：
    1. 使用 PhotosPicker；
    2. 选择后回调图片数据；
    3. 失败时显示错误；
    4. 不修改其他文件。

    输出完整代码。

### 任务 8：名片区域检测

    当前项目已有 CameraService、CaptureView。
    不要修改 CaptureView 接口。

    任务：实现 CardDetectionService。

    要求：
    1. 使用 Vision VNDetectRectanglesRequest；
    2. 返回 corners 与 confidence；
    3. 检测失败返回明确错误；
    4. 写单元测试（使用测试图片）；
    5. 不实现校正。

    输出完整代码与测试。

### 任务 9：校正页

    当前项目已有 CardDetectionService。
    不要修改 CardDetectionService 接口。

    任务：实现 CorrectionView。

    要求：
    1. 显示四边形区域；
    2. 支持拖动四角；
    3. 支持顺时针 / 逆时针旋转；
    4. 使用 Core Image CIPerspectiveCorrection；
    5. 确认、取消、重拍；
    6. 不实现 OCR。

    输出完整代码。

### 任务 10：OCR 服务

    当前项目已有 CorrectionView。
    不要修改 CorrectionView 接口。

    任务：实现 OCRService。

    要求：
    1. 使用 Vision VNRecognizeTextRequest；
    2. 支持中英文；
    3. 返回 OCRResult（rawText + observations）；
    4. 不解析字段；
    5. 写单元测试（使用测试名片）；
    6. 不修改 BusinessCard 数据模型。

    输出完整代码与测试。

### 任务 11：字段解析器

    现有 OCRService 返回 OCRResult。
    不要修改 OCRService 接口和 MVVM 架构。

    任务：实现 FieldParserService。

    要求：
    1. 输入 OCRResult，输出 [CardField]；
    2. 映射 name, company, jobTitle, mobile, phone, fax,
       email, website, address, department, postalCode, notes；
    3. 无法确认的字段返回 nil；
    4. 不允许根据语义生成原图中不存在的信息；
    5. 针对提供的 10 个测试样例写单元测试；
    6. 不修改 BusinessCard 数据模型。

    输出完整代码与测试。

### 任务 12：字段解析修复

    目前 TC07 中将公司名称错误识别为姓名。
    不要修改 BusinessCard 数据模型、OCRService 和现有已通过的测试。

    任务：分析原因，只修改字段分类规则。

    要求：
    1. 不改变接口；
    2. 不改变数据模型；
    3. 修改后重新运行全部测试；
    4. 补充针对该错误的回归测试。

    输出完整代码与测试。

### 任务 13：人工校正页

    现有 FieldParserService 返回 [CardField]。
    不要修改 FieldParserService 接口。

    任务：实现 VerificationView。

    要求：
    1. 显示所有字段；
    2. 可编辑；
    3. 可取消恢复 OCR 原结果；
    4. 确认后保存到 BusinessCard；
    5. source 变为 user；
    6. 不修改其他文件。

    输出完整代码。

### 任务 14：名片详情

    现有 BusinessCardStore。
    不要修改 BusinessCardStore 接口。

    任务：实现 DetailView。

    要求：
    1. 显示原图、处理图、全部字段、标签、备注；
    2. 点击电话可拨号；
    3. 点击 Email 可发送邮件；
    4. 点击 Website 可打开浏览器；
    5. 编辑、删除、导出入口；
    6. 不修改其他文件。

    输出完整代码。

### 任务 15：搜索

    现有 BusinessCardStore。
    不要修改 BusinessCardStore 接口。

    任务：实现 SearchView。

    要求：
    1. 支持按姓名、公司、职位、电话、Email 搜索；
    2. 无结果显示空状态；
    3. 点击结果进入详情；
    4. 写单元测试；
    5. 不修改其他文件。

    输出完整代码与测试。

### 任务 16：标签

    现有 BusinessCardStore。
    不要修改 BusinessCardStore 接口。

    任务：实现 TagsView 与标签管理。

    要求：
    1. 创建、删除标签；
    2. 添加标签到名片；
    3. 按标签筛选；
    4. 删除标签时同步从名片移除；
    5. 写单元测试；
    6. 不修改其他文件。

    输出完整代码与测试。

### 任务 17：持久化

    现有 BusinessCardStore。
    不要修改其公共接口。

    任务：实现本地持久化。

    要求：
    1. 图片存 Documents/Images；
    2. 元数据存 Documents/businesscards.json；
    3. 原子写；
    4. Kill App 后重启数据完整恢复；
    5. 写单元测试；
    6. 不修改其他文件。

    输出完整代码与测试。

### 任务 18：导出

    现有 BusinessCard、BusinessCardStore。
    不要修改数据模型。

    任务：实现 ExportService。

    要求：
    1. 导出到系统联系人；
    2. 导出 VCF；
    3. 字段映射：姓名、公司、职位、电话、Email、地址；
    4. 不存在字段不写入；
    5. 多电话、多 Email 全部导出；
    6. 失败返回明确错误；
    7. 写单元测试。

    输出完整代码与测试。

### 任务 19：UI 测试

    现有全部页面。
    不要修改业务代码。

    任务：为 T01–T20 编写 UI 测试。

    要求：
    1. 每个 T 至少一个 XCUITest；
    2. 覆盖空状态、列表、扫描、详情、编辑、搜索、标签、导出；
    3. 不修改业务逻辑。

    输出完整测试代码。

### 任务 20：回归修复

    测试 {具体用例} 失败。
    不要修改数据模型、Service 接口、已通过的测试。

    任务：分析失败原因，只修改 {具体模块}。

    要求：
    1. 不引入新依赖；
    2. 不重构其他模块；
    3. 修复后跑全部测试；
    4. 补充回归测试。

    输出修改说明与代码。

## 四、AI 失败案例记录

每次 AI 失败，记录到 `ai/failures.md`：

    ## 案例 N
    - 日期：
    - 任务：
    - 提示词：
    - AI 生成：
    - 问题：
    - 影响：
    - 修复：
    - 回归测试：
    - 结论：

## 五、AI 对话记录

每次对话，记录到 `ai/conversations.md`：

    ## YYYY-MM-DD
    - 任务：
    - 提示词：
    - AI 输出摘要：
    - 我的修改：
    - 结论：
