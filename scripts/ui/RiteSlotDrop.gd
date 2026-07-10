# RiteSlotDrop.gd
# 仪式卡槽 — 卡牌大小，支持替换/点击详情/右键移除/拖出

extends PanelContainer

signal card_dropped(slot_index: int, card_data: Dictionary)
signal card_removed(slot_index: int, card_data: Dictionary)
signal card_clicked(card_data: Dictionary)
signal empty_slot_clicked(slot_index: int)
signal resource_trimmed(slot_index: int, excess_data: Dictionary)  # 资源溢出（数量超过max）

@export var slot_index: int = 0
@export var slot_type: String = "character"
@export var required_tags: Array = []
@export var is_optional: bool = false
@export var accept: String = ""   # resource 类型时过滤卡牌名称
@export var accepts: Array = []
@export var max_cards: int = 1

var current_card: Dictionary = {}
var card_factory  # 由 RiteDetailPopup 注入
var _display_card: PanelContainer = null

const C = {
	GOLD=Color("c8a84e"), GOLD_HI=Color("e8d48b"), GOLD_LO=Color("8a6820"),
	TEXT=Color("f0e6c8"), DIM=Color("a09070"),
}
const RANK_STARS = {"STONE":"★","BRONZE":"★★","SILVER":"★★★","GOLD":"★★★★"}
const ATTR_ICONS = {"phy":"💪","com":"⚔","sur":"🏕","soc":"💬","cha":"💋","ste":"🕶","wis":"📚","mag":"🔮"}
const RANK_BG = {"STONE":Color(0.15,0.13,0.11), "BRONZE":Color(0.13,0.16,0.10), "SILVER":Color(0.12,0.13,0.15), "GOLD":Color(0.16,0.14,0.08)}
const RANK_BORDER = {"STONE":Color(0.50,0.42,0.33), "BRONZE":Color(0.60,0.68,0.35), "SILVER":Color(0.62,0.66,0.70), "GOLD":Color(0.88,0.73,0.33)}
const CHAR_QUALITY = {"player":"SILVER","meji":"SILVER","zhaqiyi":"BRONZE","tietou":"GOLD","kuaijiao":"STONE"}
const CARD_SIZE := Vector2(100, 180)
const CARD_TITLE_FONT = preload("res://assets/fonts/云峰字库重庆山城棒棒体.ttf")

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	_draw_empty()

var _press_pos: Vector2
var _pressing: bool = false

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if not current_card.is_empty():
					card_removed.emit(slot_index, current_card)
					current_card = {}
					_draw_empty()
					accept_event()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				_press_pos = event.position
				_pressing = true
				# 不 accept，让 DnD 系统也能收到
		else:
			if event.button_index == MOUSE_BUTTON_LEFT and _pressing:
				var dist = (event.position - _press_pos).length()
				if dist < 6:  # 没拖动=点击
					if current_card.is_empty():
						empty_slot_clicked.emit(slot_index)
					else:
						card_clicked.emit(current_card)
				_pressing = false

func _get_drag_data(at_position: Vector2) -> Variant:
	if current_card.is_empty():
		return null
	var data = {"type": slot_type, "data": current_card, "name": current_card.get("name","")}
	# 不在这里 emit card_removed，等 NOTIFICATION_DRAG_END 再触发
	
	# 创建跟卡牌一样的拖拽预览（原卡牌大小）
	var prev = PanelContainer.new()
	prev.custom_minimum_size = CARD_SIZE
	prev.modulate = Color(1,1,1,0.85)
	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.border_width_bottom=2; sb.border_width_top=2; sb.border_width_left=2; sb.border_width_right=2
	sb.content_margin_left=4; sb.content_margin_right=4; sb.content_margin_top=4; sb.content_margin_bottom=4
	sb.shadow_size=8; sb.shadow_color=Color("00000066")
	
	var vb = VBoxContainer.new(); vb.mouse_filter=Control.MOUSE_FILTER_IGNORE
	vb.alignment=BoxContainer.ALIGNMENT_CENTER; prev.add_child(vb)
	
	if slot_type == "sultan_card":
		sb.bg_color = RANK_BG.get(current_card.get("rank",""), Color("2a2018"))
		sb.border_color = C.GOLD
		prev.add_theme_stylebox_override("panel", sb)
		var l1 = Label.new(); l1.text={"LUST":"欢愉","LUXURY":"奢靡","CONQUEST":"征伐","MURDER":"杀戮"}.get(current_card.get("type",""),"?")
		_apply_card_title_style(l1, 20)
		l1.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(l1)
	elif slot_type == "gold" or slot_type == "resource" or slot_type == "item":
		var q = current_card.get("quality","STONE")
		sb.bg_color = RANK_BG.get(q, Color("2a2018"))
		sb.border_color = RANK_BORDER.get(q, C.GOLD_LO)
		prev.add_theme_stylebox_override("panel", sb)
		var l2 = Label.new(); l2.text=current_card.get("name","?")
		_apply_card_title_style(l2, 16)
		l2.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(l2)
	else:
		var q = CHAR_QUALITY.get(current_card.get("id",""), "STONE")
		sb.bg_color = RANK_BG.get(q, Color("2a2018"))
		sb.border_color = RANK_BORDER.get(q, C.GOLD_LO)
		prev.add_theme_stylebox_override("panel", sb)
		var l1 = Label.new(); l1.text=current_card.get("name","?")
		_apply_card_title_style(l1, 16)
		l1.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(l1)
		var l2 = Label.new(); l2.text=RANK_STARS.get(q,"★")
		l2.add_theme_font_size_override("font_size",13); l2.add_theme_color_override("font_color",C.GOLD)
		l2.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(l2)
	
	set_drag_preview(prev)
	return data

func _notification(what: int):
	if what == NOTIFICATION_DRAG_END:
		if not current_card.is_empty():
			card_removed.emit(slot_index, current_card)
			current_card = {}
			_draw_empty()


func _draw_empty():
	for c in get_children():
		c.queue_free()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("2a2018"); sb.set_corner_radius_all(10)
	sb.border_width_bottom=2; sb.border_width_top=2; sb.border_width_left=2; sb.border_width_right=2
	sb.border_color = C.GOLD_LO
	sb.content_margin_left=4; sb.content_margin_right=4; sb.content_margin_top=4; sb.content_margin_bottom=4
	add_theme_stylebox_override("panel", sb)
	
	var vb = VBoxContainer.new(); vb.alignment = BoxContainer.ALIGNMENT_CENTER; add_child(vb)
	var icon = Label.new()
	if slot_type == "gold": icon.text = "💰"
	elif slot_type == "resource": icon.text = "📦"
	elif slot_type == "item": icon.text = "🔎"
	elif slot_type == "sultan_card": icon.text = "🃏"
	else: icon.text = "👤"
	icon.add_theme_font_size_override("font_size", 30)
	icon.add_theme_color_override("font_color", Color("605040"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(icon)
	var hint = Label.new(); hint.text = "拖入\n卡牌"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("504030"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(hint)

func _draw_card_preview():
	for c in get_children():
		c.queue_free()
	_display_card = null
	if current_card.is_empty(): _draw_empty(); return
	if not card_factory:
		_draw_empty(); return
	
	match slot_type:
		"character":
			_display_card = card_factory.make_char_card(current_card)
		"sultan_card":
			_display_card = card_factory.make_sultan_card()
			_display_card.visible = true
			# 应用正确品质背景
			var sc_rank = current_card.get("rank", "STONE")
			card_factory.call("_apply_image_card_base", _display_card, sc_rank, C.GOLD_LO, false)
		"gold":
			_display_card = card_factory.make_resource_card("金币", "", "GOLD", current_card.get("count", 1))
		"resource", "item":
			_display_card = card_factory.make_resource_card(current_card.get("name", "?"), current_card.get("icon", ""), current_card.get("quality", "STONE"), current_card.get("count", 1))
		_:
			pass
	
	if _display_card:
		_display_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_display_card.size = CARD_SIZE
		_display_card.position = Vector2.ZERO
		add_child(_display_card)


func _apply_card_title_style(label: Label, font_size: int = 17) -> void:
	label.add_theme_font_override("font", CARD_TITLE_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("050403"))
	label.add_theme_color_override("font_shadow_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary: return false
	
	var drag_type = data.get("type", "")
	
	# 角色卡槽
	if slot_type == "character":
		return drag_type == "character"
	
	# 摄政王令槽
	if slot_type == "sultan_card":
		if drag_type != "sultan_card": return false
		if data.has("data") and not required_tags.is_empty():
			var cd = data.get("data", {})
			for tag in required_tags:
				if tag in ["LUST","LUXURY","CONQUEST","MURDER"] and tag != cd.get("type",""): return false
				if tag in ["STONE","BRONZE","SILVER","GOLD"] and tag != cd.get("rank",""): return false
		return true
	
	# 资源/金币卡槽
	if slot_type == "resource" or slot_type == "gold":
		if drag_type != "resource": return false
		var res_name = data.get("name", "")
		var target = accept if accept != "" else "金币"
		return res_name == target

	if slot_type == "item":
		if drag_type != "resource": return false
		var resource_type = data.get("resource_type", "")
		if resource_type == "":
			resource_type = "gold" if data.get("name", "") == "金币" else "intel"
		if accepts.is_empty():
			return resource_type != "gold"
		return accepts.has(resource_type)
	
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# 弹出旧卡
	if not current_card.is_empty():
		card_removed.emit(slot_index, current_card)
	
	var card = data.get("data", {}) if data is Dictionary and data.has("data") else (data if data is Dictionary else {})
	
	# 可堆叠资源：限制数量，多余退回
	if (slot_type == "gold" or slot_type == "resource" or slot_type == "item") and card.has("count") and card.get("count", 1) > max_cards:
		var excess = card.get("count", 1) - max_cards
		current_card = card.duplicate()
		current_card["count"] = max_cards
		var ex_data = card.duplicate()
		ex_data["count"] = excess
		resource_trimmed.emit(slot_index, ex_data)
	else:
		current_card = card
	
	_draw_card_preview()
	card_dropped.emit(slot_index, current_card)

func clear_card():
	current_card = {}
	_draw_empty()
