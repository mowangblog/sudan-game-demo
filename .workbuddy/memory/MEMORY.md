# 苏丹的游戏 — 项目长期记忆

## 项目信息
- **项目名称：** 苏丹的游戏复刻（学习项目）
- **引擎：** Godot 4.6 (Forward+ 渲染器, Jolt Physics)
- **目标：** 通过复刻学习游戏美术与 UI 设计
- **范围：** MVP — 可玩的最小核心循环，非完整商业复刻

## 技术约定
- 脚本语言：GDScript
- 数据格式：JSON（卡牌、仪式、事件数据）
- 全局状态：AutoLoad 单例（game_manager, resource_manager, event_bus）
- UI 布局：Control 节点 + 容器系统（VBox/HBox/GridContainer）

## 设计哲学
- 玩家同理心优先
- 每个系统先"跑起来"再"做漂亮"
- 所有数值标记为 [PLACEHOLDER] 直到测试
- 系统间交互必须明确（预期/可接受/缺陷）

## GDD 状态
- **文档路径：** docs/GDD.md
- **版本：** v0.2-verified (2026-06-16)
- **状态：** 核心机制已通过原版数据验证，数值细节仍为 PLACEHOLDER
- **MVP范围：** 5角色、15仪式、20事件、16苏丹卡（4类型×4等级）
- **P0 系统：** 苏丹卡、回合管理、仪式、检定（八围+二项分布）、资源（金币+5声望）、俺寻思、角色、UI框架

## 核心机制速查（已验证）
- **检定**：属性值=骰子数，二项分布（Easy=60%, Normal=50%, Hard=33%）
- **金骰子**：检定后追加+1成功，前提骰子总数≥1
- **八围属性**：体魄/战斗/生存/社交/魅力/隐匿/智慧/魔力
- **5声望**：善名/恶名/权势/侠名/灵视（各有阈值触发事件）
- **奢靡扩建**：石3金/铜5金/银10金/金20金
- **俺寻思**：拖入卡牌触发探索/处理的万能入口

## 开发经验
- **手写 .tscn 非常脆弱** → Phase 1 用纯代码构建 UI，避免 null 引用
- AutoLoad _ready 顺序按注册顺序，注意信号时序
- GameManager 必须检查 INIT 状态，避免游戏启动前的信号干扰
- **拖放实现**：DraggableCard.gd (_get_drag_data) + RiteSlot.gd (_can_drop_data/_drop_data)
- **批量结算**：点下一天→_settle_rites遍历active_rites→逐个骰检定→清理

## 当前交互流程
1. 抽卡（自动）→ 苏丹卡出现在底部手牌
2. 拖拽角色卡/苏丹卡 → 投入地图的仪式槽位
3. 槽位显示已投入的卡牌+预估成功率
4. 点「下一天」→ 批量结算所有仪式 → 推进回合

## 参考资源
- BWIKI: https://wiki.biligame.com/sultansgame/
- Steam: https://store.steampowered.com/app/3117820/
