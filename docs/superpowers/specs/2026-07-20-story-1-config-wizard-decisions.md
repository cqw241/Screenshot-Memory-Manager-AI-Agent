# 拾光 Story 1 配置向导 · 共同理解与实现决策

- 日期：2026-07-20
- 状态：已实现；Story 1 于 2026-07-21 验收通过
- 适用范围：Story 1「项目脚手架 + 首启配置向导 + 验证门禁」
- 上游文档：
  - `docs/superpowers/specs/2026-07-20-shiguang-screenshot-agent-design.md`
  - `docs/DevelopmentPlan.md`

## 1. 文档目的与优先级

本文记录产品方与开发方在 Story 1 开始前逐项确认的共同理解，供后续开发、评审、测试和交接直接引用。

当本文与上游文档在 Story 1 范围内存在冲突时，以本文为准。已确认的主要修订有：

1. 官方快捷模板不再限于智谱、通义、豆包、OpenAI 四家，而是扩展为本文列出的通用服务与编程套餐端点。
2. 验证门禁不再使用无法证明图像理解能力的 `1×1` 探测图，而使用可校验答案的小型视觉挑战图。
3. API Key 不以明文写入 Preferences，而由 HUKS 保护后持久化。

本文是 Story 1 的实现决策基线；完成结果与设备验证边界见 `docs/handover/S01-交接文档.md`。

## 2. 工程基线

| 项目 | 已确认值 |
|---|---|
| 应用名 | 拾光 |
| Bundle Name | `com.shiguang.memory` |
| 主模块 | `entry` |
| 应用模型 | HarmonyOS NEXT Stage 模型 |
| 开发语言/UI | ArkTS / ArkUI |
| 目标与最低兼容 API | API 20 |
| 本机 DevEco Studio | 6.1.1，路径 `D:\DevEco Studio` |
| 本机 SDK | HarmonyOS 6.1.1 / API 24，路径 `D:\DevEco Studio\sdk\default` |
| 构建工具 | 本机已包含 Hvigor，路径 `D:\DevEco Studio\tools\hvigor` |

实现时使用已安装的 API 24 SDK 编译，但 `targetSdkVersion` 与 `compatibleSdkVersion` 均锁定 API 20。Story 1 的代码不得无意依赖 API 21 及以上能力。

## 3. Story 1 的用户结果

Story 1 完成后，用户应获得以下行为：

1. 全新安装或本地不存在已验证配置时，应用强制进入模型配置向导，不能绕过向导进入主界面。
2. 用户填写 `baseURL`、`apiKey`、`model` 后，应用通过小型视觉挑战验证接口确实具备图像理解能力。
3. 只有验证成功，配置才可持久化，首次配置成功后进入空时间轴主界面。
4. 杀进程重启后，存在完整且已验证的配置则直接进入主界面。
5. 主界面提供设置入口；修改配置必须重新通过同一验证门禁。
6. 修改失败或取消时保留旧的已验证配置，用户仍可继续使用主界面。
7. 安装包内不包含任何默认 API Key。

## 4. 配置数据与状态

### 4.1 配置内容

一份模型配置至少包含：

- `baseURL`：OpenAI-compatible 服务根地址，始终可编辑。
- `apiKey`：用户自备的访问凭证。
- `model`：用户选择或输入的模型 ID。
- 已验证标记及验证所需的版本/时间信息。
- 已确认信任的服务源信息，用于判断地址变化后是否需要重新确认。

持久化数据必须能够明确区分“没有配置”“只有未验证草稿”“存在已验证配置”，启动逻辑只能信任最后一种状态。

### 4.2 首次配置状态流

```text
未配置 → 编辑草稿 → 验证中 → 验证成功 → 原子保存 → 主界面
                         └→ 验证失败 → 保留草稿并停留在向导
```

### 4.3 修改配置状态流

已有配置的修改采用事务式替换：

```text
旧的已验证配置 + 新草稿 → 验证新草稿
                         ├→ 成功：原子替换旧配置
                         └→ 失败/取消：丢弃或保留草稿，旧配置继续有效
```

打开设置页、开始编辑或验证失败，均不得提前清除旧配置的已验证状态。

## 5. 配置向导交互

### 5.1 表单

配置向导包含：

- 官方服务快捷模板；
- 始终可编辑的 `baseURL` 输入框；
- API Key 密码输入框；
- “推荐多模态模型列表 + 自定义模型 ID”的可输入组合框；
- 保存并验证按钮；
- 验证中的 loading 状态；
- 可读、可区分的失败提示。

`baseURL`、`apiKey`、`model` 任一为空时，保存按钮不可用。

### 5.2 模板与模型不得强绑定

- 点击模板只填充 `baseURL`，不得自动覆盖或锁定 `model`。
- 模型列表只提供建议，用户始终可以输入任意模型 ID。
- 选择了推荐模型也不代表验证通过；最终以视觉挑战结果为准。
- 推荐模型清单属于会变化的数据。实现时应集中维护，并记录最近一次依据厂商官方资料核对的日期，避免散落在 UI 代码中。

### 5.3 已保存密钥不得回显

编辑已有配置时，API Key 输入框只显示“已保存的密钥”占位状态，不回填明文。

- 用户不修改 API Key 时，可在内存中临时解密旧 Key，用于验证新的地址或模型。
- 用户输入新 Key 时，验证成功后才替换旧 Key。
- UI 不提供查看已保存明文 Key 的能力。

## 6. 官方端点目录

快捷模板分为两组。两组都只是地址填充器，不代表厂商、套餐、账号、模型或视觉能力已经通过验证。

### 6.1 多模态服务推荐

| 厂商/服务 | `baseURL` |
|---|---|
| OpenAI | `https://api.openai.com/v1` |
| 阿里云百炼 | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| 火山方舟 | `https://ark.cn-beijing.volces.com/api/v3` |
| 小米 MiMo | `https://api.xiaomimimo.com/v1` |
| 智谱开放平台 | `https://open.bigmodel.cn/api/paas/v4` |
| Kimi 开放平台 | `https://api.moonshot.cn/v1` |
| 腾讯混元 | `https://api.hunyuan.cloud.tencent.com/v1` |
| MiniMax | `https://api.minimax.io/v1` |

### 6.2 编程套餐端点

这组模板折叠在高级区域。区域顶部统一标注：

> 须确认厂商条款允许本应用调用。

不得额外标注或预判这些端点是否支持视觉；实际图像理解能力仍由视觉挑战门禁判定。

| 厂商/服务 | `baseURL` |
|---|---|
| 阿里云 Coding Plan | `https://coding.dashscope.aliyuncs.com/v1` |
| 火山方舟 Coding Plan | `https://ark.cn-beijing.volces.com/api/coding/v3` |
| 小米 MiMo Token Plan（中国集群） | `https://token-plan-cn.xiaomimimo.com/v1` |
| 智谱 Coding Plan | `https://open.bigmodel.cn/api/coding/paas/v4` |
| Kimi Code | `https://api.kimi.com/coding/v1` |
| 腾讯云 Coding Plan | `https://api.lkeap.cloud.tencent.com/coding/v3` |

腾讯云地址已从讨论中的 `ttps://...` 修正为合法的 `https://...`。

### 6.3 端点资料核对入口

以下官方资料用于后续开发时复核地址、账号体系和套餐限制；端点可能随厂商调整，实现前后均应再次核对：

- [阿里云百炼 OpenAI 兼容接口](https://help.aliyun.com/zh/model-studio/qwen-api-via-openai-chat-completions)
- [阿里云 Coding Plan](https://help.aliyun.com/en/model-studio/coding-plan)
- [火山方舟 Coding Plan OpenAI 兼容地址](https://www.volcengine.com/article/37839)
- [小米 MiMo Token Plan 快速接入](https://mimo.mi.com/docs/zh-CN/price/tokenplan/quick-access)
- [智谱 Coding Plan 常见问题](https://docs.bigmodel.cn/cn/coding-plan/faq)
- [Kimi Code 文档](https://www.kimi.com/code/docs/)
- [腾讯混元 OpenAI 兼容接口](https://cloud.tencent.com/document/product/1729/111007)
- [腾讯云 Coding Plan](https://cloud.tencent.com/document/product/1823/130092)
- [MiniMax OpenAI-compatible API](https://platform.minimax.io/docs/api-reference/text-openai-api)

## 7. URL 与服务信任规则

### 7.1 HTTPS 门禁

- 正常配置只接受 `https://`。
- 普通远程 `http://` 地址直接拒绝，不允许发送 API Key。
- 仅 `localhost`、`127.0.0.1`、`::1` 可作为本地开发例外使用 HTTP；验证前必须再次警告用户当前连接未加密。
- URL 解析必须基于标准 URL 语义，不得使用简单字符串包含判断来识别主机或回环地址。

### 7.2 官方与自定义服务

- 官方模板及用户手动输入的同一官方服务源，视为已知官方服务。
- 其他服务源视为自定义服务。
- 服务源至少以 `scheme + host + port` 判断；路径编辑不应把第三方主机伪装成官方主机。

### 7.3 自定义服务信任确认

验证自定义服务前必须弹窗：

- 明确显示目标主机；
- 告知 API Key 与视觉挑战图将发送给该服务；
- 要求用户主动确认信任后才能发送请求。

信任确认只随“成功验证并保存的配置”持久化。目标服务源变化时必须重新确认；失败的验证不得留下永久信任记录。

## 8. API Key 安全

### 8.1 持久化方案

- 使用 HarmonyOS Universal Keystore（HUKS）生成并保护设备内加密密钥。
- 使用受 HUKS 保护的密钥加密 API Key。
- Preferences 只保存密文、必要的随机量/元数据及非敏感配置，不保存 API Key 明文。
- Key 的解密结果只在实际验证或调用所需的最短生命周期内驻留内存。

### 8.2 禁止事项

- 不得在源码、资源文件、测试数据或安装包中内置默认 Key。
- 不得在日志、异常信息、埋点、网络调试输出或工作记录中输出完整 Key。
- 不得通过 `toString()`、对象整体序列化等间接方式泄漏 Key。
- 错误提示只能说明认证失败，不得回显服务端可能返回的凭证片段。

## 9. 视觉验证门禁

### 9.1 为什么不用 1×1 图

接口返回 HTTP 2xx 只说明请求被接受。纯文本模型或中转站可能忽略图片字段后仍正常回答，因此 `1×1` 图片加“请求成功”无法证明图像理解能力。

### 9.2 验证要求

- 使用体积很小、但包含可识别颜色/形状关系的视觉挑战图。
- 挑战应包含应用本地已知的正确答案；可从多个挑战中随机选择，降低模型猜中固定答案的概率。
- 请求采用 OpenAI Chat Completions 的视觉消息格式，同时发送文本指令与 Base64 Data URL 图片。
- 文本指令要求模型只返回可严格比较的短答案。
- 只有 HTTP 请求成功、响应结构合法且答案匹配，才判定为验证成功。
- 视觉挑战只证明当前 `baseURL + apiKey + model` 组合在验证时能理解图像，不代表厂商未来不会调整模型能力。

### 9.3 失败分类与用户文案

至少区分：

| 分类 | 判定示例 | 用户结果 |
|---|---|---|
| 认证失败 | HTTP 401/403 | 提示检查 API Key，不保存 |
| 地址或接口错误 | URL 非法、404、明显的协议/路径错误 | 提示检查 baseURL，不保存 |
| 无法确认图像理解 | 服务端明确拒绝图片，或挑战答案不匹配 | 提示改用多模态模型并包含示例型号，不保存 |
| 网络错误 | DNS、断网、连接失败、超时 | 提示检查网络，不保存 |
| 服务错误 | 其他明确的 4xx/5xx | 展示经过脱敏和归类的可读原因，不保存 |
| 响应格式错误 | 无合法 `choices/message/content` | 提示接口响应不兼容，不保存 |

任何失败都不得把草稿标为已验证，也不得覆盖已有的已验证配置。

## 10. 启动路由与页面边界

### 10.1 启动判断

- 没有完整、可解密、已验证配置：进入配置向导。
- 存在完整、可解密、已验证配置：进入主界面。
- 数据损坏、HUKS 解密失败或配置版本无法读取时：安全地视为未配置，显示可恢复的说明，不崩溃。

### 10.2 主界面壳

Story 1 的主界面只需提供：

- 空时间轴状态；
- 后续 Story 可扩展的底部导航占位；
- 进入设置页修改模型配置的入口。

不得为了 Story 1 提前实现 OCR、截图导入、卡片数据库或触发引擎。

## 11. 验证策略与环境边界

### 11.1 当前可执行验证

本机已经具备 DevEco Studio、API 24 SDK 与 Hvigor，因此开发时必须至少完成：

- Hvigor 构建通过；
- 纯逻辑自动测试或可重复的 mock 测试；
- 首启路由、事务式保存、URL 安全规则、错误分类、视觉答案判定的测试；
- HUKS 与 Preferences 的设备侧集成代码编译通过；
- 对所有包含中文或其他非 ASCII 内容的改动检查 Git diff，保证 UTF-8 编码未损坏。

### 11.2 不能提前宣称通过的项目

在没有实际模拟器/真机和用户自备厂商凭证时，不得宣称以下验收已经完成：

- 模拟器或真机安装启动；
- 杀进程后的设备侧持久化实测；
- 真实厂商的认证失败、视觉成功与视觉拒绝实测；
- 真机上的 HUKS 行为与 UI 交互体验。

这些项目应在工作记录和交接文档中明确标为待验证，而不是以 mock 结果代替。

## 12. 开发流程约束

Story 1 真正开始时，遵循 `docs/DevelopmentPlan.md`：

1. 从最新 `main` 创建 `feature/s01-config-wizard`。
2. 创建 `docs/worklogs/S01-工作记录.md`。
3. Task 1.1–1.5 每个 Task 完成后，自测、更新工作记录、提交并推送。
4. Story 验收完成后创建 `docs/handover/S01-交接文档.md`，再发起 PR。

本文的创建不代表 Story 启动，因此当前不创建功能分支、工作记录、交接文档或代码提交序列。

## 13. 留给实现阶段的非产品决策

以下细节尚未被产品决策锁死，开发者可在不违反本文约束的前提下选择，并应在工作记录中说明：

- 小型视觉挑战的具体图案、尺寸、随机策略和答案协议；
- 推荐模型 ID 的初始清单及其官方资料核对日期；
- ArkUI 页面和导航的具体代码组织方式；
- OpenAI-compatible URL 尾部斜杠与完整 endpoint 的规范化细节；
- 验证请求的合理超时值及是否允许用户主动重试；
- HUKS 加密参数与密文版本迁移格式。

这些选择不得削弱视觉验证、密钥保护、HTTPS 限制、事务式替换或启动门禁。
