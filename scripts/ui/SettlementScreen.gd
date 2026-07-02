# SettlementScreen.gd
# 结算主界面 — 左右分栏：骰子区 + 叙事区

extends PanelContainer

signal settlement_done(rite_result: Dictionary)

const GOLD = Color("c8a84e")
const GOLD_HI = Color("e8d48b")
const GOLD_LO = Color("8a6820")
const TEXT = Color("f0e6c8")
const DIM = Color("a09070")
const GREEN = Color("4a9a3a")
const FAIL = Color("aa3030")
const BG = Color("1a0f0a")
const SHADOW = Color("000000cc")

const FACE_DIR = "res://addons/dice_3d/assets/faces/"
const NUMBER_1 = preload(FACE_DIR + "number_1.svg")
const NUMBER_2 = preload(FACE_DIR + "number_2.svg")
const NUMBER_3 = preload(FACE_DIR + "number_3.svg")
const NUMBER_4 = preload(FACE_DIR + "number_4.svg")
const NUMBER_5 = preload(FACE_DIR + "number_5.svg")
const NUMBER_6 = preload(FACE_DIR + "number_6.svg")
const DIE_BODY_MAT = preload("res://addons/dice_3d/assets/materials/painted_plaster_number_die.tres")

var rite_data: Dictionary = {}
var char_data: Dictionary = {}
var sultan_card_data: Dictionary = {}

var narrative_vb: VBoxContainer
var stage_lbl: Label
var dice_vb: VBoxContainer
var char_lbl: Label
var attr_lbl: Label
var dice_tray: Control
var _dice_roller: DiceCinematicRoller3D
var _dice_svc: SubViewportContainer
var _pending_total_success: int = 0
var _pending_required: int = 0
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

	# 重置 3D 骰子引用（旧子节点会被 queue_free 销毁）
	_dice_roller = null
	_dice_svc = null

	var vs = get_viewport().size
	var bottom_limit = vs.y - 200 - 16  # 手牌区上方留 16px 间隙
	var w = min(vs.x - 40, 1080)
	var h = min(bottom_limit - 28, 400)
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	position = Vector2((vs.x - w) / 2, (bottom_limit - h) / 2)

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
	split.split_offset = 400  # 左侧骰子区
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

	# 骰子盘（SubViewport 占位）
	dice_tray = Control.new()
	dice_tray.custom_minimum_size = Vector2(0, 260)
	dice_vb.add_child(dice_tray)

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

	# 创建 3D 骰子 SubViewport
	_setup_3d_dice()

	# 构建骰子结果和骰子定义
	var results = []
	for _i in range(dice_count):
		results.append(randf() < 0.5)

	var golden_count = 0
	if ResourceManager.gold_dice > 0 and dice_count >= 1:
		golden_count = 1
		ResourceManager.gold_dice -= 1

	# 金骰子追加到末尾，必成功
	for _i in range(golden_count):
		results.append(true)

	var total_success = 0
	for r in results:
		if r: total_success += 1
	_pending_total_success = total_success
	_pending_required = required

	# 创建骰子并投掷（指定每个骰子的目标面）
	var definition = _make_check_die_definition()
	var dice_to_roll: Array[DiceDie3D] = []
	var requested_results = []

	for i in range(results.size()):
		var die = _dice_roller.create_die(definition)
		var mat = DIE_BODY_MAT.duplicate(true) as StandardMaterial3D
		mat.albedo_color = _die_color(i)
		die.body_material = mat
		dice_to_roll.append(die)
		# 成功 → 6点，失败 → 1点，金骰子固定 6点
		var is_golden = i >= results.size() - golden_count
		if is_golden:
			requested_results.append(6)
		else:
			requested_results.append(6 if results[i] else 1)

	# 分行布局（每行最多5个），然后投掷
	_layout_dice_grid(dice_to_roll)
	await get_tree().create_timer(0.1).timeout
	_dice_roller.roll_dice(dice_to_roll, requested_results)

	# 动画完成前隐藏结果
	result_lbl.visible = false
	result_text.visible = false
	next_btn.visible = false


func _setup_3d_dice():
	# 清理旧骰子
	if _dice_roller:
		_dice_roller.reset_all()
		for d in _dice_roller.get_registered_dice():
			_dice_roller.remove_die(d)

	if not _dice_svc:
		# SubViewport 管线：带柔光，去掉线框
		var svp = SubViewport.new()
		svp.transparent_bg = true
		svp.size = Vector2i(640, 440)

		var root_3d = Node3D.new()
		root_3d.name = "DiceRoot"
		svp.add_child(root_3d)

		# 摄像机：俯视桌面
		var cam = Camera3D.new()
		cam.position = Vector3(0, 6.0, 0.5)
		cam.rotation_degrees = Vector3(-84, 0, 0)
		cam.fov = 35.0
		root_3d.add_child(cam)

		# 主光：从上方斜照
		var key = DirectionalLight3D.new()
		key.position = Vector3(2, 6, 2)
		key.light_energy = 5.0
		root_3d.add_child(key)

		# 补光：从下后方填充
		var fill = OmniLight3D.new()
		fill.position = Vector3(-2, 2, -2)
		fill.light_energy = 3.0
		fill.omni_range = 10.0
		root_3d.add_child(fill)

		# 第二补光：从右侧补
		var fill2 = OmniLight3D.new()
		fill2.position = Vector3(3, 3, 0)
		fill2.light_energy = 2.0
		fill2.omni_range = 10.0
		root_3d.add_child(fill2)

		# 环境光（均匀提亮）
		var env = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0, 0, 0, 0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(1.0, 1.0, 1.0)
		env.ambient_light_energy = 1.5
		var we = WorldEnvironment.new()
		we.environment = env
		root_3d.add_child(we)

		# 影片式骰子滚动机 — 保持线框关闭
		_dice_roller = DiceCinematicRoller3D.new()
		_dice_roller.debug_visible = false
		_dice_roller.stage_size = Vector3(4.0, 2.5, 3.0)
		_dice_roller.spawn_dice_from_definitions_on_ready = false
		_dice_roller.auto_layout_on_add_remove = false  # 关闭自动布局，由我们手动分行排列
		_dice_roller.roll_duration = 1.4
		_dice_roller.bounce_height = 1.0
		_dice_roller.bounce_count = 3.0
		_dice_roller.spin_turns = 10.0
		_dice_roller.settle_start = 0.70
		_dice_roller.per_die_delay = 0.06
		_dice_roller.dice_spacing = 1.0
		_dice_roller.spin_clearance = 1.1
		_dice_roller.all_dice_finished.connect(_on_3d_dice_finished)
		root_3d.add_child(_dice_roller)

		# SubViewportContainer 嵌入 2D UI
		_dice_svc = SubViewportContainer.new()
		_dice_svc.stretch = true
		_dice_svc.add_child(svp)
		_dice_svc.set_anchors_preset(Control.PRESET_FULL_RECT)

		# 放入 dice_tray 占位容器
		for c in dice_tray.get_children():
			c.queue_free()
		dice_tray.add_child(_dice_svc)


func _layout_dice_grid(dice: Array) -> void:
	# 分行布局：每行最多5个骰子，行间距通过 Z 轴分布
	var max_per_row := 5
	var spacing_x := 1.1
	var spacing_z := 1.2
	var total_rows := ceili(float(dice.size()) / float(max_per_row))

	# 用 stage 坐标设置位置（roller 局部坐标），再用 _to_world 转世界坐标
	for i in range(dice.size()):
		var row := i / max_per_row
		var col := i % max_per_row
		var cols_in_row: int = min(max_per_row, dice.size() - row * max_per_row)
		var x: float = (col - (cols_in_row - 1) * 0.5) * spacing_x
		var z: float = (total_rows - 1) * 0.5 * spacing_z - row * spacing_z
		var die := dice[i] as DiceDie3D
		# 用 roller 的 _to_world 把 stage 坐标转成世界坐标，直接设 global_transform
		var world_pos: Vector3 = _dice_roller.to_global(Vector3(x, 0.05, z))
		die.global_transform = Transform3D(die.global_transform.basis, world_pos)
		die.freeze = true
		die.sleeping = true


func _make_check_die_definition() -> DiceDieDefinition3D:
	# 与 dice_3d demo 完全一致的圆角 D6 点阵面
	var def = DiceDieDefinition3D.custom("NumberDie", [
		DiceFace3D.new_face(1, &"one", NUMBER_1, "One"),
		DiceFace3D.new_face(6, &"six", NUMBER_6, "Six"),
		DiceFace3D.new_face(2, &"two", NUMBER_2, "Two"),
		DiceFace3D.new_face(5, &"five", NUMBER_5, "Five"),
		DiceFace3D.new_face(3, &"three", NUMBER_3, "Three"),
		DiceFace3D.new_face(4, &"four", NUMBER_4, "Four"),
	])
	def.edge_length = 0.65
	def.body_shape = DiceDie3D.BodyShape.ROUNDED
	def.face_decoration_scale = 0.75
	return def


func _die_color(index: int) -> Color:
	# 截图中的 pastel 骰子颜色
	var palette = [
		Color("f0c76c"),  # 暖黄
		Color("b8e0d4"),  # 薄荷
		Color("e8a598"),  # 珊瑚
		Color("a8c68f"),  # 鼠尾草绿
		Color("c4a8d8"),  # 薰衣草
		Color("f0a8c0"),  # 柔粉
	]
	return palette[index % palette.size()]


func _on_3d_dice_finished(_results: Dictionary):
	_on_dice_settled(_pending_total_success, _pending_required)


func _on_dice_settled(actual_success: int, required: int):
	var is_success = actual_success >= required

	result_lbl.visible = true
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
		# combined 检定：取两个属性的平均值（四舍五入），避免骰子过多
		var attr_list = check.get("attributes", [])
		if attr_list.size() >= 2:
			var a = attrs.get(attr_list[0], 0)
			var b = attrs.get(attr_list[1], 0)
			total = int(round(float(a + b) * 0.5))
		elif attr_list.size() == 1:
			total = attrs.get(attr_list[0], 0)
		else:
			total = 0
	# 限制最大骰子数，避免画面拥挤
	return clamp(total, 1, 8)

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
