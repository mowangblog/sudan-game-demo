# RiteDetailPopup.gd
# 仪式详情弹窗 — 点击仪式后弹出，显示介绍 + 拖入卡牌区
# 每个仪式有自己的 slots 配置，动态生成卡槽

extends Window

signal rite_configured(rite_data: Dictionary, slot_cards: Array)
signal cancelled()

const C = {
	BG_DEEP=Color("1a0f0a"),BG_PANEL=Color("2d1c12"),
	GOLD=Color("c8a84e"),GOLD_HI=Color("e8d48b"),GOLD_LO=Color("8a6820"),
	TEXT=Color("f0e6c8"),DIM=Color("a09070"),
	FAIL=Color("aa3030"),SHADOW=Color("00000099"),
}

var rite_data: Dictionary = {}
var slot_containers: Array = []  # 每个元素是 {"node": Panel, "config": Dictionary, "card": Dictionary}
var hand_cards: Array = []  # 可从底部手牌区获取

# 初始化弹窗
func setup(rite: Dictionary, available_chars: Array, active_sultan_card: Dictionary):
	rite_data = rite
	title = "📜 %s" % rite.get("name", "?")
	size = Vector2(520, 500)
	unresizable = true
	popup_window = true
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	# 清空旧内容
	for child in get_children():
		child.queue_free()
	
	_build_content(rite, available_chars, active_sultan_card)

# 构建内容
func _build_content(rite: Dictionary, available_chars: Array, active_sultan_card: Dictionary):
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.add_theme_constant_override("margin_left", 14)
	vb.add_theme_constant_override("margin_right", 14)
	vb.add_theme_constant_override("margin_top", 14)
	vb.add_theme_constant_override("margin_bottom", 14)
	add_child(vb)
	
	# ---- 标题 ----
	var title_lbl = Label.new()
	title_lbl.text = rite.get("name", "?")
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", C.GOLD)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title_lbl)
	
	# ---- 描述 ----
	var desc_lbl = Label.new()
	desc_lbl.text = rite.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", C.TEXT)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc_lbl)
	
	vb.add_child(_sep())
	
	# ---- 检定信息 ----
	var check = rite.get("check", {})
	var check_text = "检定："
	if check.type == "solo":
		var attr_name = {"phy":"体魄","com":"战斗","sur":"生存","soc":"社交","cha":"魅力","ste":"隐匿","wis":"智慧","mag":"魔力"}.get(check.attribute, check.attribute)
		check_text += "%s · 需%d成功" % [attr_name, check.required_successes]
	elif check.type == "combined":
		var attr_names = []
		for a in check.get("attributes", []):
			attr_names.append({"phy":"体魄","com":"战斗","sur":"生存","soc":"社交","cha":"魅力","ste":"隐匿","wis":"智慧","mag":"魔力"}.get(a, a))
		check_text += "、".join(attr_names) + " · 需%d成功" % check.required_successes
	var check_lbl = Label.new()
	check_lbl.text = check_text
	check_lbl.add_theme_font_size_override("font_size", 12)
	check_lbl.add_theme_color_override("font_color", C.DIM)
	vb.add_child(check_lbl)
	
	# ---- 奖励信息 ----
	var outcomes = rite.get("outcomes", {})
	var success_out = outcomes.get("success", {})
	var reward_text = "成功："
	if success_out.has("gold"):
		reward_text += "💰%+d " % success_out.gold
	if success_out.has("power"):
		reward_text += "权%+d " % success_out.power
	if success_out.has("good"):
		reward_text += "善%+d " % success_out.good
	if success_out.has("evil"):
		reward_text += "恶%+d " % success_out.evil
	if success_out.has("hero"):
		reward_text += "侠%+d " % success_out.hero
	if success_out.has("spirit"):
		reward_text += "灵%+d " % success_out.spirit
	var reward_lbl = Label.new()
	reward_lbl.text = reward_text
	reward_lbl.add_theme_font_size_override("font_size", 12)
	reward_lbl.add_theme_color_override("font_color", Color("4a9a3a"))
	vb.add_child(reward_lbl)
	
	vb.add_child(_sep())
	
	# ---- 卡槽区 ----
	vb.add_child(_lbl("🃏 拖入卡牌", 14, C.GOLD))
	
	slot_containers.clear()
	var slots = rite.get("slots", [])
	for i in range(slots.size()):
		var slot_cfg = slots[i]
		var slot_node = _create_slot(i, slot_cfg, available_chars, active_sultan_card)
		vb.add_child(slot_node)
		slot_containers.append({
			"node": slot_node,
			"config": slot_cfg,
			"card": {}
		})
	
	vb.add_child(_sep())
	
	# ---- 按钮区 ----
	var btn_hb = HBoxContainer.new()
	btn_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hb.add_theme_constant_override("separation", 20)
	vb.add_child(btn_hb)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "✅ 确认配置"
	confirm_btn.custom_minimum_size = Vector2(140, 40)
	confirm_btn.add_theme_font_size_override("font_size", 14)
	confirm_btn.pressed.connect(_on_confirm)
	btn_hb.add_child(confirm_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(100, 40)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.pressed.connect(func():
		cancelled.emit()
		queue_free()
	)
	btn_hb.add_child(cancel_btn)

# 创建卡槽
func _create_slot(index: int, slot_cfg: Dictionary, available_chars: Array, active_sultan_card: Dictionary) -> PanelContainer:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(480, 70)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("1a1210")
	sb.set_corner_radius_all(8)
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = C.GOLD_LO
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	slot.add_theme_stylebox_override("panel", sb)
	
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	slot.add_child(hb)
	
	# 槽位标签
	var slot_type = slot_cfg.get("type", "character")
	var required_tags = slot_cfg.get("required_tags", [])
	var optional = slot_cfg.get("optional", false)
	
	var tag_text = ""
	if required_tags.size() > 0:
		tag_text = "（需:%s）" % "、".join(required_tags)
	var opt_text = "（可选）" if optional else ""
	
	var label = Label.new()
	label.text = "槽位%d：%s%s %s" % [index+1, "角色" if slot_type=="character" else "苏丹卡", tag_text, opt_text]
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", C.DIM)
	label.custom_minimum_size = Vector2(200, 0)
	hb.add_child(label)
	
	# 拖放区域（占位符，实际拖放逻辑在主场景处理）
	var drop_hint = Label.new()
	drop_hint.text = "← 从下方手牌区拖入卡牌"
	drop_hint.add_theme_font_size_override("font_size", 11)
	drop_hint.add_theme_color_override("font_color", Color("605040"))
	drop_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(drop_hint)
	
	# 设置拖放数据
	slot.set_meta("slot_index", index)
	slot.set_meta("slot_config", slot_cfg)
	
	return slot

# 确认配置
func _on_confirm():
	var slot_cards = []
	for sc in slot_containers:
		slot_cards.append(sc.get("card", {}))
	rite_configured.emit(rite_data, slot_cards)
	queue_free()

# 辅助
func _lbl(t: String, s: int, c: Color) -> Label:
	var l = Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", s)
	l.add_theme_color_override("font_color", c)
	return l

func _sep() -> HSeparator:
	var s = HSeparator.new()
	return s
