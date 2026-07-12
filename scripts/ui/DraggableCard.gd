# DraggableCard.gd
# 卡牌组件 — hover悬浮 + 自由拖拽（不依赖容器布局）

extends PanelContainer

signal drag_started(card)
signal drag_ended(card, global_pos: Vector2)

const DRAG_THRESHOLD := 6.0

var is_hovered: bool = false
var is_dragging: bool = false
var is_snapping: bool = false   # 弹回动画进行中，避免与布局 tween 冲突
var _drag_tracking: bool = false
var _drag_active: bool = false
var _drag_mouse_start: Vector2
var _drag_card_offset: Vector2
var _drag_start_position: Vector2
var _rest_position: Vector2   # 弹回位置（由 Hand 设置）

var _on_hover_style: Callable = func(_h: bool): pass
var _on_click: Callable = func(): pass
var _on_right_click: Callable = func(): pass

func _ready():
	_rest_position = position
	set_process_input(true)  # 确保 _input 能接收全局事件

func _notification(what: int):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			if not is_dragging:
				is_hovered = true
				z_index = 10
				var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				t.tween_property(self, "position:y", _rest_position.y - 12, 0.15)
				_on_hover_style.call(true)
		NOTIFICATION_MOUSE_EXIT:
			if not is_dragging:
				is_hovered = false
				z_index = 0
				var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				t.tween_property(self, "position:y", _rest_position.y, 0.15)
				_on_hover_style.call(false)
		NOTIFICATION_DRAG_END:
			pass

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 右键拆分资源卡
			_on_right_click.call()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not _drag_tracking:
					_drag_tracking = true
					_drag_active = false
					_drag_mouse_start = get_global_mouse_position()
					_drag_start_position = position
					_rest_position = position
					accept_event()
			else:
				if _drag_active:
					_end_drag()
				elif _drag_tracking:
					_on_click.call()
					_end_drag()

func _input(event: InputEvent) -> void:
	if not _drag_tracking: return
	if event is InputEventMouseMotion:
		var mouse_pos = get_global_mouse_position()
		if not _drag_active:
			if _drag_mouse_start.distance_to(mouse_pos) > DRAG_THRESHOLD:
				_start_drag()
		if _drag_active:
			_update_drag(mouse_pos)

func _start_drag():
	_drag_active = true
	is_dragging = true
	set_highlight(false)  # 拖动时停止高亮脉冲
	_drag_card_offset = get_global_mouse_position() - global_position
	z_index = 100
	modulate = Color(1.0, 1.0, 1.0, 0.9)
	drag_started.emit(self)

func _end_drag():
	_drag_tracking = false
	_drag_active = false
	is_dragging = false
	drag_ended.emit(self, get_global_mouse_position())

func _update_drag(mouse_pos: Vector2):
	# 把全局坐标转成父节点本地坐标
	var new_global = mouse_pos - _drag_card_offset
	if get_parent():
		position = new_global - get_parent().global_position
	else:
		position = new_global

func snap_back():
	is_dragging = false
	is_snapping = true
	z_index = 0
	modulate = Color.WHITE
	_on_hover_style.call(false)
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "position", _rest_position, 0.25)
	t.tween_callback(func(): is_snapping = false)

func set_rest_position(pos: Vector2):
	_rest_position = pos
	if is_dragging or is_snapping:
		return
	# Y 由 hover / 高亮脉冲控制，仅在不悬停、无高亮时归位（手牌区 Y 对所有卡恒定）
	if not is_hovered and _highlight_tween == null:
		position.y = pos.y
	# X 用 tween 滑动，产生“卡牌缓缓滑动/堆叠”的动画
	if abs(position.x - pos.x) > 0.5:
		var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(self, "position:x", pos.x, 0.2)

var _highlight_tween: Tween
var _highlight_pos_tween: Tween

func set_highlight(on: bool):
	if _highlight_tween:
		_highlight_tween.kill()
		_highlight_tween = null
	if _highlight_pos_tween:
		_highlight_pos_tween.kill()
		_highlight_pos_tween = null

	var bg = get_node_or_null("CardTextureBg") as TextureRect
	var mat: ShaderMaterial = bg.material if bg else null

	if on:
		_highlight_pos_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_highlight_pos_tween.tween_property(self, "position:y", _rest_position.y - 14, 0.15)
		if mat:
			var base = get_meta("base_tint", Color.WHITE)
			var glow = Color(base.r * 1.5, base.g * 1.3, base.b * 0.7, base.a)
			_highlight_tween = create_tween().set_loops(3)
			_highlight_tween.tween_method(func(v): mat.set_shader_parameter("tint", v), base, glow, 0.35).set_trans(Tween.TRANS_SINE)
			_highlight_tween.tween_method(func(v): mat.set_shader_parameter("tint", v), glow, base, 0.35).set_trans(Tween.TRANS_SINE)
	else:
		if mat: mat.set_shader_parameter("tint", get_meta("base_tint", Color.WHITE))
		modulate = Color.WHITE
		_highlight_pos_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_highlight_pos_tween.tween_property(self, "position:y", _rest_position.y, 0.15)
