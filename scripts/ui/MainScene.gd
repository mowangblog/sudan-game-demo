# MainScene.gd — 苏丹的游戏复刻
# 参考原版布局：顶部状态栏 + 左侧地图 + 右侧事件面板 + 底部手牌

extends Control

# ============ 调色板 ============
const C = {
	BG_DEEP=Color("1a0f0a"),BG_MID=Color("241712"),BG_PANEL=Color("2d1c12"),
	GOLD=Color("c8a84e"),GOLD_HI=Color("e8d48b"),GOLD_LO=Color("8a6820"),
	TEXT=Color("f0e6c8"),DIM=Color("a09070"),RED=Color("ff4040"),
	GREEN=Color("4a9a3a"),FAIL=Color("aa3030"),SHADOW=Color("00000099"),
	LUST=Color("8b3a5c"),LUXURY=Color("3a5c8b"),CONQUEST=Color("3a5b3a"),MURDER=Color("6b2a2a"),
}
const TC = {"LUST":C.LUST,"LUXURY":C.LUXURY,"CONQUEST":C.CONQUEST,"MURDER":C.MURDER}
const TN = {"LUST":"纵欲","LUXURY":"奢靡","CONQUEST":"征服","MURDER":"杀戮"}
const RG = {"STONE":"★","BRONZE":"★★","SILVER":"★★★","GOLD":"★★★★"}
const AN = {"phy":"体魄","com":"战斗","sur":"生存","soc":"社交","cha":"魅力","ste":"隐匿","wis":"智慧","mag":"魔力"}
const AI = {"phy":"💪","com":"⚔","sur":"🏕","soc":"💬","cha":"💋","ste":"🕶","wis":"📚","mag":"🔮"}
# 品质配色：底色暗 + 边框亮 + 光晕半透明
const SC = {"STONE":Color(0.15,0.13,0.11), "BRONZE":Color(0.13,0.16,0.10), "SILVER":Color(0.12,0.13,0.15), "GOLD":Color(0.16,0.14,0.08)}
const SC_BORDER = {"STONE":Color(0.50,0.42,0.33), "BRONZE":Color(0.60,0.68,0.35), "SILVER":Color(0.62,0.66,0.70), "GOLD":Color(0.88,0.73,0.33)}
const SC_HOVER = {"STONE":Color(0.60,0.52,0.42), "BRONZE":Color(0.72,0.82,0.45), "SILVER":Color(0.74,0.78,0.82), "GOLD":Color(1.0,0.85,0.45)}
const SC_GLOW = {"STONE":Color(0.55,0.47,0.36,0.5), "BRONZE":Color(0.65,0.74,0.38,0.5), "SILVER":Color(0.68,0.71,0.74,0.5), "GOLD":Color(0.96,0.80,0.37,0.5)}
const CHAR_QUALITY = {"player":"SILVER", "meji":"BRONZE", "zhaqiyi":"BRONZE", "tietou":"STONE", "kuaijiao":"STONE"}

const SettlementPopup = preload("res://scripts/ui/SettlementPopup.gd")
const SettlementScreen = preload("res://scripts/ui/SettlementScreen.gd")
const ResourceCardManagerScript = preload("res://scripts/ui/ResourceCardManager.gd")
const MapRitePanelScript = preload("res://scripts/ui/MapRitePanel.gd")
const StatusBarScript = preload("res://scripts/ui/StatusBar.gd")
const RiteDetailPopupScript = preload("res://scripts/ui/RiteDetailPopup.gd")
const RiteRewardApplierScript = preload("res://scripts/ui/RiteRewardApplier.gd")
const RiteSettlementControllerScript = preload("res://scripts/ui/RiteSettlementController.gd")
var card_factory: CardFactory = CardFactory.new()
var hand_layout: HandLayoutManager = HandLayoutManager.new()
var popups: PopupManager = PopupManager.new()
var resource_card_manager = ResourceCardManagerScript.new()
var map_rite_panel = MapRitePanelScript.new()
var status_bar = StatusBarScript.new()
var rite_reward_applier = RiteRewardApplierScript.new()
var rite_settlement_controller = RiteSettlementControllerScript.new()

# ============ UI 节点 ============
var cp:PanelContainer;var ct_lbl:Label;var cr_lbl:Label;var cd_lbl:Label
var hand_container: Control
var event_detail_panel: PanelContainer
var event_detail_vb: VBoxContainer
var _rite_popup: PanelContainer   # 当前打开的仪式弹窗
var hand_cards: Array = []
var char_panels:Dictionary={};var char_data_all:Dictionary={}
var resource_cards: Dictionary = {}  # {"金": card_node, "情报": card_node}
var sort_mode: int = 0  # 0=无 1=分类 2=品质
var sort_btn: Button

# ============ 状态 ============
var active_rites: Array = []
var log_msgs: Array[String] = []
var _insight_used_keys: Array[String] = []
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

func _status() -> void:
	status_bar.setup(self, {"C": C})
	status_bar.build()

# 左侧地图 — 仪式节点直接散布，无地点分组
func _map() -> void:
	map_rite_panel.setup(self, {"C": C}, func(rite): _open_rite_detail(rite))
	_map_area = map_rite_panel.build()
	call_deferred("_place_permanent_rites")


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
	var is_edit = config.get("is_edit", false)
	var existing = config.get("existing", null)
	var queue = {"character": null, "sultan_card": null, "gold": null}
	if is_edit:
		var old_q = existing.get("queue", {})
		queue.character = old_q.get("character")
		queue.sultan_card = old_q.get("sultan_card")
		queue.gold = old_q.get("gold")
	else:
		var pairs = [["character", char_data], ["sultan_card", sultan_card_data], ["gold", gold_card_data]]
		for pair in pairs:
			var skey = pair[0]
			var cdata = pair[1]
			if cdata.is_empty():
				continue
			for i in range(hand_cards.size() - 1, -1, -1):
				var card = hand_cards[i]
				if not is_instance_valid(card) or card.visible:
					continue
				var dd = card.get_meta("drag_data", {})
				if dd.get("id", "") == cdata.get("id", "") and dd.get("type", "") in ["character", "sultan_card", "resource"]:
					hand_cards.remove_at(i)
					queue[skey] = card
					break
	var entry = {"rite": rite, "char": char_data, "sultan_card": sultan_card_data, "gold": gold_card_data, "queue": queue}
	if is_edit:
		var idx = active_rites.find(existing)
		if idx != -1:
			active_rites[idx] = entry
	else:
		active_rites.append(entry)
	_log("✅ 已配置「%s」" % rite.get("name", ""))
	_update_rite_btn_label(rite.get("id", -1), char_data.get("name", ""))
	_rite_popup = null
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
	_refresh()


func _on_rite_detail_resource_trimmed(slot_cfg: Dictionary, excess_data: Dictionary) -> void:
	for card in hand_cards:
		if card.visible or not is_instance_valid(card):
			continue
		var dd = card.get_meta("drag_data", {})
		if dd.get("type", "") == "resource" and dd.get("name", "") == excess_data.get("name", ""):
			_update_card_count(card, slot_cfg.get("max", 1))
			break
	resource_card_manager.give_resource_card(excess_data.get("name", "?"), excess_data.get("icon", "💰"), excess_data.get("quality", "STONE"), excess_data.get("count", 1))


func _on_rite_detail_card_clicked(slot_type: String, card_data: Dictionary) -> void:
	if slot_type == "sultan_card":
		popups.show_sultan_popup(card_data)
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

# 结算后回收卡牌：角色卡回手牌，苏丹卡/金币卡销毁（消费）
func _restore_hand_cards():
	for ar in active_rites:
		var q = ar.get("queue", {})
		# 角色卡：回手牌
		var ch = q.get("character")
		if ch and is_instance_valid(ch):
			hand_cards.append(ch)
			ch.visible = true
		# 苏丹卡：销毁（原版消耗品，全局 consume_sultan_card 已扣计数）
		var sc = q.get("sultan_card")
		if sc and is_instance_valid(sc):
			sc.queue_free()
		# 金币卡：消费销毁
		var g = q.get("gold")
		if g and is_instance_valid(g):
			g.queue_free()
	hand_layout.arrange()

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
		_merge_gold_back(g)
	hand_layout.arrange()

# 金币卡节点合并回手牌金币卡（count 累加，避免手牌出现多张金币卡）
func _merge_gold_back(gold_node):
	var back_count = gold_node.get_meta("res_count", 0)
	var target = null
	for c in hand_cards:
		if is_instance_valid(c):
			var dd = c.get_meta("drag_data", {})
			if dd.get("type","") == "resource" and dd.get("name","") == "金币":
				target = c; break
	if target:
		_update_card_count(target, target.get_meta("res_count", 0) + back_count)
		gold_node.queue_free()
	else:
		hand_cards.append(gold_node); gold_node.visible = true

func _bottom() -> void:
	hand_container = Control.new(); hand_container.name="HandContainer"
	hand_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); hand_container.offset_top=-200
	hand_container.mouse_filter=Control.MOUSE_FILTER_PASS
	add_child(hand_container)
	
	# 手牌区背景 — 作为 MainScene 的子节点，与 hand_container 同级，永不干涉卡牌排序
	var bg = ColorRect.new(); bg.name="HandBg"
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); bg.offset_top=-200
	bg.color = Color("0d0804", 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, get_child_count() - 2)  # 确保 bg 在 hand_container 下面

	# 卡牌区边框 — 同样是 MainScene 子节点（hand_container 的兄弟），不受 move_child 影响
	var cz = PanelContainer.new(); cz.name="CardZoneBorder"
	cz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var czs = StyleBoxFlat.new()
	czs.bg_color = Color("0a0604", 0.4)
	czs.border_width_bottom = 2; czs.border_width_top = 2
	czs.border_width_left = 2; czs.border_width_right = 2
	czs.border_color = C.GOLD_LO
	czs.set_corner_radius_all(6)
	cz.add_theme_stylebox_override("panel", czs)
	add_child(cz)
	move_child(cz, get_child_count() - 2)  # 在 HandBg 上面、hand_container 下面
	
	hand_cards.clear()
	
	# 俺寻思 — 左下角骷髅
	var insight = _make_insight_button()
	insight.position = Vector2(10, 0)
	insight.size.x = 86
	insight.size.y = hand_container.size.y
	hand_container.add_child(insight)
	
	# 角色卡
	for cid in ["player","meji","tietou","kuaijiao","zhaqiyi"]:
		var d = char_data_all.get(cid,{})
		if d.is_empty(): continue
		var card = card_factory.make_char_card(d)
		char_panels[cid] = card; card.name = "Char_"+cid
		card.drag_ended.connect(_on_hand_card_dropped)
		hand_container.add_child(card); hand_cards.append(card)
	
	# 苏丹卡
	cp = card_factory.make_sultan_card()
	ct_lbl = cp.get_node("VB/TypeLbl") as Label
	cr_lbl = cp.get_node("VB/RankLbl") as Label
	cd_lbl = cp.get_node("VB/DaysLbl") as Label
	cp.drag_ended.connect(_on_hand_card_dropped)
	hand_container.add_child(cp); hand_cards.append(cp)
	
	# 下一天 — 右下角
	var nb = Button.new(); nb.text="▶ 下一天"; nb.custom_minimum_size=Vector2(120,44)
	nb.add_theme_font_size_override("font_size", 15); nb.pressed.connect(_next_press)
	nb.position = Vector2(hand_container.size.x - 135, 55)
	hand_container.add_child(nb)
	
	# 排序按钮 — 下一天下方
	sort_btn = Button.new(); sort_btn.text="排序"; sort_btn.custom_minimum_size=Vector2(60,24)
	sort_btn.add_theme_font_size_override("font_size", 10)
	sort_btn.pressed.connect(hand_layout.cycle_sort)
	sort_btn.position = Vector2(hand_container.size.x - 135, 105)
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
		"refresh": func(): _refresh(),
		"update_countdown": func(): _update_countdown_labels(),
		"show_game_over": func(): popups.show_game_over(),
		"restore_hand_cards": func(): _restore_hand_cards(),
		"reset_rite_btn_labels": func(): _reset_all_rite_btn_labels(),
		"show_toasts": func(notifications): _show_toasts(notifications),
	})
	
	# 资源卡（金币、情报等可叠加）
	var gold_card = resource_card_manager.make_gold_card(ResourceManager.gold)
	hand_container.add_child(gold_card); hand_cards.append(gold_card)
	_refresh_intel_cards()
	
	hand_layout.arrange()
	
	hand_container.resized.connect(func():
		if is_instance_valid(insight): insight.size.y = hand_container.size.y
		if is_instance_valid(nb): nb.position = Vector2(hand_container.size.x - 135, hand_container.size.y / 2 - 36)
		if is_instance_valid(sort_btn): sort_btn.position = Vector2(hand_container.size.x - 135, hand_container.size.y / 2 + 16)
		_update_card_zone_border()
	)

	call_deferred("_update_card_zone_border")


func _update_card_zone_border():
	var cz = get_node_or_null("CardZoneBorder")
	if not cz: return
	var insight = hand_container.get_node_or_null("InsightBtn")
	var left = insight.position.x + insight.size.x + 4 if insight and is_instance_valid(insight) else 100
	var right = sort_btn.position.x - 4 if sort_btn and is_instance_valid(sort_btn) else hand_container.size.x - 8
	cz.position = Vector2(left, hand_container.position.y + 4)
	cz.size = Vector2(right - left, hand_container.size.y - 8)

func _make_insight_button() -> PanelContainer:
	var insight = PanelContainer.new(); insight.name="InsightBtn"
	insight.custom_minimum_size=Vector2(70, 152); insight.mouse_filter=Control.MOUSE_FILTER_STOP
	var iss = StyleBoxFlat.new(); iss.bg_color=Color("1a1018"); iss.set_corner_radius_all(10)
	iss.border_width_bottom=2; iss.border_width_top=2; iss.border_width_left=2; iss.border_width_right=2
	iss.border_color=C.GOLD_LO.darkened(0.5); iss.shadow_size=6; iss.shadow_color=C.SHADOW
	insight.add_theme_stylebox_override("panel",iss)
	# 单击 → 提示拖入卡牌
	insight.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
			_log("💀 俺寻思：将卡牌拖入此处以探索/处理")
	)
	var iv = VBoxContainer.new(); iv.mouse_filter=Control.MOUSE_FILTER_IGNORE
	iv.alignment=BoxContainer.ALIGNMENT_CENTER; insight.add_child(iv)
	var lbl = Label.new(); lbl.text="💀\n俺\n寻\n思"; lbl.add_theme_font_size_override("font_size",14)
	lbl.add_theme_color_override("font_color",C.GOLD); lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(lbl)
	var hint = Label.new(); hint.text="拖入\n卡牌"; hint.add_theme_font_size_override("font_size",9)
	hint.add_theme_color_override("font_color",C.DIM); hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(hint)
	return insight

func _on_hand_card_dropped(card: PanelContainer, global_pos: Vector2):
	var dropped_in_slot = false
	
	# 1. 检查是否拖到了俺寻思
	var insight = hand_container.get_node_or_null("InsightBtn")
	if insight and insight.get_global_rect().has_point(global_pos):
		_do_insight_with_card(card)
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
	_insight_used_keys.clear()
	# 检查是否有未执行的杀戮仪式，若是则第二天弹出荣誉杀戮
	_check_pending_honor_kill()
	rite_settlement_controller.call("start")

func _refresh() -> void:
	status_bar.refresh()
	
	var card = GameManager.active_sultan_card
	if not is_instance_valid(cp): return
	cp.visible = not card.is_empty()
	if not card.is_empty():
		ct_lbl.text = TN.get(card.get("type",""),"？")
		cr_lbl.text = RG.get(card.get("rank",""),"？")
		cd_lbl.text = "%d天" % GameManager.sultan_card_days_left
		var tc = TC.get(card.get("type",""),C.LUST)
		var rk_bg = SC.get(card.get("rank",""), Color("2a2018"))
		var rk_border = SC_BORDER.get(card.get("rank",""), C.GOLD_LO)
		var sb = StyleBoxFlat.new(); sb.bg_color=rk_bg; sb.set_corner_radius_all(10)
		sb.border_width_bottom=2; sb.border_width_top=2; sb.border_width_left=2; sb.border_width_right=2
		sb.border_color=rk_border; sb.content_margin_left=4; sb.content_margin_right=4
		sb.content_margin_top=4; sb.content_margin_bottom=4; sb.shadow_size=4; sb.shadow_color=C.SHADOW
		cp.add_theme_stylebox_override("panel",sb)
		cp.set_meta("drag_data", {"type":"sultan_card", "name":card.get("name",""), "data":card})
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
	else:
		# 苏丹卡：从 GameManager 取当前数据
		var scard = GameManager.active_sultan_card
		if not scard.is_empty():
			cp.visible = true
			hand_layout.arrange()
			return
		else:
			# 没有活跃苏丹卡，不创建
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

func _check_pending_honor_kill() -> void:
	for ar in active_rites:
		if ar.get("insight_kill_rank","") != "" and ar.char.is_empty() and not ar.get("insight_kill_used", true):
			var rank = ar.insight_kill_rank
			if rank in ["STONE","BRONZE"]:
				var honor_rite = DataManager.get_rite_by_id(205)
				if not honor_rite.is_empty():
					var entry = {"rite": honor_rite, "char": {}, "sultan_card": {}, "insight": true}
					active_rites.append(entry)
					_log("⚔ 荣誉杀戮的机会出现了——趁还来得及。")
					_refresh()
			ar.insight_kill_used = true
			break


func _do_insight_with_card(card: PanelContainer) -> void:
	var drag_data = card.get_meta("drag_data", {})
	var card_type = drag_data.get("type", "")
	var card_name = drag_data.get("name", "卡牌")
	
	# 重复检查：角色按id、其他按类型
	var repeat_key = drag_data.get("id","") if card_type == "character" else card_type
	if repeat_key in _insight_used_keys:
		_show_insight_bubble("暂时想不出\n更好的办法了。")
		return
	_insight_used_keys.append(repeat_key)
	
	# 角色卡：思考→气泡
	if card_type == "character":
		card.visible = false; hand_layout.arrange()
		await _do_think_animation()
		_insight_char_bubble(drag_data)
		card.visible = true; hand_layout.arrange()
		return
	
	# 书籍卡：加入看书仪式
	if card_type == "book":
		card.visible = false; hand_layout.arrange()
		hand_cards.erase(card)
		card.queue_free()
		await _do_think_animation()
		var book_data = drag_data.get("data", {})
		var rite = {"id":300,"name":book_data.get("name","读书"),"category":"insight","time_limit":1,"insight_trigger":{"type":"book","subtype":"READ"},"duration":1,"slots":[{"type":"character","label":"阅读者","required":true}],"book":book_data}
		var entry = {"rite": rite, "char": {}, "sultan_card": {}, "insight": true}
		active_rites.append(entry)
		# 加到地图
		if _map_area:
			_place_rite_btn(rite, _map_area, map_rite_panel.get_existing_positions())
		_show_insight_bubble("「%s」\n开始阅读" % book_data.get("name","?"))
		hand_layout.arrange()
		return
	
	# 查找匹配仪式
	var matched = _find_insight_rites(card_type, drag_data)
	if matched.is_empty():
		card.visible = false; hand_layout.arrange()
		await _do_think_animation()
		_show_insight_bubble("暂时想不出\n更好的办法了。")
		card.visible = true; hand_layout.arrange()
		return
	
	# 杀戮卡追踪
	var kill_rank = ""
	if card_type == "sultan_card" and drag_data.get("data",{}).get("type","") == "MURDER":
		kill_rank = drag_data.get("data",{}).get("rank","").to_upper()
	
	# 有匹配 → 加入地图
	var picked = matched[randi() % matched.size()]
	card.visible = false; hand_layout.arrange()
	await _do_think_animation()
	
	# 消耗检查
	var consumed := false
	if picked.get("insight_trigger",{}).get("consume", false):
		if card_type == "sultan_card":
			GameManager.consume_sultan_card(0)
			card.queue_free(); hand_cards.erase(card)
			consumed = true
	
	_add_insight_rite_to_map(picked, drag_data, consumed, kill_rank)
	if not consumed:
		card.visible = true; hand_layout.arrange()


func _do_think_animation() -> void:
	var insight = hand_container.get_node_or_null("InsightBtn")
	if insight and is_instance_valid(insight):
		var t = create_tween().set_loops(3)
		t.tween_property(insight, "modulate", Color(1.3, 1.3, 1.0), 0.25)
		t.tween_property(insight, "modulate", Color.WHITE, 0.25)
	await get_tree().create_timer(1.0).timeout
	if insight and is_instance_valid(insight):
		insight.modulate = Color.WHITE


func _show_insight_bubble(text: String) -> void:
	var bubble = PanelContainer.new()
	bubble.name = "InsightBubble"
	var bs = StyleBoxFlat.new(); bs.bg_color = Color("1a1018"); bs.set_corner_radius_all(8)
	bs.border_width_bottom=1; bs.border_width_top=1; bs.border_width_left=1; bs.border_width_right=1
	bs.border_color = C.GOLD_LO; bs.content_margin_left=10; bs.content_margin_right=10
	bs.content_margin_top=6; bs.content_margin_bottom=6
	bubble.add_theme_stylebox_override("panel", bs)
	var bl = Label.new(); bl.text=text; bl.add_theme_font_size_override("font_size",11)
	bl.add_theme_color_override("font_color", C.GOLD); bl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_child(bl)
	add_child(bubble)
	bubble.reset_size()
	await get_tree().process_frame
	var vs = get_viewport().size
	var insight = hand_container.get_node_or_null("InsightBtn")
	var x: float = 0.0; var y: float = 0.0
	if insight and is_instance_valid(insight):
		var r = insight.get_global_rect()
		x = r.position.x + r.size.x / 2 - bubble.size.x / 2
		y = r.position.y - bubble.size.y - 8
	else:
		x = 50; y = vs.y - 240
	# 限制在屏幕内
	x = clampf(x, 4, vs.x - bubble.size.x - 4)
	y = maxf(y, 4)
	bubble.position = Vector2(x, y)
	await get_tree().create_timer(2.0).timeout
	bubble.queue_free()


func _add_insight_rite_to_map(rite: Dictionary, drag_data: Dictionary, consumed: bool, kill_rank: String = ""):
	var entry = {"rite": rite, "char": {}, "sultan_card": {}, "insight": true}
	if drag_data.get("type","") == "character" and not consumed:
		entry.char = drag_data
	# 跟踪杀戮卡
	if kill_rank != "":
		entry["insight_kill_rank"] = kill_rank
		entry["insight_kill_used"] = false
	active_rites.append(entry)
	# 添加到地图上
	if _map_area:
		_place_rite_btn(rite, _map_area, map_rite_panel.get_existing_positions())
	_refresh()
	_show_insight_bubble("「%s」\n出现在地图上" % rite.get("name", "?"))


func _find_insight_rites(card_type: String, drag_data: Dictionary) -> Array:
	var all = DataManager.rites
	var matched: Array = []
	for rite in all:
		var it = rite.get("insight_trigger", {})
		if it.is_empty(): continue
		if it.get("type","") != card_type: continue
		# 装修只能做一次
		if it.get("subtype","") == "LUXURY" and GameManager.renovation_done:
			continue
		var subtype = it.get("subtype","")
		if subtype != "":
			if card_type == "sultan_card":
				var cd = drag_data.get("data",{})
				if cd.get("type","") != subtype: continue
				var filter_rank = it.get("filter_rank","")
				if typeof(filter_rank) == TYPE_ARRAY:
					if not cd.get("rank","").to_upper() in filter_rank: continue
				elif filter_rank != "" and cd.get("rank","").to_upper() != filter_rank:
					continue
			elif card_type == "resource":
				var res_id = drag_data.get("id","")
				if subtype == "INTEL":
					if not ResourceManager.INTEL_EFFECTS.has(res_id): continue
				elif res_id != subtype:
					continue
		# 杀戮卡固定返回残忍的牺牲
		if card_type == "sultan_card" and subtype == "MURDER" and rite.id != 204:
			continue
		matched.append(rite)
	return matched


func _insight_char_bubble(drag_data: Dictionary):
	var cid = drag_data.get("id","")
	var bubbles = {
		"player": "嗯？",
		"meji": "我的挚爱，我的坚定盟友。",
		"zhaqiyi": "我的学生，很有潜力的年轻人。",
		"tietou": "一个沉默寡言的铁匠。",
		"kuaijiao": "路边的消息，往往最值钱。",
	}
	var text = bubbles.get(cid, drag_data.get("name","角色"))
	_show_insight_bubble(text)


func _show_toasts(nts: Array):
	if nts.is_empty(): return
	var text = nts.pop_front()
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
		_show_toasts(nts)
	)
