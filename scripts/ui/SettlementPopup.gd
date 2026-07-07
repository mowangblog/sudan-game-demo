# SettlementPopup.gd
# 结算面板（内嵌覆盖层）— 逐个显示仪式结算，有骰子判定动画

extends PanelContainer

signal settlement_done(rite_result: Dictionary)

const FLAT_GOLD = Color("c8a84e")
const FLAT_TEXT = Color("f0e6c8")
const FLAT_DIM = Color("a09070")
const FLAT_GREEN = Color("4a9a3a")
const FLAT_FAIL = Color("aa3030")

var vb: VBoxContainer
var dice_lbl: Label
var detail_lbl: Label
var result_lbl: Label
var desc_lbl: Label
var continue_btn: Button

var rite_data: Dictionary = {}
var char_data: Dictionary = {}
var sultan_card_data: Dictionary = {}
var timer: Timer
var tick: int = 0
var dice_count: int = 0
var success_threshold: int = 0
var actual_success: int = 0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_style()

func _setup_style():
	# 面板样式
	var ps = StyleBoxFlat.new(); ps.bg_color = Color("1a0f0a"); ps.set_corner_radius_all(12)
	ps.border_width_bottom = 3; ps.border_width_top = 3
	ps.border_width_left = 3; ps.border_width_right = 3; ps.border_color = FLAT_GOLD
	ps.shadow_size = 12; ps.shadow_color = Color("000000cc")
	ps.content_margin_left = 20; ps.content_margin_right = 20
	ps.content_margin_top = 16; ps.content_margin_bottom = 16
	add_theme_stylebox_override("panel", ps)

func setup_and_show(rite: Dictionary, char_d: Dictionary, sultan: Dictionary):
	rite_data = rite
	char_data = char_d
	sultan_card_data = sultan

	# 居中定位 — 加宽加大
	custom_minimum_size = Vector2(460, 420)
	size = Vector2(460, 420)
	var vs = get_viewport().size
	position = Vector2((vs.x - 460) / 2, (vs.y - 420) / 2 - 50)

	# 清空旧内容
	for c in get_children():
		c.queue_free()

	build_content()
	start_animation()

func build_content():
	# 用 ScrollContainer 防止溢出
	var sc = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sc)

	vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)

	# 仪式名
	var nl = Label.new()
	nl.text = rite_data.get("name", "?")
	nl.add_theme_font_size_override("font_size", 20)
	nl.add_theme_color_override("font_color", FLAT_GOLD)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nl)

	# 执行者
	var cn = char_data.get("name", "（无）") if not char_data.is_empty() else "（无）"
	var cl = Label.new()
	cl.text = "执行者：%s" % cn
	cl.add_theme_font_size_override("font_size", 13)
	cl.add_theme_color_override("font_color", FLAT_TEXT)
	vb.add_child(cl)

	vb.add_child(_sep())

	# 骰子动画区
	dice_lbl = Label.new()
	dice_lbl.text = "🎲 投骰中..."
	dice_lbl.add_theme_font_size_override("font_size", 22)
	dice_lbl.add_theme_color_override("font_color", FLAT_GOLD)
	dice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(dice_lbl)

	detail_lbl = Label.new()
	detail_lbl.text = ""
	detail_lbl.add_theme_font_size_override("font_size", 12)
	detail_lbl.add_theme_color_override("font_color", FLAT_DIM)
	detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(detail_lbl)

	vb.add_child(_sep())

	# 结果标识
	result_lbl = Label.new()
	result_lbl.text = ""
	result_lbl.add_theme_font_size_override("font_size", 22)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.visible = false
	vb.add_child(result_lbl)

	# 结算叙事
	desc_lbl = Label.new()
	desc_lbl.text = ""
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", FLAT_TEXT)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.visible = false
	vb.add_child(desc_lbl)

	# 继续按钮
	continue_btn = Button.new()
	continue_btn.text = "继续 ▶"
	continue_btn.custom_minimum_size = Vector2(120, 38)
	continue_btn.add_theme_font_size_override("font_size", 14)
	continue_btn.visible = false
	continue_btn.pressed.connect(_on_continue)
	vb.add_child(continue_btn)

func start_animation():
	tick = 0
	var check = rite_data.get("check", {})
	dice_count = calc_dice_count(char_data, check)
	success_threshold = check.get("required_successes", 1)

	detail_lbl.text = "骰子数：%d  |  需成功：%d" % [dice_count, success_threshold]

	timer = Timer.new()
	timer.one_shot = false
	timer.wait_time = 0.18
	timer.timeout.connect(_on_tick)
	add_child(timer)
	timer.start()

func _on_tick():
	tick += 1
	if tick <= dice_count * 2 + 2:  # 多几帧缓冲
		var anim = ""
		for i in range(min(tick, 6)):
			anim += "🎲 " if randi() % 2 == 0 else "✅ "
		dice_lbl.text = "🎲 投骰中...  " + anim
	else:
		timer.stop()
		show_result()

func show_result():
	# 实际投掷
	actual_success = 0
	for i in range(dice_count):
		if randf() < 0.5:
			actual_success += 1

	# 金骰子
	if ResourceManager.gold_dice > 0 and dice_count >= 1:
		actual_success += 1
		ResourceManager.gold_dice -= 1

	var is_success = actual_success >= success_threshold

	dice_lbl.text = "🎲 投出：%d/%d 成功" % [actual_success, success_threshold]

	result_lbl.visible = true
	if is_success:
		result_lbl.text = "✅ 成功！"
		result_lbl.add_theme_color_override("font_color", FLAT_GREEN)
	else:
		result_lbl.text = "❌ 失败！"
		result_lbl.add_theme_color_override("font_color", FLAT_FAIL)

	var outcomes = rite_data.get("outcomes", {})
	var outcome = outcomes.get("success" if is_success else "fail", {})

	# 丰富文案 — 替换 [角色] 为实际角色名
	var char_name = char_data.get("name", "某人") if not char_data.is_empty() else "某人"
	var narrative = outcome.get("narrative", outcome.get("description", ""))
	if narrative.find("[角色]") != -1:
		narrative = narrative.replace("[角色]", char_name)

	desc_lbl.visible = true
	desc_lbl.text = narrative

	continue_btn.visible = true

func calc_dice_count(cd: Dictionary, check: Dictionary) -> int:
	if cd.is_empty():
		return 1
	var attrs = cd.get("attributes", {})
	var total = 0
	if check.type == "solo":
		total = attrs.get(check.attribute, 0)
	elif check.type == "combined":
		for a in check.get("attributes", []):
			total += attrs.get(a, 0)
	return max(1, total)

func _on_continue():
	var result = {
		"rite": rite_data,
		"char": char_data,
		"sultan_card": sultan_card_data,
		"success": actual_success >= success_threshold,
		"success_count": actual_success,
		"required": success_threshold,
	}
	settlement_done.emit(result)
	queue_free()

func _sep() -> HSeparator:
	return HSeparator.new()
