# AI 交接文档 — 摄政王的游戏

## 项目概览
Godot 4.6 复刻《苏丹的游戏》MVP。核心系统已运行：抽卡、仪式配置、骰检定、回合推进。

## 当前工程状态

**Git 干净版本：** `CLEAN_20260707` tag（`git checkout CLEAN_20260707` 可恢复）

**已工作的功能：**
- 地图上40+个仪式，点击弹窗配卡
- 角色卡/摄政王令拖入槽位，sultan_card检查
- 点「下一天」批量结算，骰子播放+叙事文本
- 古籍摊：放金币→买书，不放→只逛
- 书拖入灵光一现→读书事件，属性成长
- 结算页传值：主场景关闭同时弹出奖励小字条

## 当前正在推进：卡牌消费系统

### 问题
卡拖入槽位后在 `hand_cards` 中留下 invisible 节点，结算后 `_restore_hand_cards` 全部 set visible，金币卡被消费后仍然回到手牌。前后多次修补混乱。

### 已确认的开发计划（等待执行）

**核心思路：** 每张卡只有一个归属——要么在手牌，要么在仪式队列里。

**改动点（3处）：**

| 位置 | 改动 |
|------|------|
| `MainScene._open_rite_detail` 确认按钮 | 收集卡牌数据后，从 `hand_cards` 移除 invisible 卡，存入 `entry["stored_cards"]` |
| `MainScene._restore_hand_cards` | 遍历 active_rites，金币卡→queue_free，其他→放回 hand_cards；删掉原来的 set visible 循环 |
| `MainScene._restore_assigned_cards`（取消时） | stored_cards 原样退回 hand_cards |

**不动的东西：** 槽位拖拽、RiteSlotDrop、结算页、书店、读书事件、治理家业金币收入，全部不动。

### 此前被打乱的逻辑（不要恢复）
以下逻辑已被多次添加又删除，**不要引入**：
- resource_trimmed 信号和截断逻辑
- card_consumed 信号
- _consume_gold_card / _consume_gold_from_hand
- _sync_gold_card / _last_gold 差分金币
- ResourceManager.gold 读写（已清理）
- SettlementScreen 的 _total_rewards（已清理）

## 关键文件速查

| 文件 | 职责 |
|------|------|
| `scripts/ui/MainScene.gd` | 主场景，集合所有UI逻辑（约1300行） |
| `scripts/ui/RiteSlotDrop.gd` | 槽位组件，拖放检查+卡牌展示 |
| `scripts/ui/SettlementScreen.gd` | 结算弹窗，骰子+叙事+奖励传递 |
| `scripts/ui/CardFactory.gd` | 卡牌节点工厂（角色/资源/书/摄政王令） |
| `data/rites.json` | 所有仪式数据，统一用 outcomes.success/fail |
| `docs/GDD.md` | 设计文档 |

## 结算链路

```
_open_rite_detail → confirm_btn → active_rites.append(entry)
→ _next_press → _settle_next(index)
→ SettlementScreen.setup_and_show(rite, char, sultan, reward_text)
→ _finish_settlement → settlement_done.emit({rite,...,gold_gained})
→ callback: gold_gained>0→发金币卡, id==16→给书
→ _settle_next(index+1) 直到全部完成
→ _restore_hand_cards → TurnManager.next_day → _refresh
```

## 注意事项

- **不要大改**：用户已多次强调，一次只改一个逻辑点
- **出错先回退**：`git checkout CLEAN_20260707` 回到干净状态
- **先给方案再动手**：不确定时先问
- **金币是卡牌**：金币卡=手牌中的可堆叠资源卡（count=N），不是 ResourceManager 数据
- **outcomes 是统一字段**：所有仪式的奖励都在 outcomes.success.gold 和 outcomes.fail.gold
