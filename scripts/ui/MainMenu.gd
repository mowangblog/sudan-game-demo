# MainMenu.gd — 摄政王的游戏 主菜单

extends Control

const C = {
	BG=Color("1a0f0a"), GOLD=Color("c8a84e"), GOLD_HI=Color("e8d48b"), GOLD_LO=Color("8a6820"),
	TEXT=Color("f0e6c8"), DIM=Color("a09070"), LUST=Color("8b3a5c"),
}

const MENU_TOP = 90   # 菜单整体距屏幕顶部的偏移（即 logo 下移量），想再往下就调大这个值
const SEP_LOGO = -90  # logo ↔ 第一个按钮间距（负=按钮上移贴近/叠到 logo 底部，想更近就调更小）

# 统一弹窗背景：九宫格图（与摄政王令/角色/资源/结算弹窗一致）
const POPUP_BG = preload("res://assets/images/ui/tanchuang_bg_jiugongge.png")
const POPUP_BG_MARGIN := 80   # 九宫格四角固定边宽（像素）

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
	var dim = get_node_or_null("BGDim")
	if dim: dim.size = vs
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
	
	# 背景蒙层：半透明深色，覆盖在背景图之上、菜单之下，让主菜单背景暗淡一点
	var dim = ColorRect.new()
	dim.name = "BGDim"
	dim.color = Color(0, 0, 0, 0.35)   # alpha 0.35 = 暗淡一点（想更暗就调大，如 0.5）
	dim.size = vs
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	
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

	# BGM：主菜单背景音乐（循环，淡入）。BGM 为 AutoLoad 单例，进游戏时自动交叉淡出到游戏 BGM。
	BGM.play(load("res://assets/bgm/menu.ogg"))

func _start_new_game():
	get_tree().change_scene_to_file("res://scenes/ui/MainScene.tscn")

func _continue_game():
	get_tree().change_scene_to_file("res://scenes/ui/MainScene.tscn")

# 统一的弹窗背景：九宫格图 tanchuang_bg_jiugongge.png（3x3 缩放，整图完整展示、四角不拉伸）
func _popup_bg_stylebox() -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = POPUP_BG
	sb.region_rect = Rect2(0, 0, 614, 410)
	sb.texture_margin_left = POPUP_BG_MARGIN
	sb.texture_margin_top = POPUP_BG_MARGIN
	sb.texture_margin_right = POPUP_BG_MARGIN
	sb.texture_margin_bottom = POPUP_BG_MARGIN
	sb.content_margin_left = POPUP_BG_MARGIN
	sb.content_margin_right = POPUP_BG_MARGIN
	sb.content_margin_top = POPUP_BG_MARGIN
	sb.content_margin_bottom = POPUP_BG_MARGIN
	return sb

func _show_settings():
	if get_node_or_null("SettingsOverlay"):
		return
	# 全屏蒙层（点击空白关闭）
	var ov = Control.new()
	ov.name = "SettingsOverlay"
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var back = ColorRect.new()
	back.color = Color(0, 0, 0, 0.5)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			ov.queue_free()
	)
	ov.add_child(back)

	# 设置弹窗：复用项目统一的九宫格弹窗背景（与摄政王令/角色等弹窗完全一致）。
	# 用「显式尺寸 + 居中定位」而非 CenterContainer/PRESET_CENTER —— 后者对动态 new 出来的
	# 0 尺寸节点会塌缩成左上角锚点，导致面板不显示，只剩蒙版（之前的问题）。
	var popup = PanelContainer.new()
	popup.name = "SettingsPanel"
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_theme_stylebox_override("panel", _popup_bg_stylebox())
	popup.custom_minimum_size = Vector2(420, 260)
	var sz = popup.custom_minimum_size
	popup.size = sz
	var vs = get_viewport().size
	popup.position = Vector2((vs.x - sz.x) / 2.0, (vs.y - sz.y) / 2.0)
	ov.add_child(popup)

	# 内容
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	vb.add_theme_constant_override("content_margin_left", POPUP_BG_MARGIN)
	vb.add_theme_constant_override("content_margin_right", POPUP_BG_MARGIN)
	vb.add_theme_constant_override("content_margin_top", POPUP_BG_MARGIN)
	vb.add_theme_constant_override("content_margin_bottom", POPUP_BG_MARGIN)
	popup.add_child(vb)

	var title = Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", C.TEXT)
	vb.add_child(title)

	var hb = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "音乐音量"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", C.TEXT)
	hb.add_child(lbl)
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = BGM.volume * 100
	slider.custom_minimum_size = Vector2(180, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(slider)
	slider.value_changed.connect(func(v): BGM.set_volume(v / 100.0))
	vb.add_child(hb)

	var close = Button.new()
	close.text = "关闭"
	close.custom_minimum_size = Vector2(0, 36)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.add_theme_font_size_override("font_size", 14)
	close.add_theme_color_override("font_color", C.GOLD)
	# 纯黑底、无描边（与女术士页/事件弹窗选择按钮统一）
	var nb = StyleBoxFlat.new()
	nb.bg_color = Color("0d0d0d")
	nb.set_corner_radius_all(6)
	nb.content_margin_left = 12; nb.content_margin_right = 12
	nb.content_margin_top = 6; nb.content_margin_bottom = 6
	close.add_theme_stylebox_override("normal", nb)
	var hvb = nb.duplicate()
	hvb.bg_color = Color("1f1f1f")
	close.add_theme_stylebox_override("hover", hvb)
	vb.add_child(close)
	close.pressed.connect(func(): ov.queue_free())

	# 窗口缩放时跟随居中（把 lambda 存成 Callable，connect / is_connected / disconnect 都用它）
	var on_resize := func():
		if is_instance_valid(ov) and is_instance_valid(popup):
			var v2 = get_viewport().size
			popup.position = Vector2((v2.x - popup.size.x) / 2.0, (v2.y - popup.size.y) / 2.0)
	get_viewport().size_changed.connect(on_resize)
	popup.tree_exiting.connect(func():
		if get_viewport().is_connected("size_changed", on_resize):
			get_viewport().disconnect("size_changed", on_resize)
	)

	add_child(ov)

func _quit():
	get_tree().quit()
