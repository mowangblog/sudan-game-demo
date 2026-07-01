# TurnManager.gd
# AutoLoad 回合管理器 — 驱动每日/每周循环
# 管理天数、周数、苏丹卡倒计时、仪式限时结算

extends Node

var current_day: int = 1           # 当前天数（全局递增）
var current_week: int = 1          # 当前周数
var current_week_day: int = 1      # 本周第几天（1-7）
const DAYS_PER_WEEK := 7

var active_rites: Array = []       # [{id, time_limit, duration, ...}]
var pending_settlement: Array = [] # 本轮需要结算的仪式

func reset() -> void:
	current_day = 1
	current_week = 1
	current_week_day = 1
	active_rites = []
	pending_settlement = []

func _ready() -> void:
	# 游戏启动后，发出第1天的信号
	call_deferred("_begin_day")


## === 每日循环入口 ===
func next_day() -> void:
	# 先结束今天
	EventBus.day_ended.emit(current_day)

	current_week_day += 1

	if current_week_day > DAYS_PER_WEEK:
		current_week_day = 1
		current_week += 1
		EventBus.week_ended.emit(current_week - 1)
		_start_new_week()

	current_day += 1
	_begin_day()


func _begin_day() -> void:
	# 1. 苏丹卡倒计时 -1
	update_sultan_card_countdowns()
	# 2. 所有仪式限时 -1、用时 -1
	update_rite_timers()
	# 3. 结算用时为0的仪式
	settle_pending_rites()
	# 4. 通知新一天开始
	EventBus.day_started.emit(current_day, current_week)


func _start_new_week() -> void:
	EventBus.week_started.emit(current_week)
	# GameManager 响应此信号 → 抽取新苏丹卡


## === 苏丹卡倒计时管理 ===
func update_sultan_card_countdowns() -> void:
	# GameManager 持有当前苏丹卡数据，这里发送信号让 GameManager 处理
	EventBus.sultan_card_countdown_tick.emit("", 0)  # 占位，由 GameManager 实际处理


## === 仪式计时器管理 ===
func update_rite_timers() -> void:
	for i in range(active_rites.size() - 1, -1, -1):
		var rite = active_rites[i]
		rite.time_limit -= 1
		rite.duration -= 1

		if rite.duration <= 0:
			# 用时到0 → 进入结算队列
			var rite_data = rite.duplicate()
			pending_settlement.append(rite_data)
			active_rites.remove_at(i)


func settle_pending_rites() -> void:
	# 按仪式ID排序（越小优先级越高）
	pending_settlement.sort_custom(func(a, b): return a.id < b.id)

	for rite in pending_settlement:
		EventBus.rite_settled.emit(rite.id, "success", 0)
	pending_settlement.clear()


## === 仪式注册 ===
func register_rite(rite_data: Dictionary) -> void:
	active_rites.append(rite_data.duplicate())


func get_days_until_week_end() -> int:
	return DAYS_PER_WEEK - current_week_day + 1


## === 跳过到下一周（用于仪式成功后的快速推进） ===
func skip_to_next_week() -> void:
	# 结束当前天
	EventBus.day_ended.emit(current_day)
	# 跳到下周第一天
	current_day += DAYS_PER_WEEK - current_week_day + 1
	current_week += 1
	current_week_day = 1
	EventBus.week_ended.emit(current_week - 1)
	_start_new_week()
	_begin_day()
