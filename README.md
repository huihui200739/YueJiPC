# 阅迹

阅迹是一款面向大学生的 HarmonyOS PC 可追溯阅读工作台。它把 PDF 阅读、重点标注、来源证据和复习整理放在同一个桌面工作流里。

核心对象是“证据卡”：用户从 PDF 中选择原文后，可以保存页码、选区坐标、个人笔记、标注类型、颜色、标签和复习状态。之后点击“回到原文”，应用会重新打开对应资料、跳转到原页并突出原选区。

## 当前能力

- 导入或拖放 PDF，并复制到应用沙箱长期保存
- PDF 页码跳转、缩放、适应宽度、全文搜索和页面缩略图
- 从 PDF 文本选区创建高亮或下划线证据卡
- 保存原文、页码、选区、笔记、标签、颜色和复习状态
- 从证据卡返回原始 PDF 页面并重新突出选区
- 管理网页资料的标题、网址、摘录、笔记和标签
- 使用系统浏览器打开网页来源
- 资料库搜索、标签过滤、收藏和最近阅读
- 复习中心的全部、待复习、已掌握和标签过滤
- 按当前资料或筛选范围导出带来源信息的 Markdown
- 跨资料主题集合、证据卡只读对比和批量复习/标签操作
- JSON 结构化备份与恢复；恢复前快照和成功清理、失败回滚的 PDF 删除保护
- 数据健康检查、证据来源类型/孤儿关系提示和不包含用户内容的脱敏诊断导出
- 启动时清理中断写入留下的导入、修复和备份临时文件
- 冷启动品牌动画与本地亮色/暗色设置同步，初始化期间拦截误触，完成后平滑进入工作台
- PDF 丢失修复使用临时文件校验后原子替换，并一次性更新来源指纹和阅读元数据
- 备份恢复区分事务回滚成功、回滚失败和数据已写入但界面重载失败等状态
- 亮色、暗色、专注模式和窄窗口侧栏
- `Ctrl/Cmd+O` 导入、`Ctrl/Cmd+F` 搜索、`Ctrl/Cmd+S` 导出
- 损坏、加密、丢失 PDF，无效网址和存储失败提示
- 应用沙箱内的备份快照和 PDF 导入采用临时文件完成后再移动，避免半成品文件进入正式路径

## 技术栈

- ArkTS
- ArkUI Stage 模型
- HarmonyOS 6.1.1
- API 24
- 设备类型：`2in1`
- PDF：`@kit.PDFKit`
- 数据库：`relationalStore`
- 设置：`preferences`
- 文件：应用沙箱 `files/library/{documentId}/source.pdf`

## 工程结构

```text
YueJiPC/
├── AppScope/                         应用级配置与图标
├── design/                           品牌图标矢量源稿
├── docs/                             发布、测试和参赛材料
└── entry/src/main/
    ├── ets/data/                     数据库与仓库层
    ├── ets/model/                    领域模型
    ├── ets/pages/Index.ets           主界面和阅读工作流
    ├── ets/services/                 导入、链接、导出和设置服务
    └── resources/                    模块资源
```

详细设计见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 本地构建

要求安装包含 HarmonyOS 6.1.1 API 24 SDK 的 DevEco Studio。

```bash
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
export JAVA_HOME="/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  assembleApp -p product=default -p buildMode=debug --no-daemon
```

Release 构建：

```bash
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  assembleApp -p product=default -p buildMode=release --no-daemon
```

签名配置不提交到开源仓库。请在 DevEco Studio 中绑定自己的 AppGallery Connect 应用和发布证书。

## 数据与隐私

阅迹不创建账号，不内置广告或分析 SDK，也不把 PDF、摘录或笔记上传到应用服务器。PDF 和结构化数据保存在应用沙箱；网页来源通过系统浏览器打开。系统级备份恢复能力在应用配置中关闭，用户主动发起的 JSON 备份与恢复仅通过系统文件选择器完成，且 JSON 不包含 PDF 二进制文件。

隐私政策见 [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md)。

## 发布状态

截至 2026 年 8 月 19 日：

- P0 功能代码已实现
- API 24 Debug 和 Release 无签名构建均已通过；35 个数据完整性单元测试均已通过，覆盖备份路径、关系健康检查、诊断脱敏、临时文件识别、事务失败状态、批量复习调度、单卡证据变更一致性、缩放边界、严格网址校验和复习筛选
- 已在 `MateBook Pro` 2in1 模拟器（HarmonyOS 6.1.0.125）覆盖安装并启动 Debug 包，旧资料、页码、证据卡和设置仍可恢复
- 已验证普通、200 页、加密和损坏 PDF，以及阅读、证据卡、来源回跳、复习、Markdown 导出、重启恢复和窄窗口布局
- 已检查 PDF 阅读工具栏的系统符号按钮和固定尺寸布局，启动后显示正常
- 已验证冷启动品牌动画在亮色/暗色主题下与进入应用后的视觉主题一致，覆盖安装后资料、页码、证据卡和设置仍可恢复
- 27 个 JSON/JSON5 配置均可解析；源码区未发现证书、私钥、Profile、凭据或测试 PDF
- 当前无签名 HAP：`entry/build/default/outputs/default/entry-default-unsigned.hap`，539263 bytes，SHA-256 `2e4a5fea6b78d2bf588d33e4c3576839df33b19f683e85819a2000acb539ee60`
- 当前无签名 APP：`build/outputs/default/YueJiPC-default-unsigned.app`，237440 bytes，SHA-256 `3ad9fb17c7b22d5e59c4c593fbdfdeb0f51e7ff441afad4e4c26ad3365866bf5`
- 产物生成时间：2026 年 8 月 19 日 23:37:27（Asia/Shanghai，以本轮构建产物文件时间为准）
- 本轮已重新执行 `hvigorw test`，35 个测试通过，失败 0，错误 0；Release 构建也已重新执行并成功。可使用 [`tools/release-audit.sh`](tools/release-audit.sh) 复核产物。
- 本轮代码新增的数据库级联、输入长度、选区 JSON、网址、导出、拖放、备份恢复、数据健康、存储临时文件清理、缩放持久化和复习筛选边界，仍需按 [docs/TEST_PLAN.md](docs/TEST_PLAN.md) 完成人工回归
- 发布签名、AppGallery Connect 配置、真机验证、3 名学生测试、30 分钟稳定性测试和商店送审仍需完成
- 小艺输入法隐私协议未由本项目代为接受；文字输入和键盘快捷键仍需开发者本人完成最终人工回归

发布交接步骤见 [docs/RELEASE_HANDOFF.md](docs/RELEASE_HANDOFF.md)。

发布进度使用 [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) 跟踪，不把未执行的人工测试标记为通过。

## 后续产品路线

在完成签名和发布前人工回归后，建议按以下顺序继续完善：

1. 完成备份恢复、数据健康、删除保护和数据库迁移的人工回归，补齐异常场景记录
2. 完成签名包安装、覆盖升级、市场审核和真机稳定性验证
3. 根据学生测试反馈优化证据卡编辑、批量操作和复习流程，不扩大到 AI、云同步或账号
4. 1.1 再评估“另存为带标注 PDF”和可选的备份中包含 PDF 文件，继续保持本地优先

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
