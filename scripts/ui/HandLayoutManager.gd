# HandLayoutManager.gd
# 手牌布局管理器 — 排列/排序/合并/堆叠
# 从 MainScene 提取 (Phase 1.2)

class_name HandLayoutManager
extends RefCounted

var hand_cards: Array  # 引用 MainScene 的 hand_cards
var hand_container: Control
var sort_btn: TextureButton
var sort_mode: int = 0
var _window_start: float = 0.0   # 展开窗口起始索引（鼠标离开手牌区时冻结）
var _update_count_cb: Callable
var _CHAR_QUALITY: Dictionary = {}

const CARD_SIZE := Vector2(100, 180)

func setup(p_hand_cards: Array, p_hand_container: Control, p_sort_btn: TextureButton, update_count_cb: Callable, char_quality: Dictionary) -> void:
	hand_cards = p_hand_cards
	hand_container = p_hand_container
	sort_btn = p_sort_btn
	_update_count_cb = update_count_cb
	_CHAR_QUALITY = char_quality

func arrange():
	var visible_cards = []
	for i in range(hand_cards.size()):
		var card = hand_cards[i]
		if not is_instance_valid(card) or not card.visible: continue
		if card.is_dragging:
			continue  # 拖拽中的卡由鼠标控制位置，不参与堆叠布局计数；否则移出手牌区时仍被计入会使 n 虚增一张，堆叠窗口计算错位、右边界溢出
		visible_cards.append(card)
	
	if visible_cards.size() == 0: return
	
	var insight = hand_container.get_node_or_null("InsightBtn")
	var left = insight.position.x + insight.size.x - 10 if insight and is_instance_valid(insight) else 106
	var right = sort_btn.position.x - 8 if sort_btn and is_instance_valid(sort_btn) else hand_container.size.x - 8
	var card_y = hand_container.size.y / 2 - CARD_SIZE.y / 2.0
	var card_w = CARD_SIZE.x; var gap = 8; var n = visible_cards.size()
	var avail = right - left
	var stack_reveal = 20
	
	var full_w = n * card_w + (n - 1) * gap
	if full_w <= avail:
		var x0 = (left + right - full_w) / 2
		for i in range(n):
			var c = visible_cards[i]
			c.set_rest_position(Vector2(x0 + i * (card_w + gap), card_y))
			# 居中铺开：索引递增层级（右边盖左边），hover/拖拽时层级由卡自身管理
			if not c.is_hovered and not c.is_dragging:
				c.z_index = 1 + i
		return
	
	# 三段布局：左堆(si张,锚左) + 展开区(kk张) + 右堆(rcount张,锚右)，n=si+kk+rcount。
	# 展开区用“正常卡间距”(card_w+gap)，不拉伸。若正常间距下展开区与右堆之间还有空挡，
	# 则“少堆一张”：把一张卡从堆移入展开区(kk=k+1)并右对齐贴住右堆，展开区轻微压住堆叠顶卡
	# （最多 TOL 像素，观感像手牌自然叠压），从而消除空挡——符合用户要求。
	var stack_overhang = card_w - stack_reveal
	var denom = card_w + gap - stack_reveal
	var lm = hand_container.get_local_mouse_position()
	# 卡牌往往比容器高（card_y 为负，视觉上露在容器矩形上方），必须用手牌真实所在区域判断，
	# 否则鼠标移到堆叠区（卡牌上方露出的部分）时 has_point 失败，arrange 不触发。
	var hand_zone = Rect2(left, card_y - 24, max(avail, 0.0), CARD_SIZE.y + 40)
	var active = hand_zone.has_point(lm)
	# focus=聚焦卡的连续索引∈[0,n-1]；鼠标离开手牌区时冻结在 _window_start(不回弹)。
	var focus = clamp(_window_start, 0.0, float(n - 1))
	if active:
		focus = clamp((lm.x - left) / max(avail, 1.0), 0.0, 1.0) * float(n - 1)
		_window_start = focus
	# 初值 k 用“两侧都堆”的保守下界(floor)，避免初值过大令 si 卡死在 n-1(旧版空挡根因)。
	var ke0 = (avail - n * stack_reveal - 2.0 * stack_overhang - gap) / denom
	var k = clamp(int(floor(ke0)), 1, n)
	var si = int(round(clamp(focus - float(k - 1) / 2.0, 0.0, float(n - k))))
	for iter in range(16):
		var overL = stack_overhang if si > 0 else 0.0
		var rc0 = n - si - k
		var overR = stack_overhang if rc0 > 0 else 0.0
		var gapL = gap if si > 0 else 0
		var gapR = gap if rc0 > 0 else 0
		var ke = (avail - n * stack_reveal - overL - overR - gapL - gapR + gap) / denom
		# floor 保证展开区永不溢出（余量非负，后面用“少堆一张”吸收）。
		k = clamp(int(floor(ke)), 1, n)
		si = int(round(clamp(focus - float(k - 1) / 2.0, 0.0, float(n - k))))
	var rcount = n - si - k

	# 尝试“少堆一张”：多铺一张展开卡(kk=k+1)，右对齐贴住右堆/右边界消除右侧空挡。
	# 仅当展开区压住左堆顶卡的交叠 ≤ TOL 时才接受（无左堆时直接接受，越界由后面 clamp 处理）。
	var TOL = 60.0
	var kk = k
	var upgraded = false
	var rcc = rcount
	if rcount >= 1:
		rcc = rcount - 1
		var rc_edge = (right - card_w - (rcc - 1) * stack_reveal) if rcc > 0 else right
		var sRc = (rc_edge - gap) if rcc > 0 else right
		var sw = (k + 1) * card_w + k * gap
		var first_c = sRc - sw
		var sLc = 0.0
		if si > 0:
			sLc = si * stack_reveal + stack_overhang + gap
		if si == 0 or (sLc - first_c) <= TOL:
			upgraded = true
			kk = k + 1
			rcount = rcc
	if not upgraded and si >= 1:
		rcc = rcount
		var rc_edge2 = (right - card_w - (rcc - 1) * stack_reveal) if rcc > 0 else right
		var sRc2 = (rc_edge2 - gap) if rcc > 0 else right
		var sw2 = (k + 1) * card_w + k * gap
		var first_c2 = sRc2 - sw2
		var sLc2 = (si - 1) * stack_reveal + stack_overhang + gap
		if (sLc2 - first_c2) <= TOL:
			upgraded = true
			kk = k + 1
			si = si - 1

	# 左堆：索引 < si，锚定左边缘向右堆叠；靠窗口（右边）的卡层级更高
	var left_end = left
	var x = left
	for i in range(si):
		var c = visible_cards[i]
		c.set_rest_position(Vector2(x, card_y))
		x += stack_reveal
		if not c.is_hovered and not c.is_dragging:
			c.z_index = 1 + i
	left_end = x

	# 右堆：索引 >= si + kk，锚定右边缘向左堆叠；靠窗口（左边）的卡层级更高
	var right_start = right
	if rcount > 0:
		for i in range(si + kk, n):
			var c = visible_cards[i]
			var off = (n - 1 - i) * stack_reveal
			c.set_rest_position(Vector2(right - card_w - off, card_y))
			if not c.is_hovered and not c.is_dragging:
				# 右堆 z 整体抬到展开区之上，使三段 z 域 [1,si]/[si+1,si+kk]/[si+kk+1,n] 严格不重叠，
				# 否则原公式 1+(n-1)-i 的 z 域会与展开区/左堆重叠，导致相邻卡 z 交叉、视觉穿插乱。
				c.z_index = 1 + si + kk + (n - 1) - i
		right_start = right - card_w - (rcount - 1) * stack_reveal

	# 展开区：索引 [si, si+kk-1]。正常卡间距；少堆一张后右对齐贴右堆(消除右侧空挡)，
	# 否则左对齐贴左堆；无堆时(全展开)居中。z 整体抬到两侧堆叠之上，保证交界一致。
	var rc_edge_p = (right - card_w - (rcount - 1) * stack_reveal) if rcount > 0 else right
	var sL = left_end + (stack_overhang if si > 0 else 0.0) + (gap if si > 0 else 0)
	var sR = (rc_edge_p - gap) if rcount > 0 else right
	var spread_w = kk * card_w + (kk - 1) * gap
	var first_x = 0.0
	if si == 0 and rcount == 0:
		first_x = (left + right - spread_w) / 2.0   # 全展开：居中
	elif upgraded:
		first_x = max(sR - spread_w, left)          # 右对齐贴右堆，且不越左边界
	else:
		first_x = sL                                # 左对齐贴左堆
	for i in range(kk):
		var c = visible_cards[si + i]
		c.set_rest_position(Vector2(first_x + float(i) * (card_w + gap), card_y))
		if not c.is_hovered and not c.is_dragging:
			c.z_index = n + 1 + i

func update_card_zone():
	var cz = hand_container.get_node_or_null("CardZone")
	if not cz: return
	var insight = hand_container.get_node_or_null("InsightBtn")
	var cz_left = insight.position.x + insight.size.x - 10 if insight and is_instance_valid(insight) else 100
	var cz_right = sort_btn.position.x - 4 if sort_btn and is_instance_valid(sort_btn) else hand_container.size.x - 8
	cz.position = Vector2(cz_left, 4)
	cz.size = Vector2(cz_right - cz_left, hand_container.size.y - 8)

func cycle_sort():
	sort_mode = (sort_mode + 1) % 2
	auto_merge_resources()
	if sort_mode == 0:
		hand_cards.sort_custom(func(a, b): return _sort_by_category(a) < _sort_by_category(b))
	else:
		hand_cards.sort_custom(func(a, b): return _sort_by_quality(a) < _sort_by_quality(b))
	arrange()

func auto_merge_resources():
	var merged = {}
	for i in range(hand_cards.size() - 1, -1, -1):
		var c = hand_cards[i]
		var rt = c.get_meta("res_type", "")
		if rt == "" or not is_instance_valid(c): continue
		if not rt in merged:
			merged[rt] = c
		else:
			var target = merged[rt]
			_update_count_cb.call(target, target.get_meta("res_count", 0) + c.get_meta("res_count", 0))
			c.queue_free()
			hand_cards.remove_at(i)

func _sort_by_category(c: PanelContainer) -> int:
	if c.name == "SC": return 1
	if c.get_meta("res_type", "") != "": return 0
	return 2

func _sort_by_quality(c: PanelContainer) -> int:
	var dd = c.get_meta("drag_data", {})
	var q = dd.get("data", {}).get("rank", "")
	if q == "": q = dd.get("data", {}).get("quality", "")
	if q == "":
		var cq = _CHAR_QUALITY.get(dd.get("id", ""), "STONE")
		q = cq
	return {"GOLD": 0, "SILVER": 1, "BRONZE": 2, "STONE": 3}.get(q, 4)
