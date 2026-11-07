# map · 纸上迷宫

## 项目用途

把用户上传的手绘迷宫制作成可玩的二维游戏。当前主版本为 **Windows 原生版 v0.2.0**，使用 Godot 4.7.2 标准版与 GDScript；网页 v0.1 保留为旧版。

游戏规则：收齐全部星星才能进入终点，传 n 到达传 n+1，钥匙打开对应门，问号没有物品。当前含 4 颗星星、5 把钥匙和 5 个传送点；钥匙可重复使用，传5为最终落点。

## 基本使用

- Windows：完整解压本轮交付的 map-windows-x64-v0.2.0.zip，运行 map.exe；map.pck 须与程序放在同一文件夹。无需安装 Godot、Python 或 Node.js。
- WASD／方向键平滑移动；点击道路寻路，键盘立即接管。鼠标右键／中键拖动，滚轮缩放，F 全图，C 定位，空格／Esc 暂停，F11 全屏。
- 原生版自动存档独立于网页；窗口失焦会暂停并清除方向输入。
- 电脑地图去除了纸张底纹横线，原始照片作为核对依据保留。处理范围见 [Windows 原生版](docs/context/NATIVE.md#数据与去线)。
- 构建与测试见 [RUNBOOK](docs/context/RUNBOOK.md#业务运行与验证)；正式包生成在 outputs/，不作为源码提交。

## 网页旧版

旧版离线入口为 [map.html](dist/map.html) 或 [打开map.cmd](打开map.cmd)，在线地址和历史记录见 [MAP](docs/context/MAP.md#配置与部署)。本轮只更新电脑版本，网页继续使用原有资源与行为。

## 文档入口

- [协作规则](AGENTS.md) 与 [任务索引](PROJECT_INDEX.md)
- [当前状态与证据](docs/context/NOW.md)
- [Windows 原生结构与去线范围](docs/context/NATIVE.md)
- [原始游戏设计与识别依据](docs/context/GAME_DESIGN.md)
- [目录、版本与部署](docs/context/MAP.md)

少数原图门编号、钥匙2和终点位置仍为暂定；用户试玩验收状态见 [RISKS](docs/context/RISKS.md)。
