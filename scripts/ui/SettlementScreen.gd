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
const RiteItemEffectResolver = preload("res://scripts/game/RiteItemEffectResolver.gd")

const POPUP_BG = preload("res://assets/images/ui/tanchuang_bg_jiugongge.png")
const POPUP_BG_MARGIN := 80   # 九宫格四角固定边宽（像素），按实际角花尺寸调整

const JIXU_BTN = preload("res://assets/images/ui/jixu.png")
const JIXU_BTN_SIZE := Vector2(140, 78)   # 按 jixu.png 实际比例(358x200)显示，避免变形

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

var rite_data: Dictionary = {}
var char_data: Dictionary = {}
var sultan_card_data: Dictionary = {}
var item_data: Array = []
var reward_text: String = ""

var narrative_vb: VBoxContainer
var _stage_log: VBoxContainer
var _tw_label: Label
var dice_vb: VBoxContainer
var char_lbl: Label
var attr_lbl: Label
var dice_tray: Control
var _dice_roller: DiceCinematicRoller3D
var _dice_svc: SubViewportContainer
var _pending_required: int = 0
var _stages: Array = []
var _stage_idx: int = 0
var _current_stage: Dictionary = {}
var _notifications: Array[String] = []
var _typewrite_timer: Timer
var _typewrite_full: String = ""
var _typewrite_cb: Callable
var _typewrite_pos: int = 0
var _stage_all_success: bool = true
var _stage_success_counts: Array[int] = []
var _rerolls_remaining: int = 0
var _item_effects: Dictionary = {}
var _reroll_btn: Button
var _pending_check: Dictionary = {}
var _pending_char: Dictionary = {}
var check_lbl: Label
var result_lbl: Label
var count_lbl: Label
var _result_overlay: Panel = null   # 骰子结果蒙版（覆盖骰子区，不占布局高度）
var _overlay_tween: Tween = null
var next_btn: TextureButton
var _close_btn: TextureButton   # 右上角物理角落的关闭按钮（叠加在父节点上）

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_on_viewport_resized)

# 按当前视口把面板居中到手牌区上方区域，并随窗口缩放实时重排
func _layout_in_map() -> void:
	var vs = get_viewport().size
	var bottom_limit = vs.y - 200 - 16
	var w = min(vs.x - 40, 1080)
	var h = min(bottom_limit - 28, 400)
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	position = Vector2((vs.x - w) / 2, (bottom_limit - h) / 2)

func _on_viewport_resized() -> void:
	_layout_in_map()
	_position_corner_close()

# 右上角物理角落的关闭按钮：叠加到父节点上（本节点是 PanelContainer，角上的子节点会被拉伸覆盖，
# 故放在父节点），真正贴弹窗角落，与 RiteDetailPopup 行为一致。本节点销毁时自动清理。
func _add_corner_close() -> void:
	if _close_btn != null and is_instance_valid(_close_btn):
		return
	_close_btn = TextureButton.new()
	_close_btn.texture_normal = preload("res://assets/images/ui/cha_btn.png")
	_close_btn.ignore_texture_size = true
	_close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_close_btn.custom_minimum_size = Vector2(32, 32)
	_close_btn.size = Vector2(32, 32)
	_close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_btn.mouse_entered.connect(func(): _close_btn.modulate = Color(1.15, 1.15, 1.15))
	_close_btn.mouse_exited.connect(func(): _close_btn.modulate = Color.WHITE)
	_close_btn.pressed.connect(func(): _finish_settlement())
	var p = get_parent()
	if p != null:
		p.add_child(_close_btn)
	_position_corner_close()
	tree_exiting.connect(func():
		if is_instance_valid(_close_btn):
			_close_btn.queue_free()
	)

func _position_corner_close() -> void:
	if _close_btn == null or not is_instance_valid(_close_btn):
		return
	var sz = 32
	_close_btn.custom_minimum_size = Vector2(sz, sz)
	_close_btn.size = Vector2(sz, sz)
	_close_btn.position = Vector2(position.x + size.x - sz - 4, position.y + 4)

func setup_and_show(rite: Dictionary, char_d: Dictionary, sultan: Dictionary, reward: String = "", items: Array = []):
	rite_data = rite
	char_data = char_d
	sultan_card_data = sultan
	item_data = items
	_item_effects = RiteItemEffectResolver.resolve(item_data)
	reward_text = reward
	_dice_roller = null
	_dice_svc = null

	_layout_in_map()

	for c in get_children(): c.queue_free()

	add_theme_stylebox_override("panel", _popup_bg_stylebox())

	_build_layout()
	_start_settlement()
	_add_corner_close()

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

	# 骰子结果改以"蒙版"形式覆盖在骰子区之上短暂显示（见 _result_overlay），不加入布局，避免撑高页面

	# 重投按钮
	_reroll_btn = Button.new()
	_reroll_btn.text = "🔄 重投"
	_reroll_btn.custom_minimum_size = Vector2(100, 32)
	_reroll_btn.add_theme_font_size_override("font_size", 12)
	_reroll_btn.visible = false
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	dice_vb.add_child(_reroll_btn)

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

	# 阶段日志容器（所有 stage 文本累积显示）
	_stage_log = VBoxContainer.new()
	_stage_log.add_theme_constant_override("separation", 10)
	narrative_vb.add_child(_stage_log)

	next_btn = TextureButton.new()
	next_btn.texture_normal = JIXU_BTN
	next_btn.ignore_texture_size = true
	next_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	next_btn.custom_minimum_size = JIXU_BTN_SIZE
	next_btn.size = JIXU_BTN_SIZE
	next_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	next_btn.visible = false
	next_btn.mouse_entered.connect(func(): next_btn.modulate = Color(1.15, 1.15, 1.15))
	next_btn.mouse_exited.connect(func(): next_btn.modulate = Color.WHITE)
	next_btn.pressed.connect(_on_next)
	narrative_vb.add_child(next_btn)

func _start_settlement():
	# 兼容旧仪式：无 stages 则自动生成
	if rite_data.has("stages") and not rite_data.stages.is_empty():
		_stages = rite_data.stages
	else:
		_stages = _auto_stage(rite_data)
	_stage_idx = 0
	_stage_all_success = true

	if not char_data.is_empty():
		char_lbl.text = "👤 " + char_data.get("name", "?")
		# 显示本次仪式需要的属性（角色当前对应属性值），而不是角色最高属性
		_update_required_attr_label()
	else:
		char_lbl.text = "无角色"
		attr_lbl.text = ""

	_animate_entrance()

# 显示本次仪式（所有阶段检定）需要的属性，以及角色当前对应属性值
func _update_required_attr_label() -> void:
	var ai_map = {"phy":"💪","com":"⚔","sur":"🏕","soc":"💬","cha":"💋","ste":"🕶","wis":"📚","mag":"🔮"}
	var an_map = {"phy":"体魄","com":"战斗","sur":"生存","soc":"社交","cha":"魅力","ste":"隐匿","wis":"智慧","mag":"魔力"}
	var attrs = char_data.get("attributes", {})
	var seen := {}
	var parts := []
	for stage in _stages:
		var check = stage.get("check")
		if check == null or not (check is Dictionary) or check.is_empty():
			continue
		var keys := []
		if check.has("attribute"):
			keys.append(check.attribute)
		elif check.has("attributes"):
			for k in check.attributes:
				keys.append(k)
		for k in keys:
			if seen.has(k):
				continue
			seen[k] = true
			parts.append("%s %s %d" % [ai_map.get(k, ""), an_map.get(k, k), attrs.get(k, 0)])
	if parts.is_empty():
		attr_lbl.text = "（无属性检定）"
	else:
		attr_lbl.text = "  ".join(PackedStringArray(parts))


func _animate_entrance():
	scale = Vector2(0.5, 0.5)
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(self, "modulate:a", 1.0, 0.2)
	t.tween_callback(func(): _process_stage())

func _auto_stage(rite: Dictionary) -> Array:
	var s := {}
	var c = rite.get("check", {})
	if not c is Dictionary:
		c = {}
	if not c.is_empty():
		s["check"] = c
		s["text"] = rite.get("description", "")
		var char_name = char_data.get("name","") if not char_data.is_empty() else ""
		s["success_text"] = rite.get("outcomes",{}).get("success",{}).get("narrative","")
		s["failure_text"] = rite.get("outcomes",{}).get("fail",{}).get("narrative","")
		if char_name != "":
			s["success_text"] = s["success_text"].replace("[角色]", char_name)
			s["failure_text"] = s["failure_text"].replace("[角色]", char_name)
		s["on_failure"] = "end"
	else:
		s["text"] = rite.get("description","")
		s["check"] = null
	# 复制 roll_rewards
	if rite.has("roll_rewards"):
		s["roll_rewards"] = rite.roll_rewards
	return [s]

func _process_stage():
	if _stage_idx >= _stages.size():
		_finish_settlement(); return
	var stage = _stages[_stage_idx]
	_hide_result_overlay(); check_lbl.text = ""
	_reroll_btn.visible = false
	# 清除上一阶段的骰子
	if _dice_roller:
		_dice_roller.reset_all()
		for d in _dice_roller.get_registered_dice():
			_dice_roller.remove_die(d)
	next_btn.visible = false

	# 分隔线 + 阶段文本标签
	if _stage_idx > 0:
		_stage_log.add_child(HSeparator.new())
	var stg_lbl = Label.new()
	stg_lbl.add_theme_font_size_override("font_size", 14)
	stg_lbl.add_theme_color_override("font_color", TEXT)
	stg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage_log.add_child(stg_lbl)

	_typewrite_on_label(stg_lbl, stage.get("text",""), func():
		var c = stage.get("check")
		if c != null and not c.is_empty():
			_do_check(stage, c)
		else:
			var ok_lbl = Label.new()
			ok_lbl.add_theme_font_size_override("font_size", 13)
			ok_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ok_lbl.add_theme_color_override("font_color", DIM)
			_stage_log.add_child(ok_lbl)
			_typewrite_on_label(ok_lbl, stage.get("success_text",""), func():
				next_btn.visible = true))

func _do_check(stage: Dictionary, check: Dictionary):
	_current_stage = stage
	_pending_check = check
	_pending_char = char_data
	
	# 计算可重投次数：只使用本次放入物品槽的情报。
	_rerolls_remaining = _item_effects.get("rerolls", 0) if stage.has("check") else 0
	
	var dc = _calc_dice_count(char_data, check, _item_effects)
	var req = check.get("required_successes", 1)
	var atype = "solo" if check.has("attribute") else check.get("type","solo")
	var an_name = ""
	if atype == "solo":
		var an_map = {"phy":"体魄","com":"战斗","sur":"生存","soc":"社交","cha":"魅力","ste":"隐匿","wis":"智慧","mag":"魔力"}
		an_name = an_map.get(check.get("attribute",""), "")
	
	var extra = ""
	if _rerolls_remaining > 0:
		extra = "  🔄×%d" % _rerolls_remaining
	var item_desc = _item_effects.get("descriptions", [])
	if not item_desc.is_empty():
		extra += "  🔎%s" % "；".join(item_desc)
	check_lbl.text = "%s检定 🎲×%d 需✅×%d%s" % [an_name, dc, req, extra]
	_pending_required = req
	_setup_3d_dice()
	_do_roll_dice(dc)


func _do_roll_dice(dice_count: int) -> void:
	_reroll_btn.visible = false
	var faces: Array[int] = []
	for _i in range(dice_count):
		faces.append(randi() % 6 + 1)
	if ResourceManager.gold_dice > 0 and dice_count >= 1:
		ResourceManager.gold_dice -= 1; faces.append(6)

	var def = DiceDieDefinition3D.custom("DotDie", [
		DiceFace3D.new_face(1,&"one",NUMBER_1,"One"), DiceFace3D.new_face(6,&"six",NUMBER_6,"Six"),
		DiceFace3D.new_face(2,&"two",NUMBER_2,"Two"), DiceFace3D.new_face(5,&"five",NUMBER_5,"Five"),
		DiceFace3D.new_face(3,&"three",NUMBER_3,"Three"), DiceFace3D.new_face(4,&"four",NUMBER_4,"Four"),
	])
	def.edge_length=0.65; def.body_shape=DiceDie3D.BodyShape.ROUNDED
	var wm = StandardMaterial3D.new(); wm.albedo_color=Color("e8e0d8"); wm.roughness=0.4
	var dice_to_roll: Array[DiceDie3D] = []; var req_res = []
	for i in range(faces.size()):
		var die = _dice_roller.create_die(def); die.body_material=wm
		dice_to_roll.append(die); req_res.append(faces[i])
	_layout_dice_grid(dice_to_roll)
	await get_tree().create_timer(0.1).timeout
	_dice_roller.roll_dice(dice_to_roll, req_res, {"per_die_delay":randf_range(0.01,0.08)})


func _on_reroll_pressed():
	_rerolls_remaining -= 1
	_reroll_btn.text = "🔄 重投 ×%d" % _rerolls_remaining
	_setup_3d_dice()
	_do_roll_dice(_calc_dice_count(_pending_char, _pending_check, _item_effects))

func _on_dice_settled_stage(_results: Dictionary):
	await get_tree().process_frame
	var cam_pos = Vector3(0,6.0,0.5)
	var sc:=0; var fc:=0
	var gm = StandardMaterial3D.new(); gm.albedo_color=Color("e8c84a"); gm.roughness=0.35; gm.metallic=0.3
	for r in _results.values():
		if not r is DiceRollResult: continue
		var die: DiceDie3D = r.die
		if not is_instance_valid(die): continue
		if _compute_visible_face(die,cam_pos) >= 4:
			sc+=1; die.body_material=gm
		else:
			fc+=1

	var ok = sc >= _pending_required
	_stage_success_counts.append(sc)
	if not ok: _stage_all_success=false
	_show_result_overlay(ok, sc, fc)

	# 在 stage_log 中追加结果文本（打字机）
	var res_lbl = Label.new()
	res_lbl.add_theme_font_size_override("font_size", 13)
	res_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	res_lbl.add_theme_color_override("font_color", GREEN if ok else FAIL)
	_stage_log.add_child(res_lbl)
	_typewrite_on_label(res_lbl, _current_stage.get("success_text" if ok else "failure_text",""), func():
		if not ok and _rerolls_remaining > 0:
			_reroll_btn.visible = true
			_reroll_btn.text = "🔄 重投 ×%d" % _rerolls_remaining
			# 重投可用：蒙层保留作结果展示，右侧不显示"继续"（让用户自行选择重投）
		else:
			if not ok and _current_stage.get("on_failure","")=="end":
				_stages=_stages.slice(0,_stage_idx+1)
			next_btn.visible = true)

func _on_next():
	_stage_idx+=1
	if _stage_idx < _stages.size():
		_process_stage()
	else:
		_finish_settlement()

func _finish_settlement():
	if reward_text != "":
		_show_reward_notification()
	settlement_done.emit({"rite":rite_data,"char":char_data,"sultan_card":sultan_card_data,"success":_stage_all_success,"notifications":_notifications.duplicate(),"stage_success_counts":_stage_success_counts.duplicate(),"stages":_stages.duplicate(true)})
	queue_free()

func _show_reward_notification():
	_notifications.append(reward_text)



# 打字机效果
func _typewrite_on_label(lbl: Label, text: String, cb: Callable):
	_tw_label=lbl; _typewrite_full=text; _typewrite_cb=cb; _typewrite_pos=0; lbl.text=""
	if _typewrite_timer==null:
		_typewrite_timer=Timer.new(); _typewrite_timer.one_shot=false; _typewrite_timer.wait_time=0.015
		add_child(_typewrite_timer); _typewrite_timer.timeout.connect(_tw_tick)
	_typewrite_timer.start()
	if not gui_input.is_connected(_tw_skip):
		gui_input.connect(_tw_skip)
	if not lbl.gui_input.is_connected(_tw_skip):
		lbl.gui_input.connect(_tw_skip)

func _tw_tick():
	if _typewrite_pos < _typewrite_full.length():
		_typewrite_pos+=1; _tw_label.text=_typewrite_full.substr(0,_typewrite_pos)
	else:
		_typewrite_timer.stop()
		_disable_skip()
		_typewrite_cb.call()

func _tw_skip(_e):
	if _e is InputEventMouseButton and _e.button_index == MOUSE_BUTTON_LEFT and _e.pressed:
		if _typewrite_timer: _typewrite_timer.stop()
		if _tw_label and is_instance_valid(_tw_label):
			_tw_label.text=_typewrite_full
		if _typewrite_cb.is_valid():
			_disable_skip()
			_typewrite_cb.call()


func _disable_skip():
	if _typewrite_timer: _typewrite_timer.stop()
	if gui_input.is_connected(_tw_skip): gui_input.disconnect(_tw_skip)


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
		_dice_roller.result_side = DiceCinematicRoller3D.ResultSide.POS_Y
		_dice_roller.stage_side_follows_result = false
		_dice_roller.stage_side = DiceCinematicRoller3D.ResultSide.NEG_Z
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
		_dice_roller.all_dice_finished.connect(_on_dice_settled_stage)
		root_3d.add_child(_dice_roller)

		_dice_svc = SubViewportContainer.new()
		_dice_svc.stretch = true
		_dice_svc.add_child(svp)
		_dice_svc.set_anchors_preset(Control.PRESET_FULL_RECT)

		for c in dice_tray.get_children():
			c.queue_free()
		dice_tray.add_child(_dice_svc)
		_ensure_result_overlay()


# 骰子结果以"蒙版"覆盖在骰子区（dice_tray）之上短暂显示，不加入布局，避免撑高页面
func _ensure_result_overlay() -> void:
	if _result_overlay != null and is_instance_valid(_result_overlay):
		return
	_result_overlay = Panel.new()
	_result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_overlay.visible = false
	var obs = StyleBoxFlat.new()
	obs.bg_color = Color(0, 0, 0, 0.8)
	obs.set_corner_radius_all(8)
	_result_overlay.add_theme_stylebox_override("panel", obs)
	var ovb = VBoxContainer.new()
	ovb.set_anchors_preset(Control.PRESET_FULL_RECT)
	ovb.alignment = BoxContainer.ALIGNMENT_CENTER
	ovb.add_theme_constant_override("separation", 8)
	_result_overlay.add_child(ovb)
	result_lbl = Label.new()
	result_lbl.add_theme_font_size_override("font_size", 24)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ovb.add_child(result_lbl)
	count_lbl = Label.new()
	count_lbl.add_theme_font_size_override("font_size", 14)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ovb.add_child(count_lbl)
	dice_tray.add_child(_result_overlay)

func _show_result_overlay(ok: bool, sc: int, fc: int) -> void:
	_ensure_result_overlay()
	if _overlay_tween != null and is_instance_valid(_overlay_tween):
		_overlay_tween.kill()
	result_lbl.text = "✅ 成功" if ok else "❌ 失败"
	result_lbl.add_theme_color_override("font_color", GREEN if ok else FAIL)
	count_lbl.text = "成功×%d  失败×%d  |  需×%d" % [sc, fc, _pending_required]
	count_lbl.add_theme_color_override("font_color", GREEN if ok else FAIL)
	# 不自动消失：蒙层常驻，待用户点右侧文字区的"继续"按钮收起（_on_next → _process_stage 会隐藏它）
	_result_overlay.visible = true
	_result_overlay.modulate.a = 0.0
	_overlay_tween = create_tween()
	_overlay_tween.tween_property(_result_overlay, "modulate:a", 1.0, 0.2)

func _hide_result_overlay() -> void:
	if _overlay_tween != null and is_instance_valid(_overlay_tween):
		_overlay_tween.kill()
	if _result_overlay != null and is_instance_valid(_result_overlay):
		_result_overlay.visible = false

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

func _calc_dice_count(cd: Dictionary, check: Dictionary, item_effects: Dictionary = {}) -> int:
	if cd.is_empty(): return 1
	var attrs = cd.get("attributes", {})
	var item_bonus = RiteItemEffectResolver.bonus_for_check(check, item_effects)
	var total = 0
	if check.get("type", "solo") == "solo":
		total = attrs.get(check.get("attribute", "phy"), 0) + item_bonus
	else:
		var attr_list = check.get("attributes", [])
		if attr_list.size() >= 2:
			var a = attrs.get(attr_list[0], 0)
			var b = attrs.get(attr_list[1], 0)
			total = int(round(float(a + b + item_bonus) * 0.5))
		elif attr_list.size() == 1:
			total = attrs.get(attr_list[0], 0) + item_bonus
	return clamp(total, 1, 8)
