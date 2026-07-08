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
const RN = {"STONE": "岩石", "BRONZE": "青铜", "SILVER": "白银", "GOLD": "黄金"}
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
var _typing_timer: Timer = null
var _typing_target: String = ""       # 目标全文
var _typing_prefix: String = ""       # 追加前已有文本
var _typing_pos: int = 0              # 当前进度（字符数）
var _on_complete: Callable = func(): pass  # 抽令完成后回调

# ---- 子节点 ----
var _bg: ColorRect
var _main_panel: PanelContainer
var _portrait_area: PanelContainer
var _dialogue_area: VBoxContainer
var _dialogue_text: Label
var _btn_container: VBoxContainer
var _card_box: CardBox
var _swap_card: PanelContainer = null        # 换令时展示的只读当前令
var _swap_on_confirm: Callable = func(): pass  # 换令确认回调（供卡牌点击复用）

# ---- 进度面板 ----
var _progress_panel: ScrollContainer = null    # 进度面板（懒构建，复用对话区空间）
var _progress_inner: VBoxContainer = null
var _greeting_cbs: Dictionary = {}            # 缓存问候页回调，供进度页「返回」复用
var _noop: Callable = func(): pass


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

	# 主面板 — 横长方形，手牌区上方
	_main_panel = PanelContainer.new()
	_main_panel.name = "SorceressPanel"
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_panel.z_index = 110

	var vs = get_viewport().get_visible_rect().size
	var pw = min(vs.x - 60, 700)
	var ph = min(vs.y - 260, 380)  # 留手牌区200+状态栏32+间距28
	_main_panel.custom_minimum_size = Vector2(pw, ph)
	# 置顶偏上
	_main_panel.position = Vector2((vs.x - pw) / 2, 36)

	var ps = StyleBoxFlat.new()
	ps.bg_color = Color("120808")
	ps.set_corner_radius_all(16)
	ps.border_width_bottom = 4; ps.border_width_top = 4
	ps.border_width_left = 4; ps.border_width_right = 4
	ps.border_color = C.GOLD
	ps.shadow_size = 20; ps.shadow_color = Color("c8a84e30")
	ps.content_margin_left = 20; ps.content_margin_right = 20
	ps.content_margin_top = 14; ps.content_margin_bottom = 14
	_main_panel.add_theme_stylebox_override("panel", ps)
	add_child(_main_panel)

	var outer_hb = HBoxContainer.new()
	outer_hb.add_theme_constant_override("separation", 14)
	_main_panel.add_child(outer_hb)

	# ---- 左侧：女术士立绘区（缩小，固定高度） ----
	_portrait_area = PanelContainer.new()
	_portrait_area.custom_minimum_size = Vector2(140, 0)
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
	avatar_lbl.add_theme_font_size_override("font_size", 48)
	avatar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_vb.add_child(avatar_lbl)

	var name_lbl = Label.new()
	name_lbl.text = _dialogues.get("npc_name", "女术士")
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", C.LUST)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_vb.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = _dialogues.get("npc_description", "")
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", C.DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(124, 0)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_vb.add_child(desc_lbl)

	# ---- 右侧：对话区+按钮区 ----
	var right_vb = VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 6)
	outer_hb.add_child(right_vb)

	# 关闭按钮行
	var close_hb = HBoxContainer.new()
	right_vb.add_child(close_hb)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_hb.add_child(spacer)
	var close_btn = Button.new()
	close_btn.text = "✕ 离开"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", C.DIM)
	close_btn.custom_minimum_size = Vector2(70, 28)
	close_btn.pressed.connect(_on_leave)
	close_hb.add_child(close_btn)

	# 对话文本区
	_dialogue_area = VBoxContainer.new()
	_dialogue_area.add_theme_constant_override("separation", 6)
	_dialogue_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vb.add_child(_dialogue_area)

	_dialogue_text = Label.new()
	_dialogue_text.name = "DialogueText"
	_dialogue_text.add_theme_font_size_override("font_size", 13)
	_dialogue_text.add_theme_color_override("font_color", C.TEXT)
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.custom_minimum_size = Vector2(pw - 200, 0)
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
	_btn_container.add_theme_constant_override("separation", 4)
	right_vb.add_child(_btn_container)


# ---- 入口 ----
func open_for_draw(card_data: Dictionary, is_first: bool, on_complete: Callable) -> void:
	_current_card_data = card_data
	_is_first_draw = is_first
	_on_complete = on_complete
	visible = true
	_card_box.reset_box()
	_clear_swap_card()
	_hide_progress_panel()

	if _is_first_draw:
		_show_first_time_intro()
	else:
		_show_draw_prompt()


func open_for_greeting(on_draw: Callable, on_swap: Callable, on_progress: Callable, on_chat: Callable) -> void:
	_greeting_cbs = {"draw": on_draw, "swap": on_swap, "progress": on_progress, "chat": on_chat}
	visible = true
	_card_box.reset_box()
	_clear_swap_card()
	_hide_progress_panel()
	_clear_buttons()
	_set_dialogue(_dialogues.get("greeting", {}).get("default", "尊贵的阁下……有什么我可以效劳的吗？"))

	var draw_btn_data = _dialogues.get("entry_buttons", {})
	_add_btn(draw_btn_data.get("draw", "抽取摄政王令"), func(): on_draw.call())
	_add_btn(draw_btn_data.get("swap", "交换摄政王令"), func(): on_swap.call())
	_add_btn(draw_btn_data.get("progress", "查看进度"), func(): on_progress.call())
	_add_btn(draw_btn_data.get("chat", "与她聊聊"), func(): _open_chat_menu())


func open_for_swap(swap_tokens: int, on_confirm: Callable) -> void:
	visible = true
	_card_box.reset_box()
	_clear_swap_card()
	_hide_progress_panel()
	_clear_buttons()
	_swap_on_confirm = on_confirm
	if swap_tokens <= 0:
		_set_dialogue(_dialogues.get("swap_flow", {}).get("no_tokens", "您本局已用完所有换令机会。"))
		_add_btn("我知道了", func(): visible = false)
		return
	var pool_empty = DataManager._card_pool.size() == 0
	if pool_empty:
		_set_dialogue(_dialogues.get("swap_flow", {}).get("pool_empty", "令匣里已经空了……"))
		_add_btn("我知道了", func(): visible = false)
		return
	var card = GameManager.active_sultan_card
	if card.is_empty():
		_set_dialogue("您手上现在还没有摄政王令，无法交换。")
		_add_btn("我知道了", func(): visible = false)
		return
	_show_swap_card(card)
	var prompt = _dialogues.get("swap_flow", {}).get("prompt", "")
	prompt = prompt.replace("{n}", str(swap_tokens))
	_set_dialogue(prompt)
	_add_btn("确认换令", func(): _show_swap_confirm(card))
	_add_btn("还是算了", func(): visible = false)


func _show_swap_confirm(card: Dictionary) -> void:
	_clear_swap_card()
	_clear_buttons()
	_set_dialogue(_dialogues.get("swap_flow", {}).get("confirm", "您确定要将此令放回令匣吗？"))
	_add_btn("确定放回令匣", func(): _swap_on_confirm.call())
	_add_btn("再想想", func(): open_for_swap(GameManager.swap_tokens, _swap_on_confirm))


func _show_swap_card(card_data: Dictionary) -> void:
	_clear_swap_card()
	var card = PanelContainer.new()
	card.name = "SwapCardPreview"
	card.custom_minimum_size = Vector2(90, 130)
	var rank = card_data.get("rank", "STONE")
	var card_type = card_data.get("type", "LUST")
	var bg_color = SC.get(rank, Color("2a2018"))
	var border_color = TC.get(card_type, C.LUST)
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color; sb.set_corner_radius_all(10)
	sb.border_width_bottom = 2; sb.border_width_top = 2; sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_color = border_color
	sb.content_margin_left = 6; sb.content_margin_right = 6; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	var tl = Label.new()
	tl.text = TN.get(card_type, "?")
	tl.add_theme_font_size_override("font_size", 16)
	tl.add_theme_color_override("font_color", border_color)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)

	var rl = Label.new()
	rl.text = RG.get(rank, "★")
	rl.add_theme_font_size_override("font_size", 12)
	rl.add_theme_color_override("font_color", C.GOLD)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rl)

	var nl = Label.new()
	nl.text = card_data.get("name", "?")
	nl.add_theme_font_size_override("font_size", 11)
	nl.add_theme_color_override("font_color", C.GOLD_HI)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nl)

	# 只读展示：点击该令直接进入确认步骤（不可拖拽）
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_show_swap_confirm(card_data)
	)
	_dialogue_area.add_child(card)
	_swap_card = card


func _clear_swap_card() -> void:
	if _swap_card and is_instance_valid(_swap_card):
		_swap_card.queue_free()
		_swap_card = null


# ---- 首次抽令讲解 ----
func _show_first_time_intro() -> void:
	_phase = "type_intro"
	_clear_buttons()
	_set_dialogue(_dialogues.get("rank_introduction", {}).get("first_time_intro", ""))
	_show_intro_buttons()


func _show_intro_buttons() -> void:
	# 一层：只保留抽令（品级询问已挪进「与她聊聊」常驻）
	_clear_buttons()
	var draw_btn_data = _dialogues.get("entry_buttons", {})
	_add_btn(draw_btn_data.get("draw", "直接抽取摄政王令"), func(): _show_draw_prompt())


func _open_chat_menu() -> void:
	# 「与她聊聊」：常驻的品级询问入口；四种令 + 返回（按钮常驻）
	_phase = "rank_intro"
	_clear_buttons()
	_set_dialogue(_dialogues.get("rank_quality_intro", "") + "\n\n—— 选择一种令，查看它的四个品级 ——")
	for type_key in ["LUST", "LUXURY", "CONQUEST", "MURDER"]:
		var tname = TN.get(type_key, "?")
		_add_btn("%s令" % tname, func(): _show_type_ranks(type_key))
	_add_btn("返回", func(): _back_to_greeting())


func _back_to_greeting() -> void:
	open_for_greeting(_greeting_cbs["draw"], _greeting_cbs["swap"], _greeting_cbs["progress"], _greeting_cbs["chat"])


func _show_type_ranks(type_key: String) -> void:
	# 不清空按钮：四个令按钮常驻；四个品级合并成一段说明
	var type_name = TN.get(type_key, "?")
	var ranks = _dialogues.get("rank_introduction", {})
	var segs: PackedStringArray = []
	for r in ["STONE", "BRONZE", "SILVER", "GOLD"]:
		var t = ranks.get(r, {}).get("short", "").replace("{type}", type_name)
		segs.append("%s%s·%s" % [RN.get(r, ""), RG.get(r, ""), t])
	var merged = "—— %s令 · 四个品级（由低到高） ——\n%s" % [type_name, "  ｜  ".join(segs)]
	_set_dialogue(merged)


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
	_card_box.play_open_animation()

	# 从DataManager抽令
	if _current_card_data.is_empty():
		_current_card_data = DataManager.draw_sultan_card()
	if _current_card_data.is_empty():
		_set_dialogue("令匣已经空了……恭喜您，所有摄政王令都已被折断！")
		_card_box.visible = false
		_add_btn("我知道了", func(): visible = false)
		return

	# 通知GameManager记录令牌
	GameManager.draw_sultan_card_via_sorceress(_current_card_data)

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
	_card_box.visible = false
	_is_first_draw = false
	var card_data = _current_card_data
	_current_card_data = {}
	visible = false
	_on_complete.call(card_data)


const CHARS_PER_TICK = 4  # 每帧推进4字符（Timer每60ms→等效15ms/字）

# ---- 对话渲染 ----
func _set_dialogue(text: String) -> void:
	_stop_typing()
	_dialogue_text.text = ""
	_typing_prefix = ""
	_typing_target = text
	_typing_pos = 0
	_start_typing()


func _append_dialogue(text: String) -> void:
	_stop_typing()
	_typing_prefix = _dialogue_text.text
	_typing_target = text
	_typing_pos = 0
	_start_typing()


func _start_typing() -> void:
	if _typing_target.is_empty():
		return
	_typing_timer = Timer.new()
	_typing_timer.wait_time = CHARS_PER_TICK * 15.0 / 1000.0  # 60ms/帧
	_typing_timer.one_shot = false
	_typing_timer.timeout.connect(_on_typing_tick)
	add_child(_typing_timer)
	_typing_timer.start()


func _on_typing_tick() -> void:
	_typing_pos += CHARS_PER_TICK
	if _typing_pos >= _typing_target.length():
		# 完成
		_dialogue_text.text = _typing_prefix + _typing_target
		_stop_typing()
	else:
		_dialogue_text.text = _typing_prefix + _typing_target.left(_typing_pos)


func _stop_typing() -> void:
	if _typing_timer:
		_typing_timer.stop()
		_typing_timer.queue_free()
		_typing_timer = null


func _skip_typing() -> void:
	_stop_typing()
	if not _typing_target.is_empty():
		_dialogue_text.text = _typing_prefix + _typing_target
		_typing_target = ""


func _on_dialogue_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_skip_typing()


# ---- 按钮管理 ----
func _clear_buttons() -> void:
	for child in _btn_container.get_children():
		child.queue_free()


func _make_btn(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", C.GOLD)
	btn.custom_minimum_size = Vector2(0, 30)
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
	return btn


func _add_btn(text: String, callback: Callable) -> void:
	_btn_container.add_child(_make_btn(text, callback))


func _on_leave() -> void:
	visible = false
	_card_box.reset_box()
	_clear_swap_card()
	_hide_progress_panel()
	if _phase == "draw_box" or _phase == "card_reveal":
		# 离开抽令流程但令已抽，需要通知主场景刷新
		_on_complete.call(_current_card_data)


# ---- 进度面板（Phase 4） ----
func open_for_progress() -> void:
	visible = true
	_stop_typing()
	_card_box.reset_box()
	_clear_swap_card()
	_clear_buttons()
	_dialogue_text.visible = false
	_show_progress_panel()
	_add_btn("返回", func():
		_hide_progress_panel()
		open_for_greeting(
			_greeting_cbs.get("draw", _noop),
			_greeting_cbs.get("swap", _noop),
			_greeting_cbs.get("progress", _noop),
			_greeting_cbs.get("chat", _noop)
		)
	)


func _ensure_progress_panel() -> void:
	if is_instance_valid(_progress_panel):
		return
	_progress_panel = ScrollContainer.new()
	_progress_panel.name = "ProgressPanel"
	_progress_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_progress_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_area.add_child(_progress_panel)
	_progress_inner = VBoxContainer.new()
	_progress_inner.add_theme_constant_override("separation", 4)
	_progress_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_panel.add_child(_progress_inner)


func _show_progress_panel() -> void:
	_ensure_progress_panel()
	_progress_panel.visible = true
	for c in _progress_inner.get_children():
		c.queue_free()
	var lines = _build_progress_text().split("\n")
	for line in lines:
		var lbl = Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 12)
		if line.begins_with("——"):
			lbl.add_theme_color_override("font_color", C.GOLD_HI)
		else:
			lbl.add_theme_color_override("font_color", C.TEXT)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_progress_inner.add_child(lbl)


func _hide_progress_panel() -> void:
	if is_instance_valid(_progress_panel):
		_progress_panel.visible = false
	_dialogue_text.visible = true


func _build_progress_text() -> String:
	var day = TurnManager.current_day
	var broken: Array = GameManager.consumed_cards
	var total = DataManager.sultan_cards.size()
	var lines: PackedStringArray = []
	lines.append("—— 当前进度 ——")
	lines.append("已存活 %d 天" % day)
	lines.append("折令 %d / %d" % [broken.size(), total])
	lines.append("")
	lines.append("—— 已折断的摄政王令 ——")
	if broken.is_empty():
		lines.append("（尚无）")
	else:
		for c in broken:
			var tn = TN.get(c.get("type", ""), "?")
			var rg = RG.get(c.get("rank", ""), "★")
			lines.append("%s %s  ✓" % [rg, tn])
	lines.append("")
	lines.append("—— 令池剩余 ——")
	var stats = DataManager.get_card_pool_stats()
	for tkey in ["LUST", "LUXURY", "CONQUEST", "MURDER"]:
		var tn = TN.get(tkey, "?")
		var s = stats.get(tkey, {})
		lines.append("%s：石%d 铜%d 银%d 金%d" % [tn, s.get("STONE", 0), s.get("BRONZE", 0), s.get("SILVER", 0), s.get("GOLD", 0)])
	lines.append("")
	var cur = GameManager.active_sultan_card
	lines.append("—— 当前手中 ——")
	if cur.is_empty():
		lines.append("（无摄政王令）")
	else:
		var tn = TN.get(cur.get("type", ""), "?")
		var rg = RG.get(cur.get("rank", ""), "★")
		lines.append("%s%s  （剩余 %d 天）" % [rg, tn, GameManager.sultan_card_days_left])
	return "\n".join(lines)
