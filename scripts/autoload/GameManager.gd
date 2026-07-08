# GameManager.gd
# AutoLoad 游戏状态管理器 — 核心协调者
# 管理摄政王令生命周期、游戏状态、结束判定

extends Node

enum GameState {
	INIT,         # 初始化中
	DAY_ACTIVE,   # 每日行动中
	GAME_OVER     # 游戏结束
}

var state: GameState = GameState.INIT
var active_sultan_card: Dictionary = {}  # 当前活跃的摄政王令
var sultan_card_days_left: int = 0       # 摄政王令剩余天数
var is_game_over: bool = false
var ending_type: String = ""
var renovation_done: bool = false  # 装修完成标记(仅一次)


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)


## === 游戏启动 ===
func start_game() -> void:
	print("[GameManager] Starting new game...")
	is_game_over = false
	ending_type = ""
	active_sultan_card = {}
	sultan_card_days_left = 0
	renovation_done = false
	state = GameState.DAY_ACTIVE
	ResourceManager.reset()
	TurnManager.reset()
	EventBus.game_started.emit()
	_draw_sultan_card()


## === 摄政王令抽取 ===
func _draw_sultan_card() -> void:
	var card = DataManager.draw_sultan_card()
	if card.is_empty():
		return

	active_sultan_card = card
	sultan_card_days_left = 8
	state = GameState.DAY_ACTIVE

	EventBus.sultan_card_drawn.emit(card)
	print("[GameManager] Sultan card drawn: %s (Rank: %s, Type: %s)" % [card.name, card.rank, card.type])


## === 每日开始 ===
func _on_day_started(day: int) -> void:
	if state == GameState.GAME_OVER:
		return
	if state == GameState.INIT:
		return
	print("[GameManager] Day %d — Sultan card days left: %d" % [day, sultan_card_days_left])

	# 检查是否逾期
	if sultan_card_days_left <= 0 and _is_card_unspent():
		_trigger_death()


## === 每日结束 ===
func _on_day_ended(day: int) -> void:
	if state == GameState.GAME_OVER:
		return
	sultan_card_days_left -= 1
	if not active_sultan_card.is_empty():
		EventBus.sultan_card_countdown_tick.emit(active_sultan_card.get("id", ""), sultan_card_days_left)


## === 摄政王令消耗 ===
func consume_sultan_card(rite_id: int) -> void:
	if active_sultan_card.is_empty():
		return

	var card_id = active_sultan_card.get("id", "")
	var card_name = active_sultan_card.get("name", "")

	print("[GameManager] Sultan card '%s' consumed via rite %d" % [card_name, rite_id])
	active_sultan_card = {}
	EventBus.sultan_card_consumed.emit(card_id)
	
	# 消耗后立即补抽新卡
	_draw_sultan_card()


## === 死亡判定 ===
func _is_card_unspent() -> bool:
	return not active_sultan_card.is_empty()

func _trigger_death() -> void:
	print("[GameManager] Sultan card expired — DEATH!")
	state = GameState.GAME_OVER
	ending_type = "DEATH"
	is_game_over = true
	EventBus.game_over.emit("DEATH")


func trigger_game_over(ending: String) -> void:
	print("[GameManager] Game over: %s" % ending)
	state = GameState.GAME_OVER
	ending_type = ending
	is_game_over = true
	EventBus.game_over.emit(ending)


## === 工具方法 ===
func current_day() -> int:
	return TurnManager.current_day

func get_days_until_sultan_card_expires() -> int:
	return sultan_card_days_left
