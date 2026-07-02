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
var card_factory: CardFactory = CardFactory.new()
var hand_layout: HandLayoutManager = HandLayoutManager.new()

# ============ UI 节点 ============
var d_lbl:Label;var w_lbl:Label;var gd_lbl:Label
var g_lbl:Label;var e_lbl:Label;var p_lbl:Label;var h_lbl:Label;var s_lbl:Label
var cp:PanelContainer;var ct_lbl:Label;var cr_lbl:Label;var cd_lbl:Label
var hand_container: Control
var event_detail_panel: PanelContainer
var event_detail_vb: VBoxContainer
var hand_cards: Array = []
var char_panels:Dictionary={};var char_data_all:Dictionary={}
var resource_cards: Dictionary = {}  # {"金": card_node, "情报": card_node}
var sort_mode: int = 0  # 0=无 1=分类 2=品质
var sort_btn: Button

# ============ 状态 ============
var active_rites: Array = []
var log_msgs: Array[String] = []
var settle_sultan_used: bool = false
var current_rite_detail: Dictionary = {}

func _ready() -> void:
	theme = _init_theme()
	card_factory.setup({
		"C":C,"SC":SC,"SC_BORDER":SC_BORDER,"SC_HOVER":SC_HOVER,"SC_GLOW":SC_GLOW,
		"CHAR_QUALITY":CHAR_QUALITY,"AI":AI
	}, func(d): _show_char_popup(d))
	_char_load()
	_build()
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
	_event_detail_panel()
	_bottom()

func _bg() -> void:
	self_modulate = C.BG_DEEP

func _status() -> void:
	var b = HBoxContainer.new()
	b.set_anchors_preset(Control.PRESET_TOP_WIDE); b.offset_bottom = 38
	b.add_theme_constant_override("separation", 8)
	add_child(b)
	
	d_lbl = _sl("第1天"); w_lbl = _sl("第1周"); gd_lbl = _sl("🎲金骰:3",C.GOLD)
	g_lbl = _sl("善0",Color("5a9a5a")); e_lbl = _sl("恶0",C.FAIL)
	p_lbl = _sl("权0",Color("9a6aba")); h_lbl = _sl("侠0",Color("5a8aba")); s_lbl = _sl("灵0",Color("6a8a5a"))
	
	for x in [d_lbl,_sl("│",C.GOLD_LO),w_lbl,_sl("│",C.GOLD_LO),
		gd_lbl,_sl("│",C.GOLD_LO),g_lbl,e_lbl,p_lbl,h_lbl,s_lbl]:
		b.add_child(x)

# 左侧地图 — 使用 Control 手动定位，更像原版
func _map() -> void:
	var map = PanelContainer.new()
	map.name = "MapPanel"
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.offset_top = 45; map.offset_bottom = -200; map.offset_right = -340
	var ps = StyleBoxFlat.new(); ps.bg_color = C.BG_MID; ps.set_corner_radius_all(10)
	ps.border_width_bottom=2; ps.border_width_top=2; ps.border_width_left=2; ps.border_width_right=2
	ps.border_color = C.GOLD_LO; ps.shadow_size=6; ps.shadow_color=C.SHADOW
	ps.content_margin_left=12; ps.content_margin_right=12; ps.content_margin_top=10; ps.content_margin_bottom=10
	map.add_theme_stylebox_override("panel", ps)
	add_child(map)
	
	var map_area = Control.new(); map_area.name = "MapArea"; map_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_area.mouse_filter = Control.MOUSE_FILTER_PASS
	map.add_child(map_area)
	
	var all_rites = _load_rites()
	var locs = [
		{"id":"palace",    "n":"🏛 宫廷",   "pos":Vector2(0.5, 0.15), "c":Color("3d3020")},
		{"id":"market",    "n":"🏪 市场",   "pos":Vector2(0.7, 0.35), "c":Color("2d3525")},
		{"id":"slums",     "n":"🏚 贫民窟", "pos":Vector2(0.3, 0.35), "c":Color("2a2018")},
		{"id":"barracks",  "n":"⚔ 军营",   "pos":Vector2(0.2, 0.60), "c":Color("25282a")},
		{"id":"temple",    "n":"🕌 寺庙",   "pos":Vector2(0.5, 0.60), "c":Color("252a30")},
		{"id":"wilderness","n":"🌲 野外",   "pos":Vector2(0.8, 0.60), "c":Color("242a20")},
	]
	
	for loc in locs:
		var node = _loc_node(loc, all_rites)
		node.set_anchors_preset(Control.PRESET_CENTER)
		node.position = Vector2(loc.pos.x * map_area.size.x, loc.pos.y * map_area.size.y) - node.size / 2
		map_area.add_child(node)
	
	# 尺寸变化时重新定位
	map_area.resized.connect(func():
		for c in map_area.get_children():
			var loc_pos = c.get_meta("loc_pos", Vector2(0.5,0.5))
			c.position = Vector2(loc_pos.x * map_area.size.x, loc_pos.y * map_area.size.y) - c.size / 2
	)

func _loc_node(loc:Dictionary, all_rites:Array) -> Control:
	var pn = PanelContainer.new()
	pn.custom_minimum_size = Vector2(140, 110)
	pn.set_meta("loc_pos", loc.pos)
	
	var ps = StyleBoxFlat.new(); ps.bg_color = Color(loc.c); ps.set_corner_radius_all(12)
	ps.border_width_bottom=2; ps.border_width_top=2; ps.border_width_left=2; ps.border_width_right=2
	ps.border_color = C.GOLD_LO; ps.shadow_size=5; ps.shadow_color=C.SHADOW
	ps.content_margin_left=8; ps.content_margin_right=8; ps.content_margin_top=6; ps.content_margin_bottom=6
	pn.add_theme_stylebox_override("panel", ps)
	pn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var vb = VBoxContainer.new(); pn.add_child(vb)
	var title = Label.new(); title.text = loc.n; title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", C.GOLD); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	
	var loc_rites = []
	for r in all_rites:
		if r.get("location","") == loc.id:
			loc_rites.append(r)
	
	for rite in loc_rites:
		var is_cfg = _find_configured_rite(rite) != null
		var btn = Button.new()
		btn.text = ("✅ " if is_cfg else "  ") + rite.get("name","?")
		btn.custom_minimum_size = Vector2(0, 24); btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_open_rite_detail.bind(rite))
		vb.add_child(btn)
	
	return pn

# 右侧事件/仪式详情面板
func _event_detail_panel() -> void:
	event_detail_panel = PanelContainer.new()
	event_detail_panel.name = "EventDetailPanel"
	event_detail_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	event_detail_panel.offset_top = 45; event_detail_panel.offset_bottom = -200; event_detail_panel.offset_left = -340
	var ps = StyleBoxFlat.new(); ps.bg_color = C.BG_PANEL; ps.set_corner_radius_all(10)
	ps.border_width_bottom=2; ps.border_width_top=2; ps.border_width_left=2; ps.border_width_right=2
	ps.border_color = C.GOLD_LO; ps.shadow_size=6; ps.shadow_color=C.SHADOW
	ps.content_margin_left=14; ps.content_margin_right=14
	ps.content_margin_top=10; ps.content_margin_bottom=10
	event_detail_panel.add_theme_stylebox_override("panel", ps)
	add_child(event_detail_panel)
	
	var sc = ScrollContainer.new(); sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_detail_panel.add_child(sc)
	
	event_detail_vb = VBoxContainer.new()
	event_detail_vb.add_theme_constant_override("separation", 10)
	event_detail_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_detail_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(event_detail_vb)
	
	# 默认空状态
	var empty_lbl = Label.new(); empty_lbl.text = "🃏\n点击左侧地图中的仪式\n查看详情并配置卡牌"
	empty_lbl.add_theme_font_size_override("font_size", 14)
	empty_lbl.add_theme_color_override("font_color", C.DIM)
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_lbl.name = "EmptyHint"
	event_detail_vb.add_child(empty_lbl)

func _open_rite_detail(rite:Dictionary) -> void:
	current_rite_detail = rite
	
	# 清空现有内容
	for c in event_detail_vb.get_children():
		c.queue_free()
	
	var vb = event_detail_vb
	
	# 检查是否已配置
	var existing = _find_configured_rite(rite)
	var is_edit = existing != null
	
	# 标题行 + 状态标记
	var hb = HBoxContainer.new(); vb.add_child(hb)
	var tl = Label.new()
	tl.text = "📜 " + rite.get("name","") + (" (已配置)" if is_edit else "")
	tl.add_theme_font_size_override("font_size", 18)
	tl.add_theme_color_override("font_color", C.GREEN if is_edit else C.GOLD)
	tl.size_flags_horizontal=Control.SIZE_EXPAND_FILL; hb.add_child(tl)
	
	# 描述
	var dl = Label.new(); dl.text = rite.get("description",""); dl.add_theme_font_size_override("font_size", 12)
	dl.add_theme_color_override("font_color", C.TEXT); dl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(dl)
	vb.add_child(_sep())
	
	# 检定信息
	var check = rite.get("check",{})
	var ck_txt = "检定："
	if check.type == "solo":
		ck_txt += "%s · 需%d成功" % [AN.get(check.attribute,"?"), check.required_successes]
	elif check.type == "combined":
		var ans = []
		for a in check.get("attributes",[]): ans.append(AN.get(a,a))
		ck_txt += "、".join(ans) + " · 需%d成功" % check.required_successes
	var ck_lbl = Label.new(); ck_lbl.text = ck_txt; ck_lbl.add_theme_font_size_override("font_size", 11)
	ck_lbl.add_theme_color_override("font_color", C.DIM); vb.add_child(ck_lbl)
	
	var out = rite.get("outcomes",{}).get("success",{})
	var rw_txt = "成功奖励："
	if out.has("gold"): rw_txt += "💰%+d " % out.gold
	if out.has("power"): rw_txt += "权%+d " % out.power
	if out.has("good"): rw_txt += "善%+d " % out.good
	if out.has("evil"): rw_txt += "恶%+d " % out.evil
	if out.has("hero"): rw_txt += "侠%+d " % out.hero
	if out.has("spirit"): rw_txt += "灵%+d " % out.spirit
	var rw_lbl = Label.new(); rw_lbl.text = rw_txt; rw_lbl.add_theme_font_size_override("font_size", 11)
	rw_lbl.add_theme_color_override("font_color", C.GREEN); vb.add_child(rw_lbl)
	
	vb.add_child(_sep())
	vb.add_child(_lbl("🃏 拖入卡牌", 13, C.GOLD))
	
	var slot_nodes = []
	var slots = rite.get("slots",[])
	
	var slot_row = HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 12)
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(slot_row)
	
	for i in range(slots.size()):
		var slot_cfg = slots[i]
		var slot = _create_slot_ui(i, slot_cfg)
		slot_row.add_child(slot)
		# 先加进场景树，再回显卡牌
		if is_edit:
			if slot_cfg.type == "character" and not existing.char.is_empty():
				slot._drop_data(Vector2.ZERO, {"type":"character","data":existing.char})
			elif slot_cfg.type == "sultan_card" and not existing.sultan_card.is_empty():
				slot._drop_data(Vector2.ZERO, {"type":"sultan_card","data":existing.sultan_card})
		slot_nodes.append(slot)
		# 连接槽位信号
		slot.card_removed.connect(func(idx, card_data):
			_return_card_to_hand(slot_type_to_str(slot_cfg.type), card_data)
		)
		slot.card_clicked.connect(func(card_data):
			if slot_cfg.type == "sultan_card":
				_show_sultan_popup(card_data)
			else:
				_show_char_popup(card_data)
		)
	
	vb.add_child(_sep())
	
	var btn_hb = HBoxContainer.new(); btn_hb.alignment=BoxContainer.ALIGNMENT_CENTER
	btn_hb.add_theme_constant_override("separation", 16); vb.add_child(btn_hb)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "确认"
	confirm_btn.custom_minimum_size=Vector2(100,38); confirm_btn.add_theme_font_size_override("font_size", 13)
	confirm_btn.pressed.connect(func():
		var char_data = {}; var sultan_card_data = {}
		for sn in slot_nodes:
			if not sn.current_card.is_empty():
				if sn.slot_type == "character": char_data = sn.current_card
				elif sn.slot_type == "sultan_card": sultan_card_data = sn.current_card
		var valid = true
		for sn in slot_nodes:
			if not sn.is_optional and sn.current_card.is_empty():
				valid = false; _log("❌ 槽位未配置")
		if not valid: return
		var entry = {"rite": rite, "char": char_data, "sultan_card": sultan_card_data}
		if is_edit:
			var idx = active_rites.find(existing)
			if idx != -1: active_rites[idx] = entry
		else:
			active_rites.append(entry)
		_log("✅ 已配置「%s」" % rite.get("name",""))
		_commit_assigned_cards(slot_nodes)
		_clear_event_detail()
		_refresh()
	)
	btn_hb.add_child(confirm_btn)
	
	var cancel_btn = Button.new(); cancel_btn.text="取消"
	cancel_btn.custom_minimum_size=Vector2(100,38); cancel_btn.add_theme_font_size_override("font_size", 13)
	cancel_btn.pressed.connect(func():
		if is_edit:
			# 已配置→取消配置
			var idx = active_rites.find(existing)
			if idx != -1: active_rites.remove_at(idx)
			_log("🗑 已取消「%s」" % rite.get("name",""))
		_restore_assigned_cards(slot_nodes)
		_clear_event_detail()
		_refresh()
	)
	btn_hb.add_child(cancel_btn)
	
	event_detail_panel.set_meta("slot_nodes", slot_nodes)
	event_detail_panel.set_meta("assigned_cards", [])

func _clear_event_detail():
	for c in event_detail_vb.get_children():
		c.queue_free()
	var empty_lbl = Label.new(); empty_lbl.text = "🃏\n点击左侧地图中的仪式\n查看详情并配置卡牌"
	empty_lbl.add_theme_font_size_override("font_size", 14)
	empty_lbl.add_theme_color_override("font_color", C.DIM)
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_lbl.name = "EmptyHint"
	event_detail_vb.add_child(empty_lbl)

func _create_slot_ui(index:int, slot_cfg:Dictionary) -> Node:
	var slot = preload("res://scripts/ui/RiteSlotDrop.gd").new()
	slot.slot_index = index
	slot.slot_type = slot_cfg.get("type", "character")
	slot.required_tags = slot_cfg.get("required_tags", [])
	slot.is_optional = slot_cfg.get("optional", false)
	return slot

func _restore_assigned_cards(slot_nodes:Array):
	var assigned = event_detail_panel.get_meta("assigned_cards", [])
	for c in assigned:
		if is_instance_valid(c): c.visible = true
	for s in slot_nodes:
		if is_instance_valid(s) and s.has_method("clear_card"):
			s.clear_card()
	event_detail_panel.set_meta("assigned_cards", [])
	hand_layout.arrange()

func _commit_assigned_cards(slot_nodes:Array):
	# 不再 queue_free，只保持隐藏——结算后恢复
	for s in slot_nodes:
		if is_instance_valid(s) and s.has_method("clear_card"):
			s.clear_card()
	event_detail_panel.set_meta("assigned_cards", [])
	hand_layout.arrange()

# 结算后恢复手牌
func _restore_hand_cards():
	for c in hand_cards:
		if is_instance_valid(c) and not c.visible:
			c.visible = true
	hand_layout.arrange()

func _bottom() -> void:
	hand_container = Control.new(); hand_container.name="HandContainer"
	hand_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); hand_container.offset_top=-200
	hand_container.mouse_filter=Control.MOUSE_FILTER_PASS
	add_child(hand_container)
	
	# 卡牌区域背景（只覆盖卡牌区域，在俺寻思和下一天之间）
	var card_zone = PanelContainer.new(); card_zone.name="CardZone"
	card_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zs = StyleBoxFlat.new(); zs.bg_color=Color("0d0804",0.85); zs.set_corner_radius_all(8)
	zs.border_width_bottom=1; zs.border_width_top=1; zs.border_width_left=1; zs.border_width_right=1
	zs.border_color = C.GOLD_LO
	card_zone.add_theme_stylebox_override("panel",zs)
	hand_container.add_child(card_zone)
	
	# 延迟设置初始位置
	call_deferred("_update_card_zone")
	
	hand_cards.clear()
	
	# 俺寻思 — 左下角骷髅
	var insight = _make_insight_button()
	insight.position = Vector2(10, 50)
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
	ct_lbl = cp.get_node("VBoxContainer/TypeLbl") as Label
	cr_lbl = cp.get_node("VBoxContainer/RankLbl") as Label
	cd_lbl = cp.get_node("VBoxContainer/DaysLbl") as Label
	cp.drag_ended.connect(_on_hand_card_dropped)
	hand_container.add_child(cp); hand_cards.append(cp)
	
	# 资源卡（金币等可叠加）
	var gold_card = card_factory.make_resource_card("金币", "💰", "GOLD", ResourceManager.gold)
	gold_card.drag_ended.connect(_on_hand_card_dropped)
	gold_card.drag_started.connect(func(_c): hand_layout.arrange())
	gold_card._on_right_click = func(): _split_resource_card(gold_card, "金币", "💰", "GOLD")
	gold_card._on_click = func(): _show_res_popup("金币", "💰", "GOLD", gold_card.get_meta("res_count", 0))
	hand_container.add_child(gold_card); hand_cards.append(gold_card)
	resource_cards["金币"] = gold_card
	
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
	
	hand_layout.arrange()
	
	hand_container.resized.connect(func():
		if is_instance_valid(insight): insight.position = Vector2(10, hand_container.size.y / 2 - 61)
		if is_instance_valid(nb): nb.position = Vector2(hand_container.size.x - 135, hand_container.size.y / 2 - 36)
		if is_instance_valid(sort_btn): sort_btn.position = Vector2(hand_container.size.x - 135, hand_container.size.y / 2 + 16)
		hand_layout.update_card_zone()
	)


func _make_insight_button() -> PanelContainer:
	var insight = PanelContainer.new(); insight.name="InsightBtn"
	insight.custom_minimum_size=Vector2(70,152); insight.mouse_filter=Control.MOUSE_FILTER_STOP
	var iss = StyleBoxFlat.new(); iss.bg_color=Color("1a1018"); iss.set_corner_radius_all(10)
	iss.border_width_bottom=2; iss.border_width_top=2; iss.border_width_left=2; iss.border_width_right=2
	iss.border_color=C.GOLD_LO.darkened(0.5); iss.shadow_size=6; iss.shadow_color=C.SHADOW
	insight.add_theme_stylebox_override("panel",iss)
	# 点击也保留，拖入也生效
	insight.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
			_do_insight()
	)
	var iv = VBoxContainer.new(); iv.mouse_filter=Control.MOUSE_FILTER_IGNORE
	iv.alignment=BoxContainer.ALIGNMENT_CENTER; insight.add_child(iv)
	var lbl = Label.new(); lbl.text="💀\n俺寻思"; lbl.add_theme_font_size_override("font_size",14)
	lbl.add_theme_color_override("font_color",C.GOLD); lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(lbl)
	var hint = Label.new(); hint.text="拖入卡牌"; hint.add_theme_font_size_override("font_size",9)
	hint.add_theme_color_override("font_color",C.DIM); hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(hint)
	return insight

func _on_hand_card_dropped(card: PanelContainer, global_pos: Vector2):
	var dropped_in_slot = false
	
	# 1. 检查是否拖到了俺寻思
	var insight = hand_container.get_node_or_null("InsightBtn")
	if insight and insight.get_global_rect().has_point(global_pos):
		_do_insight()
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
	
	# 3. 检查仪式详情面板中的卡槽
	if not dropped_in_slot:
		var slot_nodes = event_detail_panel.get_meta("slot_nodes", [])
		for slot in slot_nodes:
			if is_instance_valid(slot) and slot.has_method("_can_drop_data"):
				if slot.get_global_rect().has_point(global_pos):
					var data = card.get_meta("drag_data", {})
					if slot._can_drop_data(global_pos, data):
						slot._drop_data(global_pos, data)
						card.visible = false
						var assigned = event_detail_panel.get_meta("assigned_cards", [])
						assigned.append(card)
						event_detail_panel.set_meta("assigned_cards", assigned)
						dropped_in_slot = true
						break
	
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
	var c2 = source_card.get_meta("res_count", 0)
	if c2 <= 1: return
	_update_card_count(source_card, c2 - 1)
	var newc = card_factory.make_resource_card(name_str, icon, quality, 1)
	newc.drag_ended.connect(_on_hand_card_dropped)
	newc.drag_started.connect(func(_c): hand_layout.arrange())
	newc._on_right_click = func(): _split_resource_card(newc, name_str, icon, quality)
	newc._on_click = func(): _show_res_popup(name_str, icon, quality, newc.get_meta("res_count", 0))
	hand_container.add_child(newc)
	var idx = hand_cards.find(source_card)
	if idx != -1: hand_cards.insert(idx + 1, newc)
	else: hand_cards.append(newc)
	hand_layout.arrange()

# 金币卡数量更新（同步 ResourceManager）
func _update_card_count(card: PanelContainer, count: int):
	card.set_meta("res_count", count)
	card.get_meta("res_data").count = count
	card.set_meta("drag_data", card.get_meta("res_data"))
	var lbl = card.get_node_or_null("VB/CountLbl")
	if lbl: lbl.text = ("x%d" % count) if count > 1 else ""
	if card.get_meta("res_type","") == "金币":
		ResourceManager.gold = count

func _show_res_popup(name_str:String, icon:String, quality:String, count:int):
	var popup = PanelContainer.new()
	popup.name="ResPopup"; popup.mouse_filter=Control.MOUSE_FILTER_STOP
	popup.custom_minimum_size=Vector2(280,160)
	var vs = get_viewport().size
	popup.position=Vector2((vs.x-280)/2,(vs.y-160)/2-40)
	var ps=StyleBoxFlat.new(); ps.bg_color=Color("1a0f0a"); ps.set_corner_radius_all(12)
	ps.border_width_bottom=3; ps.border_width_top=3; ps.border_width_left=3; ps.border_width_right=3
	ps.border_color=C.GOLD; ps.shadow_size=12; ps.shadow_color=Color("000000cc")
	ps.content_margin_left=16; ps.content_margin_right=16; ps.content_margin_top=12; ps.content_margin_bottom=12
	popup.add_theme_stylebox_override("panel",ps)
	var vb=VBoxContainer.new(); vb.add_theme_constant_override("separation",8); popup.add_child(vb)
	var hb=HBoxContainer.new(); vb.add_child(hb)
	var tl=Label.new(); tl.text="%s · x%d" % [name_str,count]; tl.add_theme_font_size_override("font_size",18)
	tl.add_theme_color_override("font_color",C.GOLD); tl.size_flags_horizontal=Control.SIZE_EXPAND_FILL; hb.add_child(tl)
	var cb=Button.new(); cb.text="✕"; cb.custom_minimum_size=Vector2(32,32); cb.pressed.connect(func(): popup.queue_free()); hb.add_child(cb)
	vb.add_child(_sep())
	var info=Label.new(); info.text="%s品质 · 可叠加\n右键拆分一个 · 拖两块合并" % quality
	info.add_theme_font_size_override("font_size",12); info.add_theme_color_override("font_color",C.TEXT); vb.add_child(info)
	add_child(popup)

# --- 结算 ---
func _next_press() -> void:
	if GameManager.is_game_over:
		_log("⚰️ 游戏已结束。"); _refresh(); return
	if active_rites.size() == 0:
		_log("⚔ 无事发生，推进一天。")
		active_rites.clear()
		TurnManager.next_day()
		_refresh()
		if GameManager.is_game_over: _show_game_over()
		return
	settle_sultan_used = false
	_log("⚔ 开始结算 %d 个仪式..." % active_rites.size())
	_settle_next(0)

func _settle_next(index:int) -> void:
	if index >= active_rites.size():
		if settle_sultan_used:
			GameManager.consume_sultan_card(0)
			_log("🃏 苏丹卡已消耗。")
		_restore_hand_cards()  # 人物卡回到手牌
		active_rites.clear()
		TurnManager.next_day()
		_log("✅ 所有仪式结算完毕。")
		_refresh()
		if GameManager.is_game_over: _show_game_over()
		return
	
	var ar = active_rites[index]
	if not ar.sultan_card.is_empty(): settle_sultan_used = true
	
	var popup = SettlementPopup.new()
	add_child(popup)
	popup.setup_and_show(ar.rite, ar.char, ar.sultan_card)
	popup.settlement_done.connect(func(result:Dictionary):
		_log("  结算：「%s」%s" % [result.rite.get("name",""), "成功" if result.success else "失败"])
		_settle_next(index+1)
	)

func _show_game_over() -> void:
	var panel = PanelContainer.new()
	panel.name = "GameOverPanel"; panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps = StyleBoxFlat.new(); ps.bg_color = Color("1a0000"); ps.set_corner_radius_all(16)
	ps.border_width_bottom=4; ps.border_width_top=4; ps.border_width_left=4; ps.border_width_right=4
	ps.border_color = C.FAIL; ps.shadow_size=20; ps.shadow_color=Color("aa000066")
	ps.content_margin_left=30; ps.content_margin_right=30; ps.content_margin_top=20; ps.content_margin_bottom=20
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = Vector2(360, 230); panel.size = Vector2(360, 230)
	var vs = get_viewport().size
	panel.position = Vector2((vs.x - 360) / 2, (vs.y - 230) / 2 - 60)
	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 14); panel.add_child(vb)
	var tl = Label.new(); tl.text = "☠ 苏丹的愤怒！"; tl.add_theme_font_size_override("font_size", 22)
	tl.add_theme_color_override("font_color", C.FAIL); tl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(tl)
	var dl = Label.new(); dl.text = "苏丹卡到期未消除...\n你已被处决。"; dl.add_theme_font_size_override("font_size", 14)
	dl.add_theme_color_override("font_color", C.TEXT); dl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(dl)
	var back = Button.new(); back.text="🏠 返回主菜单"; back.custom_minimum_size=Vector2(200,40)
	back.add_theme_font_size_override("font_size", 14); back.add_theme_color_override("font_color", C.TEXT)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vb.add_child(back)
	add_child(panel)

# 角色卡详情弹窗
func _show_char_popup(d:Dictionary):
	var popup = PanelContainer.new()
	popup.name = "CharPopup"; popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.custom_minimum_size = Vector2(340, 300)
	var vs = get_viewport().size
	popup.position = Vector2((vs.x - 340) / 2, (vs.y - 300) / 2 - 40)
	var ps = StyleBoxFlat.new(); ps.bg_color = Color("1a0f0a"); ps.set_corner_radius_all(12)
	ps.border_width_bottom=3; ps.border_width_top=3; ps.border_width_left=3; ps.border_width_right=3
	ps.border_color = C.GOLD; ps.shadow_size=12; ps.shadow_color=Color("000000cc")
	ps.content_margin_left=16; ps.content_margin_right=16; ps.content_margin_top=12; ps.content_margin_bottom=12
	popup.add_theme_stylebox_override("panel", ps)
	
	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); popup.add_child(vb)
	
	var hb = HBoxContainer.new(); vb.add_child(hb)
	var tl = Label.new(); tl.text = "👤 " + d.get("name","?")
	tl.add_theme_font_size_override("font_size", 18); tl.add_theme_color_override("font_color", C.GOLD)
	tl.size_flags_horizontal=Control.SIZE_EXPAND_FILL; hb.add_child(tl)
	var cb = Button.new(); cb.text="✕"; cb.custom_minimum_size=Vector2(32,32); cb.pressed.connect(func(): popup.queue_free())
	hb.add_child(cb)
	
	var tt = Label.new(); tt.text = d.get("title",""); tt.add_theme_font_size_override("font_size", 12)
	tt.add_theme_color_override("font_color", C.DIM); vb.add_child(tt)
	
	vb.add_child(_sep())
	var desc = Label.new(); desc.text = d.get("description",""); desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", C.TEXT); desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; vb.add_child(desc)
	vb.add_child(_sep())
	
	# 八维属性
	vb.add_child(_lbl("八围属性", 13, C.GOLD))
	var grid = GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 12)
	vb.add_child(grid)
	var attrs = d.get("attributes",{})
	for k in ["phy","com","sur","soc","cha","ste","wis","mag"]:
		var al = Label.new(); al.text = "%s %s %d" % [AI.get(k,k), AN.get(k,k), attrs.get(k,0)]
		al.add_theme_font_size_override("font_size", 11); al.add_theme_color_override("font_color", C.TEXT)
		grid.add_child(al)
	
	vb.add_child(_sep())
	var bonus = Label.new(); bonus.text = "📌 " + d.get("ritual_bonus",""); bonus.add_theme_font_size_override("font_size", 11)
	bonus.add_theme_color_override("font_color", C.GOLD_HI); bonus.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; vb.add_child(bonus)
	
	add_child(popup)

# 苏丹卡详情弹窗
func _show_sultan_popup(d:Dictionary):
	var popup = PanelContainer.new()
	popup.name = "SultanPopup"; popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.custom_minimum_size = Vector2(380, 280)
	var vs = get_viewport().size
	popup.position = Vector2((vs.x - 380) / 2, (vs.y - 280) / 2 - 40)
	var tc = TC.get(d.get("type",""), C.LUST)
	var ps = StyleBoxFlat.new(); ps.bg_color = Color("1a0f0a"); ps.set_corner_radius_all(12)
	ps.border_width_bottom=3; ps.border_width_top=3; ps.border_width_left=3; ps.border_width_right=3
	ps.border_color = tc; ps.shadow_size=12; ps.shadow_color=Color(tc.r,tc.g,tc.b,0.4)
	ps.content_margin_left=16; ps.content_margin_right=16; ps.content_margin_top=12; ps.content_margin_bottom=12
	popup.add_theme_stylebox_override("panel", ps)
	
	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); popup.add_child(vb)
	
	var hb = HBoxContainer.new(); vb.add_child(hb)
	var tl = Label.new(); tl.text = "🃏 " + d.get("name","?")
	tl.add_theme_font_size_override("font_size", 18); tl.add_theme_color_override("font_color", C.GOLD)
	tl.size_flags_horizontal=Control.SIZE_EXPAND_FILL; hb.add_child(tl)
	var cb = Button.new(); cb.text="✕"; cb.custom_minimum_size=Vector2(32,32); cb.pressed.connect(func(): popup.queue_free())
	hb.add_child(cb)
	
	var info = Label.new()
	info.text = "%s · %s | 剩余 %d 天" % [TN.get(d.get("type",""),"?"), RG.get(d.get("rank",""),"?"), GameManager.sultan_card_days_left]
	info.add_theme_font_size_override("font_size", 13); info.add_theme_color_override("font_color", tc); vb.add_child(info)
	
	vb.add_child(_sep())
	var desc = Label.new(); desc.text = d.get("description",""); desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", C.TEXT); desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; vb.add_child(desc)
	
	if d.has("flavor"):
		vb.add_child(_sep())
		var fl = Label.new(); fl.text = "\"" + d.get("flavor","") + "\""; fl.add_theme_font_size_override("font_size", 11)
		fl.add_theme_color_override("font_color", C.DIM); fl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; vb.add_child(fl)
	
	add_child(popup)

func _refresh() -> void:
	d_lbl.text = "第%d天" % TurnManager.current_day
	w_lbl.text = "第%d周" % TurnManager.current_week
	gd_lbl.text = "🎲金骰:%d" % ResourceManager.gold_dice
	g_lbl.text = "善%d" % ResourceManager.reputations.good
	e_lbl.text = "恶%d" % ResourceManager.reputations.evil
	p_lbl.text = "权%d" % ResourceManager.reputations.power
	h_lbl.text = "侠%d" % ResourceManager.reputations.hero
	s_lbl.text = "灵%d" % ResourceManager.reputations.spirit
	
	var card = GameManager.active_sultan_card
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

# 同步金币卡数量和 ResourceManager

func _load_rites() -> Array:
	var f = FileAccess.open("res://data/rites.json",FileAccess.READ)
	if f == null: return []
	var d = JSON.parse_string(f.get_as_text()); f.close()
	if d == null: return []
	return d

func slot_type_to_str(t: String) -> String:
	return "character" if t == "character" else "sultan_card"

# 卡牌从槽位移除时，恢复到手中
func _return_card_to_hand(card_type: String, card_data: Dictionary):
	# 先找已隐藏的匹配卡牌
	for c in hand_cards:
		if not c.visible and is_instance_valid(c):
			var dd = c.get_meta("drag_data", {})
			if dd.get("type","") == card_type and dd.get("id","") == card_data.get("id",""):
				c.visible = true
				hand_layout.arrange()
				return
	
	# 找不到（如确认后重开再拖出），重新创建一张
	var new_card: PanelContainer
	if card_type == "character":
		new_card = _make_char_card(card_data)
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

func _sl(t:String, c:Color=Color.WHITE) -> Label:
	var l = Label.new(); l.text=t; l.add_theme_color_override("font_color",c)
	l.add_theme_font_size_override("font_size",13); l.vertical_alignment=3; return l

func _cl(t:String, s:int, c:Color) -> Label:
	var l = Label.new(); l.text=t; l.add_theme_font_size_override("font_size",s)
	l.add_theme_color_override("font_color",c); l.horizontal_alignment=1; return l

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

func _do_insight() -> void:
	var card = GameManager.active_sultan_card
	if card.is_empty(): _log("俺寻思：暂无卡牌可探索。"); return
	var discoveries = [
		"在角落发现了被遗忘的宝箱...（金币+5）",
		"密信揭示了贵族的秘密...（权势+1）",
		"流浪猫带路发现了隐藏道具...（金骰子+1）",
		"不小心惊动了卫兵...（金币-2）",
		"在旧书中看到禁断的诗...（灵视+1）",
	]
	var idx = randi()%discoveries.size()
	var result = discoveries[idx]
	_log("俺寻思：%s" % result.split("（")[0])
	match idx:
		0: ResourceManager.add_gold(5)
		1: ResourceManager.modify_reputation("power",1)
		2: ResourceManager.modify_gold_dice(1)
		3: ResourceManager.add_gold(-2)
		4: ResourceManager.modify_reputation("spirit",1)
	_refresh()
