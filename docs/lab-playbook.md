# 机房开发手册（Lab Playbook）

本文档回答两个问题：**去机房前要做什么、机房后要做什么**。

适用范围：手上只有 Windows 电脑 + iPhone，Mac 只能使用学校机房，共 4～5 次、每次约 3～4 小时。

---

## 零、核心策略（一句话）

> **代码在机房外写完，机房内只做四件事：编译、真机运行、跑测试、截图提交。**

理由：

- 写 Swift 代码不需要 macOS。TRAE 或其他 AI 在 Windows 上同样能产出 Swift 源码。
- 只有 **编译、真机调试、XCTest/XCUITest、Xcode 截图** 这四件事必须在 Mac 上做。
- 机房时间是最贵的资源，绝不能花在"想代码"和"打字"上。

因此机房外的工作量应该是**最大**的，机房内只是把已经写好的东西跑起来。

---

## 一、已确认的环境事实（2026-10-12）

以下事实已确认，后续方案按此执行，详见 `docs/reference-environment.md`。

| 项 | 情况 | 由此产生的做法 |
|---|---|---|
| 教师是否锁定参考环境 | **否** | 自行锁定 CamCard 版本 / 语言 / 登录状态并写进报告，声明"参考环境由学生自锁定" |
| 测试名片是否统一提供 | **否** | 已自建 42 张 + Ground Truth，见 `references/test-images/` |
| 机房 Mac 权限 | 自由度较高，可登录自己的 Apple ID，Xcode **可以更新** | 第 1 次机房先把 Xcode 更新到支持 iOS 26/27 的版本 |
| 我的设备 | iPhone 15 Pro Max / iOS 26（可能升到 iOS 27） | Deployment Target 定为 **iOS 17**；项目期间**不要升级手机系统** |

仍需确认的两件事（不影响开工，但影响时间安排）：

| # | 问题 | 为什么重要 |
|---|---|---|
| Q1 | 机房电脑是每次重置，还是保留我的环境？ | 若每次重置，则 Xcode 更新、Apple ID 登录、证书信任、git 凭据每次都要重做，要去争取"保留环境"或额外机时 |
| Q2 | 机房总共能用几次？能否额外申请？最终提交物是什么？ | 5 次做完全部功能非常紧，需要提前争取缓冲 |

> **注意**：iPhone 是 iOS 26，因此机房那台 Mac 的 Xcode 必须是能支持 iOS 26 的版本（Xcode 26 或更新）。
> 若机房预装的是旧版 Xcode，第 1 次机房的第一件事就是更新它——这是一个数 GB 的下载，务必留足时间，并确认更新后能保留到下次。

---

## 二、机房前：环境准备（只需做一次）

### 2.1 在你自己的 iPhone 上

- 记录 **iOS 版本号**（设置 → 通用 → 关于本机），用来核对 Q3 的 Xcode 版本。
- 安装 CamCard，用**锁定版本**完成至少 3 遍完整流程（拍照扫描 → 校正 → 识别 → 保存 → 详情 → 搜索），全程**录屏**。
  - 录屏是"行为 Ground Truth"，比截图更有说服力，报告里可直接引用。
- 截 20 张以上关键页面截图，放 `references/screenshots/reference/`。
- 记录 CamCard 版本号、App 语言、登录状态。

### 2.2 账号与凭据

- 确认 GitHub 仓库是 **Private**（里面有你的作业，建议私有）。
- 准备一个 **GitHub Personal Access Token**（勾选 repo 权限），存在手机备忘录或密码管理器里。
  - 机房电脑每次重置后 `git push` 都要重新登录，用 token 比用密码可靠。
  - **绝对不要把 token 写进仓库里的任何文件。**
- 准备好 Apple ID 账号密码（免费签名要用），并确认能接收双重认证验证码。

### 2.3 物料

- 数据线（先确认机房 Mac 的接口是 USB-C 还是 USB-A，必要时带转接头）。
- 测试名片：**打印版**（相机拍摄用）+ **图片版**（相册导入 / 模拟器用）。
- 充电线或充电宝，一下午真机调试很耗电。

### 2.4 测试数据集与 Ground Truth（机房外完成）

> ✅ **已完成**：教师不统一提供，已自建 42 张测试名片与 Ground Truth，位于 `references/test-images/` 与 `references/ground-truth/`，可用 `tools/generate_test_cards.ps1` 重新生成。下面保留原始要求备查。

- 若老师提供，直接采用，并检查是否覆盖作业 7.4 列出的 11 种类型。
- 若老师不提供，自己合成 ≥30 张，建议配比：

| 类型 | 建议张数 |
|---|---|
| 中文名片 | 6 |
| 英文名片 | 6 |
| 中英双语 | 6 |
| 竖版 / 特殊版式 | 4 |
| 多电话 / 多 Email | 4 |
| 字段缺失（如无 Website） | 4 |
| 拍摄质量差（倾斜 / 阴影 / 暗背景） | 4 |
| 复杂 Logo / 背景 | 4 |

- 每张名片配一个 Ground Truth JSON，字段不存在就写 `null`。
- **不要使用真实个人信息**：用虚构姓名、`example.com` 邮箱、`+86 138-0000-xxxx` 这类号码。

### 2.5 代码准备（机房外完成，按批次）

按 `ai/prompts.md` 的任务 1～20 分批在 Windows 上写代码并 push。建议节奏：

| 批次 | 内容 | 对应机房 |
|---|---|---|
| A | Models（BusinessCard / Tag / CardField / OCRResult）、BusinessCardStore、ImageStore、Theme、App 入口 + NavigationStack 路由、CardHolder 空状态与列表、其余页面占位 | 机房 1 |
| B | PermissionService、CameraService、CaptureView（含 PhotosPicker 导入）、CardDetectionService、DetectionView、CorrectionView | 机房 2 |
| C | OCRService、FieldParserService、ExtractionView、VerificationView | 机房 3 |
| D | DetailView、编辑、搜索、Tags、ExportService、Store/Export 单元测试 | 机房 4 |
| E | XCUITest（T01–T20）、边界条件修复 | 机房 5 |

每批代码写完后做机房外能做的自查：

1. API 签名是否与 Apple 官方文档一致（Vision / AVFoundation / Core Image / Contacts 最容易写错）。
2. 是否所有类型都在同一 module 内，有没有漏掉 `import`。
3. 占位 View 必须能编译（最简单的 `Text("TODO")`）。
4. 新增 / 修改的文件是否记入 `ai/conversations.md`。

> 机房外**无法编译**，所以第一批代码里出现编译错误是必然的。因此批次 A 要尽量小、尽量用最常见的写法，把"编译通过"当作机房 1 的唯一目标。

---

## 三、机房中：每次的标准流程

### 3.1 时间盒（按 4 小时计）

| 时间 | 事项 |
|---|---|
| 0:00–0:20 | 环境恢复：登录 Apple ID、`git pull`、连接 iPhone、信任此电脑、开启开发者模式、跑一次已有测试确认基线 |
| 0:20–0:40 | 把本批新代码放进工程，编译 |
| 0:40–2:30 | 修编译错误 → 真机运行 → 手动走流程 → 修逻辑问题 |
| 2:30–3:20 | 跑单元测试 / UI 测试、截图（学生版）、录屏 |
| 3:20–3:45 | `git add/commit/push`（**必须 push**，机房电脑会被重置） |
| 3:45–4:00 | 记录本次编译错误、失败现象、下一步任务清单 |

### 3.2 机房 1 的额外步骤（只做一次，但最关键）

1. 在 `src/` 下新建 Xcode 项目：名称 `CamCardClone`、Interface 选 SwiftUI、Language 选 Swift。
   - 这样会生成 `src/CamCardClone.xcodeproj` + `src/CamCardClone/`，与 `PROJECT_RULES.md` 第二节的目录约定基本对齐。
2. **设置 Info.plist 权限描述**（缺任何一个，调用对应功能时 App 会被系统直接终止）：

| Key | 用途 |
|---|---|
| `NSCameraUsageDescription` | 相机拍摄 |
| `NSPhotoLibraryUsageDescription` | 读取相册（使用自定义相册选择器时需要） |
| `NSPhotoLibraryAddUsageDescription` | 保存图片到相册（若实现该功能） |
| `NSContactsUsageDescription` | 导出到系统联系人 |

3. 设置 Deployment Target：先看 iPhone 的 iOS 版本，再决定 iOS 16 还是 iOS 17。
4. 若 Xcode 为 16 及以上，建议把 `src/CamCardClone` 作为 **File System Synchronized Group** 加入工程。
   - 好处：在 Windows 上新增 `.swift` 文件、到机房 `git pull` 之后，Xcode 会**自动**把它纳入 target，不必每次手动 Add Files。
5. 配置签名：Signing & Capabilities → Team 选个人 Team（免费），Bundle ID 用唯一值（如 `com.<你的名字>.CamCardClone`）。
6. 真机首次运行后，在 iPhone 上信任开发者证书（设置 → 通用 → VPN 与设备管理）。
7. 确认能跑起来后**立刻 commit 并 push**（`.xcodeproj` 要提交，不要被 .gitignore 排除）。

### 3.3 已知的坑（提前知道能省大量时间）

| 坑 | 说明 |
|---|---|
| Info.plist 缺权限描述 | 一调用相机 / 相册 / 联系人就被系统强杀，报错很不明显 |
| iOS 16+ 需要开发者模式 | 首次安装开发版 App 前要在 iPhone 上开启"开发者模式"并重启手机，会吃掉 5～10 分钟 |
| 免费签名 7 天过期 | 隔周再去时手机上 App 已打不开，属正常现象，重新 Run 一次即可；**最终演示前必须再 Run 一次** |
| 机房电脑重置 | Apple ID 登录、证书、DerivedData、git 凭据全部丢失，每次都要重做 |
| 坐标系 | Vision 返回归一化、**左下**原点的角点；Core Image 也是左下原点；UIKit/SwiftUI 是**左上**原点。三者混用是最常见的边界 / 透视校正 bug |
| 模拟器不能拍照 | T03 / T04 必须真机；T05–T19 可以在模拟器上做（把名片图片拖进模拟器相册即可），速度更快 |
| Vision 中文识别 | 需要 `recognitionLevel = .accurate`，且 `recognitionLanguages` 包含 `zh-Hans`；非英语识别需 iOS 14+，本项目目标版本没问题，但仍要在真机验证 |
| 模拟器与真机差异 | 截图证据建议统一在同一台设备上生成，报告中注明设备与系统版本 |

---

## 四、机房后：当天必做（在 Windows 上完成）

1. `git pull`，确认机房里的提交已同步到本地。
2. 整理**编译错误清单**：每个错误 → 原因 → 修复方式，写入 `ai/failures.md`。
3. 更新 `changes/change-history.md`：本次新增文件、接口变更、目录变更。
4. 更新 `verify/test-results.md`：本次跑了哪些用例、结果如何。
5. 把机房截图 / 录屏归档到 `references/screenshots/student/`，命名建议 `T07_ocr_raw_YYYYMMDD.png`。
6. 更新 `ai/conversations.md`：本次 AI 任务、提示词、AI 输出摘要、你的人工修改。
7. 写"下次机房任务卡"：明确要在机房验证的 5～10 个具体动作。
8. 把下一批代码在 Windows 上写完并 push。

> 截图和录屏是一次性证据：免费签名过期后 App 会失效，**证据必须留在仓库里**。

---

## 五、五次机房作战表

| 次 | 机房目标 | 对应验收 | 机房外（本批） |
|---|---|---|---|
| 1 | 工程建好、签名通过、真机跑起来、空状态 + 导航 + 占位页 | T01、T02 | 批次 A 代码 + 参考截图 + 测试数据集 |
| 2 | 拍摄、相册导入、区域检测、校正 | T03–T06 | 批次 B 代码 + 测试名片图片 |
| 3 | OCR、字段解析、人工校正、保存（打通端到端主流程） | T07–T12 | 批次 C 代码 + FieldParser 单测样例 |
| 4 | 详情、编辑、搜索、标签、持久化、导出 | T13–T19 | 批次 D 代码 + Store / Export 单测 |
| 5 | 全量回归 T01–T20、20 组 UI 截图对比、修复、归档、演示 | 全部 | 报告 + 演示稿 |

**关键里程碑是第 3 次机房**：端到端主流程必须在这天跑通。如果第 3 次结束还没打通，立刻降低范围并与老师沟通，不要拖到最后一次。

---

## 六、降级方案（如果时间不够）

按优先级保留，从下往上砍：

1. 标签管理（T16）→ 只保留"给名片加标签 + 按标签筛选"，砍掉独立标签管理页。
2. 手动四角调整（T06 的交互部分）→ 保留自动检测 + 自动裁剪，手动调整作为扩展。
3. 导出到系统联系人 → 只保留 VCF 导出（T19 允许二选一）。
4. 只读详情 → 保留编辑（T14）。
5. **不可砍**：T01、T04、T05、T07、T08、T09、T11、T12、T18（作业明确强调的持久化与"不虚构字段"）。

---

## 七、参考环境锁定记录（待填写）

| 项 | 值 |
|---|---|
| CamCard 版本 | 待填 |
| 参考 iOS 版本 | iOS 26 |
| 参考设备型号 | iPhone 15 Pro Max |
| App 语言 | 待填 |
| 登录状态 | 待填 |
| 是否允许使用免费功能 | 待填 |
| 测试名片来源（老师提供 / 自建） | 自建（教师未统一提供） |
| 测试名片数量 | 42 张（34 张基础 + 8 张拍摄质量差变体） |
| Deployment Target | iOS 17.0 |
| 机房 Mac 的 Xcode 版本 | **27.0**（2026-10-16 实测，能编译 iOS 26/27 目标） |
| 我的 iPhone 型号 / iOS 版本 | iPhone 15 Pro Max / iOS 26 |
| 机房可用次数 | 4～5 次，每次约一下午 |

### 策略调整（2026-10-16）

首次机房验证通过后，后续开发**可能转到自己的 Mac 上进行**，机房转为备用。若转自己的 Mac，需要：安装 Xcode、clone 仓库、重新选一次签名 Team、iPhone 开启开发者模式。

**本仓库不含 Xcode 工程文件**，所以无论在哪台机器上，第一次都要按第二节的步骤重新创建工程并把 `src/` 下的源码加进 target。
