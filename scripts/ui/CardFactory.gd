# CardFactory.gd
# 卡牌工厂 — 创建角色卡/摄政王令/资源卡
# 从 MainScene 提取，依赖 C/SC 等常量通过 set_constants 注入

class_name CardFactory
extends RefCounted

const GOLD_CARD_BG = preload("res://assets/images/cards/gold_card_bg.png")
const STONE_CARD_BG = preload("res://assets/images/cards/shi_resized.png")
const BRONZE_CARD_BG = preload("res://assets/images/cards/tong_resized.png")
const SILVER_CARD_BG = preload("res://assets/images/cards/ying_resized.png")
const GOLD_RARITY_CARD_BG = preload("res://assets/images/cards/jin_resized.png")
const PLAYER_PORTRAIT = preload("res://assets/images/characters/zhujue.png")
const CHAR_PORTRAITS = {
	"meji": preload("res://assets/images/characters/meji_resized.png"),
	"tietou": preload("res://assets/images/characters/tietou_resized.png"),
	"kuaijiao": preload("res://assets/images/characters/kuaijiao_resized.png"),
	"zhaqiyi": preload("res://assets/images/characters/zhaqiyi_resized.png"),
}
const SC_PORTRAIT = {
	"MURDER": preload("res://assets/images/characters/shalu.png"),
}
const CARD_TITLE_FONT = preload("res://assets/fonts/庞门正道粗书体.ttf")
const CARD_NUMBER_FONT = preload("res://assets/fonts/青柳隶书.ttf")
const CARD_SIZE := Vector2(100, 180)

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
	card.custom_minimum_size = CARD_SIZE; card.mouse_filter = Control.MOUSE_FILTER_STOP
	var quality = CHAR_QUALITY.get(d.get("id", ""), "STONE")
	var q_border = SC_BORDER.get(quality, C.get("GOLD_LO", Color("8a6820")))
	_apply_image_card_base(card, quality, q_border, false)

	var pid = d.get("id", "")
	var portrait: Texture2D = CHAR_PORTRAITS.get(pid, PLAYER_PORTRAIT if pid == "player" else null)
	if d.has("portrait") and str(d.get("portrait", "")) != "":
		portrait = load(str(d.get("portrait", "")))
	_add_card_face_content(card, d.get("name", "?"), "", "", portrait)

	card.set_meta("drag_data", {"type": "character", "id": d.get("id", ""), "name": d.get("name", ""), "data": d})

	card._on_hover_style = func(hovered: bool):
		var q_glow = SC_GLOW.get(quality, Color("c8a84e80"))
		var q_hover = SC_HOVER.get(quality, q_border)
		_apply_image_card_base(card, quality, q_hover if hovered else q_border, hovered, q_glow)

	card._on_click = func():
		_on_click_char.call(d)

	return card

func make_sultan_card() -> PanelContainer:
	var card = preload("res://scripts/ui/DraggableCard.gd").new()
	card.name = "SC"; card.custom_minimum_size = CARD_SIZE; card.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_image_card_base(card, "STONE", C.get("GOLD_LO", Color("8a6820")), false)
	_add_card_face_content(card, "欢愉", "7天", "", null)

	card.visible = false

	var q_border = C.get("GOLD_LO", Color("8a6820"))
	card._on_hover_style = func(hovered: bool):
		var q = card.get_meta("card_quality", "STONE")
		_apply_image_card_base(card, q, q_border, hovered, SC_GLOW.get(q, Color("c8a84e80")))

	return card

func make_resource_card(name_str: String, icon: String, quality: String, count: int) -> PanelContainer:
	var card = preload("res://scripts/ui/DraggableCard.gd").new()
	card.name = "Res_" + name_str; card.custom_minimum_size = CARD_SIZE; card.mouse_filter = Control.MOUSE_FILTER_STOP
	var q_border = SC_BORDER.get(quality, C.get("GOLD_LO", Color("8a6820")))
	var bg_override: Texture2D = GOLD_CARD_BG if name_str == "金币" else null
	_apply_image_card_base(card, quality, q_border, false, Color("c8a84e80"), bg_override)
	_add_card_face_content(card, name_str, ("x%d" % count) if count > 1 else "", "", null)

	var resource_type = "gold" if name_str == "金币" else "intel"
	var res_data = {"type": "resource", "resource_type": resource_type, "id": name_str, "name": name_str, "quality": quality, "count": count, "icon": icon}
	card.set_meta("drag_data", res_data)
	card.set_meta("res_type", name_str)
	card.set_meta("res_count", count)
	card.set_meta("res_data", res_data)

	card._on_hover_style = func(hovered: bool):
		_apply_image_card_base(card, quality, q_border, hovered, SC_GLOW.get(quality, Color("c8a84e80")), bg_override)

	return card


func _add_texture_background(card: PanelContainer, texture: Texture2D) -> void:
	var tex = card.get_node_or_null("CardTextureBg") as TextureRect
	if tex == null:
		tex = TextureRect.new()
		tex.name = "CardTextureBg"
		card.add_child(tex)
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
	var m = ShaderMaterial.new()
	m.shader = preload("res://shaders/round_corners.gdshader")
	tex.material = m
	card.move_child(tex, 0)


func _make_card_overlay(card: PanelContainer) -> Control:
	var overlay = Control.new()
	overlay.name = "CardTextOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	card.add_child(overlay)
	return overlay


func _add_card_face_content(card: PanelContainer, title: String, number_text: String = "", icon: String = "", portrait: Texture2D = null) -> void:
	var overlay = _make_card_overlay(card)

	var title_lbl = Label.new()
	title_lbl.name = "TitleLbl"
	title_lbl.text = title
	_apply_card_title_style(title_lbl, 17)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_lbl.offset_left = 6
	title_lbl.offset_right = -6
	title_lbl.offset_top = 5
	title_lbl.offset_bottom = 34
	overlay.add_child(title_lbl)

	if portrait != null:
		var portrait_rect = TextureRect.new()
		portrait_rect.name = "Portrait"
		portrait_rect.texture = portrait
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait_rect.offset_left = 0
		portrait_rect.offset_right = 0
		portrait_rect.offset_top = 36
		portrait_rect.offset_bottom = -30
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(portrait_rect)

	var count_lbl = Label.new()
	count_lbl.name = "CountLbl"
	count_lbl.text = number_text
	count_lbl.add_theme_font_override("font", CARD_NUMBER_FONT)
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


func _add_gold_resource_text(card: PanelContainer, title: String, count: int) -> void:
	_add_card_face_content(card, title, ("x%d" % count) if count > 1 else "", "", null)


func _apply_card_title_style(label: Label, font_size: int = 18) -> void:
	label.add_theme_font_override("font", CARD_TITLE_FONT)
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", Color("000000"))
	label.add_theme_color_override("font_shadow_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


func _card_background_for_quality(quality: String) -> Texture2D:
	match quality:
		"BRONZE", "COPPER":
			return BRONZE_CARD_BG
		"SILVER":
			return SILVER_CARD_BG
		"GOLD":
			return GOLD_RARITY_CARD_BG
		_:
			return STONE_CARD_BG


func _apply_image_card_base(card: PanelContainer, quality: String, border_color: Color, hovered: bool = false, glow_color: Color = Color("c8a84e80"), texture_override: Texture2D = null) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(10)
	sb.border_width_bottom = 0
	sb.border_width_top = 0
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_color = border_color
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	sb.shadow_size = 12 if hovered else 4
	sb.shadow_color = glow_color if hovered else C.get("SHADOW", Color("00000099"))
	card.add_theme_stylebox_override("panel", sb)
	_add_texture_background(card, texture_override if texture_override != null else _card_background_for_quality(quality))
	card.set_meta("card_quality", quality)
	var tex = card.get_node_or_null("CardTextureBg") as TextureRect
	if tex:
		tex.modulate = Color(1.12, 1.12, 1.08) if quality in ["BRONZE", "COPPER"] else Color.WHITE


func make_book_card(book_data: Dictionary) -> PanelContainer:
	var card = preload("res://scripts/ui/DraggableCard.gd").new()
	card.name = "Book_" + book_data.get("id", "?"); card.custom_minimum_size = CARD_SIZE; card.mouse_filter = Control.MOUSE_FILTER_STOP
	var quality = book_data.get("rank", "STONE")
	var q_border = SC_BORDER.get(quality, C.get("GOLD_LO", Color("8a6820")))
	_apply_image_card_base(card, quality, q_border, false)
	_add_card_face_content(card, book_data.get("name", "?"), "", "", null)

	card.set_meta("drag_data", {"type": "book", "id": book_data.get("id", ""), "name": book_data.get("name", ""), "data": book_data, "rank": quality})

	card._on_hover_style = func(hovered: bool):
		_apply_image_card_base(card, quality, q_border, hovered, SC_GLOW.get(quality, Color("c8a84e80")))

	return card
