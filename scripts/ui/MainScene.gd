# MainScene.gd — 摄政王的游戏复刻
# 参考原版布局：顶部状态栏 + 左侧地图 + 右侧事件面板 + 底部手牌

extends Control

const CARD_SIZE := Vector2(100, 180)

# ============ 调色板 ============
const C = {
	BG_DEEP=Color("1a0f0a"),BG_MID=Color("241712"),BG_PANEL=Color("2d1c12"),
	GOLD=Color("c8a84e"),GOLD_HI=Color("e8d48b"),GOLD_LO=Color("8a6820"),
	TEXT=Color("f0e6c8"),DIM=Color("a09070"),RED=Color("ff4040"),
	GREEN=Color("4a9a3a"),FAIL=Color("aa3030"),SHADOW=Color("00000099"),
	LUST=Color("8b3a5c"),LUXURY=Color("3a5c8b"),CONQUEST=Color("3a5b3a"),MURDER=Color("6b2a2a"),
}
const TC = {"LUST":C.LUST,"LUXURY":C.LUXURY,"CONQUEST":C.CONQUEST,"MURDER":C.MURDER}
const TN = {"LUST":"欢愉","LUXURY":"奢靡","CONQUEST":"征伐","MURDER":"杀戮"}
const RG = {"STONE":"★","BRONZE":"★★","SILVER":"★★★","GOLD":"★★★★"}
const AN = {"phy":"体魄","com":"战斗","sur":"生存","soc":"社交","cha":"魅力","ste":"隐匿","wis":"智慧","mag":"魔力"}
const AI = {"phy":"💪","com":"⚔","sur":"🏕","soc":"💬","cha":"💋","ste":"🕶","wis":"📚","mag":"🔮"}
# 品质配色：底色暗 + 边框亮 + 光晕半透明
const SC = {"STONE":Color(0.15,0.13,0.11), "BRONZE":Color(0.13,0.16,0.10), "SILVER":Color(0.12,0.13,0.15), "GOLD":Color(0.16,0.14,0.08)}
const SC_BORDER = {"STONE":Color(0.50,0.42,0.33), "BRONZE":Color(0.60,0.68,0.35), "SILVER":Color(0.62,0.66,0.70), "GOLD":Color(0.88,0.73,0.33)}
const SC_HOVER = {"STONE":Color(0.60,0.52,0.42), "BRONZE":Color(0.72,0.82,0.45), "SILVER":Color(0.74,0.78,0.82), "GOLD":Color(1.0,0.85,0.45)}
const SC_GLOW = {"STONE":Color(0.55,0.47,0.36,0.5), "BRONZE":Color(0.65,0.74,0.38,0.5), "SILVER":Color(0.68,0.71,0.74,0.5), "GOLD":Color(0.96,0.80,0.37,0.5)}
const CHAR_QUALITY = {"player":"SILVER", "meji":"SILVER", "zhaqiyi":"BRONZE", "tietou":"GOLD", "kuaijiao":"STONE"}

const ResourceCardManagerScript = preload("res://scripts/ui/ResourceCardManager.gd")
const MapRitePanelScript = preload("res://scripts/ui/MapRitePanel.gd")
const StatusBarScript = preload("res://scripts/ui/StatusBar.gd")
const RiteDetailPopupScript = preload("res://scripts/ui/RiteDetailPopup.gd")
const RiteRewardApplierScript = preload("res://scripts/ui/RiteRewardApplier.gd")
const RiteSettlementControllerScript = preload("res://scripts/ui/RiteSettlementController.gd")
const InsightControllerScript = preload("res://scripts/game/InsightController.gd")
const EventCheckerScript = preload("res://scripts/game/EventChecker.gd")
var card_factory: CardFactory = CardFactory.new()
var hand_layout: HandLayoutManager = HandLayoutManager.new()
var popups: PopupManager = PopupManager.new()
var resource_card_manager = ResourceCardManagerScript.new()
var map_rite_panel = MapRitePanelScript.new()
var status_bar = StatusBarScript.new()
var rite_reward_applier = RiteRewardApplierScript.new()
var rite_settlement_controller = RiteSettlementControllerScript.new()
var insight_controller = InsightControllerScript.new()
var event_checker = EventCheckerScript.new()
var _pending_event_check: bool = false
var _sorceress_scene: SorceressScene = null  # 女术士页面

# ============ UI 节点 ============
var cp:PanelContainer;var ct_lbl:Label;var cr_lbl:Label;var cd_lbl:Label
var hand_container: Control
var event_detail_panel: PanelContainer
var event_detail_vb: VBoxContainer
var _rite_popup: RiteDetailPopup   # 当前打开的仪式弹窗
var hand_cards: Array = []
var char_panels:Dictionary={};var char_data_all:Dictionary={}
var resource_cards: Dictionary = {}  # {"金": card_node, "情报": card_node}
var sort_mode: int = 0  # 0=无 1=分类 2=品质
var sort_btn: TextureButton

# ============ 状态 ============
var active_rites: Array = []
var log_msgs: Array[String] = []
var _toast_queue: Array[String] = []
var _toast_running: bool = false
var _map_area: Control
var _rite_seed: int = 42
var _all_rites: Array = []

# 常驻仪式 id 列表
const PERMANENT_RITE_IDS = [1, 2, 3, 4, 15]  # 本回合已寻思：角色用id，其他用类型
var _pending_honor_kill: bool = false          # 下次刷新时展示荣誉杀戮
var current_rite_detail: Dictionary = {}

func _ready() -> void:
	theme = _init_theme()
	card_factory.setup({
		"C":C,"SC":SC,"SC_BORDER":SC_BORDER,"SC_HOVER":SC_HOVER,"SC_GLOW":SC_GLOW,
		"CHAR_QUALITY":CHAR_QUALITY,"AI":AI
	}, func(d): popups.show_char_popup(d))
	popups.setup(self, {"C":C,"TC":TC,"TN":TN,"RG":RG,"AI":AI,"AN":AN})
	_char_load()
	_build()
	EventBus.rite_appeared.connect(func(rite: Dictionary):
		if _map_area:
			_place_rite_btn(rite, _map_area, map_rite_panel.get_existing_positions())
	)
	EventBus.sultan_card_needs_draw.connect(_on_sultan_card_needs_draw)
	# 创建女术士页面（初始隐藏）
	_sorceress_scene = SorceressScene.new()
	_sorceress_scene.name = "SorceressScene"
	_sorceress_scene.visible = false
	add_child(_sorceress_scene)
	GameManager.start_game()
	_refresh()

func _process(_delta: float):
	for c in hand_cards:
		if is_instance_valid(c) and c.is_dragging:
			hand_layout.arrange()
			return

func _init_theme() -> Theme:
	var t = Theme.new()
	var bs = StyleBoxFlat.new(); bs.bg_color = C.GOLD_LO; bs.set_corner_radius_all(6)
	bs.border_width_bottom=2; bs.border_width_top=2
	bs.border_width_left=2; bs.border_width_right=2; bs.border_color = C.GOLD
	bs.content_margin_left=14; bs.content_margin_right=14
	bs.content_margin_top=6; bs.content_margin_bottom=6
	t.set_stylebox("normal","Button",bs)
	var bh = bs.duplicate(); bh.bg_color = C.GOLD; t.set_stylebox("hover","Button",bh)
	var bp = bs.duplicate(); bp.bg_color = C.GOLD_HI; t.set_stylebox("pressed","Button",bp)
	t.set_color("font_color","Button",C.TEXT)
	t.set_color("font_hover_color","Button",C.BG_DEEP)
	t.set_font_size("font_size","Button",13)
	return t

func _char_load() -> void:
	var f = FileAccess.open("res://data/characters.json",FileAccess.READ)
	if f == null: return
	var data = JSON.parse_string(f.get_as_text()); f.close()
	if data == null: return
	for c in data: char_data_all[c.id] = c

func _build() -> void:
	_bg()
	_status()
	_map()
	_bottom()

func _bg() -> void:
	self_modulate = C.BG_DEEP

	# 地图背景图：放在独立 CanvasLayer 中，避免被 MainScene 的 self_modulate 染暗
	var bg_layer = CanvasLayer.new()
	bg_layer.name = "MapBgLayer"
	bg_layer.layer = -100   # 位于 MainScene（layer 0）之下
	var bg_tex = TextureRect.new()
	bg_tex.name = "MapBg"
	bg_tex.texture = preload("res://assets/images/ui/map_bg.png")
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED   # 保持比例铺满，超出部分裁切
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_tex.modulate = Color(1.0, 1.0, 1.0)   # 原图已提亮，此处保持 1.0；想再亮就调大（如 1.3）
	bg_layer.add_child(bg_tex)
	add_child(bg_layer)
	# 铺满「整个游戏界面」：全屏背景（map_bg 为 1920×1080 = 16:9，与 1600×900 视口同比例，故完整展示无裁切、无变形）
	var _fit_bg = func():
		var vs = get_viewport().size
		bg_tex.size = Vector2(vs.x, vs.y)
		bg_tex.position = Vector2(0, 0)
	_fit_bg.call()
	get_viewport().size_changed.connect(_fit_bg)

func _status() -> void:
	status_bar.setup(self, {"C": C})
	status_bar.build(_on_sorceress_icon_pressed)

# 左侧地图 — 仪式节点直接散布，无地点分组
func _map() -> void:
	map_rite_panel.setup(self, {"C": C}, func(rite): _open_rite_detail(rite))
	_map_area = map_rite_panel.build()
	call_deferred("_place_permanent_rites")

# ---- 令匣图标入口（已内嵌到 StatusBar 左上角，见 StatusBar._sorceress_icon） ----
func _place_permanent_rites():
	map_rite_panel.place_permanent_rites(_load_rites())


func _place_rite_btn(rite: Dictionary, area: Control, placed: Array) -> void:
	map_rite_panel.place_rite_btn(rite, placed)


func _update_rite_btn_label(rite_id: int, char_name: String):
	map_rite_panel.update_rite_btn_label(rite_id, char_name)


func _find_rite_by_id(rite_id: int):
	for r in _load_rites():
		if r.get("id", -1) == rite_id: return r
	return {}


func _reset_all_rite_btn_labels():
	map_rite_panel.reset_all_rite_btn_labels()


func _close_rite_popup() -> void:
	_clear_all_highlights()
	if _rite_popup and is_instance_valid(_rite_popup):
		_rite_popup.queue_free()
		_rite_popup = null

func _open_rite_detail(rite: Dictionary) -> void:
	_close_rite_popup()
	current_rite_detail = rite
	var current_existing = _find_configured_rite(rite)
	var rite_popup = RiteDetailPopupScript.new()
	rite_popup.card_factory = card_factory
	rite_popup.setup(rite, current_existing, {"C": C, "AN": AN}, get_viewport().size)
	rite_popup.committed.connect(_on_rite_detail_committed)
	rite_popup.cancelled.connect(_on_rite_detail_cancelled)
	rite_popup.card_return_requested.connect(_return_card_to_hand)
	rite_popup.resource_trimmed.connect(_on_rite_detail_resource_trimmed)
	rite_popup.card_clicked.connect(_on_rite_detail_card_clicked)
	rite_popup.highlight_requested.connect(_on_rite_detail_highlight_requested)
	rite_popup.validation_failed.connect(func(message): _log(message))
	add_child(rite_popup)
	_rite_popup = rite_popup


func _on_rite_detail_committed(config: Dictionary) -> void:
	var rite = config.get("rite", {})
	var char_data = config.get("char", {})
	var sultan_card_data = config.get("sultan_card", {})
	var gold_card_data = config.get("gold", {})
	var item_cards: Array = config.get("items", [])
	var is_edit = config.get("is_edit", false)
	var existing = config.get("existing", null)
	var queue = {"character": null, "sultan_card": null, "gold": null, "items": []}
	if is_edit:
		var old_q = existing.get("queue", {})
		_return_queue_to_hand(old_q)
	var pairs = [["character", char_data], ["sultan_card", sultan_card_data], ["gold", gold_card_data]]
	for pair in pairs:
		var skey = pair[0]
		var cdata = pair[1]
		if cdata.is_empty():
			continue
		queue[skey] = _take_card_from_hand(cdata, ["character", "sultan_card", "resource"], not is_edit)
	for item_data in item_cards:
		if item_data.is_empty():
			continue
		var item_card = _take_card_from_hand(item_data, ["resource"], not is_edit)
		if item_card:
			queue.items.append(item_card)
			_on_item_card_queued(item_card, item_data)
	var entry = {"rite": rite, "char": char_data, "sultan_card": sultan_card_data, "gold": gold_card_data, "items": item_cards, "queue": queue}
	if is_edit:
		var idx = active_rites.find(existing)
		if idx != -1:
			active_rites[idx] = entry
	else:
		active_rites.append(entry)
	_log("✅ 已配置「%s」" % rite.get("name", ""))
	_update_rite_btn_label(rite.get("id", -1), char_data.get("name", ""))
	_rite_popup = null
	_clear_all_highlights()
	_refresh()


func _on_rite_detail_cancelled(is_edit: bool, existing) -> void:
	if is_edit:
		var idx = active_rites.find(existing)
		if idx != -1:
			var old_entry = active_rites[idx]
			active_rites.remove_at(idx)
			_return_queue_to_hand(old_entry.get("queue", {}))
		var rite = existing.get("rite", {}) if existing else {}
		_update_rite_btn_label(rite.get("id", -1), "")
		_log("🗑 已取消「%s」" % rite.get("name", ""))
	_rite_popup = null
	_clear_all_highlights()
	_refresh()


func _on_rite_detail_resource_trimmed(slot_cfg: Dictionary, excess_data: Dictionary) -> void:
	for card in hand_cards:
		if card.visible or not is_instance_valid(card):
			continue
		var dd = card.get_meta("drag_data", {})
		if dd.get("type", "") == "resource" and dd.get("name", "") == excess_data.get("name", ""):
			_update_card_count(card, slot_cfg.get("max", 1))
			break
	var excess_card = resource_card_manager.give_resource_card(excess_data.get("name", "?"), excess_data.get("icon", "💰"), excess_data.get("quality", "STONE"), excess_data.get("count", 1))
	resource_cards[excess_data.get("name", "?")] = excess_card


func _on_rite_detail_card_clicked(slot_type: String, card_data: Dictionary) -> void:
	if slot_type == "sultan_card":
		popups.show_sultan_popup(card_data)
	elif slot_type == "gold" or slot_type == "resource" or slot_type == "item":
		popups.show_res_popup(card_data.get("name", "?"), card_data.get("icon", "📦"), card_data.get("quality", "STONE"), card_data.get("count", 1))
	else:
		popups.show_char_popup(card_data)


func _on_rite_detail_highlight_requested(slot) -> void:
	_clear_all_highlights()
	for card in hand_cards:
		if not is_instance_valid(card) or not card.visible:
			continue
		var drag_data = card.get_meta("drag_data", {})
		if drag_data.is_empty():
			continue
		if slot._can_drop_data(Vector2.ZERO, drag_data):
			card.set_highlight(true)


func _take_card_from_hand(card_data: Dictionary, allowed_types: Array, hidden_only: bool = true) -> PanelContainer:
	for i in range(hand_cards.size() - 1, -1, -1):
		var card = hand_cards[i]
		if not is_instance_valid(card):
			continue
		if hidden_only and card.visible:
			continue
		var dd = card.get_meta("drag_data", {})
		if not allowed_types.has(dd.get("type", "")):
			continue
		if dd.get("id", "") != card_data.get("id", ""):
			continue
		if not hidden_only and card.visible and dd.get("type", "") == "resource":
			var take_count = card_data.get("count", 1)
			var current_count = card.get_meta("res_count", dd.get("count", 1))
			if current_count > take_count:
				_update_card_count(card, current_count - take_count)
				var queue_card = resource_card_manager.give_resource_card(card_data.get("name", "?"), card_data.get("icon", "📦"), card_data.get("quality", "STONE"), take_count)
				hand_cards.erase(queue_card)
				queue_card.visible = false
				return queue_card
		hand_cards.remove_at(i)
		card.visible = false
		return card
	return null


func _on_item_card_queued(card: PanelContainer, item_data: Dictionary) -> void:
	resource_card_manager.consume_resource_card_data(item_data)
	var item_name = item_data.get("name", "")
	if resource_cards.get(item_name) == card:
		resource_cards.erase(item_name)

# 结算后回收卡牌：角色卡回手牌，摄政王令挂回手牌（单例复用，下一抽令在原节点刷新），金币/道具/书本卡销毁（消费）
func _restore_hand_cards():
	for ar in active_rites:
		var q = ar.get("queue", {})
		# 角色卡：回手牌
		var ch = q.get("character")
		if ch and is_instance_valid(ch):
			hand_cards.append(ch)
			ch.visible = true
		# 摄政王令：消耗后从仪式队列摘下，挂回手牌数组（不销毁单例节点，下一抽令在原节点刷新）
		var sc = q.get("sultan_card")
		if sc and is_instance_valid(sc):
			if not hand_cards.has(sc):
				hand_cards.append(sc)
			sc.visible = false
		# 金币卡：消费销毁
		var g = q.get("gold")
		if g and is_instance_valid(g):
			g.queue_free()
		for item in q.get("items", []):
			if item and is_instance_valid(item):
				item.queue_free()
		# 书本卡：消费销毁
		var bk = q.get("book_card")
		if bk and is_instance_valid(bk):
			bk.queue_free()
	hand_layout.arrange()
	# 回收后兜底刷新：若本帧内抽令已完成（cp已在hand_cards），确保cp显示/隐藏与当前active_sultan_card一致
	_refresh()

# 取消仪式时，queue 里的卡牌退回手牌（金币合并回手牌金币卡）
func _return_queue_to_hand(q: Dictionary):
	var ch = q.get("character")
	if ch and is_instance_valid(ch):
		hand_cards.append(ch); ch.visible = true
	var sc = q.get("sultan_card")
	if sc and is_instance_valid(sc):
		hand_cards.append(sc); sc.visible = true
	var g = q.get("gold")
	if g and is_instance_valid(g):
		_merge_resource_back(g)
	for item in q.get("items", []):
		if item and is_instance_valid(item):
			resource_card_manager.restore_resource_card_data(item.get_meta("drag_data", {}))
			_merge_resource_back(item)
	hand_layout.arrange()

# 资源卡节点合并回手牌同类资源卡（count 累加，避免手牌出现重复堆叠）
func _merge_resource_back(resource_node):
	var back_count = resource_node.get_meta("res_count", 0)
	var back_data = resource_node.get_meta("drag_data", {})
	var back_name = back_data.get("name", "")
	var target = null
	for c in hand_cards:
		if is_instance_valid(c):
			var dd = c.get_meta("drag_data", {})
			if dd.get("type","") == "resource" and dd.get("name","") == back_name:
				target = c; break
	if target:
		_update_card_count(target, target.get_meta("res_count", 0) + back_count)
		resource_node.queue_free()
	else:
		hand_cards.append(resource_node)
		resource_node.visible = true
		if back_name != "":
			resource_cards[back_name] = resource_node

func _bottom() -> void:
	hand_container = Control.new(); hand_container.name="HandContainer"
	hand_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); hand_container.offset_top=-200
	hand_container.mouse_filter=Control.MOUSE_FILTER_PASS
	add_child(hand_container)
	
	# 手牌区背景 — 作为 MainScene 的子节点，与 hand_container 同级，永不干涉卡牌排序
	var bg = ColorRect.new(); bg.name="HandBg"
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); bg.offset_top=-120   # 高度 120，低于卡牌高度(180)，让卡牌能探出上边
	bg.color = Color("0d0804")   # 不透明深色蒙版（截图里那种低于卡牌高度的底条）
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, get_child_count() - 2)  # 确保 bg 在 hand_container 下面

	# 卡牌区边框 — 同样是 MainScene 子节点（hand_container 的兄弟），不受 move_child 影响
	var cz = PanelContainer.new(); cz.name="CardZoneBorder"
	cz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var czs = StyleBoxFlat.new()
	czs.bg_color = Color(0, 0, 0, 0)   # 去掉卡牌区背景蒙版（全透明）
	czs.border_width_bottom = 0; czs.border_width_top = 0
	czs.border_width_left = 0; czs.border_width_right = 0
	czs.border_color = C.GOLD_LO
	czs.set_corner_radius_all(0)
	cz.add_theme_stylebox_override("panel", czs)
	add_child(cz)
	move_child(cz, get_child_count() - 2)  # 在 HandBg 上面、hand_container 下面
	
	hand_cards.clear()
	
	# 灵光一现 — 左下角骷髅
	var insight = _make_insight_button()
	insight.position = Vector2(-10, -70)   # x=-10 左侧再减 10px（按钮左探出 10px）
	hand_container.add_child(insight)   # 尺寸保持 CARD_SIZE（与卡牌一致），不被手牌区高度撑开
	
	# 角色卡
	for cid in ["player","meji","tietou","kuaijiao","zhaqiyi"]:
		var d = char_data_all.get(cid,{})
		if d.is_empty(): continue
		var card = card_factory.make_char_card(d)
		char_panels[cid] = card; card.name = "Char_"+cid
		card.drag_ended.connect(_on_hand_card_dropped)
		hand_container.add_child(card); hand_cards.append(card)
	
	# 摄政王令
	cp = card_factory.make_sultan_card()
	ct_lbl = cp.get_node_or_null("CardTextOverlay/TitleLbl") as Label
	cr_lbl = null
	cd_lbl = cp.get_node_or_null("CardTextOverlay/CountLbl") as Label
	cp.drag_ended.connect(_on_hand_card_dropped)
	hand_container.add_child(cp); hand_cards.append(cp)
	
	# 下一天 — 右下角（图片按钮）
	var nb = TextureButton.new()
	nb.texture_normal = preload("res://assets/images/ui/next_day_btn.png")
	nb.ignore_texture_size = true
	nb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	nb.custom_minimum_size = Vector2(200, 112)  # 比例≈1.786 贴合原图，不变形
	nb.size = Vector2(200, 112)
	nb.pressed.connect(_next_press)
	nb.mouse_entered.connect(func(): nb.modulate = Color(1.15, 1.15, 1.15))
	nb.mouse_exited.connect(func(): nb.modulate = Color.WHITE)
	nb.position = Vector2(hand_container.size.x - 215, 85)
	hand_container.add_child(nb)
	
	# 排序按钮 — 下一天下方
	sort_btn = TextureButton.new()
	sort_btn.texture_normal = preload("res://assets/images/ui/sort_btn.png")
	sort_btn.ignore_texture_size = true
	sort_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	sort_btn.custom_minimum_size = Vector2(56, 56)  # 原图 205×205 (1:1)
	sort_btn.size = Vector2(56, 56)
	sort_btn.pressed.connect(hand_layout.cycle_sort)
	sort_btn.mouse_entered.connect(func(): sort_btn.modulate = Color(1.15, 1.15, 1.15))
	sort_btn.mouse_exited.connect(func(): sort_btn.modulate = Color.WHITE)
	sort_btn.position = Vector2(hand_container.size.x - 273, 113)
	hand_container.add_child(sort_btn)
	
	# 初始化手牌布局管理器
	hand_layout.setup(hand_cards, hand_container, sort_btn, func(card, count): _update_card_count(card, count), CHAR_QUALITY)
	resource_card_manager.setup(
		card_factory,
		hand_layout,
		popups,
		hand_container,
		hand_cards,
		resource_cards,
		func(card, global_pos): _on_hand_card_dropped(card, global_pos)
	)
	rite_reward_applier.setup(
		card_factory,
		resource_card_manager,
		hand_container,
		hand_cards,
		hand_layout,
		func(card, global_pos): _on_hand_card_dropped(card, global_pos),
		func(message): _log(message)
	)
	rite_settlement_controller.call("setup", self, active_rites, rite_reward_applier, {
		"log": func(message): _log(message),
		"refresh": func(): 
			_refresh()
			if _pending_event_check:
				_pending_event_check = false
				_process_event_queue(),
		"update_countdown": func(): _update_countdown_labels(),
		"show_game_over": func(): popups.show_game_over(),
		"restore_hand_cards": func(): _restore_hand_cards(),
		"reset_rite_btn_labels": func(): _reset_all_rite_btn_labels(),
		"show_toasts": func(notifications): _show_toasts(notifications),
	})
	insight_controller.call("setup", self, {"C": C}, hand_container, hand_cards, hand_layout, active_rites, {
		"log": func(message): _log(message),
		"refresh": func(): _refresh(),
		"place_rite": func(rite): _place_rite_btn(rite, _map_area, map_rite_panel.get_existing_positions()),
	})
	
	# 资源卡（金币、情报等可叠加）
	var gold_card = resource_card_manager.make_gold_card(ResourceManager.gold)
	hand_container.add_child(gold_card); hand_cards.append(gold_card)
	_refresh_intel_cards()
	
	hand_layout.arrange()
	
	hand_container.resized.connect(func():
		if is_instance_valid(nb): nb.position = Vector2(hand_container.size.x - 215, 90)
		if is_instance_valid(sort_btn): sort_btn.position = Vector2(hand_container.size.x - 273, 118)
		_update_card_zone_border()
	)

	call_deferred("_update_card_zone_border")


func _update_card_zone_border():
	var cz = get_node_or_null("CardZoneBorder")
	if not cz: return
	var insight = hand_container.get_node_or_null("InsightBtn")
	var left = insight.position.x + insight.size.x - 10 if insight and is_instance_valid(insight) else 100
	var right = sort_btn.position.x - 4 if sort_btn and is_instance_valid(sort_btn) else hand_container.size.x - 8
	cz.position = Vector2(left, hand_container.position.y + 4)
	cz.size = Vector2(right - left, hand_container.size.y - 8)

func _make_insight_button() -> PanelContainer:
	var insight = PanelContainer.new(); insight.name="InsightBtn"
	insight.custom_minimum_size=Vector2(240, 270); insight.size=Vector2(240, 270); insight.mouse_filter=Control.MOUSE_FILTER_STOP
	# 去掉背景与边框，只保留图片（图片自身带透明背景，即为完整的「俺寻思」）
	var iss = StyleBoxFlat.new()
	iss.bg_color = Color(0, 0, 0, 0)            # 背景透明
	iss.set_corner_radius_all(0)
	iss.border_width_bottom = 0; iss.border_width_top = 0; iss.border_width_left = 0; iss.border_width_right = 0
	iss.shadow_size = 0                         # 关阴影，否则图片四周会透出一圈暗边
	insight.add_theme_stylebox_override("panel", iss)
	# 单击 → 提示拖入卡牌
	insight.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
			_log("💀 灵光一现：将卡牌拖入此处以探索/处理")
	)
	# 「俺寻思」按钮面：用 anxunsi.png 替换原来的 💀+文字（只显示图片）
	var iv = TextureRect.new(); iv.name="InsightFace"
	iv.texture = preload("res://assets/images/ui/anxunsi.png")
	iv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	iv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	iv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # 完整显示图片、不裁切（想铺满裁切改 COVERED）
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 点击/拖放落到 InsightBtn 面板上
	iv.modulate = Color(1.15, 1.15, 1.15)   # 提亮一点
	insight.add_child(iv)
	return insight

func _on_hand_card_dropped(card: PanelContainer, global_pos: Vector2):
	var dropped_in_slot = false
	
	# 1. 检查是否拖到了灵光一现
	var insight = hand_container.get_node_or_null("InsightBtn")
	if insight and insight.get_global_rect().has_point(global_pos):
		insight_controller.call("do_insight_with_card", card)
		dropped_in_slot = true
	
	# 2. 资源卡合并 — 拖到同类型资源卡上
	if not dropped_in_slot:
		var res_type = card.get_meta("res_type", "")
		if res_type != "":
			for other in hand_cards:
				if other == card or not other.visible: continue
				if other.get_meta("res_type","") == res_type and other.get_global_rect().has_point(global_pos):
					var c1 = card.get_meta("res_count", 0)
					var c2 = other.get_meta("res_count", 0)
					_update_card_count(other, c1 + c2)
					card.queue_free(); hand_cards.erase(card)
					_log("💰 合并×%d → 共×%d" % [c1, c1+c2])
					dropped_in_slot = true
					break
	
	# 3. 检查仪式弹窗中的卡槽
	if not dropped_in_slot and _rite_popup and is_instance_valid(_rite_popup):
		if _rite_popup.has_method("try_drop_card"):
			dropped_in_slot = _rite_popup.try_drop_card(card, global_pos)
	
	if not dropped_in_slot:
		_reorder_card(card, global_pos)
	hand_layout.arrange()

func _reorder_card(card: PanelContainer, global_pos: Vector2):
	var card_idx = hand_cards.find(card)
	if card_idx == -1: return
	var local_pos = hand_container.get_local_mouse_position()
	var target_idx = card_idx
	for i in range(hand_cards.size()):
		if i == card_idx: continue
		var other = hand_cards[i]
		var other_center = other.position + other.size / 2.0
		if local_pos.x < other_center.x and i < card_idx:
			target_idx = i; break
		elif local_pos.x > other_center.x and i > card_idx:
			target_idx = i; break
	if target_idx != card_idx:
		hand_cards.remove_at(card_idx); hand_cards.insert(target_idx, card)
		for i in range(hand_cards.size()):
			var c = hand_cards[i] as Control
			if c.get_index() != i: hand_container.move_child(c, i)

func _split_resource_card(source_card: PanelContainer, name_str: String, icon: String, quality: String):
	resource_card_manager.split_resource_card(source_card, name_str, icon, quality)

# 金币卡数量更新（同步 ResourceManager）
func _update_card_count(card: PanelContainer, count: int):
	resource_card_manager.update_card_count(card, count)

func _next_press() -> void:
	insight_controller.call("clear_used_keys")
	insight_controller.call("check_pending_honor_kill")
	_pending_event_check = true
	rite_settlement_controller.call("start")

# ---- 女术士页面：抽令信号处理 ----
func _on_sultan_card_needs_draw(is_first: bool) -> void:
	if not is_instance_valid(_sorceress_scene):
		return
	var card_data: Dictionary = {}
	_sorceress_scene.open_for_draw(card_data, is_first, func(card: Dictionary):
		_refresh()
		_animate_card_into_hand()
	)

# ---- 主动点击女术士图标 ----
func _on_sorceress_icon_pressed() -> void:
	if not is_instance_valid(_sorceress_scene):
		return
	if GameManager.active_sultan_card.is_empty():
		_sorceress_scene.open_for_draw({}, GameManager.has_drawn_first_card, func(card: Dictionary):
			_refresh()
			_animate_card_into_hand()
		)
	else:
		var cb_draw = func():
			_sorceress_scene.open_for_draw({}, false, func(card: Dictionary):
				_refresh()
				_animate_card_into_hand()
			)
		var cb_swap = func():
			_sorceress_scene.open_for_swap(GameManager.swap_tokens, func():
				GameManager.swap_sultan_card()
			)
		var cb_progress = func():
			_sorceress_scene.open_for_progress()
		var cb_chat = func():
			pass
		_sorceress_scene.open_for_greeting(cb_draw, cb_swap, cb_progress, cb_chat)



# ---- 令牌落入手牌动画 ----
func _animate_card_into_hand() -> void:
	if not is_instance_valid(cp) or not cp.visible:
		return
	# 从上方滑入
	var target_y = cp.position.y
	cp.position.y = -80
	cp.modulate = Color(1, 1, 1, 0)
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(cp, "position:y", target_y, 0.35)
	t.parallel().tween_property(cp, "modulate", Color.WHITE, 0.15)

func _refresh() -> void:
	status_bar.refresh()
	
	var card = GameManager.active_sultan_card
	if not is_instance_valid(cp): return
	# 双队列：cp在hand_cards则显示，不在则已被投入仪式队列，不显示
	if not hand_cards.has(cp):
		return
	cp.visible = not card.is_empty()
	if not card.is_empty():
		if not is_instance_valid(ct_lbl):
			ct_lbl = cp.get_node_or_null("CardTextOverlay/TitleLbl") as Label
		if not is_instance_valid(cd_lbl):
			cd_lbl = cp.get_node_or_null("CardTextOverlay/CountLbl") as Label
		if is_instance_valid(ct_lbl):
			ct_lbl.text = TN.get(card.get("type",""),"？")
		if is_instance_valid(cd_lbl):
			cd_lbl.text = "%d天" % GameManager.sultan_card_days_left
		var sc_type = card.get("type","")
		var sc_rank = card.get("rank","STONE")
		var rk_border = SC_BORDER.get(sc_rank, C.GOLD_LO)
		var sc_bg = card_factory.sultan_card_bg(sc_type, sc_rank)
		card_factory.call("_apply_image_card_base", cp, sc_rank, rk_border, false, Color("c8a84e80"), sc_bg, 20.0)
		cp.set_meta("sc_bg", sc_bg)
		cp.set_meta("drag_data", {"type":"sultan_card", "id":card.get("id",""), "name":card.get("name",""), "data":card})
	hand_layout.arrange()
	_refresh_intel_cards()

# 同步金币卡数量和 ResourceManager

func _load_rites() -> Array:
	var f = FileAccess.open("res://data/rites.json",FileAccess.READ)
	if f == null: return []
	var d = JSON.parse_string(f.get_as_text()); f.close()
	if d == null: return []
	return d

func _update_countdown_labels():
	map_rite_panel.update_countdown_labels()


func _refresh_intel_cards():
	resource_card_manager.refresh_intel_cards()

func slot_type_to_str(t: String) -> String:
	if t == "character": return "character"
	if t == "sultan_card": return "sultan_card"
	return "resource"

# 卡牌从槽位移除时，恢复到手中
func _return_card_to_hand(card_type: String, card_data: Dictionary):
	# 先找已隐藏的匹配卡牌
	for c in hand_cards:
		if not c.visible and is_instance_valid(c):
			var dd = c.get_meta("drag_data", {})
			if dd.get("type","") == card_type and dd.get("id","") == card_data.get("id",""):
				c.visible = true
				if card_type == "resource" and card_data.has("count"):
					_update_card_count(c, card_data.get("count", 1))
				hand_layout.arrange()
				return
	
	# 找不到（如确认后重开再拖出），重新创建一张
	var new_card: PanelContainer
	if card_type == "character":
		new_card = card_factory.make_char_card(card_data)
	elif card_type == "resource":
		new_card = resource_card_manager.give_resource_card(card_data.get("name", "?"), card_data.get("icon", "📦"), card_data.get("quality", "STONE"), card_data.get("count", 1))
		resource_cards[card_data.get("name", "?")] = new_card
		hand_layout.arrange()
		return
	else:
		# 摄政王令：从 GameManager 取当前数据
		var scard = GameManager.active_sultan_card
		if not scard.is_empty():
			cp.visible = true
			hand_layout.arrange()
			return
		else:
			# 没有活跃摄政王令，不创建
			return
	
	new_card.drag_ended.connect(_on_hand_card_dropped)
	new_card.drag_started.connect(func(_c): hand_layout.arrange())
	hand_container.add_child(new_card)
	hand_cards.append(new_card)
	hand_layout.arrange()



func _clear_all_highlights():
	for card in hand_cards:
		if is_instance_valid(card) and card.has_method("set_highlight"):
			card.set_highlight(false)

func _find_configured_rite(rite:Dictionary):
	for ar in active_rites:
		if ar.rite.get("id", -1) == rite.get("id", -2):
			return ar
	return null

func _get_configured_for_loc(loc_id:String) -> Array:
	var result = []
	for ar in active_rites:
		if ar.rite.get("location","") == loc_id: result.append(ar)
	return result

func _lbl(t:String, s:int, c:Color) -> Label:
	var l = Label.new(); l.text=t; l.add_theme_font_size_override("font_size",s)
	l.add_theme_color_override("font_color",c); return l

func _sep() -> HSeparator:
	return HSeparator.new()

func _log(msg:String) -> void:
	log_msgs.append(msg)
	if log_msgs.size() > 50: log_msgs.pop_front()
	_refresh()
	print("[MainScene]", msg)


func _show_toasts(nts: Array):
	for t in nts:
		if t != "":
			_toast_queue.append(t)
	if _toast_running: return
	_play_next_toast()

func _play_next_toast():
	if _toast_queue.is_empty():
		_toast_running = false
		return
	_toast_running = true
	var text = _toast_queue.pop_front()
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C.GOLD_HI)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(1, 1, 1, 0)
	add_child(lbl)
	lbl.reset_size()
	await get_tree().process_frame
	lbl.position = Vector2((size.x - lbl.size.x) / 2, -24)
	var t = create_tween()
	t.tween_property(lbl, "position:y", 8, 0.2)
	t.parallel().tween_property(lbl, "modulate:a", 1, 0.15)
	t.tween_interval(1.0)
	t.tween_property(lbl, "position:y", -24, 0.2)
	t.parallel().tween_property(lbl, "modulate:a", 0, 0.15)
	t.tween_callback(func():
		if is_instance_valid(lbl): lbl.queue_free()
		_play_next_toast()
	)


func _process_event_queue() -> void:
	var events = event_checker.get_triggered_events()
	if events.is_empty(): return
	for ev in events:
		event_checker.mark_triggered(ev.get("id", ""))
		var chosen_idx = await _await_event_choice(ev)
		if chosen_idx >= 0 and chosen_idx < ev.choices.size():
			_apply_event_outcome(ev.choices[chosen_idx].get("outcome", {}))

func _await_event_choice(ev: Dictionary) -> int:
	var result_idx: int = -1
	popups.show_event_popup(ev, func(event, idx):
		result_idx = idx
	)
	await Engine.get_main_loop().process_frame
	while result_idx == -1:
		await Engine.get_main_loop().process_frame
	return result_idx

func _apply_event_outcome(outcome: Dictionary) -> void:
	if outcome.is_empty(): return
	var nts: Array[String] = []
	if outcome.has("gold"):
		var v = outcome.gold
		if v > 0:
			resource_card_manager.give_gold_cards(v)
			nts.append("💰 %+d金币" % v)
		elif v < 0:
			ResourceManager.add_gold(v)
			nts.append("💰 %d金币" % v)
	if outcome.has("good"):
		ResourceManager.modify_reputation("good", outcome.good)
		nts.append("名望 %+d" % outcome.good)
	if outcome.has("evil"):
		ResourceManager.modify_reputation("evil", outcome.evil)
		nts.append("恶名 %+d" % outcome.evil)
	if outcome.has("power"):
		ResourceManager.modify_reputation("power", outcome.power)
		nts.append("权势 %+d" % outcome.power)
	if outcome.has("hero"):
		ResourceManager.modify_reputation("hero", outcome.hero)
		nts.append("义名 %+d" % outcome.hero)
	if outcome.has("spirit"):
		ResourceManager.modify_reputation("spirit", outcome.spirit)
		nts.append("灵知 %+d" % outcome.spirit)
	if nts.size() > 0:
		_show_toasts(nts)
	_refresh()
