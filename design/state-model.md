# 状态模型

本文件定义 CamCardClone 完整工作流的状态与状态转换。每个状态与转换都必须能追溯到实现代码与测试用例。

## 一、主流程

    CardHolder / Home
         ↓
    Scanner Entry
         ↓
    Capture / Import
         ↓
    Card Detection
         ↓
    Perspective / Orientation Correction
         ↓
    OCR Processing
         ↓
    Field Extraction
         ↓
    Manual Verification
         ↓
    Save
         ↓
    Card Detail
         ↓
    Search / Tags
         ↓
    Contact Export

## 二、状态定义

| 状态 | 进入条件 | 显示内容 | 可用操作 | 退出条件 |
|---|---|---|---|---|
| empty | 无名片数据 | 空状态提示 | 扫描名片 | 进入 scanner |
| list | 有名片数据 | 名片列表 | 点击、搜索、扫描、删除 | 进入 detail / scanner / search |
| scanning | 进入扫描入口 | 相机预览或导入入口 | 快门、导入、返回 | 拍摄/导入成功或取消 |
| preview | 拍摄/导入完成 | 结果预览 | 确认、重拍、取消 | 确认进入 detecting，取消返回 |
| detecting | 确认图片 | 检测中提示 | 取消 | 检测成功进入 correcting，失败进入 error/noResult |
| correcting | 检测完成 | 四边形区域 | 拖角、旋转、确认、取消、重拍 | 确认进入 ocrProcessing |
| ocrProcessing | 校正确认 | 进度提示 | 取消 | 成功进入 extracting，失败进入 error |
| extracting | OCR 完成 | OCR 原始文本、字段 | 编辑、确认、取消 | 确认进入 manualVerification |
| manualVerification | 字段解析完成 | 结构化字段表单 | 编辑、取消、保存 | 保存进入 saved |
| saved | 用户确认保存 | 保存成功反馈 | 查看详情、返回列表 | 进入 detail 或 list |
| detail | 打开名片 | 原图、处理图、字段、标签、备注 | 编辑、删除、导出、返回 | 编辑、删除、返回 |
| editing | 点击编辑 | 可编辑字段表单 | 保存、取消 | 保存更新卡片，取消返回 detail |
| search | 点击搜索 | 搜索框、结果列表 | 输入、清除、点击结果 | 返回 list / 进入 detail |
| tags | 点击标签 | 标签列表 | 创建、删除、筛选 | 返回 list / 进入筛选结果 |
| exporting | 点击导出 | 导出进度 | 取消 | 成功进入 exported，失败进入 error |
| exported | 导出完成 | 成功反馈 | 完成、分享 | 返回 detail |
| error | 任意失败 | 错误信息 | 重试、取消、返回 | 重试或返回上一状态 |
| permissionDenied | 权限被拒绝 | 权限说明 | 前往设置、返回 | 返回上一状态 |
| noResult | 无法识别 | 无结果提示 | 手动录入、重拍、返回 | 进入 manualVerification 或返回 |

## 三、异常路径

    Capture
     ├── Cancel        → CardHolder / Scanner
     ├── Retake        → Capture
     ├── PermissionDenied → PermissionDenied
     └── Confirm       → Card Detection

    Detection
     ├── Success       → Correction
     ├── NoResult      → NoResult
     └── Cancel        → Preview

    Correction
     ├── Confirm       → OCR
     ├── Cancel        → Preview
     └── Retake        → Capture

    OCR
     ├── Success       → Field Extraction
     ├── Fail          → Error
     └── Cancel        → Correction

    Extraction
     ├── Confirm       → Manual Verification
     └── Cancel        → Correction

    Manual Verification
     ├── Confirm       → Save
     ├── Cancel        → Extraction
     └── Empty Fields  → Allow Save

    Detail
     ├── Edit          → Editing
     ├── Delete        → CardHolder
     ├── Export        → Exporting
     └── Back          → CardHolder

    Editing
     ├── Save          → Detail
     └── Cancel        → Detail

## 四、状态一致性要求

- 所有状态必须有明确的进入条件、显示内容、可用操作、退出条件。
- 每个状态必须对应至少一个测试用例（T01–T20）。
- 状态转换必须可测试。
- 不允许出现未定义状态。
- 状态变化必须走 ViewModel，不允许 View 直接切换状态。
- Kill App 后重新启动，已保存状态必须恢复，未保存状态允许丢失。
