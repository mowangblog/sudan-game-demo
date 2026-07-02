# 重构计划

> 目标：MainScene 从 1118 行拆到 <400 行，单例职责清晰，后续系统接入不打架。

---

## 当前架构问题

```
MainScene (1118行)  ← 上帝类，管一切
  ├── UI 搭建（状态栏、地图、手牌区、弹窗）
  ├── 卡牌管理（创建、拖放、排列、排序、合并）
  ├── 仪式流程（详情面板、确认、取消、结算）
  └── 游戏逻辑（下一天、游戏结束、刷新）
```

## 目标架构

```
Game (场景根，<300行)
 ├── UILayer（状态栏 + 日志）
 │    └── StatusBar
 ├── MapPanel（地点网格 + 仪式按钮）
 ├── HandZone（手牌区）
 │    ├── HandLayoutManager    ← 排列/折叠/排序
 │    ├── CardFactory           ← 角色卡/苏丹卡/资源卡创建
 │    ├── CardDragController    ← 拖放到槽位/合并/拆分
 │    └── ResourceCardManager   ← 金币卡叠加/拆分/同步
 ├── RitePanel（仪式详情 + 槽位）
 │    └── SlotManager
 └── PopupLayer（结算动画、角色详情、游戏结束）
      └── SettlementPopup / CharPopup / GameOverPopup
```

## 分阶段执行

### Phase 1：卡牌系统独立（先做，影响最大）

| 步骤 | 内容 | 收益 |
|------|------|------|
| 1.1 | 提取 `CardFactory` — `_make_char_card` / `_make_sultan_card` / `_make_resource_card` 搬出 | 减 ~200 行 |
| 1.2 | 提取 `HandLayoutManager` — `_arrange_hand` + `_cycle_sort` + `_auto_merge_resources` | 减 ~100 行 |
| 1.3 | 提取 `CardDragController` — `_on_hand_card_dropped` 拆出去 | 减 ~80 行 |
| 1.4 | 提取 `ResourceCardManager` — 金币同步/拆合/数量更新，干掉 `_sync_gold_card` | 减 ~50 行 |

### Phase 2：弹窗统一管理

| 步骤 | 内容 | 收益 |
|------|------|------|
| 2.1 | 创建 `PopupManager` — 统一管理所有弹窗的生命周期 | 新文件 |
| 2.2 | `_show_game_over` / `_show_char_popup` / `_show_sultan_popup` / `_show_res_popup` 迁移 | 减 ~120 行 |

### Phase 3：仪式流程独立

| 步骤 | 内容 | 收益 |
|------|------|------|
| 3.1 | 提取 `RiteController` — `_open_rite_detail` / `_commit` / `_restore` / `_clear` / 结算触发 | 减 ~100 行 |
| 3.2 | 结算流程 `_next_press` / `_settle_next` 迁移到 RiteController | 减 ~60 行 |

### Phase 4：单例瘦身

| 步骤 | 内容 | 收益 |
|------|------|------|
| 4.1 | `ResourceManager.gold` 改为读取金币卡数量，不独立存储 | 消除双源问题 |
| 4.2 | `GameManager` + `TurnManager` 合并为 `GameState`，或明确分工：Game 管状态 / Turn 管时间 | 单例 5→4 |
| 4.3 | 所有 `reset()` 统一为 `GameState.new_game()` 一键重置 | 不再漏 reset |

### Phase 5：数据层整理

| 步骤 | 内容 | 收益 |
|------|------|------|
| 5.1 | `rites.json` 补全仪式效果字段（gold / power / hero 等已存在，补充缺失项） | 数据完整 |
| 5.2 | `DataManager` 增加缓存，避免每次打开仪式都重新读 JSON | 性能 |

## 不做的事

- 不做 DI 容器 / 服务定位器（过度设计）
- 不引入状态机框架（Godot 的 scene tree 已够用）
- 不手写 .tscn（保持纯代码策略）
- 不改卡牌拖拽底层（DraggableCard 已经很干净）

## 重构原则

1. **每个 Phase 可独立提交**，不破坏运行
2. **先搬代码再删旧代码**，不丢逻辑
3. **Phase 1 做完再开 Phase 2**，不并行
4. **超过 200 行的新文件必须再拆**
