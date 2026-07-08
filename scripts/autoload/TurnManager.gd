# TurnManager.gd
# AutoLoad 回合管理器 — 驱动每日循环
# 管理天数、摄政王令倒计时、仪式限时结算

extends Node

var current_day: int = 1

var active_rites: Array = []       # [{id, time_limit, duration, ...}]
var pending_settlement: Array = [] # 本轮需要结算的仪式

func reset() -> void:
	current_day = 1
	active_rites = []
	pending_settlement = []

func _ready() -> void:
	call_deferred("_begin_day")


## === 每日循环入口 ===
func next_day() -> void:
	EventBus.day_ended.emit(current_day)
	current_day += 1
	_begin_day()


func _begin_day() -> void:
	update_rite_timers()
	settle_pending_rites()
	_spawn_daily_rites()
	EventBus.day_started.emit(current_day)


func _spawn_daily_rites() -> void:
	var normal_rites: Array = []
	for r in DataManager.rites:
		if r.get("category","") != "normal": continue
		if r.get("insight_trigger"): continue
		normal_rites.append(r)
	if normal_rites.is_empty(): return
	var count = 1 + (randi() % 2)
	for _i in range(count):
		var idx = randi() % normal_rites.size()
		var rite = normal_rites[idx]
		EventBus.rite_appeared.emit(rite.duplicate())


## === 仪式计时器管理 ===
func update_rite_timers() -> void:
	for i in range(active_rites.size() - 1, -1, -1):
		var rite = active_rites[i]
		rite.time_limit -= 1
		rite.duration -= 1

		if rite.duration <= 0:
			var rite_data = rite.duplicate()
			pending_settlement.append(rite_data)
			active_rites.remove_at(i)


func settle_pending_rites() -> void:
	pending_settlement.sort_custom(func(a, b): return a.id < b.id)

	for rite in pending_settlement:
		EventBus.rite_settled.emit(rite.id, "success", 0)
	pending_settlement.clear()


## === 仪式注册 ===
func register_rite(rite_data: Dictionary) -> void:
	active_rites.append(rite_data.duplicate())
