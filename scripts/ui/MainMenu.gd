# MainMenu.gd — 摄政王的游戏 主菜单

extends Control

const C = {
	BG=Color("1a0f0a"), GOLD=Color("c8a84e"), GOLD_HI=Color("e8d48b"), GOLD_LO=Color("8a6820"),
	TEXT=Color("f0e6c8"), DIM=Color("a09070"), LUST=Color("8b3a5c"),
}

func _ready():
	# 根节点填满窗口
	anchor_left = 0; anchor_right = 1; anchor_top = 0; anchor_bottom = 1
	_center_on_resize()
	resized.connect(_center_on_resize)
	_build()

func _center_on_resize():
	# 拿到 VBoxContainer 并重新居中
	var cv = get_node_or_null("MenuVBox")
	if cv:
		var vs = get_viewport().size
		cv.position = Vector2((vs.x - cv.size.x) / 2, (vs.y - cv.size.y) / 2)

func _build():
	# 背景满屏
	var bg = ColorRect.new(); bg.color = C.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 装饰线 满宽
	var line = ColorRect.new(); line.color = C.GOLD
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); line.offset_top = 100; line.offset_bottom = 102
	add_child(line)
	
	var cv = VBoxContainer.new()
	cv.name = "MenuVBox"
	cv.add_theme_constant_override("separation", 6)
	add_child(cv)
	
	# 标题
	var title = Label.new(); title.text = "🕌 摄政王的游戏"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", C.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(title)
	
	var sub = Label.new(); sub.text = "Sultan's Game"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", C.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(sub)
	
	var sp1 = Control.new(); sp1.custom_minimum_size = Vector2(0, 30); cv.add_child(sp1)
	
	# 按钮
	var btns = [
		{"t":"🎮  开始新游戏", "f":_start_new_game, "c":C.GOLD},
		{"t":"📂  继续游戏",   "f":_continue_game, "c":C.DIM},
		{"t":"⚙  设置",       "f":_show_settings, "c":C.DIM},
		{"t":"🚪  退出",       "f":_quit,          "c":Color("aa5050")},
	]
	
	for bd in btns:
		var btn = Button.new()
		btn.text = bd.t
		btn.custom_minimum_size = Vector2(240, 48)
		btn.add_theme_font_size_override("font_size", 16)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color("2a1c0a"); sb.set_corner_radius_all(8)
		sb.border_width_bottom=2; sb.border_width_top=2
		sb.border_width_left=2; sb.border_width_right=2; sb.border_color = C.GOLD_LO
		sb.content_margin_left=16; sb.content_margin_right=16
		btn.add_theme_stylebox_override("normal", sb)
		var sh = StyleBoxFlat.new(); sh.set_corner_radius_all(8)
		sh.bg_color = Color("3a2c0a"); sh.border_width_bottom=2; sh.border_width_top=2
		sh.border_width_left=2; sh.border_width_right=2; sh.border_color = C.GOLD_HI
		sh.content_margin_left=16; sh.content_margin_right=16
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_color_override("font_color", bd.c)
		btn.add_theme_color_override("font_hover_color", C.GOLD_HI)
		btn.pressed.connect(bd.f)
		cv.add_child(btn)
	
	# 底部版本
	var sp2 = Control.new(); sp2.custom_minimum_size = Vector2(0, 20); cv.add_child(sp2)
	var ver = Label.new(); ver.text = "v0.1"
	ver.add_theme_font_size_override("font_size", 10)
	ver.add_theme_color_override("font_color", Color("5a4a3a"))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(ver)
	
	# 初始居中
	call_deferred("_center_on_resize")

func _start_new_game():
	get_tree().change_scene_to_file("res://scenes/ui/MainScene.tscn")

func _continue_game():
	get_tree().change_scene_to_file("res://scenes/ui/MainScene.tscn")

func _show_settings():
	print("[Menu] Settings not implemented yet")

func _quit():
	get_tree().quit()
