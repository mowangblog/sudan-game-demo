class_name DiceCinematicRollPanel
extends PanelContainer


signal dice_count_changed(count: int)
signal roll_started(dice: Array[DiceDie3D])
signal dice_results_finished(results: Array[DiceRollResult])

enum DiceType {
	NORMAL,
	ICON,
	D20,
}

const _TYPE_ROW_PATHS := {
	DiceType.NORMAL: "MarginContainer/VBoxContainer/DiceTypeRows/NormalRow",
	DiceType.ICON: "MarginContainer/VBoxContainer/DiceTypeRows/IconRow",
	DiceType.D20: "MarginContainer/VBoxContainer/DiceTypeRows/D20Row",
}

const _TYPE_DISPLAY_NAMES := {
	DiceType.NORMAL: "NumberDie",
	DiceType.ICON: "IconDie",
	DiceType.D20: "D20Die",
}

@export_category("Dice Cinematic Roll Panel")
@export_group("Roller")
## Path to the DiceCinematicRoller3D this panel controls. When empty, the panel searches the current scene.
@export var roller_path: NodePath
## Definition used by the Normal row.
@export var normal_die_definition: DiceDieDefinition3D
## Definition used by the Icons row.
@export var icon_die_definition: DiceDieDefinition3D
## Definition used by the D20 row.
@export var d20_die_definition: DiceDieDefinition3D

@export_group("Dice Counts")
## Maximum total dice visible in the roller.
@export_range(1, 32, 1) var max_dice: int = 9:
	get:
		return _max_dice
	set(value):
		_max_dice = max(value, 1)
		_trim_counts_to_max()
		if is_inside_tree():
			_sync_visible_dice(true)
## Number of Normal D6 dice included in the next roll.
@export_range(0, 32, 1) var normal_dice_count: int = 1:
	get:
		return _normal_dice_count
	set(value):
		_normal_dice_count = clampi(value, 0, max_dice)
		_trim_counts_to_max(DiceType.NORMAL)
		if is_inside_tree():
			_sync_visible_dice(true)
## Number of icon dice included in the next roll.
@export_range(0, 32, 1) var icon_dice_count: int = 0:
	get:
		return _icon_dice_count
	set(value):
		_icon_dice_count = clampi(value, 0, max_dice)
		_trim_counts_to_max(DiceType.ICON)
		if is_inside_tree():
			_sync_visible_dice(true)
## Number of D20 dice included in the next roll.
@export_range(0, 32, 1) var d20_dice_count: int = 0:
	get:
		return _d20_dice_count
	set(value):
		_d20_dice_count = clampi(value, 0, max_dice)
		_trim_counts_to_max(DiceType.D20)
		if is_inside_tree():
			_sync_visible_dice(true)

var _max_dice := 9
var _normal_dice_count := 1
var _icon_dice_count := 0
var _d20_dice_count := 0
var _roller: DiceCinematicRoller3D
var _dice_by_type: Dictionary = {}
var _active_dice: Array[DiceDie3D] = []
var _expected_result_count := 0
var _rolling := false
var _minus_buttons: Dictionary = {}
var _count_labels: Dictionary = {}
var _plus_buttons: Dictionary = {}
var _roll_button: Button
var _status_label: Label
var _results_label: Label


func _ready() -> void:
	_cache_ui_nodes()
	if not _has_required_ui():
		push_warning("DiceCinematicRollPanel expects the bundled dice_cinematic_roll_panel.tscn node layout.")
		return
	_connect_ui()
	refresh(false)


func refresh(tweened: bool = false) -> void:
	_resolve_roller()
	if _roller == null:
		_status_label.text = "Assign a DiceCinematicRoller3D"
		_results_label.text = ""
		_update_buttons()
		return

	if not _roller.all_dice_finished.is_connected(_on_all_dice_finished):
		_roller.all_dice_finished.connect(_on_all_dice_finished)

	_sync_visible_dice(tweened)


func set_dice_type_count(type: int, value: int, tweened: bool = true) -> void:
	if _rolling:
		return

	var current_count := _get_type_count(type)
	var other_dice_count := get_dice_count() - current_count
	var next_count := clampi(value, 0, max_dice - other_dice_count)
	_set_type_count(type, next_count)
	_sync_visible_dice(tweened)


func add_normal_die_to_roll() -> void:
	_change_type_count(DiceType.NORMAL, 1)


func remove_normal_die_from_roll() -> void:
	_change_type_count(DiceType.NORMAL, -1)


func add_icon_die_to_roll() -> void:
	_change_type_count(DiceType.ICON, 1)


func remove_icon_die_from_roll() -> void:
	_change_type_count(DiceType.ICON, -1)


func add_d20_die_to_roll() -> void:
	_change_type_count(DiceType.D20, 1)


func remove_d20_die_from_roll() -> void:
	_change_type_count(DiceType.D20, -1)


func get_dice_count() -> int:
	return _normal_dice_count + _icon_dice_count + _d20_dice_count


func get_active_dice() -> Array[DiceDie3D]:
	return _active_dice.duplicate()


func _cache_ui_nodes() -> void:
	for type in _get_dice_types():
		var row := get_node_or_null(_TYPE_ROW_PATHS[type]) as HBoxContainer
		if row == null:
			continue
		_minus_buttons[type] = row.get_node_or_null("MinusButton") as Button
		_count_labels[type] = row.get_node_or_null("CountLabel") as Label
		_plus_buttons[type] = row.get_node_or_null("PlusButton") as Button

	_roll_button = get_node_or_null("MarginContainer/VBoxContainer/RollButton") as Button
	_status_label = get_node_or_null("MarginContainer/VBoxContainer/StatusLabel") as Label
	_results_label = get_node_or_null("MarginContainer/VBoxContainer/ResultsLabel") as Label


func _has_required_ui() -> bool:
	if _roll_button == null or _status_label == null or _results_label == null:
		return false
	for type in _get_dice_types():
		if (
			not _minus_buttons.has(type)
			or not _count_labels.has(type)
			or not _plus_buttons.has(type)
		):
			return false
	return true


func _connect_ui() -> void:
	for type in _get_dice_types():
		var minus_button := _minus_buttons[type] as Button
		var plus_button := _plus_buttons[type] as Button
		var minus_callable := Callable(self, "_change_type_count").bind(type, -1)
		var plus_callable := Callable(self, "_change_type_count").bind(type, 1)
		if not minus_button.pressed.is_connected(minus_callable):
			minus_button.pressed.connect(minus_callable)
		if not plus_button.pressed.is_connected(plus_callable):
			plus_button.pressed.connect(plus_callable)

	if not _roll_button.pressed.is_connected(_on_roll_pressed):
		_roll_button.pressed.connect(_on_roll_pressed)


func _resolve_roller() -> void:
	_roller = null
	if not roller_path.is_empty():
		_roller = get_node_or_null(roller_path) as DiceCinematicRoller3D
	if _roller != null:
		return

	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	_roller = _find_first_roller(scene_root)


func _find_first_roller(node: Node) -> DiceCinematicRoller3D:
	if node is DiceCinematicRoller3D:
		return node as DiceCinematicRoller3D
	for child in node.get_children():
		var found := _find_first_roller(child)
		if found != null:
			return found
	return null


func _change_type_count(type: int, delta: int) -> void:
	set_dice_type_count(type, _get_type_count(type) + delta, true)


func _sync_visible_dice(tweened: bool) -> void:
	_collect_active_dice()
	if _roller != null:
		_roller.layout_dice(_active_dice, tweened)
	_update_labels(true)
	dice_count_changed.emit(get_dice_count())


func _collect_active_dice() -> void:
	_active_dice.clear()
	if _roller == null:
		return

	for type in _get_dice_types():
		var target_count := _get_type_count(type)
		_ensure_dice_capacity(type, target_count)
		var dice := _get_dice_list(type)
		for index in range(dice.size()):
			var die := dice[index] as DiceDie3D
			if die == null:
				continue
			die.visible = index < target_count
			if die.visible:
				_active_dice.append(die)


func _ensure_dice_capacity(type: int, count: int) -> void:
	var dice := _get_dice_list(type)
	while dice.size() < count:
		var definition := _get_definition_for_type(type)
		var die := _roller.create_die(definition)
		die.name = "%s%d" % [_get_die_name_prefix(type, definition), dice.size() + 1]
		die.visible = false
		dice.append(die)


func _get_dice_list(type: int) -> Array:
	if not _dice_by_type.has(type):
		_dice_by_type[type] = []
	return _dice_by_type[type]


func _get_definition_for_type(type: int) -> DiceDieDefinition3D:
	match type:
		DiceType.NORMAL:
			if normal_die_definition != null:
				return normal_die_definition
		DiceType.ICON:
			if icon_die_definition != null:
				return icon_die_definition
			if normal_die_definition != null:
				return normal_die_definition
		DiceType.D20:
			if d20_die_definition != null:
				return d20_die_definition
			return DiceDieDefinition3D.numbered_d20()
	return DiceDieDefinition3D.numbered_d6()


func _get_die_name_prefix(type: int, definition: DiceDieDefinition3D) -> String:
	if definition != null and not definition.display_name.is_empty():
		return definition.display_name
	return _TYPE_DISPLAY_NAMES.get(type, "Die")


func _on_roll_pressed() -> void:
	if _roller == null:
		_status_label.text = "Assign a DiceCinematicRoller3D"
		return

	_collect_active_dice()
	if _active_dice.is_empty():
		_status_label.text = "Add at least one die"
		return

	_expected_result_count = _active_dice.size()
	_rolling = true
	_status_label.text = "Rolling..."
	_results_label.text = ""
	_update_buttons()
	_roller.roll_dice(_active_dice)
	roll_started.emit(_active_dice.duplicate())


func _on_all_dice_finished(results: Dictionary) -> void:
	if not _rolling:
		return
	var ordered_results := _get_ordered_active_results(results)
	if ordered_results.size() < _expected_result_count:
		return

	_rolling = false
	_status_label.text = "Results"
	_results_label.text = _format_result_list(ordered_results)
	_update_buttons()
	dice_results_finished.emit(ordered_results)


func _get_ordered_active_results(results: Dictionary) -> Array[DiceRollResult]:
	var ordered_results: Array[DiceRollResult] = []
	for die in _active_dice:
		if results.has(die):
			ordered_results.append(results[die])
	return ordered_results


func _format_result_list(results: Array[DiceRollResult]) -> String:
	var lines: Array[String] = []
	for result in results:
		var die_name := result.die.name if result.die != null else "Die"
		var face_text := result.display_name
		if face_text.is_empty():
			face_text = str(result.value)
		lines.append("%s: %s" % [die_name, face_text])
	return "\n".join(lines)


func _update_labels(clear_results: bool = false) -> void:
	if _roll_button == null:
		return

	for type in _get_dice_types():
		var label := _count_labels[type] as Label
		label.text = str(_get_type_count(type))

	if clear_results and not _rolling:
		_status_label.text = ""
		_results_label.text = ""

	_update_buttons()


func _update_buttons() -> void:
	if _roll_button == null:
		return

	var total_count := get_dice_count()
	for type in _get_dice_types():
		var minus_button := _minus_buttons[type] as Button
		var plus_button := _plus_buttons[type] as Button
		minus_button.disabled = _rolling or _get_type_count(type) <= 0
		plus_button.disabled = _rolling or total_count >= max_dice

	_roll_button.disabled = _rolling or _roller == null or total_count <= 0


func _get_dice_types() -> Array[int]:
	return [DiceType.NORMAL, DiceType.ICON, DiceType.D20]


func _get_type_count(type: int) -> int:
	match type:
		DiceType.NORMAL:
			return _normal_dice_count
		DiceType.ICON:
			return _icon_dice_count
		DiceType.D20:
			return _d20_dice_count
	return 0


func _set_type_count(type: int, value: int) -> void:
	match type:
		DiceType.NORMAL:
			_normal_dice_count = value
		DiceType.ICON:
			_icon_dice_count = value
		DiceType.D20:
			_d20_dice_count = value


func _trim_counts_to_max(preferred_type: int = -1) -> void:
	_normal_dice_count = clampi(_normal_dice_count, 0, max_dice)
	_icon_dice_count = clampi(_icon_dice_count, 0, max_dice)
	_d20_dice_count = clampi(_d20_dice_count, 0, max_dice)

	var overflow := get_dice_count() - max_dice
	if overflow <= 0:
		return

	for type in _get_dice_types():
		if type == preferred_type:
			continue
		var remove_count := mini(_get_type_count(type), overflow)
		_set_type_count(type, _get_type_count(type) - remove_count)
		overflow -= remove_count
		if overflow <= 0:
			return

	if preferred_type != -1:
		_set_type_count(preferred_type, max(_get_type_count(preferred_type) - overflow, 0))
