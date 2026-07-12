# SorceressScene.gd
# 摄政王NPC页面 — 对话+令匣抽令交互
# 覆盖层弹窗式，不阻塞主场景

class_name SorceressScene
extends Control

const CARD_TITLE_FONT = preload("res://assets/fonts/云峰字库重庆山城棒棒体.ttf")
const CARD_SIZE := Vector2(100, 180)
const HAND_ZONE_H := 200   # 与 MainScene._bottom 手牌区高度一致
const STATUS_BAR_H := 38   # 与 StatusBar 顶栏高度一致

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

# 统一的弹窗背景：九宫格图 tanchuang_bg_jiugongge.png（3x3 缩放，整图完整展示、四角不拉伸）
const POPUP_BG = preload("res://assets/images/ui/tanchuang_bg_jiugongge.png")
const POPUP_BG_MARGIN := 80   # 九宫格四角固定边宽（像素），按实际角花尺寸调整

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
var _dialogue_scroll: ScrollContainer = null   # 对话文本滚动区：文字变长只在此区域内滚动，不挤压下方卡牌
var _dialogue_text: Label
var _btn_container: VBoxContainer
var _card_box: CardBox
var _swap_card: Control = null               # 换令时展示的只读当前令（现为居中 HBox 容器）
var _swap_on_confirm: Callable = func(): pass  # 换令确认回调（供卡牌点击复用）
var card_factory: CardFactory = null          # 注入：用于抽卡后真实展示卡牌
var _drawn_card: Control = null              # 抽卡后展示的真实令牌卡牌（含居中容器）
var _close_btn: TextureButton = null          # 右上角物理角落的关闭按钮（叠加在 self 上）

# ---- 进度面板 ----
var _progress_panel: ScrollContainer = null    # 进度面板（懒构建，复用对话区空间）
var _progress_inner: VBoxContainer = null
var _greeting_cbs: Dictionary = {}            # 缓存问候页回调，供进度页「返回」复用
var _noop: Callable = func(): pass


func _ready() -> void:
	_load_dialogues()
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)


# 按当前视口把主面板居中到地图区（状态栏下、手牌区上）
func _layout_main_panel(vs: Vector2) -> void:
	var r = Rect2(0, STATUS_BAR_H, vs.x, vs.y - STATUS_BAR_H - HAND_ZONE_H)
	# 背景换成九宫格图（content_margin=80），需放宽面板尺寸，避免内容被内缩得过窄
	var pw = clamp(r.size.x * 0.7, 640, min(r.size.x * 0.96, 1000))
	var ph = clamp(r.size.y * 0.72, 440, min(r.size.y * 0.95, 760))
	_main_panel.custom_minimum_size = Vector2(pw, ph)
	_main_panel.size = Vector2(pw, ph)
	_main_panel.position = Vector2(r.position.x + (r.size.x - pw) / 2.0, r.position.y + (r.size.y - ph) / 2.0)
	_position_close_btn()
	if is_instance_valid(_dialogue_text):
		_dialogue_text.custom_minimum_size = Vector2(pw - 320, 0)


func _on_viewport_resized() -> void:
	if not is_instance_valid(_main_panel):
		return
	_layout_main_panel(get_viewport().get_visible_rect().size)


func _load_dialogues() -> void:
	var f = FileAccess.open("res://data/sorceress_dialogues.json", FileAccess.READ)
	if f == null:
		print("[SorceressScene] WARNING: sorceress_dialogues.json not found")
		return
	var json = JSON.parse_string(f.get_as_text())
	f.close()
	if json != null:
		_dialogues = json


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


# 把关闭按钮贴到主面板物理右上角（叠加在 self，不受内容区 80px 缩进影响）
func _position_close_btn() -> void:
	if _close_btn == null or not is_instance_valid(_close_btn):
		return
	var sz = 32
	_close_btn.custom_minimum_size = Vector2(sz, sz)
	_close_btn.size = Vector2(sz, sz)
	_close_btn.position = Vector2(_main_panel.position.x + _main_panel.size.x - sz - 4, _main_panel.position.y + 4)


func _build_ui() -> void:
	# 全屏半透明背景
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.7)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.z_index = 100
	add_child(_bg)

	# 主面板 — 横长方形，居中于地图区（状态栏以下、手牌区以上），约占 2/3
	_main_panel = PanelContainer.new()
	_main_panel.name = "SorceressPanel"
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_panel.z_index = 110

	var vs = get_viewport().get_visible_rect().size
	_layout_main_panel(vs)

	_main_panel.add_theme_stylebox_override("panel", _popup_bg_stylebox())
	add_child(_main_panel)

	# 右上角物理角落的关闭按钮（叠加到 self，真正贴面板角落，不随内容区 80px 缩进影响）
	_close_btn = TextureButton.new()
	_close_btn.name = "SorceressClose"
	_close_btn.texture_normal = preload("res://assets/images/ui/cha_btn.png")
	_close_btn.ignore_texture_size = true
	_close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_close_btn.custom_minimum_size = Vector2(32, 32)
	_close_btn.size = Vector2(32, 32)
	_close_btn.z_index = 120
	_close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_btn.mouse_entered.connect(func(): _close_btn.modulate = Color(1.15, 1.15, 1.15))
	_close_btn.mouse_exited.connect(func(): _close_btn.modulate = Color.WHITE)
	_close_btn.pressed.connect(_on_leave)
	add_child(_close_btn)
	_position_close_btn()

	var outer_hb = HBoxContainer.new()
	outer_hb.add_theme_constant_override("separation", 14)
	_main_panel.add_child(outer_hb)

	# ---- 左侧：摄政王立绘区（缩小，固定高度） ----
	_portrait_area = PanelContainer.new()
	_portrait_area.custom_minimum_size = Vector2(140, 0)
	_portrait_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var port_sb = StyleBoxFlat.new()
	port_sb.bg_color = Color("1a0f0a")
	port_sb.set_corner_radius_all(12)
	port_sb.border_width_bottom = 2; port_sb.border_width_top = 2
	port_sb.border_width_left = 2; port_sb.border_width_right = 2
	port_sb.border_color = Color("8a682060")
	port_sb.content_margin_left = 8; port_sb.content_margin_right = 8
	port_sb.content_margin_top = 8; port_sb.content_margin_bottom = 8
	_portrait_area.add_theme_stylebox_override("panel", port_sb)
	outer_hb.add_child(_portrait_area)

	var port_vb = VBoxContainer.new()
	port_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	port_vb.add_theme_constant_override("separation", 8)
	_portrait_area.add_child(port_vb)

	# 摄政王立绘（替换为 shezhengwang.png）
	var portrait_tex = TextureRect.new()
	portrait_tex.name = "NpcPortrait"
	portrait_tex.texture = preload("res://assets/images/characters/shezhengwang.png")
	portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_tex.custom_minimum_size = Vector2(120, 180)
	portrait_tex.size = Vector2(120, 180)
	portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port_vb.add_child(portrait_tex)

	var name_lbl = Label.new()
	name_lbl.text = _dialogues.get("npc_name", "摄政王")
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", C.GOLD)
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

	# 对话文本区
	_dialogue_area = VBoxContainer.new()
	_dialogue_area.add_theme_constant_override("separation", 6)
	_dialogue_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vb.add_child(_dialogue_area)

	# 对话文本放在 ScrollContainer 内：文字变长只会在该区域滚动，不会把下方卡牌往下挤（卡牌位置固定）
	_dialogue_scroll = ScrollContainer.new()
	_dialogue_scroll.name = "DialogueScroll"
	_dialogue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED   # 只允许上下滚动
	_dialogue_area.add_child(_dialogue_scroll)

	_dialogue_text = Label.new()
	_dialogue_text.name = "DialogueText"
	_dialogue_text.add_theme_font_size_override("font_size", 13)
	_dialogue_text.add_theme_color_override("font_color", C.TEXT)
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.custom_minimum_size = Vector2(_main_panel.custom_minimum_size.x - 320, 0)
	_dialogue_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_text.size_flags_vertical = 0   # 不占布局高度，超出时在 ScrollContainer 内滚动，避免推挤下方卡牌
	_dialogue_text.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_text.gui_input.connect(_on_dialogue_click)
	_dialogue_scroll.add_child(_dialogue_text)

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
	_clear_drawn_card()
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
	_clear_drawn_card()
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
	_clear_drawn_card()
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
	if card_factory == null:
		return
	# 用真实卡牌样式展示当前摄政王令（与抽卡成功卡面一致）
	var card = card_factory.make_sultan_card_filled(card_data)
	# 卡面文字：类型名 + 剩余天数（与手牌/抽卡卡牌一致）
	var overlay = card.get_node_or_null("CardTextOverlay")
	if overlay:
		var title_lbl = overlay.get_node_or_null("TitleLbl") as Label
		if title_lbl:
			title_lbl.text = TN.get(card_data.get("type", "LUST"), "?")
		var count_lbl = overlay.get_node_or_null("CountLbl") as Label
		if count_lbl:
			count_lbl.text = "%d天" % GameManager.sultan_card_days_left
	# 交互：点击卡牌直接进入确认步骤（只读展示；若被拖动则松手弹回原位）
	card._on_click = func(): _show_swap_confirm(card_data)
	card.drag_ended.connect(func(_c: Control, _p: Vector2): card.snap_back())
	# 柔和"落入"动画（与抽卡卡一致：底部枢轴 + 缩放生长 + 淡入，无夸张回弹）
	var cs = card.custom_minimum_size
	card.pivot_offset = Vector2(cs.x * 0.5, cs.y)
	card.scale = Vector2(0.92, 0.92)
	card.modulate.a = 0.0
	var pop = card.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	pop.tween_property(card, "modulate:a", 1.0, 0.3)
	pop.parallel().tween_property(card, "scale", Vector2(1.0, 1.0), 0.4)
	# 居中展示在对话区下方；容器固定高度不 expand，避免文字变长时挤压卡牌
	var hb = HBoxContainer.new()
	hb.name = "SwapCardHolder"
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.custom_minimum_size = Vector2(0, cs.y)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(card)
	_dialogue_area.add_child(hb)
	_swap_card = hb


func _apply_card_title_style(label: Label, font_size: int = 17) -> void:
	label.add_theme_font_override("font", CARD_TITLE_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("050403"))
	label.add_theme_color_override("font_shadow_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _clear_swap_card() -> void:
	if _swap_card and is_instance_valid(_swap_card):
		_swap_card.queue_free()
		_swap_card = null


# 抽卡成功后：在对话区下方真实展示抽到的令牌卡牌（与手牌令牌同外观，仅展示不可拖拽）
func _show_drawn_card(card_data: Dictionary) -> void:
	_clear_drawn_card()
	if card_factory == null:
		return
	# 抽到真实卡牌后，隐藏令匣动画占位，给卡牌让出空间（下次抽卡由 open_for_draw 重新显示）
	if is_instance_valid(_card_box):
		_card_box.visible = false
	var card = card_factory.make_sultan_card_filled(card_data)
	# 卡面文字：类型名 + 剩余天数（与手牌令牌一致）
	var overlay = card.get_node_or_null("CardTextOverlay")
	if overlay:
		var title_lbl = overlay.get_node_or_null("TitleLbl") as Label
		if title_lbl:
			title_lbl.text = TN.get(card_data.get("type", "LUST"), "?")
		var count_lbl = overlay.get_node_or_null("CountLbl") as Label
		if count_lbl:
			count_lbl.text = "%d天" % GameManager.sultan_card_days_left
	# 纯展示：禁用拖拽/点击，避免 DraggableCard 在弹窗内被拖走
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 柔和"落入"动画（参考手牌令牌落入手牌：位移+淡入、无夸张回弹）
	# 受 VBox 布局限制不能改 position，改用底部枢轴 + 缩放生长 + 淡入，呈现从下往上浮现
	var cs = card.custom_minimum_size
	card.pivot_offset = Vector2(cs.x * 0.5, cs.y)
	card.scale = Vector2(0.92, 0.92)
	card.modulate.a = 0.0
	var pop = card.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	pop.tween_property(card, "modulate:a", 1.0, 0.3)
	pop.parallel().tween_property(card, "scale", Vector2(1.0, 1.0), 0.4)
	# 居中展示在对话区下方（令匣之后）；卡牌容器固定高度、不 expand，确保打字机过程中文字变长时牌尺寸不被挤压变化
	var hb = HBoxContainer.new()
	hb.name = "DrawnCardHolder"
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.custom_minimum_size = Vector2(0, cs.y)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(card)
	_dialogue_area.add_child(hb)
	_drawn_card = hb


func _clear_drawn_card() -> void:
	if _drawn_card and is_instance_valid(_drawn_card):
		_drawn_card.queue_free()
		_drawn_card = null
	# 对话文本现在常驻 ScrollContainer 内（size_flags_vertical=0），无需恢复 expand


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
	# 不清空按钮：四个令按钮常驻；令牌描述 + 品级描述合并成一段
	var type_name = TN.get(type_key, "?")
	var type_desc = _dialogues.get("type_introduction", {}).get(type_key, {}).get("desc", "")
	var ranks = _dialogues.get("rank_introduction", {})
	var segs: PackedStringArray = []
	for r in ["STONE", "BRONZE", "SILVER", "GOLD"]:
		var t = ranks.get(r, {}).get("short", "").replace("{type}", type_name)
		segs.append("%s%s·%s" % [RN.get(r, ""), RG.get(r, ""), t])
	var merged = "%s\n\n—— %s令 · 四个品级（由低到高） ——\n%s" % [type_desc, type_name, "  ｜  ".join(segs)]
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

	# 品级讲解台词 + 抽卡卡牌（卡牌固定在底部，入场动画立即播放）
	_phase = "card_reveal"
	_clear_buttons()
	_show_rank_commentary(_current_card_data)
	_show_drawn_card(_current_card_data)

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
	_clear_drawn_card()
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
		if _dialogue_scroll: _dialogue_scroll.scroll_vertical = 999999   # Godot4 无 scroll_to_bottom，设极大值自动钳到最大，滚到最底
		_stop_typing()
	else:
		_dialogue_text.text = _typing_prefix + _typing_target.left(_typing_pos)
		if _dialogue_scroll: _dialogue_scroll.scroll_vertical = 999999


func _stop_typing() -> void:
	if _typing_timer:
		_typing_timer.stop()
		_typing_timer.queue_free()
		_typing_timer = null


func _skip_typing() -> void:
	_stop_typing()
	if not _typing_target.is_empty():
		_dialogue_text.text = _typing_prefix + _typing_target
		if _dialogue_scroll: _dialogue_scroll.scroll_vertical = 999999
		_typing_target = ""


func _on_dialogue_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_skip_typing()


# ---- 按钮管理 ----
func _clear_buttons() -> void:
	for child in _btn_container.get_children():
		child.queue_free()


# 与「设置」弹窗关闭按钮同款样式：纯黑底 + 金字 + 字号14 + 高36 + 撑满宽度（无金描边）
func _make_btn(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", C.GOLD)
	btn.custom_minimum_size = Vector2(0, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nb = StyleBoxFlat.new()
	nb.bg_color = Color("0d0d0d")
	nb.set_corner_radius_all(6)
	nb.content_margin_left = 12; nb.content_margin_right = 12
	nb.content_margin_top = 6; nb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", nb)
	var hvb = nb.duplicate()
	hvb.bg_color = Color("1f1f1f")
	btn.add_theme_stylebox_override("hover", hvb)
	# 按下：黑底白字
	var pvb = nb.duplicate()
	pvb.bg_color = Color("000000")
	btn.add_theme_stylebox_override("pressed", pvb)
	btn.add_theme_color_override("font_hover_color", Color("f0f0f0"))
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.pressed.connect(callback)
	return btn


func _add_btn(text: String, callback: Callable) -> void:
	_btn_container.add_child(_make_btn(text, callback))


func _on_leave() -> void:
	visible = false
	_card_box.reset_box()
	_clear_swap_card()
	_clear_drawn_card()
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
	_clear_drawn_card()
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
