# SettlementScreen.gd
# 结算主界面 — 左右分栏：骰子区 + 叙事区
# Phase 1: 静态 UI 框架，无动画

extends PanelContainer

signal settlement_done(rite_result: Dictionary)

const GOLD = Color("c8a84e"); const GOLD_HI = Color("e8d48b"); const GOLD_LO = Color("8a6820")
const TEXT = Color("f0e6c8"); const DIM = Color("a09070"); const GREEN = Color("4a9a3a")
const FAIL = Color("aa3030"); const BG = Color("1a0f0a"); const SHADOW = Color("000000cc")

var rite_data: Dictionary = {}
var char_data: Dictionary = {}
var sultan_card_data: Dictionary = {}

var narrative_vb: VBoxContainer
var stage_lbl: Label
var dice_vb: VBoxContainer
var char_lbl: Label
var attr_lbl: Label
var dice_tray: HBoxContainer
var check_lbl: Label
var result_lbl: Label
var result_text: Label
var next_btn: Button

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup_and_show(rite: Dictionary, char_d: Dictionary, sultan: Dictionary):
	rite_data = rite
	char_data = char_d
	sultan_card_data = sultan

	var vs = get_viewport().size
	var w = min(vs.x - 60, 960); var h = min(vs.y - 80, 600)
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	position = Vector2((vs.x - w) / 2, (vs.y - h) / 2 - 20)

	for c in get_children(): c.queue_free()

	var ps = StyleBoxFlat.new(); ps.bg_color = BG; ps.set_corner_radius_all(12)
	ps.border_width_bottom = 3; ps.border_width_top = 3
	ps.border_width_left = 3; ps.border_width_right = 3
	ps.border_color = GOLD; ps.shadow_size = 16; ps.shadow_color = SHADOW
	ps.content_margin_left = 16; ps.content_margin_right = 16
	ps.content_margin_top = 12; ps.content_margin_bottom = 12
	add_theme_stylebox_override("panel", ps)

	_build_layout()
	_start_settlement()

func _build_layout():
	var split = HSplitContainer.new()
	split.split_offset = 260  # 左侧骰子区固定宽度
	split.add_theme_constant_override("separation", 0)
	add_child(split)

	# === 左侧：骰子区 ===
	var left = PanelContainer.new()
	var lps = StyleBoxFlat.new(); lps.bg_color = Color("0d0804"); lps.set_corner_radius_all(8)
	lps.border_width_bottom = 1; lps.border_width_top = 1
	lps.border_width_left = 1; lps.border_width_right = 1
	lps.border_color = GOLD_LO; lps.content_margin_left = 12; lps.content_margin_right = 12
	lps.content_margin_top = 10; lps.content_margin_bottom = 10
	left.add_theme_stylebox_override("panel", lps)
	split.add_child(left)

	dice_vb = VBoxContainer.new()
	dice_vb.add_theme_constant_override("separation", 10)
	dice_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(dice_vb)

	# 角色名 + 品质星
	char_lbl = Label.new()
	char_lbl.add_theme_font_size_override("font_size", 16)
	char_lbl.add_theme_color_override("font_color", GOLD)
	char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_vb.add_child(char_lbl)

	# 核心属性
	attr_lbl = Label.new()
	attr_lbl.add_theme_font_size_override("font_size", 12)
	attr_lbl.add_theme_color_override("font_color", DIM)
	attr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_vb.add_child(attr_lbl)

	dice_vb.add_child(_sep())

	# 骰子盘
	dice_tray = HBoxContainer.new()
	dice_tray.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_tray.add_theme_constant_override("separation", 4)
	dice_vb.add_child(dice_tray)

	dice_vb.add_child(_sep())

	# 检定要求
	check_lbl = Label.new()
	check_lbl.add_theme_font_size_override("font_size", 11)
	check_lbl.add_theme_color_override("font_color", DIM)
	check_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dice_vb.add_child(check_lbl)

	# 结果
	result_lbl = Label.new()
	result_lbl.add_theme_font_size_override("font_size", 20)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.visible = false
	dice_vb.add_child(result_lbl)

	# === 右侧：叙事区 ===
	var right = ScrollContainer.new()
	split.add_child(right)

	narrative_vb = VBoxContainer.new()
	narrative_vb.add_theme_constant_override("separation", 12)
	narrative_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(narrative_vb)

	# 标题
	var ns = VBoxContainer.new(); ns.add_theme_constant_override("separation", 4)
	narrative_vb.add_child(ns)

	var nl = Label.new()
	nl.text = rite_data.get("name", "?")
	nl.add_theme_font_size_override("font_size", 20)
	nl.add_theme_color_override("font_color", GOLD)
	ns.add_child(nl)

	var cn = char_data.get("name", "") if not char_data.is_empty() else ""
	if cn != "":
		var cl = Label.new()
		cl.text = "执行者：" + cn
		cl.add_theme_font_size_override("font_size", 12)
		cl.add_theme_color_override("font_color", DIM)
		ns.add_child(cl)

	# 分隔线
	var sep = HSeparator.new()
	narrative_vb.add_child(sep)

	# 当前阶段文本
	stage_lbl = Label.new()
	stage_lbl.add_theme_font_size_override("font_size", 14)
	stage_lbl.add_theme_color_override("font_color", TEXT)
	stage_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative_vb.add_child(stage_lbl)

	# 检定结果文本
	result_text = Label.new()
	result_text.add_theme_font_size_override("font_size", 13)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.visible = false
	narrative_vb.add_child(result_text)

	# 继续按钮
	next_btn = Button.new()
	next_btn.text = "继续 ▶"; next_btn.custom_minimum_size = Vector2(120, 36)
	next_btn.add_theme_font_size_override("font_size", 13)
	next_btn.visible = false
	next_btn.pressed.connect(_on_next)
	narrative_vb.add_child(next_btn)

func _start_settlement():
	# 显示角色信息
	if not char_data.is_empty():
		char_lbl.text = "👤 " + char_data.get("name", "?")
		var attrs = char_data.get("attributes", {})
		var best_k = ""; var best_v = 0
		for k in attrs:
			if attrs[k] > best_v: best_v = attrs[k]; best_k = k
		var ai_map = {"phy":"💪","com":"⚔","sur":"🏕","soc":"💬","cha":"💋","ste":"🕶","wis":"📚","mag":"🔮"}
		var an_map = {"phy":"体魄","com":"战斗","sur":"生存","soc":"社交","cha":"魅力","ste":"隐匿","wis":"智慧","mag":"魔力"}
		attr_lbl.text = "%s %s %d" % [ai_map.get(best_k, ""), an_map.get(best_k, best_k), best_v]
	else:
		char_lbl.text = "无角色"
		attr_lbl.text = ""

	# 获取 stages（Phase 4 会补数据，现在自动生成单 stage）
	_start_stage()

func _start_stage():
	var check = rite_data.get("check", {})
	var dice_count = _calc_dice_count(char_data, check)
	var required = check.get("required_successes", 1)

	# 显示检定信息
	var atype = "solo" if check.has("attribute") else check.get("type", "solo")
	var attr_name = ""
	if atype == "solo":
		var an_map = {"phy":"体魄","com":"战斗","sur":"生存","soc":"社交","cha":"魅力","ste":"隐匿","wis":"智慧","mag":"魔力"}
		attr_name = an_map.get(check.get("attribute",""), "")
	check_lbl.text = "%s检定 | 🎲×%d 需✅×%d" % [attr_name, dice_count, required]

	# 叙事文本
	var narrative = rite_data.get("description", "仪式开始...")
	stage_lbl.text = "“" + narrative + "”"

	# 投骰（Phase 2 加动画）
	var actual_success = 0
	for i in range(dice_count):
		if randf() < 0.5: actual_success += 1
	if ResourceManager.gold_dice > 0 and dice_count >= 1:
		actual_success += 1
		ResourceManager.gold_dice -= 1

	# 显示骰子结果
	for c in dice_tray.get_children(): c.queue_free()
	for i in range(dice_count):
		var die = Label.new()
		die.text = "✅" if i < actual_success else "❌"
		die.add_theme_font_size_override("font_size", 28)
		dice_tray.add_child(die)

	# 结果显示
	result_lbl.visible = true
	var is_success = actual_success >= required
	if is_success:
		result_lbl.text = "✅ 成功"
		result_lbl.add_theme_color_override("font_color", GREEN)
	else:
		result_lbl.text = "❌ 失败"
		result_lbl.add_theme_color_override("font_color", FAIL)

	# 结果文本
	result_text.visible = true
	var outcomes = rite_data.get("outcomes", {})
	var outcome = outcomes.get("success" if is_success else "fail", {})
	result_text.text = outcome.get("narrative", outcome.get("description", ""))
	if is_success:
		result_text.add_theme_color_override("font_color", GREEN)
	else:
		result_text.add_theme_color_override("font_color", FAIL)

	# 应用效果
	if outcome.has("gold"): ResourceManager.add_gold(outcome.gold)
	if outcome.has("power"): ResourceManager.modify_reputation("power", outcome.power)
	if outcome.has("good"): ResourceManager.modify_reputation("good", outcome.good)
	if outcome.has("evil"): ResourceManager.modify_reputation("evil", outcome.evil)
	if outcome.has("hero"): ResourceManager.modify_reputation("hero", outcome.hero)
	if outcome.has("spirit"): ResourceManager.modify_reputation("spirit", outcome.spirit)

	next_btn.visible = true

func _calc_dice_count(cd: Dictionary, check: Dictionary) -> int:
	if cd.is_empty(): return 1
	var attrs = cd.get("attributes", {})
	var total = 0
	if check.get("type", "solo") == "solo":
		total = attrs.get(check.get("attribute", "phy"), 0)
	else:
		for a in check.get("attributes", []):
			total += attrs.get(a, 0)
	return max(1, total)

func _on_next():
	var success = result_lbl.text.contains("成功")
	settlement_done.emit({
		"rite": rite_data,
		"char": char_data,
		"sultan_card": sultan_card_data,
		"success": success,
		"success_count": 0,  # Phase 3 会补充
		"required": 0,
	})
	queue_free()

func _sep() -> HSeparator:
	return HSeparator.new()
