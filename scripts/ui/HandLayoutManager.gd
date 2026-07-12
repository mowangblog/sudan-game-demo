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
			if not hand_container.get_global_rect().has_point(card.global_position + card.size / 2):
				continue
		visible_cards.append(card)
	
	if visible_cards.size() == 0: return
	
	var insight = hand_container.get_node_or_null("InsightBtn")
	var left = insight.position.x + insight.size.x - 10 if insight and is_instance_valid(insight) else 106
	var right = sort_btn.position.x - 8 if sort_btn and is_instance_valid(sort_btn) else hand_container.size.x - 8
	var card_y = hand_container.size.y / 2 - CARD_SIZE.y / 2.0
	var card_w = CARD_SIZE.x; var gap = 8; var n = visible_cards.size()
	var avail = right - left
	var stack_reveal = 28
	
	var full_w = n * card_w + (n - 1) * gap
	if full_w <= avail:
		var x0 = (left + right - full_w) / 2
		for i in range(n):
			visible_cards[i].set_rest_position(Vector2(x0 + i * (card_w + gap), card_y))
		return
	
	# 计算最多能完整铺开的卡数 k
	var k = 1
	var used = card_w
	while k < n:
		var next = used + gap + card_w
		if next > avail - stack_reveal: break
		used = next
		k += 1

	# 鼠标 X → 展开窗口起始索引 s（鼠标离开手牌区时冻结在上次的值）
	var lm = hand_container.get_local_mouse_position()
	var s: float
	# 卡牌往往比容器高（card_y 为负，视觉上露在容器矩形上方），必须用手牌真实所在区域判断，
	# 否则鼠标移到堆叠区（卡牌上方露出的部分）时 has_point 失败，arrange 不触发。
	var hand_zone = Rect2(left, card_y - 24, max(avail, 0.0), CARD_SIZE.y + 40)
	if hand_zone.has_point(lm):
		var t = clamp((lm.x - left) / max(avail, 1.0), 0.0, 1.0)
		s = t * float(n - k)
	else:
		s = _window_start
	_window_start = clamp(s, 0.0, float(n - k))
	var si = int(floor(_window_start))

	# 左堆：索引 < si，锚定左边缘向右堆叠
	var left_end = left
	var x = left
	for i in range(si):
		visible_cards[i].set_rest_position(Vector2(x, card_y))
		x += stack_reveal
	left_end = x

	# 右堆：索引 >= si + k，锚定右边缘向左堆叠
	var rcount = n - si - k
	var right_start = right
	if rcount > 0:
		for i in range(si + k, n):
			var off = (n - 1 - i) * stack_reveal
			visible_cards[i].set_rest_position(Vector2(right - card_w - off, card_y))
		right_start = right - card_w - (rcount - 1) * stack_reveal

	# 展开区：索引 [si, si + k - 1]，居中放在左右堆之间
	var spread_w = k * card_w + (k - 1) * gap
	var mid_l = left_end + gap
	var mid_r = right_start - gap
	var spread_start = mid_l
	if spread_w < (mid_r - mid_l):
		spread_start = mid_l + (mid_r - mid_l - spread_w) / 2.0
	for i in range(k):
		visible_cards[si + i].set_rest_position(Vector2(spread_start + i * (card_w + gap), card_y))

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
