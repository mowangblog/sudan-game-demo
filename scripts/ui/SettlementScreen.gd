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
const DOT_1 = preload(FACE_DIR + "number_1.svg")
const DOT_2 = preload(FACE_DIR + "number_2.svg")
const DOT_3 = preload(FACE_DIR + "number_3.svg")
const DOT_4 = preload(FACE_DIR + "number_4.svg")
const DOT_5 = preload(FACE_DIR + "number_5.svg")
const DOT_6 = preload(FACE_DIR + "number_6.svg")
const NUMBER_1 = DOT_1
const NUMBER_2 = DOT_2
const NUMBER_3 = DOT_3
const NUMBER_4 = DOT_4
const NUMBER_5 = DOT_5
const NUMBER_6 = DOT_6

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
var _pending_required: int = 0
var check_lbl: Label
var result_lbl: Label
var count_lbl: Label
var result_text: Label
var next_btn: Button

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup_and_show(rite: Dictionary, char_d: Dictionary, sultan: Dictionary):
	rite_data = rite
	char_data = char_d
	sultan_card_data = sultan
	_dice_roller = null
	_dice_svc = null

	var vs = get_viewport().size
	var bottom_limit = vs.y - 200 - 16
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
	split.split_offset = 400
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

	char_lbl = Label.new()
	char_lbl.add_theme_font_size_override("font_size", 16)
	char_lbl.add_theme_color_override("font_color", GOLD)
	char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_vb.add_child(char_lbl)

	attr_lbl = Label.new()
	attr_lbl.add_theme_font_size_override("font_size", 12)
	attr_lbl.add_theme_color_override("font_color", DIM)
	attr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_vb.add_child(attr_lbl)

	# 骰子规则提示
	var rule_lbl = Label.new()
	rule_lbl.text = "⚀⚁⚂ 1-3失败  |  ⚃⚄⚅ 4-6成功"
	rule_lbl.add_theme_font_size_override("font_size", 10)
	rule_lbl.add_theme_color_override("font_color", Color("706040"))
	rule_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_vb.add_child(rule_lbl)

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

	# 成功/失败计数
	count_lbl = Label.new()
	count_lbl.add_theme_font_size_override("font_size", 12)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.visible = false
	dice_vb.add_child(count_lbl)

	# === 右侧：叙事区 ===
	var right = ScrollContainer.new()
	split.add_child(right)

	narrative_vb = VBoxContainer.new()
	narrative_vb.add_theme_constant_override("separation", 12)
	narrative_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(narrative_vb)

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

	narrative_vb.add_child(HSeparator.new())

	stage_lbl = Label.new()
	stage_lbl.add_theme_font_size_override("font_size", 14)
	stage_lbl.add_theme_color_override("font_color", TEXT)
	stage_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative_vb.add_child(stage_lbl)

	result_text = Label.new()
	result_text.add_theme_font_size_override("font_size", 13)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.visible = false
	narrative_vb.add_child(result_text)

	next_btn = Button.new()
	next_btn.text = "继续 ▶"; next_btn.custom_minimum_size = Vector2(120, 36)
	next_btn.add_theme_font_size_override("font_size", 13)
	next_btn.visible = false
	next_btn.pressed.connect(_on_next)
	narrative_vb.add_child(next_btn)

func _start_settlement():
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
	_start_stage()

func _start_stage():
	var check = rite_data.get("check", {})
	var dice_count = _calc_dice_count(char_data, check)
	var required = check.get("required_successes", 1)

	var atype = "solo" if check.has("attribute") else check.get("type", "solo")
	var attr_name = ""
	if atype == "solo":
		var an_map = {"phy":"体魄","com":"战斗","sur":"生存","soc":"社交","cha":"魅力","ste":"隐匿","wis":"智慧","mag":"魔力"}
		attr_name = an_map.get(check.get("attribute",""), "")
	check_lbl.text = "%s检定 | 🎲×%d 需✅×%d" % [attr_name, dice_count, required]

	var narrative = rite_data.get("description", "仪式开始...")
	stage_lbl.text = "—" + narrative + "—"

	_setup_3d_dice()

	# 投骰：每颗骰子随机 1-6 面值
	var faces: Array[int] = []
	for _i in range(dice_count):
		faces.append(randi() % 6 + 1)

	# 金骰子：额外追加一颗，必为6
	if ResourceManager.gold_dice > 0 and dice_count >= 1:
		ResourceManager.gold_dice -= 1
		faces.append(6)

	_pending_required = required

	# 直角立方体 + SVG 点阵贴面，确保看到的点数 = 面值
	var def = DiceDieDefinition3D.custom("DotDie", [
		DiceFace3D.new_face(1, &"one",   NUMBER_1, "One"),
		DiceFace3D.new_face(6, &"six",   NUMBER_6, "Six"),
		DiceFace3D.new_face(2, &"two",   NUMBER_2, "Two"),
		DiceFace3D.new_face(5, &"five",  NUMBER_5, "Five"),
		DiceFace3D.new_face(3, &"three", NUMBER_3, "Three"),
		DiceFace3D.new_face(4, &"four",  NUMBER_4, "Four"),
	])
	def.edge_length = 0.65
	def.body_shape = DiceDie3D.BodyShape.ROUNDED

	var white_mat = StandardMaterial3D.new()
	white_mat.albedo_color = Color("e8e0d8")
	white_mat.roughness = 0.4

	var dice_to_roll: Array[DiceDie3D] = []
	var requested_results = []
	for i in range(faces.size()):
		var die = _dice_roller.create_die(def)
		die.body_material = white_mat
		dice_to_roll.append(die)
		requested_results.append(faces[i])

	_layout_dice_grid(dice_to_roll)
	await get_tree().create_timer(0.1).timeout
	_dice_roller.roll_dice(dice_to_roll, requested_results)

	result_lbl.visible = false
	count_lbl.visible = false
	result_text.visible = false
	next_btn.visible = false


func _setup_3d_dice():
	if _dice_roller:
		_dice_roller.reset_all()
		for d in _dice_roller.get_registered_dice():
			_dice_roller.remove_die(d)

	if not _dice_svc:
		var svp = SubViewport.new()
		svp.transparent_bg = true
		svp.size = Vector2i(640, 440)

		var root_3d = Node3D.new()
		root_3d.name = "DiceRoot"
		svp.add_child(root_3d)

		var cam = Camera3D.new()
		cam.position = Vector3(0, 6.0, 0.5)
		cam.rotation_degrees = Vector3(-84, 0, 0)
		cam.fov = 35.0
		root_3d.add_child(cam)

		var key = DirectionalLight3D.new()
		key.position = Vector3(2, 6, 2)
		key.light_energy = 5.0
		root_3d.add_child(key)

		var fill = OmniLight3D.new()
		fill.position = Vector3(-2, 2, -2)
		fill.light_energy = 3.0
		fill.omni_range = 10.0
		root_3d.add_child(fill)

		var fill2 = OmniLight3D.new()
		fill2.position = Vector3(3, 3, 0)
		fill2.light_energy = 2.0
		fill2.omni_range = 10.0
		root_3d.add_child(fill2)

		var env = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0, 0, 0, 0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(1.0, 1.0, 1.0)
		env.ambient_light_energy = 1.5
		var we = WorldEnvironment.new()
		we.environment = env
		root_3d.add_child(we)

		_dice_roller = DiceCinematicRoller3D.new()
		_dice_roller.debug_visible = false
		_dice_roller.stage_size = Vector3(4.0, 2.5, 3.0)
		_dice_roller.spawn_dice_from_definitions_on_ready = false
		_dice_roller.auto_layout_on_add_remove = false
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

		_dice_svc = SubViewportContainer.new()
		_dice_svc.stretch = true
		_dice_svc.add_child(svp)
		_dice_svc.set_anchors_preset(Control.PRESET_FULL_RECT)

		for c in dice_tray.get_children():
			c.queue_free()
		dice_tray.add_child(_dice_svc)


func _layout_dice_grid(dice: Array) -> void:
	var max_per_row := 5
	var spacing_x := 1.1
	var spacing_z := 1.2
	var total_rows := ceili(float(dice.size()) / float(max_per_row))

	for i in range(dice.size()):
		var row := i / max_per_row
		var col := i % max_per_row
		var cols_in_row: int = min(max_per_row, dice.size() - row * max_per_row)
		var x: float = (col - (cols_in_row - 1) * 0.5) * spacing_x
		var z: float = (total_rows - 1) * 0.5 * spacing_z - row * spacing_z
		var die := dice[i] as DiceDie3D
		var world_pos: Vector3 = _dice_roller.to_global(Vector3(x, 0.05, z))
		die.global_transform = Transform3D(die.global_transform.basis, world_pos)
		die.freeze = true
		die.sleeping = true


func _on_3d_dice_finished(_results: Dictionary):
	await get_tree().process_frame
	var cam_pos = Vector3(0, 6.0, 0.5)  # 摄像机位置

	var success_count := 0
	var fail_count := 0
	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color("e8c84a")
	gold_mat.roughness = 0.35
	gold_mat.metallic = 0.3

	for result in _results.values():
		if not result is DiceRollResult:
			continue
		var die: DiceDie3D = result.die
		if not is_instance_valid(die):
			continue
		# 用摄像机方向计算实际可见面值（不用 addon 的，俯视角下 addon 算的可能不对）
		var actual_val = _compute_visible_face(die, cam_pos)
		if actual_val >= 4:
			success_count += 1
			die.body_material = gold_mat
		else:
			fail_count += 1

	_on_dice_settled(success_count, _pending_required, success_count, fail_count)

func _compute_visible_face(die: DiceDie3D, cam_pos: Vector3) -> int:
	var die_pos = die.global_transform.origin
	var to_cam = (cam_pos - die_pos).normalized()
	var best_val = 0
	var best_dot = -2.0
	for slot in die.get_face_slots():
		var local_n = die.get_local_face_normal(slot)
		var world_n = (die.global_transform.basis * local_n).normalized()
		var dot = world_n.dot(to_cam)
		if dot > best_dot:
			best_dot = dot
			var face = die.get_face(slot)
			if face: best_val = face.value
	return best_val


func _on_dice_settled(success_count: int, required: int, succ: int, fail: int):
	var is_success = success_count >= required

	result_lbl.visible = true
	if is_success:
		result_lbl.text = "✅ 成功"
		result_lbl.add_theme_color_override("font_color", GREEN)
	else:
		result_lbl.text = "❌ 失败"
		result_lbl.add_theme_color_override("font_color", FAIL)

	count_lbl.visible = true
	count_lbl.text = "成功 × %d   失败 × %d  |  需 × %d" % [succ, fail, required]
	if is_success:
		count_lbl.add_theme_color_override("font_color", GREEN)
	else:
		count_lbl.add_theme_color_override("font_color", FAIL)

	result_text.visible = true
	var outcomes = rite_data.get("outcomes", {})
	var outcome = outcomes.get("success" if is_success else "fail", {})
	result_text.text = outcome.get("narrative", outcome.get("description", ""))
	if is_success:
		result_text.add_theme_color_override("font_color", GREEN)
	else:
		result_text.add_theme_color_override("font_color", FAIL)

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
		var attr_list = check.get("attributes", [])
		if attr_list.size() >= 2:
			var a = attrs.get(attr_list[0], 0)
			var b = attrs.get(attr_list[1], 0)
			total = int(round(float(a + b) * 0.5))
		elif attr_list.size() == 1:
			total = attrs.get(attr_list[0], 0)
	return clamp(total, 1, 8)

func _on_next():
	var success = result_lbl.text.contains("成功")
	settlement_done.emit({
		"rite": rite_data,
		"char": char_data,
		"sultan_card": sultan_card_data,
		"success": success,
		"success_count": 0,
		"required": 0,
	})
	queue_free()
