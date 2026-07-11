# PopupManager.gd
# 弹窗管理器 — 角色/摄政王令/资源/游戏结束弹窗
# 从 MainScene 提取 (Phase 2)

class_name PopupManager
extends RefCounted

var _root: Control
var _C: Dictionary = {}
var _TC: Dictionary = {}; var _TN: Dictionary = {}; var _RG: Dictionary = {}
var _AI: Dictionary = {}; var _AN: Dictionary = {}
var _live_popups: Array = []      # 当前存活的弹窗（用于窗口缩放实时重排）
var _resize_bound: bool = false   # 是否已绑定视口缩放信号

const POPUP_BG = preload("res://assets/images/ui/tanchuang_bg_jiugongge.png")
const POPUP_BG_MARGIN := 80   # 九宫格四角固定边宽（像素），按实际角花尺寸调整

func setup(root: Control, constants: Dictionary) -> void:
	_root = root
	if not _resize_bound:
		_root.get_viewport().size_changed.connect(_on_viewport_resized)
		_resize_bound = true
	_live_popups.clear()
	_C = constants.get("C", {})
	_TC = constants.get("TC", {})
	_TN = constants.get("TN", {})
	_RG = constants.get("RG", {})
	_AI = constants.get("AI", {})
	_AN = constants.get("AN", {})

func _sep() -> HSeparator:
	var s = HSeparator.new(); s.add_theme_constant_override("separation", 6); return s

# 统一的弹窗背景：九宫格图 tanchuang_bg_jiugongge.png（nine-patch，整图完整展示、四角不拉伸、中间拉伸）
func _popup_bg_stylebox() -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = POPUP_BG
	sb.region_rect = Rect2(0, 0, 614, 410)
	# StyleBoxTexture 天生就是九宫格(3x3 缩放)，用 texture_margin_* 定义四角固定边宽。
	# 注意：nine_patch_stretch 是 NinePatchRect 节点的属性，StyleBoxTexture 上不存在，写它会运行时报错。
	sb.texture_margin_left = POPUP_BG_MARGIN
	sb.texture_margin_top = POPUP_BG_MARGIN
	sb.texture_margin_right = POPUP_BG_MARGIN
	sb.texture_margin_bottom = POPUP_BG_MARGIN
	sb.content_margin_left = POPUP_BG_MARGIN
	sb.content_margin_right = POPUP_BG_MARGIN
	sb.content_margin_top = POPUP_BG_MARGIN
	sb.content_margin_bottom = POPUP_BG_MARGIN
	return sb

# 统一的关闭（叉号）按钮：图片 cha_btn.png
func _close_btn(popup) -> TextureButton:
	var cb = TextureButton.new()
	cb.texture_normal = preload("res://assets/images/ui/cha_btn.png")
	cb.ignore_texture_size = true
	cb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	cb.custom_minimum_size = Vector2(32, 32)  # 原图 205×205 (1:1)
	cb.size = Vector2(32, 32)
	cb.mouse_entered.connect(func(): cb.modulate = Color(1.15, 1.15, 1.15))
	cb.mouse_exited.connect(func(): cb.modulate = Color.WHITE)
	cb.pressed.connect(func(): popup.queue_free())
	return cb

# 右上角物理角落的关闭按钮：叠加到 _root 上，真正贴弹窗角落（不受 PanelContainer 内容区 80px 缩进影响），
# 与 RiteDetailPopup 行为一致。弹窗销毁时自动清理，视口缩放时跟随重排。
func _add_corner_close(popup: Control) -> TextureButton:
	var cb = _close_btn(popup)
	cb.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(cb)
	_position_corner_close(cb, popup)
	if not popup.has_meta("corner_close"):
		popup.set_meta("corner_close", cb)
		popup.tree_exiting.connect(func():
			if is_instance_valid(cb):
				cb.queue_free()
		)
	return cb

func _position_corner_close(cb: TextureButton, popup: Control) -> void:
	var sz = 32
	cb.custom_minimum_size = Vector2(sz, sz)
	cb.size = Vector2(sz, sz)
	cb.position = Vector2(popup.position.x + popup.size.x - sz - 4, popup.position.y + 4)

# 事件选择按钮：统一为摄政王弹窗的横向长条按钮样式（深色底+金边框+金字+hover高亮）
func _make_choice_btn(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", _C.get("GOLD", Color("c8a84e")))
	btn.custom_minimum_size = Vector2(0, 30)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = Color("2a1810")
	btn_sb.set_corner_radius_all(8)
	btn_sb.border_width_bottom = 2; btn_sb.border_width_left = 2; btn_sb.border_width_right = 2; btn_sb.border_width_top = 2
	btn_sb.border_color = _C.get("GOLD_LO", Color("8a6820"))
	btn_sb.content_margin_left = 12; btn_sb.content_margin_right = 12
	btn_sb.content_margin_top = 6; btn_sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", btn_sb)
	var hover_sb = StyleBoxFlat.new()
	hover_sb.bg_color = Color("3a2818")
	hover_sb.set_corner_radius_all(8)
	hover_sb.border_width_bottom = 2; hover_sb.border_width_left = 2; hover_sb.border_width_right = 2; hover_sb.border_width_top = 2
	hover_sb.border_color = _C.get("GOLD_HI", Color("e8d48b"))
	hover_sb.content_margin_left = 12; hover_sb.content_margin_right = 12
	hover_sb.content_margin_top = 6; hover_sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.mouse_entered.connect(func(): btn.modulate = Color(1.15, 1.15, 1.15))
	btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)
	btn.pressed.connect(callback)
	return btn

func _sl(t:String, c:Color=Color.WHITE) -> Label:
	var l = Label.new(); l.text=t; l.add_theme_color_override("font_color",c); return l

# ---- 自适应布局：弹窗按屏幕大小缩放，并居中于「地图区」(状态栏以下、手牌区以上) ----
const HAND_ZONE_H := 200   # 与 MainScene._bottom 手牌区高度一致
const STATUS_BAR_H := 38   # 与 StatusBar 顶栏高度一致

# 地图区矩形：状态栏以下、手牌区以上的可用区域
func _map_rect() -> Rect2:
	var vs = _root.get_viewport().size
	return Rect2(0, STATUS_BAR_H, vs.x, vs.y - STATUS_BAR_H - HAND_ZONE_H)

# 计算弹窗目标尺寸：w_frac/h_frac 为占地图区的比例（约 2/3 即 0.66）
func _map_target_size(w_frac: float, h_frac: float, min_w := 320, min_h := 200, max_w := 1500, max_h := 900) -> Vector2:
	var r = _map_rect()
	var pw = clamp(r.size.x * w_frac, min_w, min(r.size.x * 0.96, max_w))
	var ph = clamp(r.size.y * h_frac, min_h, min(r.size.y * 0.96, max_h))
	return Vector2(pw, ph)

# 设置尺寸并居中到地图区
func _place_in_map(popup: Control, w_frac: float, h_frac: float, min_w := 320, min_h := 200, max_w := 1500, max_h := 900) -> void:
	var sz = _map_target_size(w_frac, h_frac, min_w, min_h, max_w, max_h)
	popup.custom_minimum_size = sz
	popup.size = sz
	var r = _map_rect()
	popup.position = Vector2(r.position.x + (r.size.x - sz.x) / 2.0, r.position.y + (r.size.y - sz.y) / 2.0)
	# 记录布局参数，供窗口缩放时实时重排
	popup.set_meta("map_layout", {w_frac=w_frac, h_frac=h_frac, min_w=min_w, min_h=min_h, max_w=max_w, max_h=max_h})
	if not _live_popups.has(popup):
		_live_popups.append(popup)
		popup.tree_exiting.connect(func(): _live_popups.erase(popup))

# 窗口缩放时，对所有存活弹窗按当前地图区重排
func _on_viewport_resized() -> void:
	var vs = _root.get_viewport().size
	for popup in _live_popups:
		if not is_instance_valid(popup):
			continue
		var lay = popup.get_meta("map_layout", null)
		if lay == null:
			continue
		var r = Rect2(0, STATUS_BAR_H, vs.x, vs.y - STATUS_BAR_H - HAND_ZONE_H)
		var pw = clamp(r.size.x * lay.w_frac, lay.min_w, min(r.size.x * 0.96, lay.max_w))
		var ph = clamp(r.size.y * lay.h_frac, lay.min_h, min(r.size.y * 0.96, lay.max_h))
		popup.custom_minimum_size = Vector2(pw, ph)
		popup.size = Vector2(pw, ph)
		popup.position = Vector2(r.position.x + (r.size.x - pw) / 2.0, r.position.y + (r.size.y - ph) / 2.0)
		var cb = popup.get_meta("corner_close", null)
		if cb and is_instance_valid(cb):
			_position_corner_close(cb, popup)

func show_char_popup(d: Dictionary):
	var popup = PanelContainer.new()
	popup.name = "CharPopup"; popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_theme_stylebox_override("panel", _popup_bg_stylebox())

	var main_hb = HBoxContainer.new()
	main_hb.add_theme_constant_override("separation", 16)
	main_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup.add_child(main_hb)

	var left = VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hb.add_child(left)

	var title_hb = HBoxContainer.new(); left.add_child(title_hb)
	var name_lbl = Label.new(); name_lbl.text = d.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 18); name_lbl.add_theme_color_override("font_color", _C.get("GOLD", Color("c8a84e")))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_hb.add_child(name_lbl)

	var title_sub = Label.new(); title_sub.text = d.get("title", "")
	title_sub.add_theme_font_size_override("font_size", 12)
	title_sub.add_theme_color_override("font_color", _C.get("DIM", Color("a09070"))); left.add_child(title_sub)

	left.add_child(_sep())
	var desc = Label.new(); desc.text = d.get("description", "")
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", _C.get("TEXT", Color("f0e6c8")))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(desc)

	left.add_child(_sep())
	var attrs_lbl = Label.new(); attrs_lbl.text = "属性"
	attrs_lbl.add_theme_font_size_override("font_size", 13)
	attrs_lbl.add_theme_color_override("font_color", _C.get("GOLD", Color("c8a84e"))); left.add_child(attrs_lbl)
	var grid = GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 12)
	left.add_child(grid)
	var attrs = d.get("attributes", {})
	for k in ["phy", "com", "sur", "soc", "cha", "ste", "wis", "mag"]:
		var al = Label.new(); al.text = "%s %s %d" % [_AI.get(k, k), _AN.get(k, k), attrs.get(k, 0)]
		al.add_theme_font_size_override("font_size", 11); al.add_theme_color_override("font_color", _C.get("TEXT", Color("f0e6c8")))
		grid.add_child(al)

	left.add_child(_sep())
	var bonus = Label.new(); bonus.text = "📌 " + d.get("ritual_bonus", "")
	bonus.add_theme_font_size_override("font_size", 11); bonus.add_theme_color_override("font_color", _C.get("GOLD_HI", Color("e8d48b")))
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(bonus)
	var _sp_l = Control.new(); _sp_l.size_flags_vertical = Control.SIZE_EXPAND_FILL; left.add_child(_sp_l)

	var right = Control.new()
	right.custom_minimum_size = Vector2(160, 220)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hb.add_child(right)
	var pid = d.get("id", "")
	var portrait_path: String = ""
	match pid:
		"player": portrait_path = "res://assets/images/characters/zhujue.png"
		"meji": portrait_path = "res://assets/images/characters/meji_resized.png"
		"tietou": portrait_path = "res://assets/images/characters/tietou_resized.png"
		"kuaijiao": portrait_path = "res://assets/images/characters/kuaijiao_resized.png"
		"zhaqiyi": portrait_path = "res://assets/images/characters/zhaqiyi_resized.png"
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var pr = TextureRect.new()
		pr.texture = load(portrait_path)
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pr.set_anchors_preset(Control.PRESET_FULL_RECT)
		right.add_child(pr)

	_place_in_map(popup, 0.62, 0.72, 360, 260)
	_root.add_child(popup)
	_add_corner_close(popup)

func show_sultan_popup(d: Dictionary):
	var popup = PanelContainer.new()
	popup.name = "SultanPopup"; popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var tc = _TC.get(d.get("type", ""), _C.get("LUST", Color("8b3a5c")))
	popup.add_theme_stylebox_override("panel", _popup_bg_stylebox())

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); popup.add_child(vb)
	var hb = HBoxContainer.new(); vb.add_child(hb)
	var tl = Label.new(); tl.text = "🃏 " + d.get("name", "?")
	tl.add_theme_font_size_override("font_size", 18); tl.add_theme_color_override("font_color", _C.get("GOLD", Color("c8a84e")))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(tl)

	var info = Label.new()
	info.text = "%s · %s | 剩余 %d 天" % [_TN.get(d.get("type", ""), "?"), _RG.get(d.get("rank", ""), "?"), GameManager.sultan_card_days_left]
	info.add_theme_font_size_override("font_size", 13); info.add_theme_color_override("font_color", tc); vb.add_child(info)

	vb.add_child(_sep())
	var desc = Label.new(); desc.text = d.get("description", "")
	desc.add_theme_font_size_override("font_size", 12); desc.add_theme_color_override("font_color", _C.get("TEXT", Color("f0e6c8")))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; vb.add_child(desc)
	var _sp_s = Control.new(); _sp_s.size_flags_vertical = Control.SIZE_EXPAND_FILL; vb.add_child(_sp_s)

	_place_in_map(popup, 0.5, 0.55, 300, 220)
	_root.add_child(popup)
	_add_corner_close(popup)

func show_res_popup(name_str: String, icon: String, quality: String, count: int):
	var popup = PanelContainer.new()
	popup.name = "ResPopup"; popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var q_stars = {"STONE": "★", "BRONZE": "★★", "SILVER": "★★★", "GOLD": "★★★★"}
	popup.add_theme_stylebox_override("panel", _popup_bg_stylebox())

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 6); popup.add_child(vb)
	var hb = HBoxContainer.new(); vb.add_child(hb)
	var tl = Label.new(); tl.text = "%s %s" % [icon, name_str]
	tl.add_theme_font_size_override("font_size", 18); tl.add_theme_color_override("font_color", _C.get("GOLD", Color("c8a84e")))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(tl)

	var ql = Label.new(); ql.text = "%s · ×%d" % [q_stars.get(quality, "★"), count]
	ql.add_theme_font_size_override("font_size", 13); ql.add_theme_color_override("font_color", _C.get("GOLD_HI", Color("e8d48b")))
	vb.add_child(ql)
	var _sp_r = Control.new(); _sp_r.size_flags_vertical = Control.SIZE_EXPAND_FILL; vb.add_child(_sp_r)

	_place_in_map(popup, 0.42, 0.42, 260, 160)
	_root.add_child(popup)
	_add_corner_close(popup)

func show_game_over():
	var popup = PanelContainer.new()
	popup.name = "GameOverPopup"; popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_theme_stylebox_override("panel", _popup_bg_stylebox())

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 12); popup.add_child(vb)
	var tl = Label.new(); tl.text = "💀 游戏结束"; tl.add_theme_font_size_override("font_size", 24)
	tl.add_theme_color_override("font_color", _C.get("RED", Color("ff4040"))); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var sub = Label.new(); sub.text = "摄政王令逾期未处理，头身分离术已执行"
	sub.add_theme_font_size_override("font_size", 13); sub.add_theme_color_override("font_color", _C.get("DIM", Color("a09070")))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(sub)

	var _sp_g = Control.new(); _sp_g.size_flags_vertical = Control.SIZE_EXPAND_FILL; vb.add_child(_sp_g)

	var rb = Button.new(); rb.text = "🏠 返回主菜单"; rb.custom_minimum_size = Vector2(160, 40)
	rb.add_theme_font_size_override("font_size", 14); vb.add_child(rb)
	rb.pressed.connect(func():
		popup.queue_free()
		_root.get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)

	_place_in_map(popup, 0.5, 0.5, 320, 220)
	_root.add_child(popup)

func show_event_popup(event: Dictionary, on_choice: Callable) -> void:
	var popup = PanelContainer.new()
	popup.name = "EventPopup"; popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var sz = _map_target_size(0.66, 0.66, 360, 300, 1000, 760)
	popup.custom_minimum_size = sz
	popup.add_theme_stylebox_override("panel", _popup_bg_stylebox())
	
	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 10); popup.add_child(vb)
	
	var hb = HBoxContainer.new(); vb.add_child(hb)
	var tl = Label.new(); tl.text = "📜 " + event.name
	tl.add_theme_font_size_override("font_size", 18); tl.add_theme_color_override("font_color", _C.get("GOLD", Color("c8a84e")))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(tl)
	
	var sc = ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED   # 只允许上下滚动，禁用左右滚动
	sc.custom_minimum_size = Vector2(0, sz.y * 0.55); vb.add_child(sc)
	var text_lbl = Label.new(); text_lbl.text = event.text
	text_lbl.add_theme_font_size_override("font_size", 13); text_lbl.add_theme_color_override("font_color", _C.get("TEXT", Color("f0e6c8")))
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # 跟随 ScrollContainer 宽度，配合 autowrap 自动换行，避免横向溢出
	sc.add_child(text_lbl)
	
	var btns = VBoxContainer.new(); btns.add_theme_constant_override("separation", 6)
	for i in range(event.choices.size()):
		var choice = event.choices[i]
		btns.add_child(_make_choice_btn(choice.text, func(idx=i):
			popup.queue_free()
			on_choice.call(event, idx)
		))
	vb.add_child(btns)

	_place_in_map(popup, 0.66, 0.66, 360, 300, 1000, 760)
	_root.add_child(popup)
	_add_corner_close(popup)
