# AI 失败与修复记录

## 2026-10-18

### 1. `CorrectionView` 的 `@State` 拖拽锚点在 Xcode 27 编译失败

- 现象：`cannot assign to property: 'self' is immutable`，位置在 `DraggableCorner` 的 `anchor = start` 和 `anchor = nil`。
- 原因：`@State` 可选值未显式初始化，Swift 6.4/Xcode 27 的宏展开在拖拽闭包中未正确生成可写访问器。
- 修复：改为 `@State private var anchor: CGPoint? = nil`。
- 结果：App target 编译通过。

### 2. Contacts API 签名与常量不匹配

- 现象：`requestAccess(for:completionHandler:)` 的闭包被要求两个参数；`CNLabelPhoneNumberFax` 不存在。
- 修复：闭包改为 `{ allowed, _ in ... }`；传真标签改为 `CNLabelPhoneNumberWorkFax`。
- 结果：测试 target 编译通过。

### 3. 字段解析器对多词公司名截断

- 现象：`ABC Technologies Inc.` 被解析为 `Technologies Inc.`；42 张理想 OCR 公司字段准确率仅 38.1%。
- 原因：无标签行按第一个空格切分，且 `systems`、`consulting` 等公司提示词优先于职位判断。
- 修复：重写为标签优先、整行分类、职位/公司评分和强公司后缀规则。
- 结果：42 张理想 OCR 字段解析 100%，0 幻觉，0 漏识别。

### 4. Vision 忽略图片方向与横向名片宽高比

- 现象：相机/相册图片可能带 EXIF 方向；原检测器 `maximumAspectRatio = 1.0` 会排除横向名片。
- 修复：拍摄/导入后 `normalizedUp`；Vision 传入 `image.cgImagePropertyOrientation`；宽高比放宽到 `0.3...3.0`。
- 结果：构建通过，需真机确认实际检测效果。

### 5. 本机 CoreSimulator 版本不匹配

- 现象：`CoreSimulator 1171.7.0` 低于 Xcode 27.1 所需 `1174.9.2`，`simctl` 和 UI 测试无法启动。
- 处理：UI 测试只完成编译；真机/可用模拟器验收待完成，未把未运行测试标记为通过。

### 6. 检测框误套 Logo

- 现象：截图显示黄色四边形套在名片右侧的圆形 Logo 上。
- 原因：Vision 矩形检测默认只返回一个 observation，代码直接使用第一个结果；Logo 的高对比边缘可能比整张名片更容易被检测到。
- 修复：`maximumObservations = 20`，按面积和宽高比筛选候选，优先最大矩形；所有候选都过小时回退到整图手动调整。
- 验证：App target 构建通过，待模拟器重新导入 `zh_01.jpg` 复查。
