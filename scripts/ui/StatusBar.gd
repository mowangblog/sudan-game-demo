# StatusBar.gd
# Top bar with reputation(left), day+countdown gauge+gold dice(right).

class_name StatusBar
extends RefCounted

const GAUGE_TOTAL := 7

var root: Control
var C: Dictionary = {}

var _bar: PanelContainer
var day_lbl: Label
var gold_dice_lbl: Label
var gauge_lbl: Label
var gauge_blocks: Array[ColorRect] = []
var good_lbl: PanelContainer
var evil_lbl: PanelContainer
var power_lbl: PanelContainer
var hero_lbl: PanelContainer
var spirit_lbl: PanelContainer


func setup(p_root: Control, constants: Dictionary) -> void:
	root = p_root
	C = constants.get("C", {})


func build(icon_callback: Callable = Callable()) -> PanelContainer:
	_bar = PanelContainer.new()
	_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_bottom = 38
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color("1a0f0a").darkened(0.15)
	ps.border_width_bottom = 0   # 去掉状态栏底部的淡金色线（那条线正好压在背景顶部）
	ps.content_margin_left = 12; ps.content_margin_right = 12
	ps.content_margin_top = 4; ps.content_margin_bottom = 4
	_bar.add_theme_stylebox_override("panel", ps)
	root.add_child(_bar)

	var outer = HBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	_bar.add_child(outer)

	# 令匣图标（接入女术士页，固定在状态栏左上角）
	if icon_callback.is_valid():
		outer.add_child(_sorceress_icon(icon_callback))
		var _icon_sep = Control.new()
		_icon_sep.custom_minimum_size = Vector2(8, 0)
		outer.add_child(_icon_sep)

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

	# 右侧：日期 + 倒计时刻度槽 + 天数 + 金骰
	var right = HBoxContainer.new(); right.add_theme_constant_override("separation", 8)
	right.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(right)

	day_lbl = _l("第1天", 13, C.get("TEXT", Color("f0e6c8")))
	right.add_child(day_lbl)
	right.add_child(_sep())

	var gauge = HBoxContainer.new(); gauge.add_theme_constant_override("separation", 2)
	for i in range(GAUGE_TOTAL):
		var block = ColorRect.new()
		block.custom_minimum_size = Vector2(8, 16)
		block.color = Color("333333")
		gauge_blocks.append(block)
		gauge.add_child(block)
	right.add_child(gauge)

	gauge_lbl = _l("7 天", 13, C.get("GOLD_HI", Color("e8d48b")))
	right.add_child(gauge_lbl)
	right.add_child(_sep())

	gold_dice_lbl = _l("🎲金骰:3", 13, C.get("GOLD_HI", Color("e8d48b")))
	right.add_child(gold_dice_lbl)

	return _bar


func refresh() -> void:
	if not is_instance_valid(day_lbl):
		return
	day_lbl.text = "第%d天" % TurnManager.current_day
	gold_dice_lbl.text = "🎲金骰:%d" % ResourceManager.gold_dice
	_refresh_gauge()
	_good(good_lbl, ResourceManager.reputations.good)
	_good(evil_lbl, ResourceManager.reputations.evil)
	_good(power_lbl, ResourceManager.reputations.power)
	_good(hero_lbl, ResourceManager.reputations.hero)
	_good(spirit_lbl, ResourceManager.reputations.spirit)


func _refresh_gauge() -> void:
	if gauge_blocks.is_empty():
		return
	var days_left := GameManager.sultan_card_days_left
	for i in range(GAUGE_TOTAL):
		var block := gauge_blocks[i]
		if i < days_left:
			if days_left >= 5:
				block.color = Color("4a9a3a")
			elif days_left >= 3:
				block.color = Color("c8a84e")
			else:
				block.color = Color("cc3333")
		else:
			block.color = Color("333333")
	gauge_lbl.text = "%d 天" % days_left


func _good(chip: PanelContainer, val: int) -> void:
	var lbl = chip.get_child(0) as Label
	if not is_instance_valid(lbl): return
	var parts = lbl.text.split(" ")
	if parts.size() >= 2:
		lbl.text = "%s %d" % [parts[0], val]


func _sorceress_icon(cb: Callable) -> Button:
	var b = Button.new()
	b.name = "SorceressBtn"
	b.text = "📜 令匣"
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", C.get("GOLD", Color("c8a84e")))
	b.custom_minimum_size = Vector2(0, 24)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("1a1208")
	sb.set_corner_radius_all(6)
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_color = C.get("GOLD", Color("c8a84e"))
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 1; sb.content_margin_bottom = 1
	b.add_theme_stylebox_override("normal", sb)
	var hsb = StyleBoxFlat.new()
	hsb.bg_color = Color("2a1a08")
	hsb.set_corner_radius_all(6)
	hsb.border_width_top = 2; hsb.border_width_bottom = 2
	hsb.border_width_left = 2; hsb.border_width_right = 2
	hsb.border_color = Color("e8d48b")
	hsb.content_margin_left = 8; hsb.content_margin_right = 8
	hsb.content_margin_top = 1; hsb.content_margin_bottom = 1
	b.add_theme_stylebox_override("hover", hsb)
	b.pressed.connect(cb)
	return b


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
