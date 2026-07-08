# InsightController.gd
# Owns the "灵光一现" card interaction flow.

class_name InsightController
extends RefCounted

var root: Control
var C: Dictionary = {}
var hand_container: Control
var hand_cards: Array
var hand_layout: HandLayoutManager
var active_rites: Array
var _used_keys: Array[String] = []
var _callbacks: Dictionary = {}

func setup(
	p_root: Control,
	constants: Dictionary,
	p_hand_container: Control,
	p_hand_cards: Array,
	p_hand_layout: HandLayoutManager,
	p_active_rites: Array,
	callbacks: Dictionary
) -> void:
	root = p_root
	C = constants.get("C", {})
	hand_container = p_hand_container
	hand_cards = p_hand_cards
	hand_layout = p_hand_layout
	active_rites = p_active_rites
	_callbacks = callbacks


func clear_used_keys() -> void:
	_used_keys.clear()


func check_pending_honor_kill() -> void:
	for active_rite in active_rites:
		if active_rite.get("insight_kill_rank", "") != "" and active_rite.char.is_empty() and not active_rite.get("insight_kill_used", true):
			var rank = active_rite.insight_kill_rank
			if rank in ["STONE", "BRONZE"]:
				var honor_rite = DataManager.get_rite_by_id(205)
				if not honor_rite.is_empty():
					var entry = {"rite": honor_rite, "char": {}, "sultan_card": {}, "insight": true}
					active_rites.append(entry)
					_call("log", ["⚔ 荣誉清除的机会出现了——趁还来得及。"])
					_call("refresh")
			active_rite.insight_kill_used = true
			break


func do_insight_with_card(card: PanelContainer) -> void:
	var drag_data = card.get_meta("drag_data", {})
	var card_type = drag_data.get("type", "")
	var repeat_key = drag_data.get("id", "") if card_type == "character" else card_type
	if repeat_key in _used_keys:
		await show_bubble("暂时想不出\n更好的办法了。")
		return
	_used_keys.append(repeat_key)

	if card_type == "character":
		card.visible = false
		hand_layout.arrange()
		await _do_think_animation()
		await _show_char_bubble(drag_data)
		card.visible = true
		hand_layout.arrange()
		return

	if card_type == "book":
		card.visible = false
		hand_layout.arrange()
		hand_cards.erase(card)
		card.queue_free()
		await _do_think_animation()
		var book_data = drag_data.get("data", {})
		var attr_name = _book_attr_name(book_data.get("attr", ""))
		var gain = book_data.get("gain", 0)
		var rite = {"id":300,"name":book_data.get("name","读书"),"category":"insight","time_limit":1,"insight_trigger":{"type":"book","subtype":"READ"},"duration":1,"slots":[{"type":"character","label":"阅读者","required":true}],"book":book_data,"description":"阅读《%s》，使阅读者的%s永久提升%d点。" % [book_data.get("name","?"), attr_name, gain],"outcomes":{"success":{"narrative":"[角色]翻开《%s》的扉页，墨香扑面而来。书中的文字如同一把钥匙，打开了脑海中某个尘封已久的暗格——那些原来只是模糊直觉的东西，现在变得清晰而有条理。\n\n%+d %s" % [book_data.get("name","?"), gain, attr_name],book_data.get("attr",""): gain},"fail":{"narrative":"[角色]在《%s》面前坐了一个时辰，却一个字都没读进去。倒不是因为书太难——只是今天的心思被别的事情压得太重了。\n\n下次换个安静的日子再来吧。" % book_data.get("name","?")}}}
		var entry = {"rite": rite, "char": {}, "sultan_card": {}, "insight": true}
		active_rites.append(entry)
		_call("place_rite", [rite])
		await show_bubble("「%s」\n开始阅读" % book_data.get("name", "?"))
		hand_layout.arrange()
		return

	var matched = _find_insight_rites(card_type, drag_data)
	if matched.is_empty():
		card.visible = false
		hand_layout.arrange()
		await _do_think_animation()
		await show_bubble("暂时想不出\n更好的办法了。")
		card.visible = true
		hand_layout.arrange()
		return

	var kill_rank = ""
	if card_type == "sultan_card" and drag_data.get("data", {}).get("type", "") == "MURDER":
		kill_rank = drag_data.get("data", {}).get("rank", "").to_upper()

	var picked = matched[randi() % matched.size()]
	card.visible = false
	hand_layout.arrange()
	await _do_think_animation()

	var consumed := false
	if picked.get("insight_trigger", {}).get("consume", false):
		if card_type == "sultan_card":
			GameManager.consume_sultan_card(0)
			card.queue_free()
			hand_cards.erase(card)
			consumed = true

	_add_insight_rite_to_map(picked, drag_data, consumed, kill_rank)
	if not consumed:
		card.visible = true
		hand_layout.arrange()


func _book_attr_name(attr: String) -> String:
	match attr:
		"social": return "社交"
		"combat": return "战斗"
		"wisdom": return "智慧"
		"charm": return "魅力"
		"stealth": return "隐匿"
		"magic": return "魔力"
		"physique": return "体魄"
		"survival": return "生存"
		_: return attr


func show_bubble(text: String) -> void:
	var bubble = PanelContainer.new()
	bubble.name = "InsightBubble"
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color("1a1018")
	bs.set_corner_radius_all(8)
	bs.border_width_bottom = 1
	bs.border_width_top = 1
	bs.border_width_left = 1
	bs.border_width_right = 1
	bs.border_color = C.get("GOLD_LO", Color("8a6820"))
	bs.content_margin_left = 10
	bs.content_margin_right = 10
	bs.content_margin_top = 6
	bs.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", bs)
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", C.get("GOLD", Color("c8a84e")))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_child(label)
	root.add_child(bubble)
	bubble.reset_size()
	await root.get_tree().process_frame
	var viewport_size = root.get_viewport().size
	var insight = hand_container.get_node_or_null("InsightBtn")
	var x: float
	var y: float
	if insight and is_instance_valid(insight):
		var rect = insight.get_global_rect()
		x = rect.position.x + rect.size.x / 2 - bubble.size.x / 2
		y = rect.position.y - bubble.size.y - 8
	else:
		x = 50
		y = viewport_size.y - 240
	x = clampf(x, 4, viewport_size.x - bubble.size.x - 4)
	y = maxf(y, 4)
	bubble.position = Vector2(x, y)
	await root.get_tree().create_timer(2.0).timeout
	if is_instance_valid(bubble):
		bubble.queue_free()


func _do_think_animation() -> void:
	var insight = hand_container.get_node_or_null("InsightBtn")
	if insight and is_instance_valid(insight):
		var tween = root.create_tween().set_loops(3)
		tween.tween_property(insight, "modulate", Color(1.3, 1.3, 1.0), 0.25)
		tween.tween_property(insight, "modulate", Color.WHITE, 0.25)
	await root.get_tree().create_timer(1.0).timeout
	if insight and is_instance_valid(insight):
		insight.modulate = Color.WHITE


func _add_insight_rite_to_map(rite: Dictionary, drag_data: Dictionary, consumed: bool, kill_rank: String = "") -> void:
	var entry = {"rite": rite, "char": {}, "sultan_card": {}, "insight": true}
	if drag_data.get("type", "") == "character" and not consumed:
		entry.char = drag_data
	if kill_rank != "":
		entry["insight_kill_rank"] = kill_rank
		entry["insight_kill_used"] = false
	active_rites.append(entry)
	_call("place_rite", [rite])
	_call("refresh")
	await show_bubble("「%s」\n出现在地图上" % rite.get("name", "?"))


func _find_insight_rites(card_type: String, drag_data: Dictionary) -> Array:
	var matched: Array = []
	for rite in DataManager.rites:
		var trigger = rite.get("insight_trigger", {})
		if trigger.is_empty():
			continue
		if trigger.get("type", "") != card_type:
			continue
		if trigger.get("subtype", "") == "LUXURY" and GameManager.renovation_done:
			continue
		var subtype = trigger.get("subtype", "")
		if subtype != "":
			if card_type == "sultan_card":
				var card_data = drag_data.get("data", {})
				if card_data.get("type", "") != subtype:
					continue
				var filter_rank = trigger.get("filter_rank", "")
				if typeof(filter_rank) == TYPE_ARRAY:
					if not card_data.get("rank", "").to_upper() in filter_rank:
						continue
				elif filter_rank != "" and card_data.get("rank", "").to_upper() != filter_rank:
					continue
			elif card_type == "resource":
				var res_id = drag_data.get("id", "")
				if subtype == "INTEL":
					if not ResourceManager.INTEL_EFFECTS.has(res_id):
						continue
				elif res_id != subtype:
					continue
		if card_type == "sultan_card" and subtype == "MURDER" and rite.id != 204:
			continue
		matched.append(rite)
	return matched


func _show_char_bubble(drag_data: Dictionary) -> void:
	var cid = drag_data.get("id", "")
	var bubbles = {
		"player": "嗯？",
		"meji": "我的挚爱，我的坚定盟友。",
		"zhaqiyi": "我的学生，很有潜力的年轻人。",
		"tietou": "一个沉默寡言的铁匠。",
		"kuaijiao": "路边的消息，往往最值钱。",
	}
	await show_bubble(bubbles.get(cid, drag_data.get("name", "角色")))


func _call(name: String, args: Array = []) -> void:
	var cb = _callbacks.get(name, Callable())
	if cb.is_valid():
		cb.callv(args)
