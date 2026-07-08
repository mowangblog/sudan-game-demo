# PopupManager.gd
# 弹窗管理器 — 角色/摄政王令/资源/游戏结束弹窗
# 从 MainScene 提取 (Phase 2)

class_name PopupManager
extends RefCounted

var _root: Control
var _C: Dictionary = {}
var _TC: Dictionary = {}; var _TN: Dictionary = {}; var _RG: Dictionary = {}
var _AI: Dictionary = {}; var _AN: Dictionary = {}

func setup(root: Control, constants: Dictionary) -> void:
	_root = root
	_C = constants.get("C", {})
	_TC = constants.get("TC", {})
	_TN = constants.get("TN", {})
	_RG = constants.get("RG", {})
	_AI = constants.get("AI", {})
	_AN = constants.get("AN", {})

func _sep() -> HSeparator:
	var s = HSeparator.new(); s.add_theme_constant_override("separation", 6); return s

func _sl(t:String, c:Color=Color.WHITE) -> Label:
	var l = Label.new(); l.text=t; l.add_theme_color_override("font_color",c); return l

func show_char_popup(d: Dictionary):
	var popup = PanelContainer.new()
	popup.name = "CharPopup"; popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.custom_minimum_size = Vector2(340, 0)
	var vs = _root.get_viewport().size
	popup.position = Vector2((vs.x - 340) / 2, (vs.y - 280) / 2 - 40)
	var ps = StyleBoxFlat.new(); ps.bg_color = Color("1a0f0a"); ps.set_corner_radius_all(12)
	ps.border_width_bottom = 3; ps.border_width_top = 3; ps.border_width_left = 3; ps.border_width_right = 3
	ps.border_color = _C.get("GOLD", Color("c8a84e")); ps.shadow_size = 12; ps.shadow_color = Color("000000cc")
	ps.content_margin_left = 16; ps.content_margin_right = 16; ps.content_margin_top = 12; ps.content_margin_bottom = 12
	popup.add_theme_stylebox_override("panel", ps)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 6); popup.add_child(vb)
	var hb = HBoxContainer.new(); vb.add_child(hb)
	var name_lbl = Label.new(); name_lbl.text = d.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 18); name_lbl.add_theme_color_override("font_color", _C.get("GOLD", Color("c8a84e")))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(name_lbl)
	var cb = Button.new(); cb.text = "✕"; cb.custom_minimum_size = Vector2(32, 32)
	cb.pressed.connect(func(): popup.queue_free()); hb.add_child(cb)

	var title_lbl = Label.new(); title_lbl.text = d.get("title", ""); title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", _C.get("DIM", Color("a09070"))); vb.add_child(title_lbl)

	vb.add_child(_sep())
	var desc = Label.new(); desc.text = d.get("description", ""); desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", _C.get("TEXT", Color("f0e6c8")))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; vb.add_child(desc)

	vb.add_child(_sep())
	var grid = GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 12)
	vb.add_child(grid)
	var attrs = d.get("attributes", {})
	for k in ["phy", "com", "sur", "soc", "cha", "ste", "wis", "mag"]:
		var al = Label.new(); al.text = "%s %s %d" % [_AI.get(k, k), _AN.get(k, k), attrs.get(k, 0)]
		al.add_theme_font_size_override("font_size", 11); al.add_theme_color_override("font_color", _C.get("TEXT", Color("f0e6c8")))
		grid.add_child(al)

	vb.add_child(_sep())
	var bonus = Label.new(); bonus.text = "📌 " + d.get("ritual_bonus", "")
	bonus.add_theme_font_size_override("font_size", 11); bonus.add_theme_color_override("font_color", _C.get("GOLD_HI", Color("e8d48b")))
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; vb.add_child(bonus)

	_root.add_child(popup)

func show_sultan_popup(d: Dictionary):
	var popup = PanelContainer.new()
	popup.name = "SultanPopup"; popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.custom_minimum_size = Vector2(380, 280)
	var vs = _root.get_viewport().size
	popup.position = Vector2((vs.x - 380) / 2, (vs.y - 280) / 2 - 40)
	var tc = _TC.get(d.get("type", ""), _C.get("LUST", Color("8b3a5c")))
	var ps = StyleBoxFlat.new(); ps.bg_color = Color("1a0f0a"); ps.set_corner_radius_all(12)
	ps.border_width_bottom = 3; ps.border_width_top = 3; ps.border_width_left = 3; ps.border_width_right = 3
	ps.border_color = tc; ps.shadow_size = 12; ps.shadow_color = Color(tc.r, tc.g, tc.b, 0.4)
	ps.content_margin_left = 16; ps.content_margin_right = 16; ps.content_margin_top = 12; ps.content_margin_bottom = 12
	popup.add_theme_stylebox_override("panel", ps)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); popup.add_child(vb)
	var hb = HBoxContainer.new(); vb.add_child(hb)
	var tl = Label.new(); tl.text = "🃏 " + d.get("name", "?")
	tl.add_theme_font_size_override("font_size", 18); tl.add_theme_color_override("font_color", _C.get("GOLD", Color("c8a84e")))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(tl)
	var cb = Button.new(); cb.text = "✕"; cb.custom_minimum_size = Vector2(32, 32)
	cb.pressed.connect(func(): popup.queue_free()); hb.add_child(cb)

	var info = Label.new()
	info.text = "%s · %s | 剩余 %d 天" % [_TN.get(d.get("type", ""), "?"), _RG.get(d.get("rank", ""), "?"), GameManager.sultan_card_days_left]
	info.add_theme_font_size_override("font_size", 13); info.add_theme_color_override("font_color", tc); vb.add_child(info)

	vb.add_child(_sep())
	var desc = Label.new(); desc.text = d.get("description", "")
	desc.add_theme_font_size_override("font_size", 12); desc.add_theme_color_override("font_color", _C.get("TEXT", Color("f0e6c8")))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; vb.add_child(desc)

	_root.add_child(popup)

func show_res_popup(name_str: String, icon: String, quality: String, count: int):
	var popup = PanelContainer.new()
	popup.name = "ResPopup"; popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var vs = _root.get_viewport().size
	popup.custom_minimum_size = Vector2(280, 0)
	popup.position = Vector2((vs.x - 280) / 2, (vs.y - 220) / 2 - 60)
	var q_stars = {"STONE": "★", "BRONZE": "★★", "SILVER": "★★★", "GOLD": "★★★★"}
	var ps = StyleBoxFlat.new(); ps.bg_color = Color("1a0f0a"); ps.set_corner_radius_all(12)
	ps.border_width_bottom = 3; ps.border_width_top = 3; ps.border_width_left = 3; ps.border_width_right = 3
	ps.border_color = _C.get("GOLD", Color("c8a84e")); ps.shadow_size = 12; ps.shadow_color = Color("000000cc")
	ps.content_margin_left = 16; ps.content_margin_right = 16; ps.content_margin_top = 12; ps.content_margin_bottom = 12
	popup.add_theme_stylebox_override("panel", ps)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 6); popup.add_child(vb)
	var hb = HBoxContainer.new(); vb.add_child(hb)
	var tl = Label.new(); tl.text = "%s %s" % [icon, name_str]
	tl.add_theme_font_size_override("font_size", 18); tl.add_theme_color_override("font_color", _C.get("GOLD", Color("c8a84e")))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(tl)
	var cb = Button.new(); cb.text = "✕"; cb.custom_minimum_size = Vector2(32, 32)
	cb.pressed.connect(func(): popup.queue_free()); hb.add_child(cb)

	var ql = Label.new(); ql.text = "%s · ×%d" % [q_stars.get(quality, "★"), count]
	ql.add_theme_font_size_override("font_size", 13); ql.add_theme_color_override("font_color", _C.get("GOLD_HI", Color("e8d48b")))
	vb.add_child(ql)

	_root.add_child(popup)

func show_game_over():
	var popup = PanelContainer.new()
	popup.name = "GameOverPopup"; popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.custom_minimum_size = Vector2(400, 260)
	var vs = _root.get_viewport().size
	popup.position = Vector2((vs.x - 400) / 2, (vs.y - 260) / 2 - 50)
	var ps = StyleBoxFlat.new(); ps.bg_color = Color("1a0f0a"); ps.set_corner_radius_all(12)
	ps.border_width_bottom = 3; ps.border_width_top = 3; ps.border_width_left = 3; ps.border_width_right = 3
	ps.border_color = _C.get("RED", Color("ff4040")); ps.shadow_size = 16; ps.shadow_color = Color("ff000066")
	ps.content_margin_left = 20; ps.content_margin_right = 20; ps.content_margin_top = 16; ps.content_margin_bottom = 16
	popup.add_theme_stylebox_override("panel", ps)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 12); popup.add_child(vb)
	var tl = Label.new(); tl.text = "💀 游戏结束"; tl.add_theme_font_size_override("font_size", 24)
	tl.add_theme_color_override("font_color", _C.get("RED", Color("ff4040"))); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var sub = Label.new(); sub.text = "摄政王令逾期未处理，头身分离术已执行"
	sub.add_theme_font_size_override("font_size", 13); sub.add_theme_color_override("font_color", _C.get("DIM", Color("a09070")))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(sub)

	var rb = Button.new(); rb.text = "🔄 重开一局"; rb.custom_minimum_size = Vector2(160, 40)
	rb.add_theme_font_size_override("font_size", 14); vb.add_child(rb)

	rb.pressed.connect(func():
		popup.queue_free()
		_root.get_tree().change_scene_to_file("res://scenes/ui/MainScene.tscn")
	)

	_root.add_child(popup)
