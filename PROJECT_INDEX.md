# 项目索引

## 项目定位

map 是基于用户手绘图的二维迷宫，当前主版本为 Windows 原生版，网页旧版保留。用途与基本使用方式以 [README](README.md) 为准；本索引只负责路由。

## 职责与路由

按当前任务选择一行，再定位目标章节或条目。链接不是必读清单。

| 当前任务 | 权威来源 | 读取条件与更新条件 |
| --- | --- | --- |
| 确认长期约定、读写及验证要求 | [AGENTS.md](AGENTS.md) | 接手或规则可能变化时确认适用规则；长期约定变化时更新 |
| 了解项目用途、基本使用及入口 | [README.md](README.md) | 了解或使用项目时读；实际能力、使用方式或入口变化时更新 |
| 找到任务对应的资料 | 本文件 | 需要定位时读；入口或职责变化时更新，不复制专题正文 |
| 修改当前版规则与状态 | [rules.gd](godot/scripts/rules.gd) | 按收集、门锁、传送、存档或胜利方法定位，并执行 Godot 原生回归 |
| 修改地图、去线与核对原图标记 | [map.annotations.json](src/map.annotations.json) | 原始标记按条目检索；原生去线、校准及生成范围见 [NATIVE](docs/context/NATIVE.md#数据与去线) |
| 修改原生移动与界面 | [player.gd](godot/scripts/player.gd)、[main.gd](godot/scripts/main.gd) | 按运动、输入、相机或界面方法定位；结构见 [NATIVE](docs/context/NATIVE.md#运行结构) |
| 维护网页旧版 | [engine.mjs](src/engine.mjs)、[game.mjs](src/game.mjs) | 仅在任务明确维护旧网页时进入；沿用其独立构建与测试 |
| 接续当前工作 | [NOW.md](docs/context/NOW.md) | 接续时定位目标、进展、阻塞及下一步；状态实质变化时直接修订 |
| 定位目录、版本、配置或部署对象 | [MAP.md](docs/context/MAP.md) | 涉及对应对象时读；映射变化时更新，不推断未核实环境 |
| 执行文档维护或 Git 同步 | [RUNBOOK.md](docs/context/RUNBOOK.md) | 执行对应操作前读；方法变化时更新，未执行步骤不得写成成功 |
| 调研、发展或评估用户的 idea | [IDEA_RESEARCH.md](docs/context/IDEA_RESEARCH.md) | 涉及相近工作、实质差异或价值验证时按需读取；方法要求变化时更新，具体 idea 的证据按主题维护 |
| 理解已确认选择及理由 | [DECISIONS.md](docs/context/DECISIONS.md) | 涉及对应选择时检索；决策确认或被替代时更新 |
| 处理问题、风险或验证缺口 | [RISKS.md](docs/context/RISKS.md) | 涉及对应事项时检索；证据、保护措施或状态变化时更新 |
| 追溯有价值的旧过程 | [history/README.md](docs/context/history/README.md) | 有明确追溯问题时先搜索再读；必要归档时更新 |

## 信息写入定位

- 每类事实以上表指定来源为准，其他文件只保留必要摘要和相对链接。
- 业务事实仍缺少资料时，写明“待核实”及所缺证据；不要为填满文档创建推断内容。
- 现有结构如出现等价文件或章节，先评估并沿用；只有职责确实不同才新建文档并更新路由。
