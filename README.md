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
- 亮色、暗色、专注模式和窄窗口侧栏
- `Ctrl/Cmd+O` 导入、`Ctrl/Cmd+F` 搜索、`Ctrl/Cmd+S` 导出
- 损坏、加密、丢失 PDF，无效网址和存储失败提示

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

阅迹不创建账号，不内置广告或分析 SDK，也不把 PDF、摘录或笔记上传到应用服务器。PDF 和结构化数据保存在应用沙箱；网页来源通过系统浏览器打开。系统备份恢复能力在应用配置中关闭。

隐私政策见 [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md)。

## 发布状态

截至 2026 年 8 月 18 日：

- P0 功能代码已实现
- 最终源码的 API 24 Debug 和 Release 无签名构建均已通过
- 已在 `MateBook Pro` 2in1 模拟器（HarmonyOS 6.1.0.125）覆盖安装并启动 Debug 包，旧资料、页码、证据卡和设置仍可恢复
- 已验证普通、200 页、加密和损坏 PDF，以及阅读、证据卡、来源回跳、复习、Markdown 导出、重启恢复和窄窗口布局
- 已检查 PDF 阅读工具栏的系统符号按钮和固定尺寸布局，启动后显示正常
- 27 个 JSON/JSON5 配置均可解析；源码区未发现证书、私钥、Profile、凭据或测试 PDF
- 当前无签名 HAP：`entry/build/default/outputs/default/entry-default-unsigned.hap`，337016 bytes，SHA-256 `0d2e5d26c812eea737041471b06819dfd47d808b28675e82c3742a2f0323709e`
- 当前无签名 APP：`build/outputs/default/YueJiPC-default-unsigned.app`，153097 bytes，SHA-256 `05212983444f1c088ed8d5825d6159c08dbf7308f3082d8b3bc4b9df158ba8a7`
- 产物生成时间：2026 年 8 月 18 日 11:34（Asia/Shanghai）
- 本轮代码新增的数据库级联、输入长度、选区 JSON、网址、导出和拖放边界，仍需按 [docs/TEST_PLAN.md](docs/TEST_PLAN.md) 完成人工回归
- 发布签名、AppGallery Connect 配置、真机验证、3 名学生测试、30 分钟稳定性测试和商店送审仍需完成
- 小艺输入法隐私协议未由本项目代为接受；文字输入和键盘快捷键仍需开发者本人完成最终人工回归

发布进度使用 [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) 跟踪，不把未执行的人工测试标记为通过。

## 后续产品路线

在完成签名和发布前人工回归后，建议按以下顺序继续完善：

1. JSON 备份与恢复，先解决用户最担心的数据可迁移和误删恢复
2. 跨资料主题集合与证据对比，让同一主题下的论文、教材和网页摘录可以并排整理
3. 批量标签与批量复习状态，降低资料量上来后的操作成本
4. 阅读统计和复习进度，补足长期使用反馈，但不引入账号和远程分析

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
