# ResourceCardManager.gd
# Keeps resource state and hand resource cards in sync.

class_name ResourceCardManager
extends RefCounted

var card_factory: CardFactory
var hand_layout: HandLayoutManager
var popups: PopupManager
var hand_container: Control
var hand_cards: Array
var resource_cards: Dictionary

var _on_card_dropped: Callable

func setup(
	p_card_factory: CardFactory,
	p_hand_layout: HandLayoutManager,
	p_popups: PopupManager,
	p_hand_container: Control,
	p_hand_cards: Array,
	p_resource_cards: Dictionary,
	p_on_card_dropped: Callable
) -> void:
	card_factory = p_card_factory
	hand_layout = p_hand_layout
	popups = p_popups
	hand_container = p_hand_container
	hand_cards = p_hand_cards
	resource_cards = p_resource_cards
	_on_card_dropped = p_on_card_dropped


func make_gold_card(amount: int) -> PanelContainer:
	var card = _make_resource_card("金币", "💰", "GOLD", amount)
	resource_cards["金币"] = card
	return card


func give_gold_cards(amount: int) -> void:
	give_resource_card("金币", "💰", "GOLD", amount)


func give_resource_card(name_str: String, icon: String, quality: String, count: int) -> PanelContainer:
	var card = _make_resource_card(name_str, icon, quality, count)
	hand_container.add_child(card)
	hand_cards.append(card)
	hand_layout.arrange()
	return card


func split_resource_card(source_card: PanelContainer, name_str: String, icon: String, quality: String) -> void:
	var c2 = source_card.get_meta("res_count", 0)
	if c2 <= 1:
		return
	update_card_count(source_card, c2 - 1)
	var newc = _make_resource_card(name_str, icon, quality, 1)
	hand_container.add_child(newc)
	var idx = hand_cards.find(source_card)
	if idx != -1:
		hand_cards.insert(idx + 1, newc)
	else:
		hand_cards.append(newc)
	hand_layout.arrange()


func update_card_count(card: PanelContainer, count: int) -> void:
	card.set_meta("res_count", count)
	card.get_meta("res_data").count = count
	card.set_meta("drag_data", card.get_meta("res_data"))
	var lbl = card.get_node_or_null("VB/CountLbl")
	if lbl:
		lbl.text = ("x%d" % count) if count > 1 else ""
	if card.get_meta("res_type", "") == "金币":
		ResourceManager.gold = count


func refresh_intel_cards() -> void:
	for nm in _get_known_intel_names():
		var card = resource_cards.get(nm)
		var cnt = ResourceManager.get_intel_count(nm)
		var icon = _get_intel_icon(nm)
		var quality = _get_intel_card_quality(nm)
		if cnt > 0:
			if is_instance_valid(card):
				var res_data = card.get_meta("res_data", {})
				if res_data.get("quality", "") != quality:
					hand_cards.erase(card)
					resource_cards.erase(nm)
					card.queue_free()
					card = null
			if not is_instance_valid(card):
				card = _make_resource_card(nm, icon, quality, cnt)
				card._on_click = func(): popups.show_res_popup(nm, icon, quality, card.get_meta("res_count", 0))
				hand_container.add_child(card)
				hand_cards.append(card)
				resource_cards[nm] = card
			else:
				card.set_meta("res_count", cnt)
				if card.has_meta("res_data"):
					card.get_meta("res_data").count = cnt
				var lbl = card.get_node_or_null("VB/CountLbl")
				if lbl:
					lbl.text = ("x%d" % cnt) if cnt > 1 else ""
				card.visible = true
		else:
			if is_instance_valid(card):
				card.visible = false
	hand_layout.arrange()


func consume_gold_card(gold_data: Dictionary) -> void:
	# 金币也是卡牌：进入仪式队列后不返回即视为消费。
	# 禁止在结算阶段扫描/修改手牌金币。
	pass


func consume_resource_card_data(resource_data: Dictionary) -> void:
	if _resource_type(resource_data) == "intel":
		_modify_intel(resource_data, -resource_data.get("count", 1))


func restore_resource_card_data(resource_data: Dictionary) -> void:
	if _resource_type(resource_data) == "intel":
		_modify_intel(resource_data, resource_data.get("count", 1))


func _make_resource_card(name_str: String, icon: String, quality: String, count: int) -> PanelContainer:
	var card = card_factory.make_resource_card(name_str, icon, quality, count)
	card.drag_ended.connect(_on_card_dropped)
	card.drag_started.connect(func(_c): hand_layout.arrange())
	card._on_right_click = func(): split_resource_card(card, name_str, icon, quality)
	card._on_click = func(): popups.show_res_popup(name_str, icon, quality, card.get_meta("res_count", 0))
	return card


func _get_known_intel_names() -> Array:
	var names: Array = []
	for nm in ResourceManager.INTEL_EFFECTS.keys():
		if not names.has(nm):
			names.append(nm)
	for pool in [ResourceManager.intel_stone, ResourceManager.intel_copper, ResourceManager.intel_silver]:
		for nm in pool.keys():
			if not names.has(nm):
				names.append(nm)
	names.sort()
	return names


func _get_intel_card_quality(type_name: String) -> String:
	if ResourceManager.intel_silver.get(type_name, 0) > 0:
		return "SILVER"
	if ResourceManager.intel_copper.get(type_name, 0) > 0:
		return "BRONZE"
	return "STONE"


func _get_intel_icon(type_name: String) -> String:
	var icons = {
		"秘密": "📜",
		"洞察": "🔍",
		"战术": "⚔",
		"秘氛": "🕶",
		"机遇": "🧭",
		"内幕": "🏛",
		"预兆": "🔮",
		"密教": "🕯",
	}
	return icons.get(type_name, "📜")


func _resource_type(resource_data: Dictionary) -> String:
	var resource_type = resource_data.get("resource_type", "")
	if resource_type != "":
		return resource_type
	return "gold" if resource_data.get("name", "") == "金币" else "intel"


func _modify_intel(resource_data: Dictionary, delta: int) -> void:
	var name_str = resource_data.get("name", "")
	if name_str == "":
		return
	var pool = _intel_pool_for_quality(resource_data.get("quality", "STONE"))
	pool[name_str] = max(0, pool.get(name_str, 0) + delta)
	if pool[name_str] <= 0:
		pool.erase(name_str)


func _intel_pool_for_quality(quality: String) -> Dictionary:
	match quality:
		"SILVER":
			return ResourceManager.intel_silver
		"COPPER", "BRONZE":
			return ResourceManager.intel_copper
		_:
			return ResourceManager.intel_stone
