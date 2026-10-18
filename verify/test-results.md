# 测试结果

## 2026-10-18 19:07　iPhone 真机 UI 测试

在 iPhone 真机上执行 `Cmd+U`，结果：

```text
Executed 8 tests, with 0 failures (0 unexpected) in 109.729 seconds
Test Suite 'All tests' passed
```

通过的用例：

- T01 First Launch
- T02 Enter Scanner
- T13 Detail
- T14 Edit
- T15 Search
- T16 Tag
- T17 Delete
- T18 Persistence

这次运行使用 `-ui-testing-reset -ui-testing-seed` 自动生成两张测试名片，未使用真实个人数据。

> 注意：以上 8 个测试是在首页 UI 改版前执行的。之后重做了首页 Tab 栏、扫描 FAB、浅色外观和处理图缩略图，T01/T02 的断言已同步更新，但尚未在真机重跑。最终提交前必须再执行一次 `Cmd+U` 回归。

## 2026-10-18　工程化、管理闭环与解析器回归

环境：

- Xcode 27.1
- 目标：iOS 17.0，arm64
- 构建方式：`xcodebuild clean build-for-testing`，`CODE_SIGNING_ALLOWED=NO`
- 说明：本机 CoreSimulator 版本不匹配，模拟器 UI 测试无法启动；UI 测试已编译，真机/可用模拟器验收待完成。

### 1. 构建与测试 target

| 项 | 结果 | 说明 |
|---|---|---|
| `CamCardClone.xcodeproj` | ✅ 已生成 | 不再依赖机房临时工程 |
| App target | ✅ 构建通过 | 全部源文件编译 |
| `CamCardCloneTests` | ✅ 测试构建通过 | XCTest target 已接入 |
| `CamCardCloneUITests` | ✅ 测试构建通过 | T01/T02 UI 测试已编写 |
| Info.plist 权限 | ✅ 已配置 | 相机、相册、联系人 |

### 2. 逻辑回归

用 `tools/verify_logic.swift` 在 macOS 上直接编译并运行可测试的纯逻辑：

   30 passed, 0 failed

覆盖：

- 中文姓名、公司、职位、手机
- 英文多词公司不截断
- 职位与公司不混淆（`Systems Architect` vs `Orbit Aerospace Systems`）
- 中英双语姓名/公司
- 缺失 Website 不虚构
- Mobile / Office / Fax 多电话
- 多邮箱
- 无标签手机/办公电话
- 坐标往返
- 新增、搜索、标签筛选
- 备注/标签持久化
- 编辑、删除、删除标签同步清理
- 损坏 JSON 暴露错误

### 3. 42 张测试名片字段解析

用 `references/ground-truth` 中的 Ground Truth 生成“理想 OCR 文本”，运行当前 `RuleBasedFieldParser`：

| 字段 | 字段级匹配率 |
|---|---:|
| name | 100% |
| company | 100% |
| jobTitle | 100% |
| department | 100% |
| mobile | 100% |
| phone | 100% |
| fax | 100% |
| email | 100% |
| website | 100% |
| address | 100% |
| postalCode | 100% |
| **总体** | **100%** |
| 凭空生成字段 | **0** |
| 漏识别字段 | **0** |

结果文件：`analysis/parser_42_cards.json`。

> 注意：这是“OCR 文本完全正确”前提下的解析器回归，不代表真实拍照的 OCR 准确率。真实 OCR 仍需在真机上跑 42 张图片并记录原始文本。

### 4. 已实现但待设备验证

| 场景 | 状态 |
|---|---|
| T01 首次启动空状态 | 上一版通过；UI 改版后待回归 |
| T02 进入扫描入口 | 上一版通过；UI 改版后待回归 |
| T03 相机权限拒绝/前往设置 | 代码已备，待真机 |
| T04 拍摄/重拍/取消 | 代码已备，待真机 |
| T05 相册导入 | 代码已备，待模拟器/真机 |
| T06 区域检测 | 已放宽宽高比并处理方向，待真机 |
| T07 OCR | 已处理图片方向，待真机 |
| T08 字段解析 | 逻辑回归通过 |
| T09 缺失字段 | 42 张理想 OCR 下 0 幻觉 |
| T10 多电话/多邮箱 | 逻辑回归通过，编辑页可修改 |
| T11 人工校正 | 已实现，待 UI 验收 |
| T12 保存 | 已实现，待 UI 验收 |
| T13 详情 | 上一版通过；UI 改版后待回归 |
| T14 编辑 | 上一版通过；UI 改版后待回归 |
| T15 搜索 | 上一版通过；UI 改版后待回归 |
| T16 标签 | 上一版通过；UI 改版后待回归 |
| T17 删除 | 上一版通过；UI 改版后待回归 |
| T18 持久化 | 上一版通过；UI 改版后待回归 |
| T19 导出 | VCF/系统联系人已实现，测试已编写，待运行 |
| T20 异常路径 | noResult、取消、手动录入、保存失败提示已实现，待 UI 验收 |

### 5. 当前阻塞

命令行环境的 `CoreSimulator`/`devicectl` 仍受沙箱和组件状态影响，无法由自动化代理启动 UI 测试；但通过 Xcode GUI 已在 iPhone 真机上完成 8 个 UI 测试。剩余真机验收项是相机、相册、Vision OCR、VCF/联系人导出。需要：

- 继续在 iPhone 真机上完成 T03–T12、T19、T20 的人工验收；或
- 重新安装/修复完整 Xcode 的 Simulator 组件后，在模拟器上补测。
