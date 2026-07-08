# GameManager.gd
# 摄政王令生命周期 — 女术士页面抽令、每天结束倒计时减1、逾期处决
# 改动：_draw_sultan_card → emit信号触发女术士页面，不再静默抽令

extends Node

var active_sultan_card: Dictionary = {}
var sultan_card_days_left: int = 0
var is_game_over: bool = false
var renovation_done: bool = false
var has_drawn_first_card: bool = false  # 是否已抽过第一张令
var swap_tokens: int = 7               # 换令次数
var consumed_cards: Array = []         # 已折断的摄政王令记录（type/rank/name），供进度面板


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)


func start_game() -> void:
	is_game_over = false
	active_sultan_card = {}
	sultan_card_days_left = 0
	renovation_done = false
	has_drawn_first_card = false
	swap_tokens = 7
	consumed_cards = []
	ResourceManager.reset()
	TurnManager.reset()
	EventBus.game_started.emit()
	# 开局：触发女术士页面抽第一张令（而非静默抽令）
	EventBus.sultan_card_needs_draw.emit(true)


# ---- 每天开始：无卡则标记需要抽令，有卡则检查逾期 ----
func _on_day_started(day: int) -> void:
	if is_game_over:
		return

	if active_sultan_card.is_empty():
		# 无令在手 → 需要抽令，触发女术士页面
		EventBus.sultan_card_needs_draw.emit(false)
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


# ---- 抽令（由女术士页面调用） ----
func draw_sultan_card_via_sorceress(card_data: Dictionary) -> void:
	active_sultan_card = card_data
	sultan_card_days_left = 7
	has_drawn_first_card = true
	EventBus.sultan_card_drawn.emit(card_data)


# ---- 消耗：清空后触发女术士页面抽新令 ----
func consume_sultan_card(rite_id: int) -> void:
	if active_sultan_card.is_empty():
		return
	var card_id = active_sultan_card.id
	var card_name = active_sultan_card.name
	consumed_cards.append(active_sultan_card.duplicate())  # 记录折断，供进度面板
	active_sultan_card = {}
	sultan_card_days_left = 0
	EventBus.sultan_card_consumed.emit(card_id)
	# 折令后 → 需要抽新令，触发女术士页面
	EventBus.sultan_card_needs_draw.emit(false)
	print("[GameManager] Sultan card '%s' consumed via rite %d" % [card_name, rite_id])


# ---- 换令 ----
func swap_sultan_card() -> void:
	if swap_tokens <= 0:
		return
	if active_sultan_card.is_empty():
		return
	# 换出的令放回令池
	DataManager.return_sultan_card(active_sultan_card.id)
	swap_tokens -= 1
	active_sultan_card = {}
	sultan_card_days_left = 0
	# 触发女术士页面抽新令（倒计时不变由女术士页面处理）
	EventBus.sultan_card_needs_draw.emit(false)


# ---- 死亡 ----
func _trigger_death() -> void:
	is_game_over = true
	EventBus.game_over.emit("DEATH")
	print("[GameManager] Sultan card expired — DEATH!")
