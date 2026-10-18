# CamCardClone

移动应用开发课程作业：基于 SDD（Specification-Driven Development）+ TRAE，对“名片全能王（CamCard）”的“名片数字化与联系人管理”功能切片进行 100% 黑盒复刻。

## 一、作业目标

以 CamCard 作为黑盒系统，通过观察、操作、记录和测试，建立完整工程闭环：

> 产品行为 → Specification → Architecture → Implementation → Test → Difference Analysis → Revision → Regression

不获取源代码，不反编译，不复制专有模型或算法。所有 AI 生成或修改的代码必须通过测试与人工验证才能进入最终版本。

## 二、复刻范围

完整闭环：

    名片夹 / Home
         ↓
    扫描名片
         ↓
    拍摄 / 图片导入
         ↓
    名片区域检测
         ↓
    透视 / 方向校正
         ↓
    OCR 文字识别
         ↓
    联系人字段解析
         ↓
    人工确认与修改
         ↓
    保存名片
         ↓
    名片夹
         ↓
    搜索 / 标签 / 查看详情
         ↓
    联系人导出

### 包含功能

- 名片夹首页：空状态、列表、扫描入口、缩略信息、进入详情、搜索入口
- 拍摄与图片导入：相机预览、权限、快门、返回、取消、重拍、相册导入、结果预览
- 名片区域检测与校正：自动边界检测、透视校正、方向校正、手动调整、确认、重拍
- OCR 文字识别：中英文、横竖版、多电话、多 Email、字段缺失、复杂背景
- 联系人字段结构化：Name, Company, Job Title, Mobile, Phone, Fax, Email, Website, Address, Department, Postal Code, Notes
- 人工校正（Human-in-the-Loop）
- 名片保存与详情：编辑、删除、返回、点击电话/Email/Website
- 搜索、标签、备注
- 本地持久化
- 联系人导出：系统联系人 / VCF
- 异常处理：权限拒绝、无法识别、字段为空、取消、返回

### 明确不包含

登录注册、会员与订阅、支付、广告、云同步、多设备同步、CRM 同步、企业权限、数字名片、QR 交换、AI 企业情报、会议录音、销售漏斗。

## 三、100% 复刻的定义

本项目中的 100% 指：

> 在教师规定的功能边界、参考版本、设备环境和测试用例范围内，实现 100% 的可观察行为等价。

覆盖维度：

- UI 一致性
- 交互一致性
- 状态一致性
- 数据一致性
- 异常一致性
- 流程一致性

## 四、AI / OCR 的概率性验收

AI 功能分为两类。

### 确定性功能

UI、导航、状态、保存、编辑、删除、搜索、标签、导出等，要求 Reference Test Suite 100% 通过。

### 概率性功能

OCR、姓名、公司、职位、电话、Email、地址识别等，使用教师提供的固定名片测试集 + Ground Truth 量化评价。要求：

1. 保存 OCR 原始输出
2. 保存字段解析结果
3. 与 Ground Truth 比较
4. 计算字段级准确率
5. 与参考 App 结果对比
6. 分析错误原因
7. 允许人工校正

特别规则：

> AI 不允许补全名片上不存在的信息。没有 Website 就不得虚构 Website。

## 五、技术栈

- UI：SwiftUI + MVVM
- 部署目标：iOS 17 优先，真机不支持则 iOS 16
- 导航：NavigationStack
- 相机：AVFoundation
- 相册：PhotosPicker
- 区域检测：Vision VNDetectRectanglesRequest
- 透视校正：Core Image CIPerspectiveCorrection
- OCR：Vision VNRecognizeTextRequest
- 持久化：FileManager + Codable JSON，图片存 Documents/Images
- 联系人导出：Contacts 框架 / CNContactVCardSerialization
- 测试：XCTest + XCUITest

## 六、开发方式

- SDD：规格驱动开发
- TRAE：主要 AI 辅助开发环境
- Git：版本控制
- Figma：UI 设计
- 自动化测试 + 人工验收
- 小步迭代：实现 → 测试 → 修复 → 回归

禁止“一个 Prompt 生成整个 App”。每次只让 AI 完成一个明确的小任务。

## 七、目录结构

    CamCardClone/
      README.md
      PROJECT_RULES.md
      docs/
        lab-playbook.md
        reference-environment.md
      spec/
        requirements.md
        behavior.md
        acceptance.md
      design/
        architecture.md
        state-model.md
        data-model.md
      tasks/
        implementation-plan.md
      changes/
        change-history.md
      verify/
        test-cases.md
        test-results.md
        regression-results.md
      ai/
        prompts.md
        conversations.md
        failures.md
      references/
        screenshots/reference/
        screenshots/student/
        test-images/
        ground-truth/
      drafts/
      tools/
        generate_test_cards.ps1
      src/

## 八、Reference Test Suite

确定性测试 T01–T20 必须 100% 通过。详见 `verify/test-cases.md`。

## 九、六周压缩为三周的机房开发策略

- 机房外：规格、设计、测试用例、参考截图、测试名片、Ground Truth、TRAE 提示词、AI 记录、报告
- 机房内：Xcode 项目、编译、真机调试、模拟器/真机截图、自动测试、PDF/VCF 导出、Git 提交

> 具体到"去机房前 / 机房中 / 机房后"要做什么，见 `docs/lab-playbook.md`。

## 十、状态

主流程、详情、编辑、搜索、标签、VCF/联系人导出已实现，工程文件已入库。

## 十一、构建与测试

用 Xcode 打开：

    src/CamCardClone.xcodeproj

工程包含：

- `CamCardClone` App target
- `CamCardCloneTests` 单元测试 target
- `CamCardCloneUITests` UI 测试 target（T01/T02 已编写）

命令行无签名构建：

    xcodebuild \
      -project src/CamCardClone.xcodeproj \
      -scheme CamCardClone \
      -destination 'generic/platform=iOS' \
      CODE_SIGNING_ALLOWED=NO \
      build

当前验证状态见 `verify/test-results.md`。相机、相册、Vision OCR 和 UI 流程仍需在真机或可用模拟器上完成最终验收。
