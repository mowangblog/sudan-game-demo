# HandLayoutManager.gd
# 手牌布局管理器 — 排列/排序/合并/堆叠
# 从 MainScene 提取 (Phase 1.2)

class_name HandLayoutManager
extends RefCounted

var hand_cards: Array  # 引用 MainScene 的 hand_cards
var hand_container: Control
var sort_btn: Button
var sort_mode: int = 0
var _update_count_cb: Callable
var _CHAR_QUALITY: Dictionary = {}

func setup(p_hand_cards: Array, p_hand_container: Control, p_sort_btn: Button, update_count_cb: Callable, char_quality: Dictionary) -> void:
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
	var left = insight.position.x + insight.size.x + 8 if insight and is_instance_valid(insight) else 106
	var right = sort_btn.position.x - 8 if sort_btn and is_instance_valid(sort_btn) else hand_container.size.x - 8
	var card_y = hand_container.size.y / 2 - 76
	var card_w = 70; var gap = 8; var n = visible_cards.size()
	var avail = right - left
	var stack_reveal = 28
	
	var full_w = n * card_w + (n - 1) * gap
	if full_w <= avail:
		var x0 = (left + right - full_w) / 2
		for i in range(n):
			visible_cards[i].set_rest_position(Vector2(x0 + i * (card_w + gap), card_y))
		return
	
	var norm_avail = avail - stack_reveal
	var norm_count = 1
	var used = card_w
	while norm_count < n - 1:
		var next = used + gap + card_w
		if next + stack_reveal > avail: break
		used = next
		norm_count += 1
	
	var stacked_n = n - norm_count
	if stacked_n <= 0:
		norm_count = 0
		stacked_n = n
		used = 0
	
	var x = left
	for i in range(norm_count):
		visible_cards[i].set_rest_position(Vector2(x, card_y))
		x += card_w + gap
	
	x = left + used + gap if norm_count > 0 else left
	for i in range(norm_count, n):
		visible_cards[i].set_rest_position(Vector2(x, card_y))
		x += stack_reveal

func update_card_zone():
	var cz = hand_container.get_node_or_null("CardZone")
	if not cz: return
	var insight = hand_container.get_node_or_null("InsightBtn")
	var cz_left = insight.position.x + insight.size.x + 4 if insight and is_instance_valid(insight) else 100
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
