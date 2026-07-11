# MainMenu.gd — 摄政王的游戏 主菜单

extends Control

const C = {
	BG=Color("1a0f0a"), GOLD=Color("c8a84e"), GOLD_HI=Color("e8d48b"), GOLD_LO=Color("8a6820"),
	TEXT=Color("f0e6c8"), DIM=Color("a09070"), LUST=Color("8b3a5c"),
}

const MENU_TOP = 90   # 菜单整体距屏幕顶部的偏移（即 logo 下移量），想再往下就调大这个值
const SEP_LOGO = -90  # logo ↔ 第一个按钮间距（负=按钮上移贴近/叠到 logo 底部，想更近就调更小）

func _ready():
	# 根节点填满窗口
	anchor_left = 0; anchor_right = 1; anchor_top = 0; anchor_bottom = 1
	_center_on_resize()
	resized.connect(_center_on_resize)
	_build()

func _center_on_resize():
	var vs = get_viewport().size
	# 背景铺满
	var bg = get_node_or_null("BG")
	if bg: bg.size = vs
	# MenuVBox 水平居中、垂直至少距顶部 MENU_TOP
	# （不再强制垂直居中：菜单总高接近视口时会把 logo 顶到上边缘，导致“下移”被抵消）
	var cv = get_node_or_null("MenuVBox")
	if cv:
		# MENU_TOP 直接作为 logo 距顶部偏移；只有菜单总高 + MENU_TOP 超过视口（会被裁切）时才回退到垂直居中
		var top = MENU_TOP
		if cv.size.y + MENU_TOP > vs.y:
			top = (vs.y - cv.size.y) / 2
		cv.position = Vector2((vs.x - cv.size.x) / 2, top)

func _build():
	# 背景图直接按窗口尺寸
	var vs = get_viewport().size
	var bg = TextureRect.new()
	bg.name = "BG"
	bg.texture = preload("res://assets/images/ui/main_menu_bg.png")
	bg.size = vs
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(bg)
	
	var cv = VBoxContainer.new()
	cv.name = "MenuVBox"
	cv.add_theme_constant_override("separation", SEP_LOGO)   # 控制 logo ↔ 按钮组（按钮之间的间距见 btnbox）
	add_child(cv)
	
	# 标题（logo 图片）
	var logo = TextureRect.new()
	logo.name = "Logo"
	logo.texture = preload("res://assets/images/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(360, 360)   # 原图 655x655(1:1)，按原比例放大显示
	logo.size = Vector2(360, 360)
	cv.add_child(logo)
	
	# 按钮组：独立容器，按钮之间间距固定 -20（你的设定），与 logo↔按钮 互不影响
	var btnbox = VBoxContainer.new()
	btnbox.add_theme_constant_override("separation", -20)
	cv.add_child(btnbox)
	
	# 按钮（全部为图片素材）
	var btns = [
		{"n":"StartBtn",    "f":_start_new_game, "img":preload("res://assets/images/ui/start_btn.png")},
		{"n":"ContinueBtn", "f":_continue_game,  "img":preload("res://assets/images/ui/jixu_btn.png")},
		{"n":"SettingsBtn", "f":_show_settings,  "img":preload("res://assets/images/ui/shezhi_btn.png")},
		{"n":"QuitBtn",     "f":_quit,           "img":preload("res://assets/images/ui/tuichu_btn.png")},
	]

	for bd in btns:
		var sbtn = TextureButton.new()
		sbtn.name = bd.n
		sbtn.texture_normal = bd.img
		sbtn.ignore_texture_size = true
		sbtn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		sbtn.custom_minimum_size = Vector2(200, 120)   # 原图 358x200(≈1.79:1)，缩小一点
		sbtn.size = Vector2(200, 120)
		sbtn.pressed.connect(bd.f)
		sbtn.mouse_entered.connect(func(): sbtn.modulate = Color(1.15, 1.15, 1.15))
		sbtn.mouse_exited.connect(func(): sbtn.modulate = Color.WHITE)
		btnbox.add_child(sbtn)
	
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
