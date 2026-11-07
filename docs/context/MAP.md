# 项目映射

## 目录关系

路径均相对仓库根目录；不记录个人设备绝对路径。

| 位置 | 职责 |
| --- | --- |
| AGENTS.md / PROJECT_INDEX.md / README.md | 协作规则、条件路由与使用入口 |
| docs/context/ | 当前状态、原生版、设计、操作、决策和风险 |
| reference/hand-drawn-map.png | 用户提供的原始图像证据 |
| src/map.annotations.json | 地标、门要求、传送设定及旧版校准的权威来源 |
| godot/project.godot | Windows 原生工程，Godot 4.7.2 / GDScript |
| godot/scripts/ | 原生规则、移动、分块物理、导航、相机、界面与存档 |
| godot/assets/map/ | 原生去线后的图像、碰撞、导航及处理报告，不手工编辑 |
| godot/assets/NotoSansCJKsc-Regular.otf / OFL.txt | 中文字体及其原始许可证 |
| godot/tests/ | 规则/移动、界面/存档集成、真实控制器全图测试 |
| scripts/prepare_native_tools.py | 获取固定版本编辑器与 Windows 模板，校验摘要 |
| scripts/prepare_native_map.py | 从原图和标注生成原生资源 |
| scripts/build_native.py | 测试、导出、独立包验证、压缩与哈希检查 |
| src/engine.mjs / src/game.mjs / dist/ | 网页 v0.1 的规则、交互及单文件产物 |
| scripts/digitize-map.py / scripts/build.mjs / scripts/serve.mjs | 网页旧版的生成、构建和预览 |
| .openai/hosting.json | 旧网页 Sites 身份与部署配置 |

work/ 保存工具、临时依赖及检查日志；outputs/ 保存交付物；.godot/ 是引擎导入缓存，均不提交。

## 版本与远端

- Git 分支 main，GitHub 公共仓库：[project-context-foundation](https://github.com/Lyz30919235/project-context-foundation)；远端 origin 以 Git 元数据为准。
- 当前源码已接续同一历史；Windows v0.2.0 与网页 v0.1 分开维护。
- 固定工具版本为 Godot 4.7.2.stable；获取地址和摘要由准备脚本管理，不在文档复制工具二进制。
- 发布源码基线和最新同步证据以 [NOW](NOW.md#核验与证据) 为准；具体包的来源提交记录于 release-info.json。

## 配置与部署

- Windows：Compatibility 渲染器，x86_64，独立 map.exe + map.pck，含中文字体；构建后输出免安装 ZIP。
- Python 地图工具依赖见 [requirements-native.txt](../../scripts/requirements-native.txt)，仅开发/生成资源时需要。
- 网页旧版：[在线地址](https://map-paper-maze-lyz.littlecider1.chatgpt.site)，其 [2026-11-03 交付记录](history/2026-11-03-web-v0.1.md) 包含当时的发布状态。本轮没有发布新版网页或重新核验其访问策略。
