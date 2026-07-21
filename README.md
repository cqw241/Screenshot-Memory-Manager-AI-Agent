# 拾光

拾光是一款 HarmonyOS NEXT 截图记忆管家 Agent。本仓库当前实现 Story 1：项目入口、首次模型配置向导、多模态视觉验证门禁、安全配置存储和空时间轴主页。

Story 1 不包含截图监听、OCR、卡片数据库或提醒能力。

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
