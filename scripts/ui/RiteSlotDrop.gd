# RiteSlotDrop.gd
# 仪式卡槽 — 卡牌大小，支持替换/点击详情/右键移除/拖出

extends PanelContainer

signal card_dropped(slot_index: int, card_data: Dictionary)
signal card_removed(slot_index: int, card_data: Dictionary)
signal card_clicked(card_data: Dictionary)

@export var slot_index: int = 0
@export var slot_type: String = "character"
@export var required_tags: Array = []
@export var is_optional: bool = false

var current_card: Dictionary = {}

const C = {
	GOLD=Color("c8a84e"), GOLD_HI=Color("e8d48b"), GOLD_LO=Color("8a6820"),
	TEXT=Color("f0e6c8"), DIM=Color("a09070"),
}
const RANK_STARS = {"STONE":"★","BRONZE":"★★","SILVER":"★★★","GOLD":"★★★★"}
const ATTR_ICONS = {"phy":"💪","com":"⚔","sur":"🏕","soc":"💬","cha":"💋","ste":"🕶","wis":"📚","mag":"🔮"}
const RANK_BG = {"STONE":Color(0.15,0.13,0.11), "BRONZE":Color(0.13,0.16,0.10), "SILVER":Color(0.12,0.13,0.15), "GOLD":Color(0.16,0.14,0.08)}
const RANK_BORDER = {"STONE":Color(0.50,0.42,0.33), "BRONZE":Color(0.60,0.68,0.35), "SILVER":Color(0.62,0.66,0.70), "GOLD":Color(0.88,0.73,0.33)}
const CHAR_QUALITY = {"player":"SILVER","meji":"BRONZE","zhaqiyi":"BRONZE","tietou":"STONE","kuaijiao":"STONE"}

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(70, 152)
	size = Vector2(70, 152)
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
				if current_card.is_empty(): return
				var dist = (event.position - _press_pos).length()
				if dist < 6:  # 没拖动=点击
					card_clicked.emit(current_card)
				_pressing = false

func _get_drag_data(at_position: Vector2) -> Variant:
	if current_card.is_empty():
		return null
	var data = {"type": slot_type, "data": current_card, "name": current_card.get("name","")}
	# 不在这里 emit card_removed，等 NOTIFICATION_DRAG_END 再触发
	
	# 创建跟卡牌一样的拖拽预览（原卡牌大小）
	var prev = PanelContainer.new()
	prev.custom_minimum_size = Vector2(70, 152)
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
		var l1 = Label.new(); l1.text={"LUST":"纵欲","LUXURY":"奢靡","CONQUEST":"征服","MURDER":"杀戮"}.get(current_card.get("type",""),"?")
		l1.add_theme_font_size_override("font_size",20); l1.add_theme_color_override("font_color",C.GOLD)
		l1.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(l1)
		var l2 = Label.new(); l2.text=RANK_STARS.get(current_card.get("rank",""),"★")
		l2.add_theme_font_size_override("font_size",13); l2.add_theme_color_override("font_color",C.GOLD)
		l2.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(l2)
	else:
		var q = CHAR_QUALITY.get(current_card.get("id",""), "STONE")
		sb.bg_color = RANK_BG.get(q, Color("2a2018"))
		sb.border_color = RANK_BORDER.get(q, C.GOLD_LO)
		prev.add_theme_stylebox_override("panel", sb)
		var l1 = Label.new(); l1.text=current_card.get("name","?")
		l1.add_theme_font_size_override("font_size",13); l1.add_theme_color_override("font_color",C.TEXT)
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
	icon.text = "🃏" if slot_type == "sultan_card" else "👤"
	icon.add_theme_font_size_override("font_size", 30 if slot_type == "sultan_card" else 28)
	icon.add_theme_color_override("font_color", Color("605040"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(icon)
	var hint = Label.new(); hint.text = "拖入\n卡牌"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("504030"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(hint)

func _draw_card_preview():
	for c in get_children():
		c.queue_free()
	if current_card.is_empty(): _draw_empty(); return
	
	var vb = VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER; add_child(vb)
	
	if slot_type == "sultan_card":
		var label = Label.new()
		label.text = {"LUST":"纵欲","LUXURY":"奢靡","CONQUEST":"征服","MURDER":"杀戮"}.get(current_card.get("type",""), "?")
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", C.GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(label)
		var star = Label.new()
		star.text = RANK_STARS.get(current_card.get("rank",""),"★")
		star.add_theme_font_size_override("font_size", 13); star.add_theme_color_override("font_color", C.GOLD)
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(star)
		var nl = Label.new(); nl.text = current_card.get("name", "?")
		nl.add_theme_font_size_override("font_size", 12); nl.add_theme_color_override("font_color", C.TEXT)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(nl)
		var days = Label.new(); days.text = "右键拖出"
		days.add_theme_font_size_override("font_size", 9); days.add_theme_color_override("font_color", C.DIM)
		days.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(days)
		var tc = {"LUST":Color("8b3a5c"),"LUXURY":Color("3a5c8b"),"CONQUEST":Color("3a5b3a"),"MURDER":Color("6b2a2a")}.get(current_card.get("type",""), Color("6b2a2a"))
		var s_bg = RANK_BG.get(current_card.get("rank",""), Color("2a2018"))
		var sb = StyleBoxFlat.new(); sb.bg_color = s_bg; sb.set_corner_radius_all(10)
		sb.border_width_bottom=2; sb.border_width_top=2; sb.border_width_left=2; sb.border_width_right=2
		sb.border_color = tc.darkened(0.3); sb.content_margin_left=4; sb.content_margin_right=4
		sb.content_margin_top=4; sb.content_margin_bottom=4; sb.shadow_size=6; sb.shadow_color=Color("00000066")
		add_theme_stylebox_override("panel", sb)
	else:
		var nl = Label.new(); nl.text = current_card.get("name", "?")
		nl.add_theme_font_size_override("font_size", 13); nl.add_theme_color_override("font_color", C.TEXT)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(nl)
		# 品质星级
		var quality = CHAR_QUALITY.get(current_card.get("id",""), "STONE")
		var qs = RANK_STARS.get(quality, "★")
		var ql = Label.new(); ql.text = qs
		ql.add_theme_font_size_override("font_size", 13); ql.add_theme_color_override("font_color", C.GOLD)
		ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(ql)
		var attrs = current_card.get("attributes", {})
		var best=""; var best_v=0
		for k in attrs:
			if attrs[k]>best_v: best_v=attrs[k]; best=k
		var tl = Label.new(); tl.text = "%s %d" % [ATTR_ICONS.get(best, best), best_v]
		tl.add_theme_font_size_override("font_size", 10); tl.add_theme_color_override("font_color", C.GOLD)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(tl)
		var hint = Label.new(); hint.text = "右键拖出"
		hint.add_theme_font_size_override("font_size", 9); hint.add_theme_color_override("font_color", C.DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(hint)
		var c_bg = RANK_BG.get(quality, Color("2a2018"))
		var sb2 = StyleBoxFlat.new(); sb2.bg_color = c_bg; sb2.set_corner_radius_all(10)
		sb2.border_width_bottom=2; sb2.border_width_top=2; sb2.border_width_left=2; sb2.border_width_right=2
		sb2.border_color = C.GOLD_HI; sb2.content_margin_left=4; sb2.content_margin_right=4
		sb2.content_margin_top=4; sb2.content_margin_bottom=4; sb2.shadow_size=6; sb2.shadow_color=Color("00000066")
		add_theme_stylebox_override("panel", sb2)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary: return false
	
	var drag_type = data.get("type", "")
	if slot_type == "character" and drag_type != "character": return false
	if slot_type == "sultan_card" and drag_type != "sultan_card": return false
	
	if slot_type == "sultan_card" and data.has("data"):
		var cd = data.get("data", {})
		for tag in required_tags:
			if tag in ["LUST","LUXURY","CONQUEST","MURDER"] and tag != cd.get("type",""): return false
			if tag in ["STONE","BRONZE","SILVER","GOLD"] and tag != cd.get("rank",""): return false
	
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# 替换已有卡牌
	if not current_card.is_empty():
		card_removed.emit(slot_index, current_card)
	current_card = data.get("data", {}) if data is Dictionary and data.has("data") else (data if data is Dictionary else {})
	_draw_card_preview()
	card_dropped.emit(slot_index, current_card)

func clear_card():
	current_card = {}
	_draw_empty()
