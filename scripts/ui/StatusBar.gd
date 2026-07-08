# StatusBar.gd
# Top bar with reputation(left), day+countdown+gold dice(right).

class_name StatusBar
extends RefCounted

var root: Control
var C: Dictionary = {}

var _bar: PanelContainer
var day_lbl: Label
var gold_dice_lbl: Label
var countdown_lbl: Label
var good_lbl: PanelContainer
var evil_lbl: PanelContainer
var power_lbl: PanelContainer
var hero_lbl: PanelContainer
var spirit_lbl: PanelContainer


func setup(p_root: Control, constants: Dictionary) -> void:
	root = p_root
	C = constants.get("C", {})


func build() -> PanelContainer:
	_bar = PanelContainer.new()
	_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_bottom = 38
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color("1a0f0a").darkened(0.15)
	ps.border_width_bottom = 2
	ps.border_color = C.get("GOLD_LO", Color("8a6820"))
	ps.content_margin_left = 12; ps.content_margin_right = 12
	ps.content_margin_top = 4; ps.content_margin_bottom = 4
	_bar.add_theme_stylebox_override("panel", ps)
	root.add_child(_bar)

	var outer = HBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	_bar.add_child(outer)

	# 左侧：声望方块
	var left = HBoxContainer.new(); left.add_theme_constant_override("separation", 4)
	outer.add_child(left)
	good_lbl = _rep_chip("名望", Color("5a9a5a"), 0); left.add_child(good_lbl)
	evil_lbl = _rep_chip("恶名", C.get("FAIL", Color("aa3030")), 0); left.add_child(evil_lbl)
	power_lbl = _rep_chip("权势", Color("9a6aba"), 0); left.add_child(power_lbl)
	hero_lbl = _rep_chip("义名", Color("5a8aba"), 0); left.add_child(hero_lbl)
	spirit_lbl = _rep_chip("灵知", Color("6a8a5a"), 0); left.add_child(spirit_lbl)

	# 弹性间隔
	var spacer = Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(spacer)

	# 右侧：日期 + 倒计时 + 金骰
	var right = HBoxContainer.new(); right.add_theme_constant_override("separation", 8)
	right.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(right)

	day_lbl = _l("第1天", 13, C.get("TEXT", Color("f0e6c8")))
	right.add_child(day_lbl)
	right.add_child(_sep())

	countdown_lbl = _l("7", 22, Color("cc3333"))
	countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(countdown_lbl)

	gold_dice_lbl = _l("🎲金骰:3", 13, C.get("GOLD_HI", Color("e8d48b")))
	right.add_child(gold_dice_lbl)

	return _bar


func refresh() -> void:
	if not is_instance_valid(day_lbl):
		return
	day_lbl.text = "第%d天" % TurnManager.current_day
	gold_dice_lbl.text = "🎲金骰:%d" % ResourceManager.gold_dice
	_refresh_countdown()
	_good(good_lbl, ResourceManager.reputations.good)
	_good(evil_lbl, ResourceManager.reputations.evil)
	_good(power_lbl, ResourceManager.reputations.power)
	_good(hero_lbl, ResourceManager.reputations.hero)
	_good(spirit_lbl, ResourceManager.reputations.spirit)


func _refresh_countdown() -> void:
	if not is_instance_valid(countdown_lbl):
		return
	var d := GameManager.sultan_card_days_left
	countdown_lbl.text = str(d)
	if d <= 0:
		countdown_lbl.add_theme_font_size_override("font_size", 14)
		countdown_lbl.add_theme_color_override("font_color", Color("883333"))
	elif d <= 1:
		countdown_lbl.add_theme_font_size_override("font_size", 24)
		countdown_lbl.add_theme_color_override("font_color", Color("ff2020"))
	elif d <= 3:
		countdown_lbl.add_theme_font_size_override("font_size", 22)
		countdown_lbl.add_theme_color_override("font_color", Color("ee4040"))
	else:
		countdown_lbl.add_theme_font_size_override("font_size", 20)
		countdown_lbl.add_theme_color_override("font_color", Color("cc5555"))


func _good(chip: PanelContainer, val: int) -> void:
	var lbl = chip.get_child(0) as Label
	if not is_instance_valid(lbl): return
	var parts = lbl.text.split(" ")
	if parts.size() >= 2:
		lbl.text = "%s %d" % [parts[0], val]


func _rep_chip(name: String, color: Color, val: int) -> PanelContainer:
	var chip = PanelContainer.new()
	var cps = StyleBoxFlat.new()
	cps.bg_color = color * Color(1, 1, 1, 0.15)
	cps.set_corner_radius_all(4)
	cps.content_margin_left = 6; cps.content_margin_right = 6
	cps.content_margin_top = 2; cps.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", cps)
	var lbl = _l("%s %d" % [name, val], 12, color)
	chip.add_child(lbl)
	return chip


func _sep() -> Label:
	return _l("│", 13, C.get("GOLD_LO", Color("8a6820")))


func _l(text: String, size: int, color: Color) -> Label:
	var l = Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
