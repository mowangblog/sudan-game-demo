# GameManager.gd
# 摄政王令生命周期 — 每天开始无卡则抽、每天结束倒计时减1、逾期处决

extends Node

var active_sultan_card: Dictionary = {}
var sultan_card_days_left: int = 0
var is_game_over: bool = false
var renovation_done: bool = false


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)


func start_game() -> void:
	is_game_over = false
	active_sultan_card = {}
	sultan_card_days_left = 0
	renovation_done = false
	ResourceManager.reset()
	TurnManager.reset()
	EventBus.game_started.emit()
	_draw_sultan_card()  # 开局直接抽第一张卡


# ---- 每天开始：无卡则抽，有卡则检查逾期 ----
func _on_day_started(day: int) -> void:
	if is_game_over:
		return

	if active_sultan_card.is_empty():
		_draw_sultan_card()
	else:
		if sultan_card_days_left <= 0:
			_trigger_death()
	print("[GameManager] Day %d — card: %s, days: %d" % [day, active_sultan_card.get("name", "无"), sultan_card_days_left])


# ---- 每天结束：倒计时减1 ----
func _on_day_ended(_day: int) -> void:
	if is_game_over or active_sultan_card.is_empty():
		return
	sultan_card_days_left -= 1
	EventBus.sultan_card_countdown_tick.emit(active_sultan_card.id, sultan_card_days_left)


# ---- 抽卡 ----
func _draw_sultan_card() -> void:
	var card = DataManager.draw_sultan_card()
	if card.is_empty():
		return
	active_sultan_card = card
	sultan_card_days_left = 7
	EventBus.sultan_card_drawn.emit(card)


# ---- 消耗：清空后由第二天 day_started 补抽 ----
func consume_sultan_card(rite_id: int) -> void:
	if active_sultan_card.is_empty():
		return
	var card_id = active_sultan_card.id
	var card_name = active_sultan_card.name
	active_sultan_card = {}
	sultan_card_days_left = 0
	EventBus.sultan_card_consumed.emit(card_id)
	print("[GameManager] Sultan card '%s' consumed via rite %d" % [card_name, rite_id])


# ---- 死亡 ----
func _trigger_death() -> void:
	is_game_over = true
	EventBus.game_over.emit("DEATH")
	print("[GameManager] Sultan card expired — DEATH!")
