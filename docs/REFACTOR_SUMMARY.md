# 重构总结报告

> 更新日期：2026-07-07 | 阶段：Phase 1-6 已告一段落

---

## 成果总览

| 指标 | 改造前 | 当前 |
|------|--------|------|
| MainScene | 1 个文件 1129 行 | 654 行 |
| 新增/强化模块 | 0 | 9 个独立协作模块 |
| 主要风险区 | 手牌、仪式、结算、俺寻思混在 MainScene | 已拆出可单独演进的模块 |
| 奖励应用 | 分散在 SettlementScreen / MainScene / ResourceManager | 结算后效果集中到 RiteRewardApplier |

## 当前模块边界

| 模块 | 行数 | 职责 |
|------|------|------|
| `MainScene.gd` | 654 | 场景组装、系统协调、少量拖放胶水 |
| `CardFactory.gd` | 192 | 角色卡、苏丹卡、资源卡、书籍卡创建 |
| `HandLayoutManager.gd` | 118 | 手牌排列、排序、资源自动合并 |
| `PopupManager.gd` | 159 | 角色/苏丹卡/资源/游戏结束弹窗 |
| `ResourceCardManager.gd` | 159 | 金币/情报等资源卡创建、拆分、刷新、同步 |
| `MapRitePanel.gd` | 203 | 地图仪式按钮、位置、倒计时、可见性 |
| `StatusBar.gd` | 71 | 顶部日期、声望、苏丹卡倒计时 |
| `RiteDetailPopup.gd` | 365 | 仪式详情弹窗、槽位创建、拖入、确认/取消 |
| `RiteSettlementController.gd` | 81 | active rites 的逐个结算推进 |
| `RiteRewardApplier.gd` | 193 | 结算后奖励/消耗/完成标记应用 |
| `InsightController.gd` | 237 | 俺寻思、书籍、特殊仪式生成 |
| `SettlementScreen.gd` | 587 | 骰子动画、检定过程、结算文本、返回 result |

## 已完成阶段

### Phase 1-2：卡牌与弹窗基础拆分

- `CardFactory` 负责卡牌节点创建，减少 MainScene 中 UI 构造代码。
- `HandLayoutManager` 负责手牌排列、排序、资源合并。
- `PopupManager` 统一常规信息弹窗生命周期。

### Phase 3：仪式详情弹窗流程

- `RiteDetailPopup` 自己创建 slots、接收拖入、维护 assigned cards。
- 确认时 emit `committed(config)`，取消时 emit `cancelled(is_edit, existing_entry)`。
- MainScene 不再读取 popup meta，也不再直接遍历 slot_nodes。
- 已修复 `check: null` 仪式打开时报 `Nil.get` 的问题；无检定仪式显示“无需检定”。

### Phase 4：结算队列

- `RiteSettlementController` 管 active rites 的逐个推进。
- `SettlementScreen` 只返回 result，不再决定奖励怎么进手牌。
- 苏丹卡消费、装修完成标记已从队列控制器迁到奖励应用层。

### Phase 5：俺寻思/书店特殊逻辑

- `InsightController` 负责：
  - 拖入俺寻思后的特殊仪式生成
  - 书籍阅读仪式
  - 书店买书预处理
  - 荣誉杀戮等 insight 入口
- MainScene 只保留 drop 协调。

### Phase 6：数据效果系统收口

- `RiteRewardApplier` 统一处理结算后的：
  - 正向金币奖励发卡
  - 声望变化
  - roll rewards 情报
  - 书籍获得
  - 读书属性增长
  - 仪式队列中的金币卡/苏丹卡消耗记录
  - 装修完成标记
- `SettlementPopup` 旧弹窗已不再直接应用资源。
- `SettlementScreen` 不再从 outcomes 中提取金币，只负责骰子与文本。

## 关键约定

1. 金币也是卡牌。金币卡进入仪式队列后，如果不返回手牌，就视为消费。
2. 结算阶段禁止扫描手牌直接扣金币。
3. `SettlementScreen` 的边界是“检定过程 + 结果返回”，不是奖励系统。
4. 结算后给东西、扣东西、改声望，优先进入 `RiteRewardApplier`。
5. 情报卡显示与手牌同步交给 `ResourceCardManager`，不要在奖励层手写卡牌刷新逻辑。
6. 俺寻思产生的新仪式入口继续放在 `InsightController`，避免 MainScene 回涨。

## 近期提交

```text
b0fc6fd refactor: centralize rite reward application
80e646e chore: add insight controller uid
fe92d64 refactor: extract insight controller
202b21a refactor: extract rite settlement flow
c45865f refactor: move rite detail flow into popup
9948858 refactor: extract status bar
a006921 refactor: extract map rite panel
ffb7e57 fix: decouple dice result and stage axes
bc60f49 refactor: extract resource card manager
```

---

## 下一需求：物品卡槽与情报加成计划

目标：参考原版，为大部分仪式增加可选物品卡槽。玩家可以放入情报等资源卡；情报在检定中提供重投或属性加成，不同情报对应不同属性/效果。

### 设计边界

- 物品槽属于仪式配置与弹窗槽位系统，由 `RiteDetailPopup` 创建和回传。
- 放入物品后的检定加成属于结算过程，由 `SettlementScreen` 读取 active rite 的 item/resource 配置。
- 物品消耗与返回规则属于结算后效果，由 `RiteRewardApplier` 统一处理。
- 情报卡数量与手牌显示仍由 `ResourceCardManager` 同步。

### 数据结构建议

在 `data/rites.json` 的大部分仪式 slots 中增加可选槽：

```json
{
  "type": "item",
  "label": "辅助物品",
  "required": false,
  "accepts": ["intel"]
}
```

资源卡 drag_data 建议统一字段：

```json
{
  "type": "resource",
  "resource_type": "intel",
  "name": "战术",
  "quality": "COPPER",
  "count": 1
}
```

情报效果表建议先放代码常量，稳定后再数据化：

| 情报 | 属性加成 | 额外效果 |
|------|----------|----------|
| 战术 | `com` | +1 重投 |
| 秘密 | `soc` | +1 重投 |
| 洞察 | `wis` | +1 重投 |
| 机遇 | `sur` | +1 重投 |
| 内幕 | `cha` | +1 重投 |
| 预兆 | `mag` | +1 重投 |
| 秘氛 | `ste` | +1 重投 |
| 密教 | `mag` | +2 属性，0 重投 |

品质倍率沿用现有情报等级：

| 品质 | 属性加成 | 重投加成 |
|------|----------|----------|
| STONE | +1 | +1 |
| COPPER / BRONZE | +2 | +2 |
| SILVER | +3 | +3 |

### 实施步骤

1. 数据扫描与补槽
   - 给大部分有检定的仪式增加可选 `item` 槽。
   - 无检定仪式先不加，避免玩家误以为能影响结果。
   - 奢靡扩建这类资源成本槽保持原 `resource/gold` 语义，不混同辅助物品槽。

2. 槽位支持
   - `RiteSlot.gd` / `RiteDetailPopup.gd` 支持 `item` 槽。
   - `item` 槽接受 `resource` 类型，先限定情报卡。
   - `committed(config)` 增加 `items: []`，MainScene 的 active rite entry 保存 item 队列节点与数据。

3. 物品队列与返回
   - MainScene 提交仪式时，从手牌移除 item 卡，放入仪式队列。
   - 取消/覆盖仪式时返回 item 卡。
   - 结算完成后默认消费 item 卡；后续如果有“不消耗物品”再加字段。

4. 检定加成
   - 新增 `RiteItemEffectResolver.gd` 或放入 `RiteRewardApplier` 前置 helper。
   - SettlementScreen 计算骰数时，把 item 提供的属性加成并入 `_calc_dice_count`。
   - 重投次数由现有情报库存逻辑改为“本次放入的情报卡”提供，避免全局库存白嫖。

5. 消耗与同步
   - `RiteRewardApplier.apply_queue_consumption()` 统一处理 item 消耗记录。
   - `ResourceCardManager` 增加消耗资源卡后的刷新/合并入口。
   - 保持“不扫描手牌直接扣资源”的规则：消耗的是已进入仪式队列的卡。

6. UI 提示
   - 仪式详情里显示“可选物品：情报”。
   - SettlementScreen 检定标签显示加成来源，例如：`战斗检定 🎲×5 需✅×2 🔄×2`。
   - toast 显示消耗：`消耗情报：战术（铜）`。

7. 验证点
   - 有 item 槽仪式不放物品可正常结算。
   - 放入情报后骰数增加、重投次数增加。
   - 取消仪式时情报回手牌。
   - 结算后情报从手牌消失，资源数量同步。
   - 书店/扩建/俺寻思特殊仪式不因 item 槽破坏。

## 风险

- 当前 `SettlementScreen` 仍直接读取全局情报库存提供重投，这会和“放入情报才加成”的新规则冲突。需求实现时应优先拆掉这段全局白嫖逻辑。
- 资源卡存在堆叠/拆分逻辑，item 槽最好强制一次放入单张数量为 1 的卡；否则需要支持部分消耗。
- `MainScene` 的拖放胶水仍较多，item 队列加入时要小步改，不要顺手抽大 controller。
