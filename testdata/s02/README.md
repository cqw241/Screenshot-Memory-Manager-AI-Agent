# Story 2 合成验收样例

本目录包含四张不含个人隐私的确定性中文截图，用于手动验证相册导入、端侧 OCR 和结构化理解。`expected.json` 记录目标分类及 OCR 必须出现的主要文字。

图片由 `generate_samples.py` 使用 Pillow 和 Windows 微软雅黑字体生成。仓库已提交生成后的 PNG，日常验证不需要重新执行脚本。

验证时将四张 PNG 导入 HarmonyOS Emulator 或真机相册，再从拾光逐张选择。不得把模拟器结果描述为真机结果。
