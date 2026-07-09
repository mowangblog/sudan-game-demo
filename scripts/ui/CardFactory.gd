# CardFactory.gd
# 卡牌工厂 — 创建角色卡/摄政王令/资源卡
# 从 MainScene 提取，依赖 C/SC 等常量通过 set_constants 注入

class_name CardFactory
extends RefCounted

const GOLD_CARD_BG = preload("res://assets/images/cards/gold_card_bg.png")

# 注入的常量和回调
var C: Dictionary = {}
var SC: Dictionary = {}; var SC_BORDER: Dictionary = {}; var SC_HOVER: Dictionary = {}; var SC_GLOW: Dictionary = {}
var CHAR_QUALITY: Dictionary = {}
var AI: Dictionary = {}  # 属性emoji
var _on_click_char: Callable  # 点击角色卡回调

func setup(constants: Dictionary, on_click_char: Callable) -> void:
	C = constants.get("C", {})
	SC = constants.get("SC", {})
	SC_BORDER = constants.get("SC_BORDER", {})
	SC_HOVER = constants.get("SC_HOVER", {})
	SC_GLOW = constants.get("SC_GLOW", {})
	CHAR_QUALITY = constants.get("CHAR_QUALITY", {})
	AI = constants.get("AI", {})
	_on_click_char = on_click_char

func make_char_card(d: Dictionary) -> PanelContainer:
	var card = preload("res://scripts/ui/DraggableCard.gd").new()
	card.custom_minimum_size = Vector2(70, 152); card.mouse_filter = Control.MOUSE_FILTER_STOP
	var quality = CHAR_QUALITY.get(d.get("id", ""), "STONE")
	var bg = SC.get(quality, Color("2a2018"))
	var q_stars = {"STONE": "★", "BRONZE": "★★", "SILVER": "★★★", "GOLD": "★★★★"}
	var q_border = SC_BORDER.get(quality, C.get("GOLD_LO", Color("8a6820")))
	
	var sb = StyleBoxFlat.new(); sb.bg_color = bg; sb.set_corner_radius_all(10)
	sb.border_width_bottom = 2; sb.border_width_top = 2; sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_color = q_border; sb.content_margin_left = 4; sb.content_margin_right = 4
	sb.content_margin_top = 4; sb.content_margin_bottom = 4; sb.shadow_size = 4; sb.shadow_color = C.get("SHADOW", Color("00000099"))
	card.add_theme_stylebox_override("panel", sb)

	var vb = VBoxContainer.new(); vb.name = "VB"; vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER; card.add_child(vb)

	var nl = Label.new(); nl.text = d.get("name", "?"); nl.add_theme_font_size_override("font_size", 13)
	nl.add_theme_color_override("font_color", C.get("TEXT", Color("f0e6c8")))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(nl)

	var ql = Label.new(); ql.text = q_stars.get(quality, "★")
	ql.add_theme_font_size_override("font_size", 13); ql.add_theme_color_override("font_color", C.get("GOLD", Color("c8a84e")))
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(ql)

	var attrs = d.get("attributes", {})
	var best = ""; var best_v = 0
	for k in attrs:
		if attrs[k] > best_v: best_v = attrs[k]; best = k
	var bl = Label.new()
	bl.text = "%s %d" % [AI.get(best, best), best_v]
	bl.add_theme_font_size_override("font_size", 10)
	bl.add_theme_color_override("font_color", C.get("GOLD", Color("c8a84e")))
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(bl)

	card.set_meta("drag_data", {"type": "character", "id": d.get("id", ""), "name": d.get("name", ""), "data": d})

	card._on_hover_style = func(hovered: bool):
		var nsb = StyleBoxFlat.new(); nsb.bg_color = bg
		var q_glow = SC_GLOW.get(quality, Color("c8a84e80"))
		var q_hover = SC_HOVER.get(quality, q_border)
		nsb.set_corner_radius_all(10)
		nsb.border_width_bottom = 2; nsb.border_width_top = 2; nsb.border_width_left = 2; nsb.border_width_right = 2
		nsb.content_margin_left = 4; nsb.content_margin_right = 4; nsb.content_margin_top = 4; nsb.content_margin_bottom = 4
		if hovered:
			nsb.border_color = q_hover; nsb.shadow_size = 12; nsb.shadow_color = q_glow
		else:
			nsb.border_color = q_border; nsb.shadow_size = 4; nsb.shadow_color = C.get("SHADOW", Color("00000099"))
		card.add_theme_stylebox_override("panel", nsb)

	card._on_click = func():
		_on_click_char.call(d)

	return card

func make_sultan_card() -> PanelContainer:
	var card = preload("res://scripts/ui/DraggableCard.gd").new()
	card.name = "SC"; card.custom_minimum_size = Vector2(70, 152); card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb = StyleBoxFlat.new(); sb.bg_color = Color("2a2018"); sb.set_corner_radius_all(10)
	sb.border_width_bottom = 2; sb.border_width_top = 2; sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_color = C.get("GOLD_LO", Color("8a6820"))
	sb.content_margin_left = 4; sb.content_margin_right = 4; sb.content_margin_top = 4; sb.content_margin_bottom = 4
	sb.shadow_size = 4; sb.shadow_color = C.get("SHADOW", Color("00000099"))
	card.add_theme_stylebox_override("panel", sb)

	var vb = VBoxContainer.new(); vb.name = "VB"; vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER; card.add_child(vb)

	var tl = Label.new(); tl.name = "TypeLbl"; tl.text = "欢愉"
	tl.add_theme_font_size_override("font_size", 20); tl.add_theme_color_override("font_color", C.get("GOLD", Color("c8a84e")))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tl)

	var rl = Label.new(); rl.name = "RankLbl"; rl.text = "★"
	rl.add_theme_font_size_override("font_size", 13); rl.add_theme_color_override("font_color", C.get("GOLD", Color("c8a84e")))
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(rl)

	var dl = Label.new(); dl.name = "DaysLbl"; dl.text = "7天"
	dl.add_theme_font_size_override("font_size", 12); dl.add_theme_color_override("font_color", C.get("DIM", Color("a09070")))
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(dl)

	card.visible = false
	return card

func make_resource_card(name_str: String, icon: String, quality: String, count: int) -> PanelContainer:
	var card = preload("res://scripts/ui/DraggableCard.gd").new()
	card.name = "Res_" + name_str; card.custom_minimum_size = Vector2(70, 152); card.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg = SC.get(quality, Color("2a2018"))
	var q_border = SC_BORDER.get(quality, C.get("GOLD_LO", Color("8a6820")))
	if quality == "GOLD":
		var gold_panel = StyleBoxEmpty.new()
		card.add_theme_stylebox_override("panel", gold_panel)
		_add_texture_background(card, GOLD_CARD_BG)
		_add_gold_resource_text(card, name_str, count)
	else:
		var sb = StyleBoxFlat.new(); sb.bg_color = bg; sb.set_corner_radius_all(10)
		sb.border_width_bottom = 2; sb.border_width_top = 2; sb.border_width_left = 2; sb.border_width_right = 2
		sb.border_color = q_border; sb.content_margin_left = 4; sb.content_margin_right = 4
		sb.content_margin_top = 4; sb.content_margin_bottom = 4; sb.shadow_size = 4; sb.shadow_color = C.get("SHADOW", Color("00000099"))
		card.add_theme_stylebox_override("panel", sb)

	if quality != "GOLD":
		var vb = VBoxContainer.new(); vb.name = "VB"; vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.alignment = BoxContainer.ALIGNMENT_CENTER; card.add_child(vb)

		var icon_lbl = Label.new(); icon_lbl.text = icon; icon_lbl.add_theme_font_size_override("font_size", 32)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(icon_lbl)
		var nl = Label.new(); nl.text = name_str; nl.add_theme_font_size_override("font_size", 13)
		nl.add_theme_color_override("font_color", C.get("TEXT", Color("f0e6c8")))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(nl)
		var ql = Label.new(); ql.text = {"STONE": "★", "BRONZE": "★★", "SILVER": "★★★", "GOLD": "★★★★"}.get(quality, "★")
		ql.add_theme_font_size_override("font_size", 13); ql.add_theme_color_override("font_color", C.get("GOLD", Color("c8a84e")))
		ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(ql)
		var cnt_lbl = Label.new(); cnt_lbl.name = "CountLbl"; cnt_lbl.text = ("x%d" % count) if count > 1 else ""
		cnt_lbl.add_theme_font_size_override("font_size", 12); cnt_lbl.add_theme_color_override("font_color", C.get("GOLD_HI", Color("e8d48b")))
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(cnt_lbl)

	var resource_type = "gold" if name_str == "金币" else "intel"
	var res_data = {"type": "resource", "resource_type": resource_type, "id": name_str, "name": name_str, "quality": quality, "count": count, "icon": icon}
	card.set_meta("drag_data", res_data)
	card.set_meta("res_type", name_str)
	card.set_meta("res_count", count)
	card.set_meta("res_data", res_data)

	card._on_hover_style = func(hovered: bool):
		if quality == "GOLD":
			return
		var nsb = StyleBoxFlat.new(); nsb.bg_color = bg; nsb.set_corner_radius_all(10)
		nsb.border_width_bottom = 2; nsb.border_width_top = 2; nsb.border_width_left = 2; nsb.border_width_right = 2
		nsb.content_margin_left = 4; nsb.content_margin_right = 4; nsb.content_margin_top = 4; nsb.content_margin_bottom = 4
		if hovered:
			nsb.border_color = q_border; nsb.shadow_size = 12; nsb.shadow_color = SC_GLOW.get(quality, Color("c8a84e80"))
		else:
			nsb.border_color = q_border.darkened(0.3); nsb.shadow_size = 4; nsb.shadow_color = C.get("SHADOW", Color("00000099"))
		card.add_theme_stylebox_override("panel", nsb)

	return card


func _add_texture_background(card: PanelContainer, texture: Texture2D) -> void:
	var tex = TextureRect.new()
	tex.name = "CardTextureBg"
	tex.texture = texture
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 0
	tex.offset_top = 0
	tex.offset_right = 0
	tex.offset_bottom = 0
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tex)


func _add_gold_resource_text(card: PanelContainer, title: String, count: int) -> void:
	var overlay = Control.new()
	overlay.name = "GoldTextOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	card.add_child(overlay)

	var title_lbl = Label.new()
	title_lbl.name = "GoldTitleLbl"
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color("0b0702"))
	title_lbl.add_theme_constant_override("outline_size", 1)
	title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	title_lbl.add_theme_constant_override("shadow_offset_y", 1)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_lbl.offset_left = 6
	title_lbl.offset_right = -6
	title_lbl.offset_top = 5
	title_lbl.offset_bottom = 34
	overlay.add_child(title_lbl)

	var count_lbl = Label.new()
	count_lbl.name = "CountLbl"
	count_lbl.text = ("x%d" % count) if count > 1 else ""
	count_lbl.add_theme_font_size_override("font_size", 22)
	count_lbl.add_theme_color_override("font_color", Color("fff3cf"))
	count_lbl.add_theme_color_override("font_outline_color", Color("050300"))
	count_lbl.add_theme_color_override("font_shadow_color", Color("050300"))
	count_lbl.add_theme_constant_override("outline_size", 3)
	count_lbl.add_theme_constant_override("shadow_offset_x", 2)
	count_lbl.add_theme_constant_override("shadow_offset_y", 2)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	count_lbl.offset_left = 12
	count_lbl.offset_right = -12
	count_lbl.offset_top = -38
	count_lbl.offset_bottom = -4
	overlay.add_child(count_lbl)


func make_book_card(book_data: Dictionary) -> PanelContainer:
	var card = preload("res://scripts/ui/DraggableCard.gd").new()
	card.name = "Book_" + book_data.get("id", "?"); card.custom_minimum_size = Vector2(70, 152); card.mouse_filter = Control.MOUSE_FILTER_STOP
	var quality = book_data.get("rank", "STONE")
	var bg = SC.get(quality, Color("2a2018"))
	var q_border = SC_BORDER.get(quality, C.get("GOLD_LO", Color("8a6820")))
	var sb = StyleBoxFlat.new(); sb.bg_color = bg; sb.set_corner_radius_all(10)
	sb.border_width_bottom = 2; sb.border_width_top = 2; sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_color = q_border; sb.content_margin_left = 4; sb.content_margin_right = 4
	sb.content_margin_top = 4; sb.content_margin_bottom = 4; sb.shadow_size = 4; sb.shadow_color = C.get("SHADOW", Color("00000099"))
	card.add_theme_stylebox_override("panel", sb)

	var vb = VBoxContainer.new(); vb.name = "VB"; vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER; card.add_child(vb)

	var icon_lbl = Label.new(); icon_lbl.text = "📖"; icon_lbl.add_theme_font_size_override("font_size", 32)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(icon_lbl)
	var nl = Label.new(); nl.text = book_data.get("name", "?"); nl.add_theme_font_size_override("font_size", 11)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(62, 0)
	nl.add_theme_color_override("font_color", C.get("TEXT", Color("f0e6c8")))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(nl)
	var ql = Label.new(); ql.text = {"STONE": "★", "BRONZE": "★★", "SILVER": "★★★", "GOLD": "★★★★"}.get(quality, "★")
	ql.add_theme_font_size_override("font_size", 13); ql.add_theme_color_override("font_color", C.get("GOLD", Color("c8a84e")))
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(ql)

	card.set_meta("drag_data", {"type": "book", "id": book_data.get("id", ""), "name": book_data.get("name", ""), "data": book_data, "rank": quality})

	card._on_hover_style = func(hovered: bool):
		var nsb = StyleBoxFlat.new(); nsb.bg_color = bg; nsb.set_corner_radius_all(10)
		nsb.border_width_bottom = 2; nsb.border_width_top = 2; nsb.border_width_left = 2; nsb.border_width_right = 2
		nsb.content_margin_left = 4; nsb.content_margin_right = 4; nsb.content_margin_top = 4; nsb.content_margin_bottom = 4
		if hovered:
			nsb.border_color = q_border; nsb.shadow_size = 12; nsb.shadow_color = SC_GLOW.get(quality, Color("c8a84e80"))
		else:
			nsb.border_color = q_border.darkened(0.3); nsb.shadow_size = 4; nsb.shadow_color = C.get("SHADOW", Color("00000099"))
		card.add_theme_stylebox_override("panel", nsb)

	return card
