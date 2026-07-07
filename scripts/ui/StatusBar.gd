# StatusBar.gd
# Top bar for day/week, gold dice, and reputation counters.

class_name StatusBar
extends RefCounted

var root: Control
var C: Dictionary = {}

var day_lbl: Label
var week_lbl: Label
var gold_dice_lbl: Label
var good_lbl: Label
var evil_lbl: Label
var power_lbl: Label
var hero_lbl: Label
var spirit_lbl: Label

func setup(p_root: Control, constants: Dictionary) -> void:
	root = p_root
	C = constants.get("C", {})


func build() -> HBoxContainer:
	var bar = HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 38
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)

	day_lbl = _make_label("第1天")
	week_lbl = _make_label("第1周")
	gold_dice_lbl = _make_label("🎲金骰:3", C.get("GOLD", Color("c8a84e")))
	good_lbl = _make_label("善0", Color("5a9a5a"))
	evil_lbl = _make_label("恶0", C.get("FAIL", Color("aa3030")))
	power_lbl = _make_label("权0", Color("9a6aba"))
	hero_lbl = _make_label("侠0", Color("5a8aba"))
	spirit_lbl = _make_label("灵0", Color("6a8a5a"))

	for node in [
		day_lbl, _separator(), week_lbl, _separator(),
		gold_dice_lbl, _separator(), good_lbl, evil_lbl, power_lbl, hero_lbl, spirit_lbl
	]:
		bar.add_child(node)
	return bar


func refresh() -> void:
	if not is_instance_valid(day_lbl):
		return
	day_lbl.text = "第%d天" % TurnManager.current_day
	week_lbl.text = "第%d周" % TurnManager.current_week
	gold_dice_lbl.text = "🎲金骰:%d" % ResourceManager.gold_dice
	good_lbl.text = "善%d" % ResourceManager.reputations.good
	evil_lbl.text = "恶%d" % ResourceManager.reputations.evil
	power_lbl.text = "权%d" % ResourceManager.reputations.power
	hero_lbl.text = "侠%d" % ResourceManager.reputations.hero
	spirit_lbl.text = "灵%d" % ResourceManager.reputations.spirit


func _separator() -> Label:
	return _make_label("│", C.get("GOLD_LO", Color("8a6820")))


func _make_label(text: String, color: Color = Color.WHITE) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
