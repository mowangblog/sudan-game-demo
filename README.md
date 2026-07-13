# 苏丹的游戏复刻 · 摄王的游戏

> Godot 4.6 复刻学习项目 · 非商业用途

[![Godot](https://img.shields.io/badge/Godot-4.6-478cbf?logo=godot-engine)](https://godotengine.org/)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

## 简介

《苏丹的游戏》是一款卡牌驱动的叙事策略 roguelike 游戏。玩家扮演苏丹的臣子，在波斯风格的奇幻宫廷中经营势力、应对苏丹卡的威胁、派遣角色执行仪式以维持生存。

本项目为个人学习目的的 MVP 复刻，重点在于理解原版游戏的美术风格、UI 设计及核心系统机制。

已部署GitHub Pages，体验地址：[mowangblog.github.io/shewang-game-demo](https://mowangblog.github.io/shewang-game-demo/)

已部署个人网站，体验地址：[gdcode.top/game](https://gdcode.top/game/)

## 核心系统

| 系统 | 描述 |
|------|------|
| **摄政王令** | 每抽取一张，7天内必须消除，否则处决 |
| **仪式** | 派遣角色执行任务，骰子检定决定成败 |
| **八围属性** | 体魄/战斗/生存/社交/魅力/隐匿/智慧/魔力 |
| **五声望** | 名望/恶名/权势/义名/灵知 |
| **金币卡** | 可叠加、右键拆分、拖拽合并的物理卡牌 |

## 快速开始

```bash
# 用 Godot 4.6 打开项目
git clone git@github.com:mowangblog/sudan-game-demo.git
# 在 Godot 编辑器中导入 project.godot
```

## 操作指南

- **拖拽卡牌** → 投入仪式槽位
- **右键** → 拆分金币卡
- **拖金币到金币** → 合并
- **排序按钮** → 按品质/分类循环排序
- **下一天** → 结算所有仪式 → 推进回合

## 技术栈

- **引擎** Godot 4.6 (Forward+ 渲染器, Jolt Physics)
- **脚本** GDScript
- **数据** JSON (卡牌/仪式/事件)

## 参考资源

- [BWIKI 攻略站](https://wiki.biligame.com/sultansgame/)
- [Steam 商店页](https://store.steampowered.com/app/3117820/)

## License

MIT — 仅供学习参考，非原版游戏授权。
