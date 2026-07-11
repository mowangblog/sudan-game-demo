# RiteDetailPopup.gd
# Overlay popup for configuring a rite. Owns slots and assigned card nodes.

class_name RiteDetailPopup
extends PanelContainer

signal committed(config: Dictionary)
signal cancelled(is_edit: bool, existing_entry)
signal card_return_requested(card_type: String, card_data: Dictionary)
signal resource_trimmed(slot_config: Dictionary, excess_data: Dictionary)
signal card_clicked(slot_type: String, card_data: Dictionary)
signal highlight_requested(slot)
signal validation_failed(message: String)

const POPUP_BG = preload("res://assets/images/ui/tanchuang_bg_jiugongge.png")
const POPUP_BG_MARGIN := 80   # 九宫格四角固定边宽（像素），按需调整

const CONFIRM_BTN_TEX = preload("res://assets/images/ui/queren_btn.png")
const CANCEL_BTN_TEX = preload("res://assets/images/ui/quxiao_btn.png")
const CONFIRM_CANCEL_BTN_SIZE := Vector2(150, 84)   # 确认/取消按钮显示尺寸，按需调整（图片原尺寸 358x200，比例 1.79）

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

const RiteSlotDropScript = preload("res://scripts/ui/RiteSlotDrop.gd")
const CARD_SIZE := Vector2(100, 180)
const HAND_ZONE_H := 200   # 与 MainScene._bottom 手牌区高度一致
const STATUS_BAR_H := 38   # 与 StatusBar 顶栏高度一致

var C: Dictionary = {}
var AN: Dictionary = {}
var rite: Dictionary = {}
var existing_entry = null
var is_edit: bool = false
var slot_nodes: Array = []
var assigned_cards: Array = []
var card_factory  # 由 MainScene 注入
var _split_container: HSplitContainer = null  # 分栏容器，缩放重排时同步更新分隔位置

func _ready() -> void:
	if not is_inside_tree():
		return
	get_viewport().size_changed.connect(_on_viewport_resized)

# 窗口缩放时，按当前视口重排位置/尺寸，并同步分栏分隔
func _on_viewport_resized() -> void:
	if not is_inside_tree():
		return
	_configure_frame(get_viewport().size)
	if is_instance_valid(_split_container):
		_split_container.split_offset = int(custom_minimum_size.x * 0.45)

func setup(p_rite: Dictionary, p_existing_entry, constants: Dictionary, viewport_size: Vector2) -> void:
	rite = p_rite
	existing_entry = p_existing_entry
	is_edit = existing_entry != null
	C = constants.get("C", {})
	AN = constants.get("AN", {})
	name = "RitePopup"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_configure_frame(viewport_size)
	_build_content()


func try_drop_card(card: PanelContainer, global_pos: Vector2) -> bool:
	for slot in slot_nodes:
		if not is_instance_valid(slot) or not slot.has_method("_can_drop_data"):
			continue
		if not slot.get_global_rect().has_point(global_pos):
			continue
		var data = card.get_meta("drag_data", {})
		if slot._can_drop_data(global_pos, data):
			slot._drop_data(global_pos, data)
			card.visible = false
			if not assigned_cards.has(card):
				assigned_cards.append(card)
			return true
	return false


func restore_assigned_cards() -> void:
	for card in assigned_cards:
		if is_instance_valid(card):
			card.visible = true
	for slot in slot_nodes:
		if is_instance_valid(slot) and slot.has_method("clear_card"):
			slot.clear_card()
	assigned_cards.clear()


func commit_assigned_cards() -> void:
	for slot in slot_nodes:
		if is_instance_valid(slot) and slot.has_method("clear_card"):
			slot.clear_card()
	assigned_cards.clear()


func _configure_frame(viewport_size: Vector2) -> void:
	# 自适应屏幕大小，居中于地图区（状态栏以下、手牌区以上），约占 2/3
	var r = Rect2(0, STATUS_BAR_H, viewport_size.x, viewport_size.y - STATUS_BAR_H - HAND_ZONE_H)
	var pw = clamp(r.size.x * 0.66, 360, min(r.size.x * 0.95, 1200))
	var ph = clamp(r.size.y * 0.7, 340, min(r.size.y * 0.95, 780))
	custom_minimum_size = Vector2(pw, ph)
	size = Vector2(pw, ph)
	position = Vector2(r.position.x + (r.size.x - pw) / 2.0, r.position.y + (r.size.y - ph) / 2.0)
	add_theme_stylebox_override("panel", _popup_bg_stylebox())


func _build_content() -> void:
	var split = HSplitContainer.new()
	split.split_offset = int(custom_minimum_size.x * 0.45)
	_split_container = split
	add_child(split)
	_build_left(split)
	_build_right(split)


func _build_left(split: HSplitContainer) -> void:
	var left = PanelContainer.new()
	var lps = StyleBoxFlat.new()
	lps.bg_color = Color("0d0804")
	lps.set_corner_radius_all(8)
	lps.border_width_bottom = 1
	lps.border_width_top = 1
	lps.border_width_left = 1
	lps.border_width_right = 1
	lps.border_color = C.get("GOLD_LO", Color("8a6820"))
	lps.content_margin_left = 14
	lps.content_margin_right = 14
	lps.content_margin_top = 12
	lps.content_margin_bottom = 12
	left.add_theme_stylebox_override("panel", lps)
	split.add_child(left)

	var lvb = VBoxContainer.new()
	lvb.add_theme_constant_override("separation", 12)
	lvb.alignment = BoxContainer.ALIGNMENT_CENTER
	lvb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(lvb)

	var title = Label.new()
	title.text = "📜 " + rite.get("name", "") + (" (已配置)" if is_edit else "")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", C.get("GREEN", Color("4a9a3a")) if is_edit else C.get("GOLD", Color("c8a84e")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvb.add_child(title)

	var slot_flow = FlowContainer.new()
	slot_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	slot_flow.add_theme_constant_override("h_separation", 16)
	slot_flow.add_theme_constant_override("v_separation", 10)
	lvb.add_child(slot_flow)

	slot_nodes.clear()
	var slots = rite.get("slots", [])
	for i in range(slots.size()):
		_add_slot_box(slot_flow, i, slots[i])

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lvb.add_child(spacer)
	_add_buttons(lvb)


func _add_slot_box(slot_flow: FlowContainer, index: int, slot_cfg: Dictionary) -> void:
	var slot_box = VBoxContainer.new()
	slot_box.add_theme_constant_override("separation", 9)
	slot_box.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_flow.add_child(slot_box)

	var label_text = slot_cfg.get("label", "")
	if label_text == "":
		match slot_cfg.get("type", ""):
			"character": label_text = "角色卡槽"
			"sultan_card": label_text = "摄政王令槽"
			"gold": label_text = "金币卡槽"
			"item": label_text = "物品卡槽"
			_: label_text = "卡牌槽位"
	if slot_cfg.get("optional", false) or not slot_cfg.get("required", true):
		label_text += "（可选）"

	var label = Label.new()
	label.text = "🃏 " + label_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", C.get("DIM", Color("a09070")))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_box.add_child(label)

	var slot = _create_slot(index, slot_cfg)
	slot.custom_minimum_size = CARD_SIZE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot_box.add_child(slot)
	_prefill_slot(slot, slot_cfg)
	slot_nodes.append(slot)


func _create_slot(index: int, slot_cfg: Dictionary):
	var slot = RiteSlotDropScript.new()
	slot.slot_index = index
	slot.slot_type = slot_cfg.get("type", "character")
	slot.required_tags = slot_cfg.get("required_tags", [])
	slot.is_optional = not slot_cfg.get("required", true)
	slot.accept = slot_cfg.get("accept", "")
	slot.accepts = slot_cfg.get("accepts", [])
	slot.max_cards = slot_cfg.get("max", 1)
	slot.card_factory = card_factory
	slot.card_removed.connect(func(_idx, card_data): card_return_requested.emit(_slot_type_to_card_type(slot.slot_type), card_data))
	slot.resource_trimmed.connect(func(_idx, excess_data): resource_trimmed.emit(slot_cfg, excess_data))
	slot.card_clicked.connect(func(card_data): card_clicked.emit(slot.slot_type, card_data))
	slot.empty_slot_clicked.connect(func(_idx): highlight_requested.emit(slot))
	return slot


func _prefill_slot(slot, slot_cfg: Dictionary) -> void:
	if not is_edit:
		return
	if slot_cfg.get("type", "") == "character" and not existing_entry.char.is_empty():
		slot._drop_data(Vector2.ZERO, {"type": "character", "data": existing_entry.char})
	elif slot_cfg.get("type", "") == "sultan_card" and not existing_entry.sultan_card.is_empty():
		slot._drop_data(Vector2.ZERO, {"type": "sultan_card", "data": existing_entry.sultan_card})
	elif slot_cfg.get("type", "") == "item":
		var item_data = _get_existing_item_for_slot(slot.slot_index)
		if not item_data.is_empty():
			slot._drop_data(Vector2.ZERO, {"type": "resource", "data": item_data})


func _add_buttons(lvb: VBoxContainer) -> void:
	var btn_hb = HBoxContainer.new()
	btn_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hb.add_theme_constant_override("separation", 16)
	lvb.add_child(btn_hb)

	var confirm_btn = TextureButton.new()
	confirm_btn.texture_normal = CONFIRM_BTN_TEX
	confirm_btn.expand = true
	confirm_btn.stretch_mode = TextureButton.STRETCH_MODE_KEEP_ASPECT_CENTERED
	confirm_btn.custom_minimum_size = CONFIRM_CANCEL_BTN_SIZE
	confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_hb.add_child(confirm_btn)

	var cancel_btn = TextureButton.new()
	cancel_btn.texture_normal = CANCEL_BTN_TEX
	cancel_btn.expand = true
	cancel_btn.stretch_mode = TextureButton.STRETCH_MODE_KEEP_ASPECT_CENTERED
	cancel_btn.custom_minimum_size = CONFIRM_CANCEL_BTN_SIZE
	cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_hb.add_child(cancel_btn)


func _build_right(split: HSplitContainer) -> void:
	var right = PanelContainer.new()
	var rps = StyleBoxFlat.new()
	rps.bg_color = Color("0d0804")
	rps.set_corner_radius_all(8)
	rps.border_width_bottom = 1
	rps.border_width_top = 1
	rps.border_width_left = 1
	rps.border_width_right = 1
	rps.border_color = C.get("GOLD_LO", Color("8a6820"))
	rps.content_margin_left = 14
	rps.content_margin_right = 14
	rps.content_margin_top = 12
	rps.content_margin_bottom = 12
	right.add_theme_stylebox_override("panel", rps)
	split.add_child(right)

	var rsc = ScrollContainer.new()
	rsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(rsc)

	var rvb = VBoxContainer.new()
	rvb.add_theme_constant_override("separation", 12)
	rvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rsc.add_child(rvb)

	var close_row = HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	rvb.add_child(close_row)
	var close_btn = TextureButton.new()
	close_btn.texture_normal = preload("res://assets/images/ui/cha_btn.png")
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.custom_minimum_size = Vector2(28, 28)  # 原图 205×205 (1:1)
	close_btn.size = Vector2(28, 28)
	close_btn.mouse_entered.connect(func(): close_btn.modulate = Color(1.15, 1.15, 1.15))
	close_btn.mouse_exited.connect(func(): close_btn.modulate = Color.WHITE)
	close_btn.pressed.connect(_on_cancel_pressed)
	close_row.add_child(close_btn)

	var desc = Label.new()
	desc.text = rite.get("description", "")
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", C.get("TEXT", Color("f0e6c8")))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rvb.add_child(desc)
	rvb.add_child(HSeparator.new())
	_add_check_info(rvb)
	_add_reward_info(rvb)
	rvb.add_child(HSeparator.new())
	rvb.add_child(_label("🃏 将卡牌拖入左侧卡槽", 12, C.get("GOLD", Color("c8a84e"))))
	if _has_item_slot():
		rvb.add_child(_label("🔎 可选物品：情报卡可提供属性加成和重投", 11, C.get("DIM", Color("a09070"))))


func _add_check_info(rvb: VBoxContainer) -> void:
	var check = rite.get("check", {})
	if not check is Dictionary or check.is_empty():
		rvb.add_child(_label("检定：无需检定", 12, C.get("DIM", Color("a09070"))))
		return
	var text = "检定："
	if check.get("type", "solo") == "solo":
		text += "%s · 需%d成功" % [AN.get(check.get("attribute", ""), "?"), check.get("required_successes", 1)]
	elif check.get("type") == "combined":
		var names = []
		for attr in check.get("attributes", []):
			names.append(AN.get(attr, attr))
		text += "、".join(names) + " · 需%d成功" % check.get("required_successes", 1)
	var label = _label(text, 12, C.get("DIM", Color("a09070")))
	rvb.add_child(label)


func _add_reward_info(rvb: VBoxContainer) -> void:
	var out = rite.get("outcomes", {}).get("success", {})
	var text = "成功奖励："
	if out.has("gold"): text += "💰%+d " % out.gold
	if out.has("power"): text += "权%+d " % out.power
	if out.has("good"): text += "善%+d " % out.good
	if out.has("evil"): text += "恶%+d " % out.evil
	if out.has("hero"): text += "侠%+d " % out.hero
	if out.has("spirit"): text += "灵%+d " % out.spirit
	for attr in ["phy","com","sur","soc","cha","ste","wis","mag"]:
		if out.has(attr):
			text += "%s%+d " % [AN.get(attr, attr), out[attr]]
	rvb.add_child(_label(text, 12, C.get("GREEN", Color("4a9a3a"))))
	rvb.add_child(HSeparator.new())

	var fail_out = rite.get("outcomes", {}).get("fail", {})
	var fail_text = "失败后果："
	if fail_out.has("gold"): fail_text += "💰%+d " % fail_out.gold
	if fail_out.has("power"): fail_text += "权%+d " % fail_out.power
	if fail_out.has("good"): fail_text += "善%+d " % fail_out.good
	if fail_out.has("evil"): fail_text += "恶%+d " % fail_out.evil
	if fail_out.has("hero"): fail_text += "侠%+d " % fail_out.hero
	if fail_out.has("spirit"): fail_text += "灵%+d " % fail_out.spirit
	if fail_text == "失败后果：":
		fail_text = "失败：无特殊惩罚"
	var fail_label = _label(fail_text, 11, C.get("DIM", Color("a09070")))
	fail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rvb.add_child(fail_label)


func _on_confirm_pressed() -> void:
	var config = _collect_config()
	if not config.get("valid", false):
		validation_failed.emit("❌ 槽位未配置")
		return
	committed.emit(config)
	commit_assigned_cards()
	queue_free()


func _on_cancel_pressed() -> void:
	restore_assigned_cards()
	cancelled.emit(is_edit, existing_entry)
	queue_free()


func _collect_config() -> Dictionary:
	var char_data = {}
	var sultan_card_data = {}
	var gold_card_data = {}
	var item_cards: Array = []
	var valid = true
	for slot in slot_nodes:
		if not slot.current_card.is_empty():
			if slot.slot_type == "character":
				char_data = slot.current_card
			elif slot.slot_type == "sultan_card":
				sultan_card_data = slot.current_card
			elif slot.slot_type == "item":
				item_cards.append(slot.current_card)
			elif slot.slot_type == "gold" or slot.slot_type == "resource":
				gold_card_data = slot.current_card
		if not slot.is_optional and slot.current_card.is_empty():
			valid = false
	return {
		"valid": valid,
		"rite": rite,
		"char": char_data,
		"sultan_card": sultan_card_data,
		"gold": gold_card_data,
		"items": item_cards,
		"is_edit": is_edit,
		"existing": existing_entry,
	}


func _slot_type_to_card_type(slot_type: String) -> String:
	if slot_type == "character":
		return "character"
	if slot_type == "sultan_card":
		return "sultan_card"
	return "resource"


func _get_existing_item_for_slot(slot_index: int) -> Dictionary:
	if existing_entry == null:
		return {}
	var item_pos = 0
	var slots = rite.get("slots", [])
	for i in range(min(slot_index + 1, slots.size())):
		if slots[i].get("type", "") != "item":
			continue
		if i == slot_index:
			var items = existing_entry.get("items", [])
			if item_pos < items.size():
				return items[item_pos]
			return {}
		item_pos += 1
	return {}


func _has_item_slot() -> bool:
	for slot_cfg in rite.get("slots", []):
		if slot_cfg.get("type", "") == "item":
			return true
	return false


func _label(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
