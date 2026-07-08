# CardBox.gd
# 令匣交互组件 — 点击令匣→打开动画→令牌飞出展示
# 作为 SorceressScene 的子组件使用

class_name CardBox
extends PanelContainer

signal box_clicked()

var _is_open: bool = false
var _card_display: PanelContainer = null
var _overlay: ColorRect = null

func _ready() -> void:
	# 令匣外观：深色木纹底+金色边框
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

	# 令匣中央文字
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)

	var icon_lbl = Label.new()
	icon_lbl.text = "📜"
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon_lbl)

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
	# 令匣打开动画：缩放脉冲+光效闪烁
	var t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	# 边框闪金光
	var sb = get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		var t2 = create_tween()
		t2.tween_property(sb, "border_color", Color("ffe080"), 0.15)
		t2.tween_property(sb, "border_color", Color("c8a84e"), 0.3)


func show_card_display(card_data: Dictionary, TN: Dictionary, RG: Dictionary, TC: Dictionary, SC: Dictionary, SC_BORDER: Dictionary) -> void:
	# 全屏半透明遮罩
	var root = get_parent().get_parent()  # SorceressScene
	var vs = root.get_viewport().get_visible_rect().size

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.size = vs
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 200
	root.add_child(_overlay)

	# 令牌大图展示（放大版摄政王令卡）
	_card_display = PanelContainer.new()
	_card_display.name = "CardDisplay"
	_card_display.custom_minimum_size = Vector2(210, 460)
	_card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_display.z_index = 210

	var rank = card_data.get("rank", "STONE")
	var card_type = card_data.get("type", "LUST")
	var bg_color = SC.get(rank, Color("2a2018"))
	var border_color = TC.get(card_type, Color("8b3a5c"))
	var rank_border = SC_BORDER.get(rank, Color("8a6820"))

	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color; sb.set_corner_radius_all(14)
	sb.border_width_bottom = 4; sb.border_width_top = 4
	sb.border_width_left = 4; sb.border_width_right = 4
	sb.border_color = border_color
	sb.shadow_size = 16; sb.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.4)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	_card_display.add_theme_stylebox_override("panel", sb)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_display.add_child(vb)

	# 类型名（大字）
	var type_lbl = Label.new()
	type_lbl.text = TN.get(card_type, "?")
	type_lbl.add_theme_font_size_override("font_size", 36)
	type_lbl.add_theme_color_override("font_color", border_color)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(type_lbl)

	# 品级星
	var rank_lbl = Label.new()
	rank_lbl.text = RG.get(rank, "★")
	rank_lbl.add_theme_font_size_override("font_size", 20)
	rank_lbl.add_theme_color_override("font_color", Color("c8a84e"))
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(rank_lbl)

	# 令牌全名
	var name_lbl = Label.new()
	name_lbl.text = card_data.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color("ffe080"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = card_data.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color("f0e6c8"))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(desc_lbl)

	# flavor
	var flavor_lbl = Label.new()
	flavor_lbl.text = card_data.get("flavor", "")
	flavor_lbl.add_theme_font_size_override("font_size", 12)
	flavor_lbl.add_theme_color_override("font_color", Color("a09070"))
	flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(flavor_lbl)

	# 7天倒计时
	var days_lbl = Label.new()
	days_lbl.text = "7日内必须完成"
	days_lbl.add_theme_font_size_override("font_size", 14)
	days_lbl.add_theme_color_override("font_color", Color("ff6040"))
	days_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	days_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(days_lbl)

	root.add_child(_card_display)

	# 居中定位
	_card_display.position = Vector2((vs.x - 210) / 2, (vs.y - 460) / 2)

	# 飞出动画：从令匣位置飞到居中
	var box_global = global_position + Vector2(custom_minimum_size.x / 2, custom_minimum_size.y / 2)
	var card_target = _card_display.position + Vector2(105, 230)
	_card_display.position = box_global - Vector2(105, 230)
	_card_display.scale = Vector2(0.1, 0.1)
	_card_display.modulate = Color(1, 1, 1, 0)

	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_card_display, "position", card_target, 0.5)
	t.parallel().tween_property(_card_display, "scale", Vector2(1.0, 1.0), 0.5)
	t.parallel().tween_property(_card_display, "modulate", Color.WHITE, 0.3)


func hide_card_display() -> void:
	if _card_display and is_instance_valid(_card_display):
		# 消失动画
		var t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		t.tween_property(_card_display, "modulate", Color(1, 1, 1, 0), 0.3)
		t.parallel().tween_property(_card_display, "scale", Vector2(0.3, 0.3), 0.3)
		t.tween_callback(func():
			_card_display.queue_free()
			_card_display = null
		)
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null


func reset_box() -> void:
	_is_open = false
	hide_card_display()
