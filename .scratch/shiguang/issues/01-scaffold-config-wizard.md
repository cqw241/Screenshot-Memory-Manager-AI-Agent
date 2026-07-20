# 01 — 项目脚手架 + 首启配置向导 + 验证门禁

**What to build:** 用户第一次打开拾光 App,被强制引导进入模型配置页:填写 baseURL / apiKey / model(提供智谱/通义/豆包/OpenAI 的 baseURL 快捷模板)。点保存时,后台发送一次带 1×1 测试图的 OpenAI Chat Completions(vision 格式)探测请求:成功则落盘配置、进入主界面(空时间轴);模型不支持图像输入则拒绝保存,提示"该模型不支持图像输入,请填写多模态模型(如 glm-4v、qwen-vl-plus)"。已配置过的用户重启直接进主界面。不内置任何默认 key。

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] DevEco Studio 创建 HarmonyOS NEXT ArkTS 工程,能在模拟器/真机运行
- [ ] 首次启动强制进入配置向导,未通过验证无法进入主界面
- [ ] 填写有效多模态模型(如 GLM-4V)→ 探测通过 → 配置持久化 → 进入主界面
- [ ] 填写纯文本模型(如 deepseek-chat)→ 被拦截并给出含示例型号的提示
- [ ] 杀进程重启不再出现向导,直接进主界面
- [ ] 设置页可随时修改配置,修改同样过验证门禁
