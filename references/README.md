# references 目录说明

本目录保存"黑盒复刻"的证据材料。作业要求把参考 App 的外部行为转化为可比较的证据，所以这里的文件不能只存在本地，必须随仓库一起提交。

## 子目录

| 目录 | 内容 | 命名建议 |
|---|---|---|
| `screenshots/reference/` | 参考 App（CamCard）的截图 | 已采集 49 张，编号以 `screenshots/REFERENCE-INDEX.md` 为准 |
| `screenshots/student/` | 自己 App 的截图 | 使用与 reference 完全相同的文件名 |
| `test-images/` | 测试名片图片（打印版照片或合成图片） | `card_zh_01.jpg` |
| `ground-truth/` | 每张测试名片对应的 Ground Truth JSON | `card_zh_01.json` |

## 规则

- 截图对比的最小单位是"关键 UI 状态"，作业要求不少于 20 组，编号与 `spec/requirements.md` 的页面列表、`verify/test-cases.md` 的 T01–T20 对齐。
- `screenshots/reference/` 是锁定的基线，文件名不带日期；`screenshots/student/` 用**完全相同的文件名**，以便逐张对比。机房过程中产生的其他临时证据（录屏、失败截图）可在文件名里带日期。
- `ground-truth/` 里只写名片上真实存在的信息；字段不存在就写 `null`，不允许补全。
- 不使用真实个人电话与邮箱，使用虚构数据。

## 待办

- [x] `screenshots/reference/`：已采集 49 张参考截图，索引见 `screenshots/REFERENCE-INDEX.md`
- [ ] `screenshots/reference/`：补端到端流程录屏 + 4 项缺失截图
- [ ] `screenshots/student/`：随机房进度补齐，文件名与 reference 保持一致
- [x] `test-images/` + `ground-truth/`：已自建 42 张测试名片及对应 Ground Truth，由 `tools/generate_test_cards.ps1` 生成
