# CardBox.gd
# 令匣交互组件 — 点击→脉冲动画→令牌展示（简单居中淡入）

class_name CardBox
extends PanelContainer

signal box_clicked()

var _is_open: bool = false
var _card_display: PanelContainer = null
var _overlay: ColorRect = null

func _ready() -> void:
	custom_minimum_size = Vector2(120, 80)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("1a1008")
	sb.set_corner_radius_all(12)
	sb.border_width_bottom = 4; sb.border_width_top = 4
	sb.border_width_left = 4; sb.border_width_right = 4
	sb.border_color = Color("c8a84e")
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.shadow_size = 8; sb.shadow_color = Color("c8a84e60")
	add_theme_stylebox_override("panel", sb)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)

	var icon_tex = TextureRect.new()
	icon_tex.name = "BoxIcon"
	icon_tex.texture = preload("res://assets/images/ui/box_icon.png")
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.custom_minimum_size = Vector2(40, 26)
	icon_tex.size = Vector2(40, 26)
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon_tex)

	var hint_lbl = Label.new()
	hint_lbl.text = "令匣"
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color("c8a84e"))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hint_lbl)

	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not _is_open:
				accept_event()
				box_clicked.emit()


func play_open_animation() -> void:
	_is_open = true
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	# 边框闪金光
	var sb = get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		var sc = sb.border_color
		var t2 = create_tween()
		t2.tween_property(sb, "border_color", Color("ffe080"), 0.1)
		t2.tween_property(sb, "border_color", sc, 0.15)


func show_card_display(card_data: Dictionary, TN: Dictionary, RG: Dictionary, TC: Dictionary, SC: Dictionary, SC_BORDER: Dictionary) -> void:
	var root = get_parent().get_parent()  # SorceressScene

	# 覆盖层（SorceressScene面板内部居中展示，不飞出屏幕）
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_overlay)

	# 令牌展示卡 — 固定尺寸，居中
	_card_display = PanelContainer.new()
	_card_display.name = "CardDisplay"
	_card_display.custom_minimum_size = Vector2(200, 300)
	_card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rank = card_data.get("rank", "STONE")
	var card_type = card_data.get("type", "LUST")
	var bg_color = SC.get(rank, Color("2a2018"))
	var border_color = TC.get(card_type, Color("8b3a5c"))

	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color; sb.set_corner_radius_all(12)
	sb.border_width_bottom = 4; sb.border_width_top = 4
	sb.border_width_left = 4; sb.border_width_right = 4
	sb.border_color = border_color
	sb.shadow_size = 12; sb.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.3)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	_card_display.add_theme_stylebox_override("panel", sb)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_display.add_child(vb)

	var type_lbl = Label.new()
	type_lbl.text = TN.get(card_type, "?")
	type_lbl.add_theme_font_size_override("font_size", 30)
	type_lbl.add_theme_color_override("font_color", border_color)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(type_lbl)

	var rank_lbl = Label.new()
	rank_lbl.text = RG.get(rank, "★")
	rank_lbl.add_theme_font_size_override("font_size", 18)
	rank_lbl.add_theme_color_override("font_color", Color("c8a84e"))
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rank_lbl)

	var name_lbl = Label.new()
	name_lbl.text = card_data.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color("ffe080"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = card_data.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color("f0e6c8"))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(desc_lbl)

	var days_lbl = Label.new()
	days_lbl.text = "7日内必须完成"
	days_lbl.add_theme_font_size_override("font_size", 13)
	days_lbl.add_theme_color_override("font_color", Color("ff6040"))
	days_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(days_lbl)

	# 居中附加到 overlay 上
	_card_display.anchor_left = 0.5; _card_display.anchor_right = 0.5
	_card_display.anchor_top = 0.5; _card_display.anchor_bottom = 0.5
	_card_display.offset_left = -100; _card_display.offset_right = 100
	_card_display.offset_top = -150; _card_display.offset_bottom = 150
	_overlay.add_child(_card_display)

	# 简单淡入
	_card_display.modulate = Color(1, 1, 1, 0)
	var t = create_tween()
	t.tween_property(_card_display, "modulate", Color.WHITE, 0.3)


func hide_card_display() -> void:
	if _card_display and is_instance_valid(_card_display):
		_card_display.queue_free()
		_card_display = null
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null


func reset_box() -> void:
	_is_open = false
	hide_card_display()
