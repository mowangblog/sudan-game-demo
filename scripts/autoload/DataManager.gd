# DataManager.gd
# AutoLoad 数据管理器 — 从 JSON 加载所有游戏数据
# 提供数据访问接口供所有系统使用

extends Node

var sultan_cards: Array = []
var characters: Array = []
var rites: Array = []
var events: Array = []
var books: Array = []

var _card_pool: Array = []   # 牌盒（待抽取的摄政王令）


func _ready() -> void:
	_load_all_data()


func _load_all_data() -> void:
	_load_json("res://data/sultan_cards.json", sultan_cards)
	_load_json("res://data/characters.json", characters)
	_load_json("res://data/rites.json", rites)
	_load_json("res://data/events.json", events)
	_load_json("res://data/books.json", books)
	_refill_card_pool()
	print("[DataManager] Loaded %d cards, %d characters, %d rites, %d events" % [sultan_cards.size(), characters.size(), rites.size(), events.size()])


func _load_json(path: String, target: Array) -> void:
	if not FileAccess.file_exists(path):
		print("[DataManager] WARNING: File not found: %s" % path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	var json = JSON.parse_string(text)
	if json != null:
		target.assign(json)
	file.close()


## === 牌盒管理 ===
func _refill_card_pool() -> void:
	_card_pool = sultan_cards.duplicate()
	_card_pool.shuffle()


func draw_sultan_card() -> Dictionary:
	if _card_pool.is_empty():
		_refill_card_pool()
		if _card_pool.is_empty():
			return {}
	var card = _card_pool.pop_front()
	return card.duplicate()


func return_sultan_card(card_id: String) -> void:
	# 换令：把令放回令池
	for card in sultan_cards:
		if card.id == card_id:
			_card_pool.append(card.duplicate())
			return


## === 数据查询 ===
func get_character_by_id(char_id: String) -> Dictionary:
	for c in characters:
		if c.id == char_id:
			return c.duplicate()
	return {}

func get_rite_by_id(rite_id: int) -> Dictionary:
	for r in rites:
		if r.id == rite_id:
			return r.duplicate()
	return {}

func get_events_by_trigger(trigger_type: String) -> Array:
	var result: Array = []
	for e in events:
		if e.trigger_condition.get("type") == trigger_type:
			result.append(e.duplicate())
	return result
