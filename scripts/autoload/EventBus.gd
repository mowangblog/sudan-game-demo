# EventBus.gd
# AutoLoad 全局信号总线 — 解耦系统间通信
# 所有模块通过 EventBus 发送和监听信号，避免直接依赖

extends Node

## === 回合/时间信号 ===
signal day_started(day_number: int, week_number: int)
signal day_ended(day_number: int)
signal week_started(week_number: int)
signal week_ended(week_number: int)

## === 苏丹卡信号 ===
signal sultan_card_drawn(card_data: Dictionary)
signal sultan_card_consumed(card_id: String, week_number: int)
signal sultan_card_expired(card_id: String)       # 逾期未消耗 → 触发死亡
signal sultan_card_countdown_tick(card_id: String, remaining_days: int)

## === 仪式信号 ===
signal rite_appeared(rite_data: Dictionary)        # 地图上出现新仪式
signal rite_config_updated(rite_id: int, slots: Array)
signal rite_settled(rite_id: int, outcome: String, successes: int)
signal rite_expired(rite_id: int)                  # 仪式超时

## === 检定信号 ===
signal check_triggered(check_type: String, dice_count: int, required_successes: int)
signal dice_rolled(results: Array, success_count: int)
signal gold_dice_used(count: int, final_successes: int)

## === 资源/声望信号 ===
signal gold_changed(new_amount: int, delta: int)
signal reputation_changed(reputation_type: String, new_value: int)
signal reputation_threshold_reached(reputation_type: String, threshold: int)

## === 事件信号 ===
signal event_triggered(event_id: String)
signal event_choice_made(event_id: String, choice_index: int)

## === 角色信号 ===
signal character_recruited(char_id: String)
signal character_lost(char_id: String)
signal relationship_changed(char_id: String, new_status: String)

## === 游戏状态信号 ===
signal game_over(ending_type: String)
signal game_started()

## === "俺寻思" 信号 ===
signal insight_triggered(card_data: Dictionary)
