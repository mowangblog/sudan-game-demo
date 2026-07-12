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
	
	# 计算最多能完整铺开的卡数 k。
	# 用户提供修正：之前用 2*overhang 约束（最坏情况左右都有堆叠）太狠，会把一张本该展开的卡也挤进堆叠、留空档；
	# 改为 1*overhang（-1 而非 -2），放一张卡回展开区。overhang = 卡宽-露出的步长（堆叠顶卡向右探出的宽度）。
	# 左堆侧已由 free_l = left_end + overhang + gap 保护（展开首卡从堆视觉右边缘之后开始），
	# 右堆侧由 free_r = right_start - gap 保护；放宽后极端“鼠标居中、左右都堆”时展开可能略微贴紧右堆，但不留空档。
	# 解得 k <= (avail - overhang - n*stack_reveal - gap) / (card_w + gap - stack_reveal)
	var stack_overhang = card_w - stack_reveal
	var k = 1
	if n > 1:
		var denom = card_w + gap - stack_reveal
		var num = avail - stack_overhang - n * stack_reveal - gap
		k = int(floor(num / denom))
		k = clamp(k, 1, n)

	# 鼠标 X → 展开窗口起始索引 s（鼠标离开手牌区时冻结在上次的值）
	var lm = hand_container.get_local_mouse_position()
	var s: float
	# 卡牌往往比容器高（card_y 为负，视觉上露在容器矩形上方），必须用手牌真实所在区域判断，
	# 否则鼠标移到堆叠区（卡牌上方露出的部分）时 has_point 失败，arrange 不触发。
	var hand_zone = Rect2(left, card_y - 24, max(avail, 0.0), CARD_SIZE.y + 40)
	if hand_zone.has_point(lm):
		# 鼠标 X → 聚焦卡索引 focus∈[0, n-1]，再让聚焦卡尽量落在展开窗口中央。
		# 这样鼠标放在最左/最右那张卡上时，对应一侧的堆能完全收空（对称），
		# 不会像“边缘对齐线性映射”那样右侧总残留一张。
		var focus = clamp((lm.x - left) / max(avail, 1.0), 0.0, 1.0) * float(n - 1)
		s = focus - float(k - 1) / 2.0
	else:
		s = _window_start
	_window_start = clamp(s, 0.0, float(n - k))
	# round 而非 floor：左右取整对称，避免右侧因向下取整多留一张。
	var si = int(round(_window_start))

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

	# 右堆：索引 >= si + k，锚定右边缘向左堆叠；靠窗口（左边）的卡层级更高
	var rcount = n - si - k
	var right_start = right
	if rcount > 0:
		for i in range(si + k, n):
			var c = visible_cards[i]
			var off = (n - 1 - i) * stack_reveal
			c.set_rest_position(Vector2(right - card_w - off, card_y))
			if not c.is_hovered and not c.is_dragging:
				# 右堆 z 整体抬到展开区之上，使三段 z 域 [1,si]/[si+1,si+k]/[si+k+1,n] 严格不重叠，
				# 否则原公式 1+(n-1)-i 的 z 域会与展开区/左堆重叠，导致相邻卡 z 交叉、视觉穿插乱。
				c.z_index = 1 + si + k + (n - 1) - i
		right_start = right - card_w - (rcount - 1) * stack_reveal

	# 展开区：索引 [si, si + k - 1]。
	# 交界处理：① 放在左右堆之间、紧贴堆边缘（free_l/free_r），聚焦卡居中；放不下（对侧大堆的极端）才退化为贴边。
	# ② 展开卡层级整体抬到两侧堆叠之上（z=n+1+i），保证左右交界一致、展开卡不被堆卡盖住（修之前右交界堆卡压展开卡的“交界不对”）。
	# 左堆顶卡向右探出 stack_overhang，展开区须从堆的“视觉右边缘”之后开始，
	# 否则展开首卡会盖住堆叠区顶卡（正是“展示区盖住堆叠区里两张卡”的根因）。
	var free_l = left_end + (stack_overhang if si > 0 else 0) + gap
	var free_r = right_start - gap
	var spread_w = k * card_w + (k - 1) * gap
	var focus_idx = _window_start + float(k - 1) / 2.0
	var focus_x = left + focus_idx * (card_w + gap) + card_w / 2.0
	var spread_start = focus_x - spread_w / 2.0
	if spread_w <= (free_r - free_l):
		spread_start = clamp(spread_start, free_l, free_r - spread_w)
	else:
		# 理论上 k 已按最坏情况约束，不会走到这里；退化时也夹在 [free_l, free_r] 内，绝不盖堆/溢出。
		spread_start = clamp(spread_start, free_l, free_r - spread_w)
	for i in range(k):
		var c = visible_cards[si + i]
		c.set_rest_position(Vector2(spread_start + i * (card_w + gap), card_y))
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
