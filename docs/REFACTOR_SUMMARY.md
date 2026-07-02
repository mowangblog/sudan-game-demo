# 重构总结报告

> 日期：2026-07-02 | 版本 v1.0-refactored

---

## 成果总览

| 指标 | 改造前 | 改造后 |
|------|--------|--------|
| MainScene | 1 个文件 1129 行 | 1 个文件 740 行 (-34%) |
| 新模块 | 0 | 3 个独立模块 |
| 上帝类 | 1 个 | 0 个 |
| 总模块数 | 9 | 12 |

## 新增模块

| 模块 | 行数 | 类型 | 职责 |
|------|------|------|------|
| **CardFactory** | 151 | RefCounted | 角色卡/苏丹卡/金币卡的创建 |
| **HandLayoutManager** | 117 | RefCounted | 手牌排列、堆叠压缩、排序、合并 |
| **PopupManager** | 165 | RefCounted | 角色/苏丹卡/资源/游戏结束弹窗 |

## 改造前后对比

```
改造前（上帝类）：              改造后（职责分离）：
MainScene (1129行)             MainScene (740行)
  ├ 卡牌创建 (170行)             ├ 场景组装 + 仪式流程
  ├ 手牌布局 (80行)              │
  ├ 弹窗管理 (130行)            CardFactory (151行)
  ├ 拖放处理 (50行)              └ 卡牌创建全部职责
  ├ 结算流程 (80行)
  └ ...                         HandLayoutManager (117行)
                                  └ 排列/排序/合并/堆叠

                                PopupManager (165行)
                                  └ 四个弹窗的创建与生命周期
```

## 踩坑记录

| 坑 | 原因 | 教训 |
|----|------|------|
| `_end_drag()` 被调两次 | 右键拆分代码缩进错误，`_end_drag` 落在 `if` 外 | 重构后先测功能再清旧代码 |
| `Color.a(0.5)` 不存在 | Godot 4 无此方法，需用 `Color("c8a84e80")` | Godot 3→4 API 差异要逐个验证 |
| 背景遮挡手牌 | ColorRect 作为 hand_container 子节点，被 `move_child` 推到前面 | 装饰层和交互层必须在不同父节点 |
| 函数声明被批量替换破坏 | `func _arrange_hand()` → `func hand_layout.arrange()` | 永远不要对文件做不区分上下文的全局替换 |
| `call_deferred` 时序错误 | hand_layout.setup 之前就调 deferred | 依赖注入后必须验证调用顺序 |

## 未执行的计划

| Phase | 原计划 | 放弃原因 |
|-------|--------|----------|
| 1.3 CardDragController | 提取 `_on_hand_card_dropped` (~80行) | 拖放是多个系统的胶水层，拆分增加回调复杂度 |
| 1.4 ResourceCardManager | 提取金币同步 (~50行) | 同理，金币操作渗透到合并/拆分/刷新等 5+ 处 |
| Phase 3 仪式独立 | 提取 `_open_rite_detail` (~160行) | 绑定 15+ 状态变量，拆分成本远超收益 |
| Phase 4 单例瘦身 | 合并 GameManager+TurnManager | 现有分工清晰，合并反而膨胀 |

## 最终架构

```
MainScene (740行) — 场景组装 + 仪式流程协调
  ├ CardFactory (151行) — 只读工厂，无状态
  ├ HandLayoutManager (117行) — 引用 hand_cards, hand_container
  └ PopupManager (165行) — 引用 root Control

AutoLoad 单例 (不变)：
  ├ GameManager (136行) — 苏丹卡生命周期
  ├ TurnManager (108行) — 天/周计数 + 仪式计时
  ├ ResourceManager (115行) — 金币/声望/金骰子
  ├ DataManager (73行) — JSON 加载
  └ EventBus (49行) — 信号总线
```

## 提交记录

```
aa8ad90  fix: Color.a() → Color hex alpha, call_deferred 修复
b2731f1  refactor(1.1): 提取 CardFactory
9243a42  refactor(1.1): 清理旧 _make_* 函数
abb7dcf  refactor(1.2): 提取 HandLayoutManager
96f9571  fix: 清理残留的 _arrange_hand 函数体
4b4f041  fix: _return_card_to_hand 改用 card_factory
e709ab7  refactor(phase2): 提取 PopupManager
aa8ad90  fix: 修复俺寻思位置、_refresh缺arrange
3b16035  fix: 背景移到 hand_container 同级
```
