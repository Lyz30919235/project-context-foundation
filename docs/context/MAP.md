# 项目映射

## 目录关系

以下路径均相对仓库根目录。项目目录现名为 map；不记录个人设备绝对路径。

| 位置 | 职责 |
| --- | --- |
| AGENTS.md / PROJECT_INDEX.md / README.md | 协作规则、任务路由及使用入口 |
| docs/context/ | 当前状态、设计、映射、操作、决策及风险专题 |
| reference/hand-drawn-map.png | 用户上传的原始地图证据 |
| src/map.annotations.json | 原图坐标、门要求、传送设定及道路校准的权威数据 |
| scripts/digitize-map.py | 从原图与标注生成关卡 |
| src/level.generated.json | 生成的碰撞位图与绘图资源，不手工编辑 |
| src/engine.mjs | 碰撞、拾取、门锁、传送与胜利判定 |
| src/game.mjs / src/index.html / src/style.css | 浏览器交互、界面和样式 |
| scripts/build.mjs / scripts/serve.mjs | 离线单文件构建和本地预览 |
| tests/ / scripts/validate-level.mjs | 规则回归与真实地图逐步通关检查 |
| dist/index.html / dist/map.html | 相同构建内容的站点入口与离线入口 |
| 打开map.cmd | 本机默认浏览器启动入口 |
| .openai/hosting.json | Sites 身份与静态目录配置，不含认证令牌 |
| .gitignore | 忽略本地中间文件、依赖和认证材料 |

work/ 与 outputs/ 是本地产物位置，不作为现行项目事实来源；中间截图、日志和临时 Python 依赖不进入版本库。

## 版本与远端

- 本地版本管理：Git，分支 main。
- GitHub 公共仓库：[project-context-foundation](https://github.com/Lyz30919235/project-context-foundation)。本次更改项目目录和游戏名称，保留既有仓库地址。
- 远端名称：origin；实际地址以 Git 元数据为准。
- Sites 的源仓库由其工具提供，独立于 GitHub origin；认证令牌只通过会话内存及标准输入使用，不落盘。
- 当前提交与远端分支应实时查询；核验结果以 [NOW](NOW.md#核验与证据) 为准。

## 配置与部署

- 游戏：纯静态浏览器代码，运行时无网络资源和第三方包依赖。
- 本轮开发工具：Node.js 24.20.0；数字化工具依赖见 [requirements-map.txt](../../scripts/requirements-map.txt)。离线游玩不需要这些开发依赖。
- 部署配置：[hosting.json](../../.openai/hosting.json)，静态目录为 dist。
- 在线试玩：[map · 纸上迷宫](https://map-paper-maze-lyz.littlecider1.chatgpt.site)，当前仅站点所有者可访问。发布结果及代码基线见 [NOW](NOW.md#核验与证据)。
