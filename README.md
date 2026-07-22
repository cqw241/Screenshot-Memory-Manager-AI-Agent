# 拾光

拾光是一款 HarmonyOS NEXT 截图记忆管家 Agent。当前分支已完成 Story 2 的 Task 2.1–2.5 代码与模拟器联调：用户可手动导入截图，经过端侧 OCR、多模态结构化理解和本地持久化后在时间轴查看卡片，并进入详情页确认删除。

当前四类确定性样例均可在 Pura 90 HarmonyOS 6.1.1（API 24）模拟器 4 秒内出卡并在重启后保留；Core Vision 真机 OCR 仍待补验，完成后才能收尾 Story 2。Story 3 可先在该模拟器上通过接口抽象与模拟数据推进，但不得把真机 OCR 当作已验证能力。

## 当前接手基线

- 开发分支：`feature/s02-tracer-pipeline`。
- 进度与已知限制：`docs/worklogs/S02-工作记录.md`。
- Story 2 → Story 3 接手说明：`docs/handover/S02-交接文档.md`。
- Task 2.4 时间轴设计：`docs/superpowers/specs/2026-07-21-task-2-4-timeline-ui-design.md`。

## 开发环境

- DevEco Studio 6.1.1：`D:\DevEco Studio`
- HarmonyOS SDK 6.1.1 / API 24：`D:\DevEco Studio\sdk\default`
- Hvigor 6.24.3：`D:\DevEco Studio\tools\hvigor`
- Node.js 18.20.1：DevEco Studio 内置版本
- 编译 SDK：API 24
- `targetSdkVersion`：API 20
- `compatibleSdkVersion`：API 20

## 首次构建

在项目根目录创建不入库的 `local.properties`：

```properties
sdk.dir=D:/DevEco Studio/sdk
```

然后执行：

```powershell
$env:PATH = 'D:\DevEco Studio\tools\node;' + $env:PATH
$env:NODE_HOME = 'D:\DevEco Studio\tools\node'
$env:DEVECO_SDK_HOME = 'D:\DevEco Studio\sdk'
& 'D:\DevEco Studio\tools\ohpm\bin\ohpm.bat' install
& 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --node-home 'D:\DevEco Studio\tools\node' --mode module -p product=default assembleHap
```

显式使用 DevEco 内置 Node 可避免系统 Node/npm 安装目录含空格时 Hvigor 初始化失败。

也可以直接使用 DevEco Studio 6.1.1 打开项目并运行 `entry` 模块。签名信息只允许保存在本机 DevEco 配置中，禁止提交私钥或签名配置。

## 安全约束

- 不内置任何默认 API Key。
- API Key 使用 HUKS 保护的 AES-GCM 密钥加密，Preferences 只保存密文和必要元数据。
- 远程服务仅允许 HTTPS；HTTP 仅用于本机回环开发地址。
- 模型配置只有通过可校验答案的视觉挑战后才会成为已验证配置。
