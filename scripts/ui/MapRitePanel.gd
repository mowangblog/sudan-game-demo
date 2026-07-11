# MapRitePanel.gd
# Owns map panel construction and rite button presentation.

class_name MapRitePanel
extends RefCounted

var root: Control
var C: Dictionary = {}
var map_area: Control
var _on_rite_pressed: Callable

func setup(p_root: Control, constants: Dictionary, on_rite_pressed: Callable) -> void:
	root = p_root
	C = constants.get("C", {})
	_on_rite_pressed = on_rite_pressed


func build() -> Control:
	var map = PanelContainer.new()
	map.name = "MapPanel"
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.offset_top = 32
	map.offset_bottom = -200
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color("241712", 0.0)   # 透明：露出底层地图背景图（边框/圆角仍保留）
	ps.set_corner_radius_all(10)
	ps.border_width_bottom = 0
	ps.border_width_top = 0
	ps.border_width_left = 0
	ps.border_width_right = 0
	ps.border_color = C.get("GOLD_LO", Color("8a6820"))
	ps.shadow_size = 0   # 透明面板下阴影会透成整片蒙层，关掉（想保留浮起感可改成 0 并把 bg 设半透明）
	ps.content_margin_left = 12
	ps.content_margin_right = 12
	ps.content_margin_top = 10
	ps.content_margin_bottom = 10
	map.add_theme_stylebox_override("panel", ps)
	root.add_child(map)

	map_area = Control.new()
	map_area.name = "MapArea"
	map_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_area.mouse_filter = Control.MOUSE_FILTER_PASS
	map.add_child(map_area)
	map_area.resized.connect(_on_map_resized)
	return map_area


func place_permanent_rites(rites: Array) -> void:
	if not map_area or map_area.size.x <= 0:
		return
	var placed: Array[Vector2] = []
	for rite in rites:
		if rite.get("category", "") != "permanent" or rite.has("insight_trigger"):
			continue
		place_rite_btn(rite, placed)


func place_rite_btn(rite: Dictionary, placed: Array = []) -> Button:
	if not map_area:
		return null
	var btn = _make_rite_btn(rite)
	var w = map_area.size.x
	if w <= 0:
		w = 1000
	var h = map_area.size.y
	if h <= 0:
		h = 500
	var bw: float = 140
	var bh: float = 40
	var gap: float = 10
	var px: float
	var py: float
	var ok := false
	for _attempt in range(100):
		px = randf_range(gap, w - bw - gap)
		py = randf_range(gap, h - bh - gap)
		ok = true
		var r = Rect2(px - gap, py - gap, bw + gap * 2, bh + gap * 2)
		for pp in placed:
			if r.has_point(Vector2(pp.x + bw / 2, pp.y + bh / 2)):
				ok = false
				break
		if ok:
			break
	placed.append(Vector2(px, py))
	btn.set_meta("rite_pct", Vector2(px / w, py / h))
	btn.set_meta("rite_id", rite.get("id", -1))
	btn.position = Vector2(px, py)
	map_area.add_child(btn)
	_add_countdown_label(btn, rite)
	return btn


func update_rite_btn_label(rite_id: int, char_name: String) -> void:
	if not map_area:
		return
	for c in map_area.get_children():
		if c.get_meta("rite_id", -1) == rite_id:
			var old_lbl = c.get_meta("char_label") if c.has_meta("char_label") else null
			if old_lbl and is_instance_valid(old_lbl):
				old_lbl.queue_free()
			if char_name != "":
				var lbl = Label.new()
				lbl.text = char_name
				lbl.add_theme_font_size_override("font_size", 9)
				lbl.add_theme_color_override("font_color", Color("7ac7ff"))
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.custom_minimum_size.x = c.size.x
				lbl.position = Vector2(c.position.x, c.position.y - 14)
				c.set_meta("char_label", lbl)
				map_area.add_child(lbl)
			break


func reset_all_rite_btn_labels() -> void:
	if not map_area:
		return
	for c in map_area.get_children():
		var old_lbl = c.get_meta("char_label") if c.has_meta("char_label") else null
		if old_lbl and is_instance_valid(old_lbl):
			old_lbl.queue_free()


func update_countdown_labels() -> void:
	if not map_area:
		return
	for c in map_area.get_children():
		var cd = c.get_meta("cd_label") if c.has_meta("cd_label") else null
		if not cd or not is_instance_valid(cd):
			continue
		var remaining = cd.get_meta("countdown", 0) - 1
		cd.set_meta("countdown", remaining)
		if remaining <= 0:
			cd.queue_free()
			c.visible = false
		else:
			cd.text = "%d天" % remaining


func get_existing_positions() -> Array:
	var existing: Array = []
	if not map_area:
		return existing
	for c in map_area.get_children():
		var rp = c.get_meta("rite_pct") if c.has_meta("rite_pct") else null
		if rp:
			var w = map_area.size.x
			if w <= 0:
				w = 1000
			var h = map_area.size.y
			if h <= 0:
				h = 500
			existing.append(Vector2(rp.x * w, rp.y * h))
	return existing


func _make_rite_btn(rite: Dictionary) -> Button:
	var btn = Button.new()
	btn.text = rite.get("name", "?")
	btn.custom_minimum_size = Vector2(130, 34)
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", C.get("GOLD", Color("c8a84e")))
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("1a0f0a")
	sb.set_corner_radius_all(6)
	sb.border_width_bottom = 2
	sb.border_color = C.get("GOLD_LO", Color("8a6820"))
	btn.add_theme_stylebox_override("normal", sb)
	btn.pressed.connect(func(): _on_rite_pressed.call(rite))
	return btn


func _add_countdown_label(btn: Button, rite: Dictionary) -> void:
	var tl = rite.get("time_limit", 0)
	if tl <= 0:
		return
	var cl = Label.new()
	cl.text = "%d天" % tl
	cl.add_theme_font_size_override("font_size", 9)
	cl.add_theme_color_override("font_color", Color.RED)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.position = Vector2(btn.position.x, btn.position.y + btn.size.y + 2)
	cl.custom_minimum_size.x = btn.size.x
	cl.set_meta("countdown", tl)
	btn.set_meta("cd_label", cl)
	map_area.add_child(cl)


func _on_map_resized() -> void:
	for c in map_area.get_children():
		var rp = c.get_meta("rite_pct") if c.has_meta("rite_pct") else null
		if rp:
			c.position = Vector2(rp.x * map_area.size.x, rp.y * map_area.size.y)
		var lbl = c.get_meta("char_label") if c.has_meta("char_label") else null
		if lbl and is_instance_valid(lbl):
			lbl.position = Vector2(c.position.x, c.position.y - 14)
			lbl.custom_minimum_size.x = c.size.x
		var cd = c.get_meta("cd_label") if c.has_meta("cd_label") else null
		if cd and is_instance_valid(cd):
			cd.position = Vector2(c.position.x, c.position.y + c.size.y + 2)
			cd.custom_minimum_size.x = c.size.x
