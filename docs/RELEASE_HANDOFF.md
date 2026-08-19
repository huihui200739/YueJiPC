# 阅迹 1.0.0 发布交接

本文用于把当前本地发布候选包交给开发者账号完成签名、真机验证和应用市场送审。

## 当前状态

- 应用名称：阅迹
- 版本：`1.0.0`，versionCode：`1000000`
- 包名：`com.huihui.yueji`
- 设备类型：`2in1`
- 目标 SDK：HarmonyOS 6.1.1 / API 24
- 当前 Release 构建：成功
- 当前产物：未签名 HAP/App，不能直接作为市场送审包
- 当前自动化测试：35 个通过，失败 0，错误 0

当前未签名产物只用于校验构建链路，不要上传到应用市场：

- `entry/build/default/outputs/default/entry-default-unsigned.hap`
- `build/outputs/default/YueJiPC-default-unsigned.app`

## 1. 创建应用

在 AppGallery Connect 中创建 HarmonyOS 应用，应用包名必须使用：

```text
com.huihui.yueji
```

应用名称、版本号和设备类型与本仓库保持一致。填写开发者联系邮箱、支持网址和隐私政策公开网址。隐私政策正文以 [PRIVACY_POLICY.md](PRIVACY_POLICY.md) 为准，但上架前必须放到审核人员能够访问的公开地址。

## 2. 配置发布签名

使用 DevEco Studio 登录有发布权限的开发者账号，在项目的签名配置中为 `default` 产品配置发布证书和 Profile。优先使用 DevEco Studio/AppGallery Connect 提供的自动签名流程，或者使用账号下生成的发布证书、Profile 和对应密钥。

签名文件只保存在本机，不提交到 Git，不放进截图、演示视频或公开仓库。配置完成后确认：

- `com.huihui.yueji` 与 AppGallery Connect 应用包名完全一致
- 使用 Release 配置，而不是 Debug 签名
- 证书未过期，Profile 覆盖 `2in1`
- DevEco Studio 能识别当前签名配置
- `build-profile.json5` 中的签名配置只包含本机路径或受保护引用

## 3. 生成签名包

在配置好 SDK、Java 和签名后执行：

```bash
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
export JAVA_HOME="/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  assembleApp -p product=default -p buildMode=release --no-daemon
```

构建日志中不能再出现 `No signingConfigs profile is configured` 或 `skip sign`。生成后记录**已签名** HAP/App 的实际路径、大小和 SHA-256；此前清单中的未签名哈希不能替代签名包哈希。

## 4. 安装与升级验证

使用 DevEco Studio 的运行/安装能力或开发者自己的 HarmonyOS PC 真机完成以下顺序：

1. 安装签名 Release 包，启动后确认冷启动动画、资料库和 PDF 阅读工作台正常。
2. 导入自制普通 PDF，完成选区、证据卡、来源回跳、复习和 Markdown 导出。
3. 关闭并重新打开应用，确认资料、页码、证据卡、主题、标签和设置未丢失。
4. 完成中文文件名、重复导入、拖放、快捷键、网页资料卡和无效网址回归。
5. 连续运行 30 分钟，并记录无崩溃、无明显卡顿和无持续内存增长。
6. 使用同一发布签名的旧版本做覆盖升级验证；如果此前没有同一证书的已发布版本，应记录为“首次安装通过”，不要把 Debug 包覆盖安装冒充 Release 升级测试。

测试结果填写回 [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) 和 [TEST_PLAN.md](TEST_PLAN.md)。未由开发者本人或真实测试人员执行的项目保持未勾选。

## 5. 准备市场材料

提交前准备：

- 真实运行版本截图，至少覆盖资料库、三栏阅读、证据卡、来源回跳和复习中心
- 1 分 50 秒到 2 分钟演示视频
- 应用图标、短描述、完整描述和 1.0.0 更新说明
- 隐私政策公开网址
- 开发者邮箱、支持网址和公开仓库地址
- 不包含真实姓名、账号、版权论文、测试 PDF 或证书私钥的材料

截图和演示内容按 [SCREENSHOT_PLAN.md](SCREENSHOT_PLAN.md) 与 [DEMO_SCRIPT.md](DEMO_SCRIPT.md) 执行，商店文案按 [STORE_LISTING.md](STORE_LISTING.md) 执行。

## 6. 上传和送审

确认签名包、截图、隐私政策和应用信息都已完成后，在 AppGallery Connect 的应用版本管理中上传签名 Release 包，填写版本信息并提交审核。送审后只修复审核阻塞问题，不在审核期间扩大功能范围。

送审记录至少保存：

- 提交时间和版本号
- 已签名 HAP/App 文件名、大小和 SHA-256
- 审核单号或版本记录
- 驳回原因和修复版本
- 最终上架时间

## 发布前硬门槛

- [ ] 发布证书和 Profile 已配置
- [ ] 签名 Release HAP/App 构建成功
- [ ] 签名包可安装、启动和完成核心闭环
- [ ] HarmonyOS PC 真机验证通过
- [ ] 30 分钟稳定性测试通过
- [ ] 3 名学生可用性测试完成
- [ ] 隐私政策、截图、视频和商店字段齐全
- [ ] AppGallery Connect 已提交审核
