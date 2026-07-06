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
var card_factory: CardFactory = CardFactory.new()
var hand_layout: HandLayoutManager = HandLayoutManager.new()
var popups: PopupManager = PopupManager.new()

# ============ UI 节点 ============
var d_lbl:Label;var w_lbl:Label;var gd_lbl:Label
var g_lbl:Label;var e_lbl:Label;var p_lbl:Label;var h_lbl:Label;var s_lbl:Label
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
var settle_sultan_used: bool = false
var _insight_used_keys: Array[String] = []
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
		if _get_rite_by_id(rite.get("id",-1)) == null:
			active_rites.append({"rite":rite,"char":{},"sultan_card":{}})
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

# 左侧地图 — 仪式节点直接散布，无地点分组
func _map() -> void:
	var map = PanelContainer.new()
	map.name = "MapPanel"
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.offset_top = 32; map.offset_bottom = -200
	var ps = StyleBoxFlat.new(); ps.bg_color = C.BG_MID; ps.set_corner_radius_all(10)
	ps.border_width_bottom=2; ps.border_width_top=2; ps.border_width_left=2; ps.border_width_right=2
	ps.border_color = C.GOLD_LO; ps.shadow_size=6; ps.shadow_color=C.SHADOW
	ps.content_margin_left=12; ps.content_margin_right=12; ps.content_margin_top=10; ps.content_margin_bottom=10
	map.add_theme_stylebox_override("panel", ps)
	add_child(map)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	map.add_child(vb)

	_all_rites = _load_rites()
	
	var perm_hb = HBoxContainer.new()
	perm_hb.add_theme_constant_override("separation", 4)
	vb.add_child(perm_hb)
	for rite in _all_rites:
		if rite.id in PERMANENT_RITE_IDS:
			var btn = Button.new()
			btn.text = rite.get("name","?")
			btn.custom_minimum_size = Vector2(100, 40)
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", C.GOLD)
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color("1a0f0a")
			sb.set_corner_radius_all(6)
			sb.border_width_bottom = 2
			sb.border_color = C.GOLD_LO
			btn.add_theme_stylebox_override("normal", sb)
			btn.pressed.connect(func(rite2=rite): _on_rite_node_clicked(rite2))
			perm_hb.add_child(btn)
	
	var dyn_hb = HBoxContainer.new()
	dyn_hb.add_theme_constant_override("separation", 4)
	vb.add_child(dyn_hb)
	for ar in active_rites:
		var rite = ar.get("rite", ar)
		if rite.get("category","") != "permanent":
			var btn = Button.new()
			btn.text = rite.get("name","?")
			btn.custom_minimum_size = Vector2(100, 40)
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", C.GOLD)
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color("1a0f0a")
			sb.set_corner_radius_all(6)
			sb.border_width_bottom = 2
			sb.border_color = C.GOLD_LO
			btn.add_theme_stylebox_override("normal", sb)
			dyn_hb.add_child(btn)

func _make_rite_node(rite: Dictionary) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(100, 60)
	btn.text = rite.get("name", "?")
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", C.GOLD)
	var sb = StyleBoxFlat.new(); sb.bg_color = Color("2a2018"); sb.set_corner_radius_all(8)
	sb.border_width_bottom=1; sb.border_color=C.GOLD_LO
	btn.add_theme_stylebox_override("normal", sb)
	btn.pressed.connect(func(): _on_rite_node_clicked(rite))
	return btn

func _on_rite_node_clicked(rite: Dictionary):
	var existing = _get_rite_by_id(rite.get("id", -1))
	if existing:
		_log("「%s」已配置角色:%s" % [rite.get("name",""), existing.char.get("name","无")])
	else:
		var entry = {"rite": rite, "char": {}, "sultan_card": {}}
		active_rites.append(entry)
		_log("📋 「%s」已加入今日计划" % rite.get("name","?"))


func _get_rite_by_id(rite_id: int):
	for ar in active_rites:
		if ar.rite.get("id", -1) == rite_id:
			return ar
	return null

func _close_rite_popup() -> void:
	_clear_all_highlights()
	if _rite_popup and is_instance_valid(_rite_popup):
		_rite_popup.queue_free()
		_rite_popup = null

func _open_rite_detail(rite: Dictionary) -> void:
	_close_rite_popup()
	
	var popup = PanelContainer.new()
	popup.name = "RitePopup"
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 尺寸和定位：参考 SettlementScreen，大弹窗居中
	var vs = get_viewport().size
	var pw = min(vs.x - 60, 960); var ph = min(vs.y - 260, 480)
	popup.custom_minimum_size = Vector2(pw, ph)
	popup.size = Vector2(pw, ph)
	popup.position = Vector2((vs.x - pw) / 2, max(40, vs.y * 0.05))
	
	# 外层样式（金边框+阴影，和 SettlementScreen 一致）
	var ops = StyleBoxFlat.new()
	ops.bg_color = C.BG_PANEL; ops.set_corner_radius_all(12)
	ops.border_width_bottom=3; ops.border_width_top=3
	ops.border_width_left=3; ops.border_width_right=3
	ops.border_color = C.GOLD; ops.shadow_size=16; ops.shadow_color=C.SHADOW
	ops.content_margin_left=12; ops.content_margin_right=12
	ops.content_margin_top=10; ops.content_margin_bottom=10
	popup.add_theme_stylebox_override("panel", ops)
	
	# 左右分栏
	var split = HSplitContainer.new()
	split.split_offset = 440  # 左侧卡槽区占大头
	popup.add_child(split)
	
	# === 左侧：卡槽区 ===
	var left = PanelContainer.new()
	var lps = StyleBoxFlat.new()
	lps.bg_color = Color("0d0804"); lps.set_corner_radius_all(8)
	lps.border_width_bottom=1; lps.border_width_top=1; lps.border_width_left=1; lps.border_width_right=1
	lps.border_color = C.GOLD_LO
	lps.content_margin_left=14; lps.content_margin_right=14; lps.content_margin_top=12; lps.content_margin_bottom=12
	left.add_theme_stylebox_override("panel", lps)
	split.add_child(left)
	
	var lvb = VBoxContainer.new()
	lvb.add_theme_constant_override("separation", 12)
	lvb.alignment = BoxContainer.ALIGNMENT_CENTER
	lvb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(lvb)

	current_rite_detail = rite
	var existing = _find_configured_rite(rite)
	var is_edit = existing != null
	var check = rite.get("check",{})
	var out = rite.get("outcomes",{}).get("success",{})
	var slots = rite.get("slots",[])
	var slot_nodes = []

	# — 标题 —
	var tl = Label.new()
	tl.text = "📜 " + rite.get("name","") + (" (已配置)" if is_edit else "")
	tl.add_theme_font_size_override("font_size", 18)
	tl.add_theme_color_override("font_color", C.GREEN if is_edit else C.GOLD)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvb.add_child(tl)

	# — 卡槽：横向排列，自动换行 —
	var slot_flow = FlowContainer.new()
	slot_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	slot_flow.add_theme_constant_override("h_separation", 16)
	slot_flow.add_theme_constant_override("v_separation", 10)
	lvb.add_child(slot_flow)

	for i in range(slots.size()):
		var slot_cfg = slots[i]
		# 每个卡槽是一个 VBox（标签 + 槽位）
		var slot_box = VBoxContainer.new()
		slot_box.add_theme_constant_override("separation", 4)
		slot_box.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_flow.add_child(slot_box)

		var sc_lbl = Label.new()
		var label_text = "角色卡槽" if slot_cfg.type == "character" else "苏丹卡槽"
		if slot_cfg.get("optional", false): label_text += "（可选）"
		sc_lbl.text = "🃏 " + label_text
		sc_lbl.add_theme_font_size_override("font_size", 10)
		sc_lbl.add_theme_color_override("font_color", C.DIM)
		sc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_box.add_child(sc_lbl)

		var slot = _create_slot_ui(i, slot_cfg)
		slot.custom_minimum_size = Vector2(70, 152)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot_box.add_child(slot)

		if is_edit:
			if slot_cfg.type == "character" and not existing.char.is_empty():
				slot._drop_data(Vector2.ZERO, {"type":"character","data":existing.char})
			elif slot_cfg.type == "sultan_card" and not existing.sultan_card.is_empty():
				slot._drop_data(Vector2.ZERO, {"type":"sultan_card","data":existing.sultan_card})
		slot_nodes.append(slot)
		slot.card_removed.connect(func(idx, card_data):
			_return_card_to_hand(slot_type_to_str(slot_cfg.type), card_data))
		slot.card_clicked.connect(func(card_data):
			if slot_cfg.type == "sultan_card":
				popups.show_sultan_popup(card_data)
			else:
				popups.show_char_popup(card_data))
		# 点击空槽位 → 高亮符合条件的卡牌
		slot.empty_slot_clicked.connect(func(_idx):
			_clear_all_highlights()
			for card in hand_cards:
				if not is_instance_valid(card) or not card.visible:
					continue
				var drag_data = card.get_meta("drag_data", {})
				if drag_data.is_empty():
					continue
				if slot._can_drop_data(Vector2.ZERO, drag_data):
					card.set_highlight(true))

	# — 确认/取消按钮 —
	var btn_hb = HBoxContainer.new()
	btn_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hb.add_theme_constant_override("separation", 16)
	var spacer = Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lvb.add_child(spacer)
	lvb.add_child(btn_hb)

	var confirm_btn = Button.new()
	confirm_btn.text = "确认"
	confirm_btn.custom_minimum_size = Vector2(100, 38); confirm_btn.add_theme_font_size_override("font_size", 13)
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
		_close_rite_popup()
		_refresh())
	btn_hb.add_child(confirm_btn)

	var cancel_btn = Button.new(); cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(100, 38); cancel_btn.add_theme_font_size_override("font_size", 13)
	cancel_btn.pressed.connect(func():
		if is_edit:
			var idx = active_rites.find(existing)
			if idx != -1: active_rites.remove_at(idx)
			_log("🗑 已取消「%s」" % rite.get("name",""))
		_restore_assigned_cards(slot_nodes)
		_close_rite_popup()
		_refresh())
	btn_hb.add_child(cancel_btn)

	# === 右侧：描述/检定/奖励区 ===
	var right = PanelContainer.new()
	var rps = StyleBoxFlat.new()
	rps.bg_color = Color("0d0804"); rps.set_corner_radius_all(8)
	rps.border_width_bottom=1; rps.border_width_top=1; rps.border_width_left=1; rps.border_width_right=1
	rps.border_color = C.GOLD_LO
	rps.content_margin_left=14; rps.content_margin_right=14; rps.content_margin_top=12; rps.content_margin_bottom=12
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

	# 关闭按钮
	var close_row = HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	rvb.add_child(close_row)
	var close_btn = Button.new()
	close_btn.text = "✕"; close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(_close_rite_popup)
	close_row.add_child(close_btn)

	# 描述
	var dl = Label.new(); dl.text = rite.get("description","")
	dl.add_theme_font_size_override("font_size", 13); dl.add_theme_color_override("font_color", C.TEXT)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rvb.add_child(dl)
	rvb.add_child(_sep())

	# 检定信息
	var ck_txt = "检定："
	if check.get("type", "solo") == "solo":
		ck_txt += "%s · 需%d成功" % [AN.get(check.get("attribute",""),"?"), check.get("required_successes",1)]
	elif check.get("type") == "combined":
		var ans = []
		for a in check.get("attributes",[]): ans.append(AN.get(a,a))
		ck_txt += "、".join(ans) + " · 需%d成功" % check.get("required_successes",1)
	var ck_lbl = Label.new(); ck_lbl.text = ck_txt
	ck_lbl.add_theme_font_size_override("font_size", 12); ck_lbl.add_theme_color_override("font_color", C.DIM)
	rvb.add_child(ck_lbl)

	# 成功奖励
	var rw_txt = "成功奖励："
	if out.has("gold"): rw_txt += "💰%+d " % out.gold
	if out.has("power"): rw_txt += "权%+d " % out.power
	if out.has("good"): rw_txt += "善%+d " % out.good
	if out.has("evil"): rw_txt += "恶%+d " % out.evil
	if out.has("hero"): rw_txt += "侠%+d " % out.hero
	if out.has("spirit"): rw_txt += "灵%+d " % out.spirit
	var rw_lbl = Label.new(); rw_lbl.text = rw_txt
	rw_lbl.add_theme_font_size_override("font_size", 12); rw_lbl.add_theme_color_override("font_color", C.GREEN)
	rvb.add_child(rw_lbl)

	# 失败后果
	rvb.add_child(_sep())
	var fail_out = rite.get("outcomes",{}).get("fail",{})
	var fail_text = fail_out.get("narrative", fail_out.get("description", "无特殊惩罚"))
	var fl = Label.new(); fl.text = "失败：" + fail_text
	fl.add_theme_font_size_override("font_size", 11); fl.add_theme_color_override("font_color", C.DIM)
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rvb.add_child(fl)

	rvb.add_child(_sep())
	rvb.add_child(_lbl("🃏 将卡牌拖入左侧卡槽", 12, C.GOLD))

	popup.set_meta("slot_nodes", slot_nodes)
	popup.set_meta("assigned_cards", [])
	add_child(popup)
	_rite_popup = popup

func _create_slot_ui(index:int, slot_cfg:Dictionary) -> Node:
	var slot = preload("res://scripts/ui/RiteSlotDrop.gd").new()
	slot.slot_index = index
	slot.slot_type = slot_cfg.get("type", "character")
	slot.required_tags = slot_cfg.get("required_tags", [])
	slot.is_optional = slot_cfg.get("optional", false)
	return slot

func _restore_assigned_cards(slot_nodes:Array):
	if not _rite_popup: return
	var assigned = _rite_popup.get_meta("assigned_cards", [])
	for c in assigned:
		if is_instance_valid(c): c.visible = true
	for s in slot_nodes:
		if is_instance_valid(s) and s.has_method("clear_card"):
			s.clear_card()
	_rite_popup.set_meta("assigned_cards", [])
	hand_layout.arrange()

func _commit_assigned_cards(slot_nodes:Array):
	if not _rite_popup: return
	for s in slot_nodes:
		if is_instance_valid(s) and s.has_method("clear_card"):
			s.clear_card()
	_rite_popup.set_meta("assigned_cards", [])
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
	
	# 资源卡（金币等可叠加）
	var gold_card = card_factory.make_resource_card("金币", "💰", "GOLD", ResourceManager.gold)
	gold_card.drag_ended.connect(_on_hand_card_dropped)
	gold_card.drag_started.connect(func(_c): hand_layout.arrange())
	gold_card._on_right_click = func(): _split_resource_card(gold_card, "金币", "💰", "GOLD")
	gold_card._on_click = func(): popups.show_res_popup("金币", "💰", "GOLD", gold_card.get_meta("res_count", 0))
	hand_container.add_child(gold_card); hand_cards.append(gold_card)
	resource_cards["金币"] = gold_card
	
	# 情报卡（按需创建，初始可见）
	_refresh_intel_cards()
	
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
		var slot_nodes = _rite_popup.get_meta("slot_nodes", [])
		for slot in slot_nodes:
			if is_instance_valid(slot) and slot.has_method("_can_drop_data"):
				if slot.get_global_rect().has_point(global_pos):
					var data = card.get_meta("drag_data", {})
					if slot._can_drop_data(global_pos, data):
						slot._drop_data(global_pos, data)
						card.visible = false
						var assigned = _rite_popup.get_meta("assigned_cards", [])
						assigned.append(card)
						_rite_popup.set_meta("assigned_cards", assigned)
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
	newc._on_click = func(): popups.show_res_popup(name_str, icon, quality, newc.get_meta("res_count", 0))
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

func _next_press() -> void:
	_insight_used_keys.clear()
	# 检查是否有未执行的杀戮仪式，若是则第二天弹出荣誉杀戮
	_check_pending_honor_kill()
	if GameManager.is_game_over:
		_log("⚰️ 游戏已结束。"); _refresh(); return
	if active_rites.size() == 0:
		_log("⚔ 无事发生，推进一天。")
		active_rites.clear()
		TurnManager.next_day()
		_refresh()
		if GameManager.is_game_over: popups.show_game_over()
		return
	settle_sultan_used = false
	_log("⚔ 开始结算 %d 个仪式..." % active_rites.size())
	_settle_next(0)

func _settle_next(index:int) -> void:
	if index >= active_rites.size():
		if settle_sultan_used:
			GameManager.consume_sultan_card(0)
			_log("🃏 苏丹卡已消耗。")
		_restore_hand_cards()
		# 检查是否有装修仪式完成
		for ar in active_rites:
			if ar.rite.has("s2_gold") and ar.rite.get("insight_trigger",{}).get("subtype","") == "LUXURY":
				if not ar.char.is_empty():  # 有人执行了
					GameManager.renovation_done = true
					_log("🏠 装修已完成！")
		active_rites.clear()
		TurnManager.next_day()
		_log("✅ 所有仪式结算完毕。")
		_refresh()
		if GameManager.is_game_over: popups.show_game_over()
		return
	
	var ar = active_rites[index]
	
	# 俺寻思事件必须有角色才结算
	if ar.get("insight", false) and ar.char.is_empty():
		_log("⚠ 「%s」缺少角色，跳过结算。" % ar.rite.get("name","?"))
		_settle_next(index + 1)
		return
	
	if not ar.sultan_card.is_empty(): settle_sultan_used = true
	
	var screen = SettlementScreen.new()
	add_child(screen)
	screen.setup_and_show(ar.rite, ar.char, ar.sultan_card)
	screen.settlement_done.connect(func(result:Dictionary):
		_log("  结算：「%s」%s" % [result.rite.get("name",""), "成功" if result.success else "失败"])
		_settle_next(index+1)
	)

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
	hand_layout.arrange()
	_refresh_intel_cards()

# 同步金币卡数量和 ResourceManager

func _load_rites() -> Array:
	var f = FileAccess.open("res://data/rites.json",FileAccess.READ)
	if f == null: return []
	var d = JSON.parse_string(f.get_as_text()); f.close()
	if d == null: return []
	return d

func _refresh_intel_cards():
	var types = [
		{"name": "秘密", "icon": "📜", "q": "BRONZE"},
		{"name": "洞察", "icon": "🔍", "q": "BRONZE"},
	]
	for it in types:
		var nm = it.name
		var card = resource_cards.get(nm)
		var cnt = ResourceManager.get_intel_count(nm)
		if cnt > 0:
			if not is_instance_valid(card):
				card = card_factory.make_resource_card(nm, it.icon, it.q, cnt)
				card.drag_ended.connect(_on_hand_card_dropped)
				card.drag_started.connect(func(_c): hand_layout.arrange())
				card._on_right_click = func(): _split_resource_card(card, nm, it.icon, it.q)
				card._on_click = func(): popups.show_res_popup(nm, it.icon, it.q, card.get_meta("res_count", 0))
				hand_container.add_child(card); hand_cards.append(card)
				resource_cards[nm] = card
			else:
				card.set_meta("res_count", cnt)
				if card.has_meta("res_data"): card.get_meta("res_data").count = cnt
				card.get_node_or_null("VB/CountLbl").text = ("x%d" % cnt) if cnt > 1 else ""
				card.visible = true
		else:
			if is_instance_valid(card):
				card.visible = false

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
