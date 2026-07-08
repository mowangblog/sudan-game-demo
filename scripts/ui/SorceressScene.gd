# SorceressScene.gd
# 女术士NPC页面 — 对话+令匣抽令交互
# 覆盖层弹窗式，不阻塞主场景

class_name SorceressScene
extends Control

# ---- 常量 ----
const C = {
	"GOLD": Color("c8a84e"), "GOLD_HI": Color("e8d48b"), "GOLD_LO": Color("8a6820"),
	"TEXT": Color("f0e6c8"), "DIM": Color("a09070"), "RED": Color("ff4040"),
	"SHADOW": Color("00000099"),
	"LUST": Color("8b3a5c"), "LUXURY": Color("7a6820"), "CONQUEST": Color("3a6a8b"), "MURDER": Color("8b2a2a"),
}
const TC = {"LUST": C.LUST, "LUXURY": C.LUXURY, "CONQUEST": C.CONQUEST, "MURDER": C.MURDER}
const TN = {"LUST": "欢愉", "LUXURY": "奢靡", "CONQUEST": "征伐", "MURDER": "杀戮"}
const RG = {"STONE": "★", "BRONZE": "★★", "SILVER": "★★★", "GOLD": "★★★★"}
const SC = {
	"STONE": Color("2a2018"), "BRONZE": Color("3a2e18"),
	"SILVER": Color("4a4028"), "GOLD": Color("5a5038"),
}
const SC_BORDER = {
	"STONE": Color("8a6820"), "BRONZE": Color("a08030"),
	"SILVER": Color("c0a848"), "GOLD": Color("e0c860"),
}

# ---- 状态 ----
var _dialogues: Dictionary = {}
var _phase: String = ""  # "greeting" / "type_intro" / "rank_intro" / "draw_box" / "card_reveal" / "swap" / "progress" / "chat"
var _is_first_draw: bool = true
var _current_card_data: Dictionary = {}
var _typing_tween: Tween = null
var _full_dialogue_text: String = ""  # 对话全文（用于点击跳过打字机）
var _on_complete: Callable = func(): pass  # 抽令完成后回调

# ---- 子节点 ----
var _bg: ColorRect
var _main_panel: PanelContainer
var _portrait_area: PanelContainer
var _dialogue_area: VBoxContainer
var _dialogue_text: Label
var _btn_container: VBoxContainer
var _card_box: CardBox

# ---- 品级讲解状态 ----
var _intro_types_shown: Array = []  # 已展示的类型
var _intro_current_type: String = ""


func _ready() -> void:
	_load_dialogues()
	_build_ui()


func _load_dialogues() -> void:
	var f = FileAccess.open("res://data/sorceress_dialogues.json", FileAccess.READ)
	if f == null:
		print("[SorceressScene] WARNING: sorceress_dialogues.json not found")
		return
	var json = JSON.parse_string(f.get_as_text())
	f.close()
	if json != null:
		_dialogues = json


func _build_ui() -> void:
	# 全屏半透明背景
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.7)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.z_index = 100
	add_child(_bg)

	# 主面板
	_main_panel = PanelContainer.new()
	_main_panel.name = "SorceressPanel"
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_panel.z_index = 110

	var vs = get_viewport().get_visible_rect().size
	var pw = min(vs.x - 60, 700)
	var ph = min(vs.y - 80, 550)
	_main_panel.custom_minimum_size = Vector2(pw, ph)
	_main_panel.position = Vector2((vs.x - pw) / 2, (vs.y - ph) / 2)

	var ps = StyleBoxFlat.new()
	ps.bg_color = Color("120808")
	ps.set_corner_radius_all(16)
	ps.border_width_bottom = 4; ps.border_width_top = 4
	ps.border_width_left = 4; ps.border_width_right = 4
	ps.border_color = C.GOLD
	ps.shadow_size = 20; ps.shadow_color = Color("c8a84e30")
	ps.content_margin_left = 24; ps.content_margin_right = 24
	ps.content_margin_top = 20; ps.content_margin_bottom = 20
	_main_panel.add_theme_stylebox_override("panel", ps)
	add_child(_main_panel)

	var outer_hb = HBoxContainer.new()
	outer_hb.add_theme_constant_override("separation", 16)
	_main_panel.add_child(outer_hb)

	# ---- 左侧：女术士立绘区 ----
	_portrait_area = PanelContainer.new()
	_portrait_area.custom_minimum_size = Vector2(180, 0)
	_portrait_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var port_sb = StyleBoxFlat.new()
	port_sb.bg_color = Color("1a0a12")
	port_sb.set_corner_radius_all(12)
	port_sb.border_width_bottom = 2; port_sb.border_width_top = 2
	port_sb.border_width_left = 2; port_sb.border_width_right = 2
	port_sb.border_color = Color("8b3a5c60")
	port_sb.content_margin_left = 8; port_sb.content_margin_right = 8
	port_sb.content_margin_top = 8; port_sb.content_margin_bottom = 8
	_portrait_area.add_theme_stylebox_override("panel", port_sb)
	outer_hb.add_child(_portrait_area)

	var port_vb = VBoxContainer.new()
	port_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	port_vb.add_theme_constant_override("separation", 8)
	_portrait_area.add_child(port_vb)

	# 女术士emoji头像（暂用文字替代美术资源）
	var avatar_lbl = Label.new()
	avatar_lbl.text = "🔮"
	avatar_lbl.add_theme_font_size_override("font_size", 64)
	avatar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_vb.add_child(avatar_lbl)

	var name_lbl = Label.new()
	name_lbl.text = _dialogues.get("npc_name", "女术士")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", C.LUST)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_vb.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = _dialogues.get("npc_description", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", C.DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(164, 0)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_vb.add_child(desc_lbl)

	# ---- 右侧：对话区+按钮区 ----
	var right_vb = VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 12)
	outer_hb.add_child(right_vb)

	# 关闭按钮行
	var close_hb = HBoxContainer.new()
	right_vb.add_child(close_hb)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_hb.add_child(spacer)
	var close_btn = Button.new()
	close_btn.text = "✕ 离开"
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.add_theme_color_override("font_color", C.DIM)
	close_btn.custom_minimum_size = Vector2(80, 32)
	close_btn.pressed.connect(_on_leave)
	close_hb.add_child(close_btn)

	# 对话文本区
	_dialogue_area = VBoxContainer.new()
	_dialogue_area.add_theme_constant_override("separation", 8)
	_dialogue_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vb.add_child(_dialogue_area)

	_dialogue_text = Label.new()
	_dialogue_text.name = "DialogueText"
	_dialogue_text.add_theme_font_size_override("font_size", 15)
	_dialogue_text.add_theme_color_override("font_color", C.TEXT)
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.custom_minimum_size = Vector2(pw - 240, 0)
	_dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_text.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_text.gui_input.connect(_on_dialogue_click)
	_dialogue_area.add_child(_dialogue_text)

	# 令匣区（初始隐藏）
	_card_box = CardBox.new()
	_card_box.visible = false
	_card_box.box_clicked.connect(_on_box_clicked)
	_dialogue_area.add_child(_card_box)

	# 按钮区
	_btn_container = VBoxContainer.new()
	_btn_container.name = "BtnContainer"
	_btn_container.add_theme_constant_override("separation", 8)
	right_vb.add_child(_btn_container)


# ---- 入口 ----
func open_for_draw(card_data: Dictionary, is_first: bool, on_complete: Callable) -> void:
	_current_card_data = card_data
	_is_first_draw = is_first
	_on_complete = on_complete
	visible = true
	_card_box.reset_box()

	if _is_first_draw:
		_show_first_time_intro()
	else:
		_show_draw_prompt()


func open_for_greeting(on_draw: Callable, on_swap: Callable, on_progress: Callable, on_chat: Callable) -> void:
	visible = true
	_card_box.reset_box()
	_clear_buttons()
	_set_dialogue(_dialogues.get("greeting", {}).get("default", "尊贵的阁下……有什么我可以效劳的吗？"))

	var draw_btn_data = _dialogues.get("entry_buttons", {})
	_add_btn(draw_btn_data.get("draw", "抽取摄政王令"), func(): on_draw.call())
	_add_btn(draw_btn_data.get("swap", "交换摄政王令"), func(): on_swap.call())
	_add_btn(draw_btn_data.get("progress", "查看进度"), func(): on_progress.call())
	_add_btn(draw_btn_data.get("chat", "与她聊聊"), func(): on_chat.call())


func open_for_swap(swap_tokens: int, on_confirm: Callable) -> void:
	visible = true
	_card_box.reset_box()
	_clear_buttons()
	if swap_tokens <= 0:
		_set_dialogue(_dialogues.get("swap_flow", {}).get("no_tokens", "您本局已用完所有换令机会。"))
		_add_btn("我知道了", func(): visible = false)
		return
	var pool_empty = DataManager._card_pool.size() == 0
	if pool_empty:
		_set_dialogue(_dialogues.get("swap_flow", {}).get("pool_empty", "令匣里已经空了……"))
		_add_btn("我知道了", func(): visible = false)
		return
	var prompt = _dialogues.get("swap_flow", {}).get("prompt", "")
	prompt = prompt.replace("{n}", str(swap_tokens))
	_set_dialogue(prompt)
	_add_btn("确认换令", func(): on_confirm.call())
	_add_btn("还是算了", func(): visible = false)


# ---- 首次抽令讲解 ----
func _show_first_time_intro() -> void:
	_phase = "type_intro"
	_intro_types_shown = []
	_intro_current_type = ""
	_clear_buttons()
	_set_dialogue(_dialogues.get("rank_introduction", {}).get("first_time_intro", ""))
	# 显示4种类型按钮
	var type_intro = _dialogues.get("type_introduction", {})
	var draw_btn_data = _dialogues.get("entry_buttons", {})
	for type_key in ["LUST", "LUXURY", "CONQUEST", "MURDER"]:
		var tdata = type_intro.get(type_key, {})
		var label = "%s令 — %s" % [tdata.get("name", TN.get(type_key, "?")), tdata.get("desc", "")]
		label = label.left(40)  # 截断长文本做按钮
		_add_btn(tdata.get("name", TN.get(type_key, "?")) + "令", func(): _show_type_detail(type_key))
	# 品级讲解按钮
	_add_btn("不同令的品级", func(): _show_rank_quality_intro())
	# 「开始抽令」按钮（跳过讲解）
	_add_btn(draw_btn_data.get("draw", "直接抽取摄政王令"), func(): _show_draw_prompt())


func _show_type_detail(type_key: String) -> void:
	var type_intro = _dialogues.get("type_introduction", {})
	var tdata = type_intro.get(type_key, {})
	_clear_buttons()
	_set_dialogue(tdata.get("desc", ""))
	_intro_types_shown.append(type_key)
	# 继续查看其他类型或直接抽令
	var remaining = ["LUST", "LUXURY", "CONQUEST", "MURDER"].filter(func(k): return not k in _intro_types_shown)
	for k in remaining:
		var kd = type_intro.get(k, {})
		_add_btn(kd.get("name", TN.get(k, "?")) + "令", func(): _show_type_detail(k))
	_add_btn("不同令的品级", func(): _show_rank_quality_intro())
	_add_btn("我知道了，抽令吧", func(): _show_draw_prompt())


func _show_rank_quality_intro() -> void:
	_clear_buttons()
	_set_dialogue(_dialogues.get("rank_quality_intro", ""))
	_add_btn("我知道了，抽令吧", func(): _show_draw_prompt())


# ---- 抽令流程 ----
func _show_draw_prompt() -> void:
	_phase = "draw_box"
	_clear_buttons()
	var draw_flow = _dialogues.get("draw_flow", {})
	var prompt = ""
	if _is_first_draw:
		prompt = draw_flow.get("prompt_box_first", draw_flow.get("prompt_box", ""))
	else:
		prompt = draw_flow.get("prompt_box_next", draw_flow.get("prompt_box", ""))
	_set_dialogue(prompt)
	_card_box.visible = true
	_card_box.reset_box()
	# 令匣居中定位
	var box_area_width = _dialogue_text.custom_minimum_size.x
	_card_box.position = Vector2((box_area_width - 120) / 2, 20)


func _on_box_clicked() -> void:
	# 令匣被点击 → 抽令动画
	_card_box.play_open_animation()

	# 从DataManager抽令（如果还没抽的话）
	if _current_card_data.is_empty():
		_current_card_data = DataManager.draw_sultan_card()
	if _current_card_data.is_empty():
		_set_dialogue("令匣已经空了……恭喜您，所有摄政王令都已被折断！")
		_card_box.visible = false
		_add_btn("我知道了", func(): visible = false)
		return

	# 通知GameManager记录令牌
	GameManager.draw_sultan_card_via_sorceress(_current_card_data)

	# 展示令牌大图
	_card_box.show_card_display(_current_card_data, TN, RG, TC, SC, SC_BORDER)

	# 品级讲解台词
	_phase = "card_reveal"
	_clear_buttons()
	_show_rank_commentary(_current_card_data)

	# 「我知道了」按钮
	_add_btn(_dialogues.get("draw_flow", {}).get("acknowledge_btn", "我知道了"), func(): _finish_draw())


func _show_rank_commentary(card_data: Dictionary) -> void:
	var card_type = card_data.get("type", "LUST")
	var rank = card_data.get("rank", "STONE")
	var type_name = TN.get(card_type, "?")

	# 先显示 flavor_by_type 的情感台词
	var flavor_data = _dialogues.get("flavor_by_type", {})
	var type_flavors = flavor_data.get(card_type, {})
	var flavor_text = type_flavors.get(rank, "")
	if flavor_text != "":
		_append_dialogue("\n\n" + flavor_text)

	# 品级讲解（首次详细，后续简略）
	var rank_intro = _dialogues.get("rank_introduction", {})
	if _is_first_draw:
		var rank_data = rank_intro.get(rank, {})
		var prefix = rank_data.get("prefix", "")
		prefix = prefix.replace("{type}", type_name)
		_append_dialogue("\n\n" + prefix)
	else:
		var rank_data = rank_intro.get(rank, {})
		var short = rank_data.get("short", "")
		short = short.replace("{type}", type_name)
		_append_dialogue("\n\n" + short)


func _finish_draw() -> void:
	_card_box.hide_card_display()
	_card_box.visible = false
	_is_first_draw = false  # 后续不再首次讲解
	visible = false
	_current_card_data = {}
	_on_complete.call()


const TYPING_SPEED_MS = 15  # 每字15ms

# ---- 对话渲染 ----
func _set_dialogue(text: String) -> void:
	_dialogue_text.text = ""
	_full_dialogue_text = text  # 保存全文供点击跳过
	# 打字机效果
	if _typing_tween:
		_typing_tween.kill()
	_typing_tween = create_tween()
	var chars = text.length()
	var duration = chars * TYPING_SPEED_MS / 1000.0
	# 逐步显示文本
	for i in range(chars + 1):
		var delay = duration * i / max(chars, 1)
		_typing_tween.tween_callback(func(): _dialogue_text.text = text.left(i)).set_delay(delay if i > 0 else 0)


func _append_dialogue(text: String) -> void:
	# 在现有对话后追加文本（打字机效果）
	var current = _dialogue_text.text
	var full = current + text
	_full_dialogue_text = full  # 保存全文供点击跳过
	if _typing_tween:
		_typing_tween.kill()
	_typing_tween = create_tween()
	var start_idx = current.length()
	var append_chars = text.length()
	var duration = append_chars * TYPING_SPEED_MS / 1000.0
	for i in range(append_chars + 1):
		var idx = start_idx + i
		var delay = duration * i / max(append_chars, 1)
		_typing_tween.tween_callback(func(): _dialogue_text.text = full.left(idx)).set_delay(delay if i > 0 else 0)


# 点击跳过：立即显示全文
func _skip_typing() -> void:
	if _typing_tween:
		_typing_tween.kill()
		_typing_tween = null
	if _full_dialogue_text != "":
		_dialogue_text.text = _full_dialogue_text


func _on_dialogue_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_skip_typing()


# ---- 按钮管理 ----
func _clear_buttons() -> void:
	for child in _btn_container.get_children():
		child.queue_free()


func _add_btn(text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", C.GOLD)
	btn.custom_minimum_size = Vector2(0, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = Color("2a1810")
	btn_sb.set_corner_radius_all(8)
	btn_sb.border_width_bottom = 2; btn_sb.border_width_left = 2; btn_sb.border_width_right = 2; btn_sb.border_width_top = 2
	btn_sb.border_color = C.GOLD_LO
	btn_sb.content_margin_left = 12; btn_sb.content_margin_right = 12
	btn_sb.content_margin_top = 6; btn_sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", btn_sb)

	var hover_sb = StyleBoxFlat.new()
	hover_sb.bg_color = Color("3a2818")
	hover_sb.set_corner_radius_all(8)
	hover_sb.border_width_bottom = 2; hover_sb.border_width_left = 2; hover_sb.border_width_right = 2; hover_sb.border_width_top = 2
	hover_sb.border_color = C.GOLD_HI
	hover_sb.content_margin_left = 12; hover_sb.content_margin_right = 12
	hover_sb.content_margin_top = 6; hover_sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("hover", hover_sb)

	btn.pressed.connect(callback)
	_btn_container.add_child(btn)


func _on_leave() -> void:
	visible = false
	_card_box.reset_box()
	if _phase == "draw_box" or _phase == "card_reveal":
		# 离开抽令流程但令已抽，需要通知主场景刷新
		_on_complete.call()
