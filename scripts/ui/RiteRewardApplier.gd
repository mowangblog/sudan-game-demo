# RiteRewardApplier.gd
# Applies settlement results to cards/resources owned by the hand UI.

class_name RiteRewardApplier
extends RefCounted

var card_factory: CardFactory
var resource_card_manager: ResourceCardManager
var hand_container: Control
var hand_cards: Array
var hand_layout: HandLayoutManager
var _on_card_dropped: Callable
var _log: Callable

func setup(
	p_card_factory: CardFactory,
	p_resource_card_manager: ResourceCardManager,
	p_hand_container: Control,
	p_hand_cards: Array,
	p_hand_layout: HandLayoutManager,
	p_on_card_dropped: Callable,
	p_log: Callable
) -> void:
	card_factory = p_card_factory
	resource_card_manager = p_resource_card_manager
	hand_container = p_hand_container
	hand_cards = p_hand_cards
	hand_layout = p_hand_layout
	_on_card_dropped = p_on_card_dropped
	_log = p_log


func prepare_context(active_rite: Dictionary) -> Dictionary:
	var context := {"pending_book": {}}
	if active_rite.rite.get("id", -1) == 16 and not active_rite.get("gold", {}).is_empty():
		context.pending_book = pick_random_book()
	return context


func apply_result(active_rite: Dictionary, result: Dictionary, context: Dictionary) -> Array:
	var notifications: Array = result.get("notifications", [])
	_apply_roll_rewards(result, notifications)
	var gold_gained = result.get("gold_gained", 0)
	if gold_gained > 0:
		resource_card_manager.give_gold_cards(gold_gained)

	if result.success and result.rite.get("id", -1) == 16:
		var pending_book = context.get("pending_book", {})
		if not pending_book.is_empty():
			give_book(pending_book)
			notifications.append("📖 获得《%s》" % pending_book.get("name", ""))
		else:
			_log.call("📖 逛了一圈，没买书。")

	if result.success and result.rite.get("id", -1) == 300 and not active_rite.char.is_empty():
		_apply_reading_reward(active_rite)
	return notifications


func _apply_roll_rewards(result: Dictionary, notifications: Array) -> void:
	var counts: Array = result.get("stage_success_counts", [])
	var stages: Array = result.get("stages", [])
	if counts.size() == 0:
		var sc = 99 if result.get("success", false) else 0
		_apply_roll_reward_tiers(result.get("rite", {}).get("roll_rewards", []), sc, notifications)
		return
	for i in range(min(stages.size(), counts.size())):
		_apply_roll_reward_tiers(stages[i].get("roll_rewards", []), counts[i], notifications)


func _apply_roll_reward_tiers(tiers: Array, success_count: int, notifications: Array) -> void:
	for tier in tiers:
		if success_count >= tier.get("min", 0):
			var intel_data = tier.get("intel", [])
			if intel_data.size() >= 2:
				ResourceManager.add_intel(intel_data[0], intel_data[1])
				notifications.append(_intel_notification(intel_data[0], intel_data[1]))
			break


func _intel_notification(type_name: String, grade: String) -> String:
	var grade_texts = {"STONE": "石", "COPPER": "铜", "SILVER": "银"}
	return "+%s情报 %s" % [grade_texts.get(grade, grade), type_name]


func pick_random_book() -> Dictionary:
	var pool = DataManager.books.duplicate()
	if pool.is_empty():
		return {}
	for card in hand_cards:
		var data = card.get_meta("drag_data", {})
		if data.get("type", "") == "book":
			pool = pool.filter(func(book): return book.id != data.get("id", ""))
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]


func give_book(book: Dictionary = {}) -> void:
	if book.is_empty():
		book = pick_random_book()
		if book.is_empty():
			return
	var card = card_factory.make_book_card(book)
	card.drag_ended.connect(_on_card_dropped)
	card.drag_started.connect(func(_card): hand_layout.arrange())
	hand_container.add_child(card)
	hand_cards.append(card)
	hand_layout.arrange()
	_log.call("📖 购得《%s》" % book.get("name", "?"))


func _apply_reading_reward(active_rite: Dictionary) -> void:
	var book = active_rite.rite.get("book", {})
	var attr_map = {"social":"soc","combat":"com","wisdom":"wis","charm":"cha","stealth":"ste","magic":"mag","physique":"phy","survival":"sur"}
	var attr_key = attr_map.get(book.get("attr", ""), "")
	var gain = book.get("gain", 0)
	if attr_key != "" and active_rite.char.has("attributes"):
		active_rite.char["attributes"][attr_key] = active_rite.char["attributes"].get(attr_key, 0) + gain
		var ai = card_factory.AI.get(attr_key, attr_key)
		_log.call("📖 %s 读了《%s》，%s+%d" % [active_rite.char.get("name", "?"), book.get("name", "?"), ai, gain])
