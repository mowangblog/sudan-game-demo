@tool
class_name DiceCinematicRoller3D
extends Node3D


signal die_added(die: DiceDie3D)
signal die_removed(die: DiceDie3D)
signal roll_started(die: DiceDie3D)
signal roll_finished(result: DiceRollResult)
signal all_dice_finished(results: Dictionary)

const _DICE_ROOT_NAME := "_Dice"
const _DEBUG_ROOT_NAME := "_Debug"
const _MIN_VECTOR_LENGTH := 0.0001
const _PRESENTED_FACE_TWIST_STEPS := 96

enum ResultSide {
	POS_Y,
	NEG_Y,
	POS_Z,
	NEG_Z,
	POS_X,
	NEG_X,
}

@export_category("Dice Cinematic Roller")
@export_group("Stage")
## Width, height, and depth of the cinematic roll stage in local 3D units.
@export var stage_size: Vector3 = Vector3(5.5, 3.5, 1.5):
	set(value):
		stage_size = Vector3(max(value.x, 0.5), max(value.y, 0.5), max(value.z, 0.1))
		if is_inside_tree():
			rebuild()
## Local side the final result face points toward. Use -Z for dice that present toward a camera in front of the node.
@export_enum("+Y", "-Y", "+Z", "-Z", "+X", "-X") var result_side: int = ResultSide.NEG_Z
## When enabled, the stage layout plane is derived from result_side.
@export var stage_side_follows_result: bool = true
## Local side used as the stage normal when stage_side_follows_result is disabled.
@export_enum("+Y", "-Y", "+Z", "-Z", "+X", "-X") var stage_side: int = ResultSide.NEG_Z
## Distance kept between the die center and the back of the stage at the final result pose.
@export_range(0.0, 3.0, 0.01) var end_padding: float = 0.55
## Horizontal spacing between multiple dice when they settle.
@export_range(0.0, 3.0, 0.01) var dice_spacing: float = 0.95
## Minimum horizontal spacing used while multiple dice spin, so their animations do not visually overlap.
@export_range(0.0, 5.0, 0.01) var spin_clearance: float = 1.25
## Seconds used when dice reflow to make room after dice are added, removed, shown, or hidden.
@export_range(0.0, 2.0, 0.01) var layout_tween_duration: float = 0.35
## When enabled, added or removed dice cause the remaining visible dice to tween into evenly spaced positions.
@export var auto_layout_on_add_remove: bool = true
## Shows a cyan wireframe preview of the cinematic stage bounds.
@export var debug_visible: bool = true:
	set(value):
		debug_visible = value
		if is_inside_tree():
			rebuild()
## Opacity of the cinematic stage wireframe.
@export_range(0.0, 1.0, 0.001) var debug_edge_alpha: float = 0.62:
	set(value):
		debug_edge_alpha = clampf(value, 0.0, 1.0)
		_update_debug_materials()

@export_group("Dice Definitions")
## When enabled, the roller creates dice from Dice Definitions on scene start.
@export var spawn_dice_from_definitions_on_ready: bool = true
## Inspector-authored dice this cinematic roller owns.
@export var dice_definitions: Array[DiceDieDefinition3D] = []

@export_group("Motion")
## Seconds each die spends animating before it reaches the final result pose.
@export_range(0.5, 5.0, 0.01) var roll_duration: float = 2.25
## Height of the controlled bounce along the stage's vertical axis.
@export_range(0.0, 4.0, 0.01) var bounce_height: float = 0.72
## Number of bounce arcs during one cinematic roll.
@export_range(0.0, 8.0, 0.01) var bounce_count: float = 3.0
## Number of visual spin turns before the die settles into the final face.
@export_range(0.0, 20.0, 0.01) var spin_turns: float = 7.5
## Normalized time where the die begins blending from free spin into the final face orientation.
@export_range(0.0, 1.0, 0.01) var settle_start: float = 0.72
## Delay added for each later die when rolling multiple dice together.
@export_range(0.0, 1.0, 0.01) var per_die_delay: float = 0.12
## Chooses a final cube orientation where the requested result face presents forward and an adjacent face lands flat on bottom.
@export var align_flat_bottom_on_land: bool = true

@export_group("Idle")
## Randomizes which face is presented when dice are laid out or reset before rolling.
@export var randomize_idle_start_side: bool = true
## Slowly spins visible dice while they are waiting to be rolled.
@export var idle_spin_enabled: bool = true
## Chooses a fresh idle spin speed and direction whenever a die is laid out or reset.
@export var randomize_idle_spin_on_layout: bool = true
## Minimum idle spin speed in degrees per second.
@export_range(0.0, 180.0, 0.1) var idle_spin_speed_min_degrees: float = 8.0
## Maximum idle spin speed in degrees per second.
@export_range(0.0, 180.0, 0.1) var idle_spin_speed_max_degrees: float = 18.0
## When disabled, dice hold their landed result instead of idling after a completed roll.
@export var idle_spin_after_result: bool = false

var _dice_root: Node3D
var _debug_root: Node3D
var _dice: Array[DiceDie3D] = []
var _spawned_definition_dice: Array[DiceDie3D] = []
var _active_rolls: Array[Dictionary] = []
var _finished_results: Dictionary = {}
var _layout_tweens: Dictionary = {}
var _idle_spin_speeds: Dictionary = {}
var _debug_edge_material: StandardMaterial3D


func _ready() -> void:
	randomize()
	_ensure_internal_nodes()
	rebuild()
	if not Engine.is_editor_hint() and spawn_dice_from_definitions_on_ready:
		spawn_dice_from_definitions()
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_cinematic_rolls(delta)
	_update_idle_spin(delta)


func create_die(definition_or_faces: Variant = null) -> DiceDie3D:
	var die := DiceDie3D.new()
	var definition: DiceDieDefinition3D = null
	if definition_or_faces is DiceDieDefinition3D:
		definition = definition_or_faces
		definition.apply_to_die(die)
	elif definition_or_faces is Array:
		var faces: Array = definition_or_faces
		if not faces.is_empty():
			die.set_faces(faces)
	add_die(die)
	if definition != null:
		definition.apply_to_die(die)
	return die


func create_die_from_definition(definition: DiceDieDefinition3D) -> DiceDie3D:
	return create_die(definition)


func spawn_dice_from_definitions(reset_existing: bool = true) -> Array[DiceDie3D]:
	if reset_existing:
		clear_definition_spawned_dice()

	var spawned: Array[DiceDie3D] = []
	for definition in dice_definitions:
		if definition == null:
			continue
		for index in range(definition.count):
			var die := create_die_from_definition(definition)
			if definition.count > 1 and not definition.display_name.is_empty():
				die.name = "%s%d" % [definition.display_name, index + 1]
			_spawned_definition_dice.append(die)
			spawned.append(die)
	reset_all()
	return spawned


func clear_definition_spawned_dice() -> void:
	for die in _spawned_definition_dice.duplicate():
		if not is_instance_valid(die):
			continue
		remove_die(die)
		die.queue_free()
	_spawned_definition_dice.clear()


func add_die_definition(definition: DiceDieDefinition3D, spawn_now: bool = false) -> DiceDie3D:
	if definition == null:
		return null
	if not dice_definitions.has(definition):
		dice_definitions.append(definition)
	if spawn_now:
		var die := create_die_from_definition(definition)
		_spawned_definition_dice.append(die)
		reset_all()
		return die
	return null


func remove_die_definition(definition: DiceDieDefinition3D) -> void:
	dice_definitions.erase(definition)


func get_die_definitions() -> Array[DiceDieDefinition3D]:
	return dice_definitions.duplicate()


func set_die_faces(die: DiceDie3D, faces: Array) -> void:
	if die == null:
		return
	if not faces.is_empty():
		die.set_faces(faces)


func add_die(die: DiceDie3D) -> void:
	if die == null:
		return
	_ensure_internal_nodes()
	if not _dice.has(die):
		_dice.append(die)

	if die.get_parent() == null:
		_dice_root.add_child(die)
	elif die.get_parent() != _dice_root:
		die.reparent(_dice_root, true)

	die._set_roll_box(null)
	die.gravity_scale = 0.0
	die.freeze = true
	die.sleeping = true
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
	die._rebuild_die()
	_randomize_idle_spin_for_die(die)
	if auto_layout_on_add_remove and not Engine.is_editor_hint():
		layout_dice([], true)
	die_added.emit(die)


func remove_die(die: DiceDie3D) -> void:
	if die == null:
		return
	_dice.erase(die)
	_spawned_definition_dice.erase(die)
	_finished_results.erase(die)
	_idle_spin_speeds.erase(die)
	_kill_layout_tween(die)
	_remove_active_rolls_for_die(die)
	if auto_layout_on_add_remove and not Engine.is_editor_hint():
		layout_dice([], true)
	die_removed.emit(die)


func roll(die: DiceDie3D, requested_result: Variant = null, options: Dictionary = {}) -> void:
	roll_dice([die], [requested_result], options)


func roll_all(requested_results: Variant = null, options: Dictionary = {}) -> void:
	roll_dice(_dice.duplicate(), requested_results, options)


func roll_dice(dice_to_roll: Array, requested_results: Variant = null, options: Dictionary = {}) -> void:
	_active_rolls.clear()
	_finished_results.clear()

	var active_dice: Array[DiceDie3D] = []
	for item in dice_to_roll:
		var die := item as DiceDie3D
		if die != null:
			if not _dice.has(die):
				add_die(die)
			active_dice.append(die)

	if active_dice.is_empty():
		return

	for index in range(active_dice.size()):
		var die := active_dice[index]
		_kill_layout_tween(die)
		die.visible = true
		_active_rolls.append(_make_roll_animation(
			die,
			index,
			active_dice.size(),
			_get_requested_result_for_index(requested_results, die, index),
			options
		))
		roll_started.emit(die)


func cancel_rolls() -> void:
	_active_rolls.clear()


func layout_dice(dice_to_layout: Array = [], tweened: bool = true) -> void:
	var layout_dice := _get_layout_dice(dice_to_layout)
	var total := layout_dice.size()
	for index in range(total):
		var die := layout_dice[index]
		var target_position := _get_end_stage_position(index, total)
		var target_transform := Transform3D(_make_idle_basis(die), _to_world(target_position))
		_move_die_to_transform(die, target_transform, tweened)


func reset_die(die: DiceDie3D, index: int = 0, total: int = 1) -> void:
	if die == null:
		return
	var safe_total := max(total, 1)
	var stage_position := _get_end_stage_position(index, safe_total)
	_kill_layout_tween(die)
	_set_die_transform(die, Transform3D(_make_idle_basis(die), _to_world(stage_position)))
	die.freeze = true
	die.sleeping = true
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
	_randomize_idle_spin_for_die(die)


func reset_all() -> void:
	for index in range(_dice.size()):
		reset_die(_dice[index], index, _dice.size())


func get_registered_dice() -> Array[DiceDie3D]:
	return _dice.duplicate()


func get_result(die: DiceDie3D) -> DiceRollResult:
	if _finished_results.has(die):
		return _finished_results[die]
	var slot := _get_presented_slot(die)
	return _make_result(die, die.get_face(slot))


func get_result_direction() -> Vector3:
	var basis := global_transform.basis if is_inside_tree() else transform.basis
	return (basis * get_result_side_normal()).normalized()


func get_gravity_direction() -> Vector3:
	return -get_result_direction()


func get_stage_vertical_direction() -> Vector3:
	var basis := global_transform.basis if is_inside_tree() else transform.basis
	return (basis * _get_stage_vertical_normal()).normalized()


func get_result_side_normal() -> Vector3:
	return _get_side_normal(result_side)


func _get_side_normal(side: int) -> Vector3:
	match side:
		ResultSide.POS_Y:
			return Vector3.UP
		ResultSide.NEG_Y:
			return Vector3.DOWN
		ResultSide.POS_Z:
			return Vector3.BACK
		ResultSide.NEG_Z:
			return Vector3.FORWARD
		ResultSide.POS_X:
			return Vector3.RIGHT
		ResultSide.NEG_X:
			return Vector3.LEFT
		_:
			return Vector3.FORWARD


func rebuild() -> void:
	_ensure_internal_nodes()
	_clear_children(_debug_root)
	if debug_visible:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "DebugStageEdges"
		mesh_instance.mesh = _make_debug_stage_mesh()
		mesh_instance.material_override = _get_debug_edge_material()
		_debug_root.add_child(mesh_instance)


func _ensure_internal_nodes() -> void:
	_dice_root = get_node_or_null(_DICE_ROOT_NAME) as Node3D
	if _dice_root == null:
		_dice_root = Node3D.new()
		_dice_root.name = _DICE_ROOT_NAME
		add_child(_dice_root)

	_debug_root = get_node_or_null(_DEBUG_ROOT_NAME) as Node3D
	if _debug_root == null:
		_debug_root = Node3D.new()
		_debug_root.name = _DEBUG_ROOT_NAME
		add_child(_debug_root)


func _make_roll_animation(
	die: DiceDie3D,
	index: int,
	total: int,
	requested_result: Variant,
	options: Dictionary
) -> Dictionary:
	var target_slot := _resolve_target_slot(die, requested_result)
	var current_transform := _get_die_transform(die)
	var start_position := _world_to_stage(current_transform.origin)
	var layout_position := _get_end_stage_position(index, total)
	var end_position := Vector3(start_position.x, layout_position.y, start_position.z)
	var delay := _get_option_float(options, "start_delay", 0.0) + _get_option_float(options, "per_die_delay", per_die_delay) * index

	return {
		"die": die,
		"elapsed": -delay,
		"duration": _get_option_float(options, "duration", roll_duration),
		"bounce_height": _get_option_float(options, "bounce_height", bounce_height),
		"bounce_count": _get_option_float(options, "bounce_count", bounce_count),
		"spin_turns": _get_option_float(options, "spin_turns", spin_turns),
		"settle_start": _get_option_float(options, "settle_start", settle_start),
		"start_position": start_position,
		"end_position": end_position,
		"spin_axis": _random_spin_axis(),
		"start_basis": current_transform.basis,
		"target_slot": target_slot,
		"target_face": die.get_face(target_slot),
		"final_basis": _make_final_basis(die, target_slot),
	}


func _update_cinematic_rolls(delta: float) -> void:
	var index := _active_rolls.size() - 1
	while index >= 0:
		var roll := _active_rolls[index]
		var elapsed: float = roll.get("elapsed", 0.0) + delta
		roll["elapsed"] = elapsed

		if elapsed < 0.0:
			_apply_roll_transform(roll, 0.0)
		else:
			var duration: float = max(roll.get("duration", roll_duration), 0.001)
			var progress := clampf(elapsed / duration, 0.0, 1.0)
			_apply_roll_transform(roll, progress)
			if progress >= 1.0:
				_complete_roll(roll)
				_active_rolls.remove_at(index)

		index -= 1


func _apply_roll_transform(roll: Dictionary, progress: float) -> void:
	var die := roll["die"] as DiceDie3D
	if die == null:
		return

	_set_die_transform(die, Transform3D(
		_get_cinematic_basis(roll, progress),
		_to_world(_get_cinematic_stage_position(roll, progress))
	))
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
	die.freeze = true
	die.sleeping = true


func _get_cinematic_stage_position(roll: Dictionary, progress: float) -> Vector3:
	var start_position: Vector3 = roll["start_position"]
	var end_position: Vector3 = roll["end_position"]
	var eased := _ease_out_cubic(progress)
	var bounce_count_value := float(roll["bounce_count"])
	var bounce_height_value := float(roll["bounce_height"])
	var bounce: float = absf(sin(progress * PI * bounce_count_value)) * bounce_height_value * (1.0 - eased)
	var base_position := start_position.lerp(end_position, eased)
	return Vector3(base_position.x, base_position.y + bounce, base_position.z)


func _get_cinematic_basis(roll: Dictionary, progress: float) -> Basis:
	var spin_axis: Vector3 = roll["spin_axis"]
	var start_basis: Basis = roll.get("start_basis", Basis.IDENTITY)
	var final_basis: Basis = roll["final_basis"]
	var spin_amount: float = TAU * float(roll["spin_turns"]) * progress
	var spin_basis := (
		Basis(spin_axis, spin_amount)
		* Basis(Vector3.RIGHT, spin_amount * 0.61)
		* Basis(Vector3.UP, spin_amount * 0.37)
		* start_basis
	)
	var settle_weight := smoothstep(float(roll["settle_start"]), 1.0, progress)
	var spin_quaternion := spin_basis.get_rotation_quaternion()
	var final_quaternion := final_basis.get_rotation_quaternion()
	return Basis(spin_quaternion.slerp(final_quaternion, settle_weight))


func _complete_roll(roll: Dictionary) -> void:
	var die := roll["die"] as DiceDie3D
	if die == null:
		return

	var result := _make_result(die, roll["target_face"] as DiceFace3D)
	_finished_results[die] = result
	roll_finished.emit(result)
	if _active_rolls.size() <= 1 and not _finished_results.is_empty():
		all_dice_finished.emit(_finished_results.duplicate())


func _make_result(die: DiceDie3D, face: DiceFace3D) -> DiceRollResult:
	return DiceRollResult.from_face(
		die,
		null,
		face,
		get_result_direction(),
		get_gravity_direction()
	)


func _resolve_target_slot(die: DiceDie3D, requested_result: Variant) -> StringName:
	if die == null:
		return DiceDieShape3D.get_default_idle_slot(DiceDieShape3D.ShapeType.D6)

	if requested_result is Dictionary:
		var result_dictionary := requested_result as Dictionary
		if result_dictionary.has("slot"):
			return _resolve_target_slot(die, result_dictionary["slot"])
		if result_dictionary.has("face"):
			return _resolve_target_slot(die, result_dictionary["face"])
		if result_dictionary.has("face_id"):
			return _find_slot_by_face_id(die, StringName(str(result_dictionary["face_id"])))
		if result_dictionary.has("value"):
			return _find_slot_by_value(die, int(result_dictionary["value"]))

	if requested_result is DiceFace3D:
		return _find_slot_by_face(die, requested_result as DiceFace3D)

	var type := typeof(requested_result)
	if type == TYPE_STRING or type == TYPE_STRING_NAME:
		var candidate := StringName(str(requested_result))
		if die.has_face_slot(candidate):
			return candidate
		return _find_slot_by_face_id(die, candidate)

	if type == TYPE_INT or type == TYPE_FLOAT:
		return _find_slot_by_value(die, int(requested_result))

	return _random_slot(die)


func _find_slot_by_face(die: DiceDie3D, target_face: DiceFace3D) -> StringName:
	for slot in die.get_face_slots():
		if die.get_face(slot) == target_face:
			return slot
	if target_face != null and target_face.face_id != &"":
		return _find_slot_by_face_id(die, target_face.face_id)
	return _random_slot(die)


func _find_slot_by_face_id(die: DiceDie3D, face_id: StringName) -> StringName:
	for slot in die.get_face_slots():
		var face := die.get_face(slot)
		if face != null and face.face_id == face_id:
			return slot
	return _random_slot(die)


func _find_slot_by_value(die: DiceDie3D, value: int) -> StringName:
	for slot in die.get_face_slots():
		var face := die.get_face(slot)
		if face != null and face.value == value:
			return slot
	return _random_slot(die)


func _random_slot(die: DiceDie3D) -> StringName:
	if die == null:
		return DiceDieShape3D.get_default_idle_slot(DiceDieShape3D.ShapeType.D6)
	var slots := die.get_face_slots()
	if slots.is_empty():
		return die.get_default_idle_slot()
	return slots[randi() % slots.size()]


func _get_presented_slot(die: DiceDie3D) -> StringName:
	var result_direction := get_result_direction()
	var best_slot := die.get_default_idle_slot()
	var best_dot := -INF
	for slot in die.get_face_slots():
		var die_basis := die.global_transform.basis if die.is_inside_tree() else die.transform.basis
		var world_normal := (die_basis * die.get_local_face_normal(slot)).normalized()
		var score := world_normal.dot(result_direction)
		if score > best_dot:
			best_dot = score
			best_slot = slot
	return best_slot


func _make_final_basis(die: DiceDie3D, slot: StringName) -> Basis:
	if align_flat_bottom_on_land:
		if die.die_shape == DiceDie3D.DieShape.D20:
			return _make_presented_face_landing_basis(die, slot)
		return _make_flat_landing_basis(die, slot)

	var local_normal := die.get_local_face_normal(slot)
	var visible_normal := get_result_direction()
	var align_basis := _make_alignment_basis(local_normal, visible_normal)
	var twist := randf_range(-PI, PI)
	return Basis(visible_normal.normalized(), twist) * align_basis


func _make_flat_landing_basis(die: DiceDie3D, slot: StringName) -> Basis:
	var local_normal := die.get_local_face_normal(slot)
	var visible_normal := get_result_direction().normalized()
	var down := -get_stage_vertical_direction().normalized()
	var best_basis := _make_alignment_basis(local_normal, visible_normal)
	var best_bottom_score := _get_bottom_alignment_score(die, best_basis, slot)
	var best_visible_score := (best_basis * local_normal).normalized().dot(visible_normal)

	for candidate_slot in die.get_face_slots():
		var bottom_normal := die.get_local_face_normal(candidate_slot)
		var bottom_basis := _make_alignment_basis(bottom_normal, down)
		var twist := _get_twist_to_align_projection(bottom_basis * local_normal, down, visible_normal)
		var candidate := Basis(down, twist) * bottom_basis
		var bottom_score := ((candidate * bottom_normal).normalized()).dot(down)
		var visible_score := ((candidate * local_normal).normalized()).dot(visible_normal)
		if bottom_score > best_bottom_score + 0.0001 or (is_equal_approx(bottom_score, best_bottom_score) and visible_score > best_visible_score):
			best_bottom_score = bottom_score
			best_visible_score = visible_score
			best_basis = candidate

	return best_basis


func _make_presented_face_landing_basis(die: DiceDie3D, slot: StringName) -> Basis:
	var local_normal := die.get_local_face_normal(slot)
	var visible_normal := get_result_direction().normalized()
	var align_basis := _make_alignment_basis(local_normal, visible_normal)
	var best_basis := align_basis
	var best_bottom_score := _get_bottom_alignment_score(die, best_basis, slot)

	for step_index in range(_PRESENTED_FACE_TWIST_STEPS):
		var twist := TAU * float(step_index) / float(_PRESENTED_FACE_TWIST_STEPS)
		var candidate := Basis(visible_normal, twist) * align_basis
		var bottom_score := _get_bottom_alignment_score(die, candidate, slot)
		if bottom_score > best_bottom_score:
			best_bottom_score = bottom_score
			best_basis = candidate

	return best_basis


func _make_idle_basis(die: DiceDie3D) -> Basis:
	if randomize_idle_start_side:
		return _make_flat_landing_basis(die, _random_slot(die))
	return _make_flat_landing_basis(die, die.get_default_idle_slot())


func _get_bottom_alignment_score(die: DiceDie3D, basis: Basis, target_slot: StringName) -> float:
	var local_target_normal := die.get_local_face_normal(target_slot)
	var down := -get_stage_vertical_direction()
	var best_score := -INF
	for slot in die.get_face_slots():
		var local_normal := die.get_local_face_normal(slot)
		if absf(local_normal.dot(local_target_normal)) > 0.99:
			continue
		var world_normal := (basis * local_normal).normalized()
		best_score = maxf(best_score, world_normal.dot(down))
	return best_score


func _get_twist_to_align_projection(face_normal: Vector3, twist_axis: Vector3, target_normal: Vector3) -> float:
	var axis := twist_axis.normalized()
	var face_projection := face_normal - axis * face_normal.dot(axis)
	var target_projection := target_normal - axis * target_normal.dot(axis)
	if face_projection.length_squared() <= _MIN_VECTOR_LENGTH or target_projection.length_squared() <= _MIN_VECTOR_LENGTH:
		return 0.0
	face_projection = face_projection.normalized()
	target_projection = target_projection.normalized()
	var cross := face_projection.cross(target_projection)
	var dot := clampf(face_projection.dot(target_projection), -1.0, 1.0)
	return atan2(cross.dot(axis), dot)


func _make_alignment_basis(from_normal: Vector3, to_normal: Vector3) -> Basis:
	var from := from_normal.normalized()
	var to := to_normal.normalized()
	var axis := from.cross(to)
	var dot := clampf(from.dot(to), -1.0, 1.0)
	if axis.length_squared() <= _MIN_VECTOR_LENGTH:
		if dot > 0.0:
			return Basis.IDENTITY
		return Basis(_perpendicular_axis(from), PI)
	return Basis(axis.normalized(), acos(dot))


func _perpendicular_axis(axis: Vector3) -> Vector3:
	var perpendicular := axis.cross(Vector3.RIGHT)
	if perpendicular.length_squared() <= _MIN_VECTOR_LENGTH:
		perpendicular = axis.cross(Vector3.UP)
	return perpendicular.normalized()


func _random_spin_axis() -> Vector3:
	var axis := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)
	if axis.length_squared() <= _MIN_VECTOR_LENGTH:
		axis = Vector3(0.4, 1.0, 0.7)
	return axis.normalized()


func _get_requested_result_for_index(requested_results: Variant, die: DiceDie3D, index: int) -> Variant:
	if requested_results is Array:
		var result_array := requested_results as Array
		if index < result_array.size():
			return result_array[index]
		return null

	if requested_results is Dictionary:
		var result_dictionary := requested_results as Dictionary
		if result_dictionary.has(die):
			return result_dictionary[die]
		if result_dictionary.has(index):
			return result_dictionary[index]
		return null

	return requested_results


func _get_end_stage_position(index: int, total: int) -> Vector3:
	var centered_offset: float = (float(index) - float(total - 1) * 0.5) * _get_layout_spacing()
	return Vector3(
		centered_offset,
		0.05,
		_get_back_stage_z()
	)


func _get_back_stage_z() -> float:
	return -stage_size.z * 0.5 + minf(end_padding, stage_size.z * 0.45)


func _to_world(stage_position: Vector3) -> Vector3:
	var active_transform := global_transform if is_inside_tree() else transform
	return active_transform * _stage_to_local(stage_position)


func _world_to_stage(world_position: Vector3) -> Vector3:
	var active_transform := global_transform if is_inside_tree() else transform
	var local_position := active_transform.affine_inverse() * world_position
	var axes := _get_stage_axes()
	var horizontal: Vector3 = axes["horizontal"]
	var vertical: Vector3 = axes["vertical"]
	var normal: Vector3 = axes["normal"]
	return Vector3(
		local_position.dot(horizontal),
		local_position.dot(vertical),
		local_position.dot(normal)
	)


func _stage_to_local(stage_position: Vector3) -> Vector3:
	var axes := _get_stage_axes()
	var horizontal: Vector3 = axes["horizontal"]
	var vertical: Vector3 = axes["vertical"]
	var normal: Vector3 = axes["normal"]
	return horizontal * stage_position.x + vertical * stage_position.y + normal * stage_position.z


func _get_stage_vertical_normal() -> Vector3:
	return _get_stage_axes()["vertical"]


func _get_stage_axes() -> Dictionary:
	var normal := (get_result_side_normal() if stage_side_follows_result else _get_side_normal(stage_side)).normalized()
	var reference_up := Vector3.UP
	if absf(normal.dot(reference_up)) > 0.95:
		reference_up = Vector3.FORWARD
	var horizontal := normal.cross(reference_up).normalized()
	var vertical := horizontal.cross(normal).normalized()
	return {
		"normal": normal,
		"horizontal": horizontal,
		"vertical": vertical,
	}


func _make_debug_stage_mesh() -> ArrayMesh:
	return _make_debug_bounds_edge_mesh()


func _make_debug_bounds_edge_mesh() -> ArrayMesh:
	var half := stage_size * 0.5
	var corners := [
		Vector3(-half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, half.y, -half.z),
		Vector3(-half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z),
		Vector3(half.x, -half.y, half.z),
		Vector3(half.x, half.y, half.z),
		Vector3(-half.x, half.y, half.z),
	]
	var edge_indices := [
		0, 1, 1, 2, 2, 3, 3, 0,
		4, 5, 5, 6, 6, 7, 7, 4,
		0, 4, 1, 5, 2, 6, 3, 7,
	]
	var vertices := PackedVector3Array()
	for index in edge_indices:
		vertices.append(_stage_to_local(corners[index]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


func _get_layout_spacing() -> float:
	return maxf(dice_spacing, spin_clearance)


func _get_layout_dice(dice_to_layout: Array) -> Array[DiceDie3D]:
	var layout_dice: Array[DiceDie3D] = []
	var source := dice_to_layout if not dice_to_layout.is_empty() else _dice
	for item in source:
		var die := item as DiceDie3D
		if die == null:
			continue
		if not is_instance_valid(die):
			continue
		if not die.visible:
			continue
		layout_dice.append(die)
	return layout_dice


func _get_die_transform(die: DiceDie3D) -> Transform3D:
	if die != null and die.is_inside_tree():
		return die.global_transform
	return die.transform if die != null else Transform3D.IDENTITY


func _set_die_transform(die: DiceDie3D, target_transform: Transform3D) -> void:
	if die == null:
		return
	if die.is_inside_tree():
		die.global_transform = target_transform
	else:
		die.transform = target_transform


func _move_die_to_transform(die: DiceDie3D, target_transform: Transform3D, tweened: bool) -> void:
	if die == null:
		return
	_kill_layout_tween(die)
	die.freeze = true
	die.sleeping = true
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
	if randomize_idle_spin_on_layout:
		_randomize_idle_spin_for_die(die)

	if not tweened or layout_tween_duration <= 0.0 or not is_inside_tree():
		_set_die_transform(die, target_transform)
		return

	var start_transform := _get_die_transform(die)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(
		Callable(self, "_set_die_interpolated_transform").bind(die, start_transform, target_transform),
		0.0,
		1.0,
		layout_tween_duration
	)
	tween.finished.connect(func() -> void:
		if _layout_tweens.get(die, null) == tween:
			_layout_tweens.erase(die)
	)
	_layout_tweens[die] = tween


func _set_die_interpolated_transform(
	weight: float,
	die: DiceDie3D,
	start_transform: Transform3D,
	target_transform: Transform3D
) -> void:
	if die == null or not is_instance_valid(die):
		return
	var origin := start_transform.origin.lerp(target_transform.origin, weight)
	var rotation := start_transform.basis.get_rotation_quaternion().slerp(
		target_transform.basis.get_rotation_quaternion(),
		weight
	)
	_set_die_transform(die, Transform3D(Basis(rotation), origin))


func _kill_layout_tween(die: DiceDie3D) -> void:
	if not _layout_tweens.has(die):
		return
	var tween := _layout_tweens[die] as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_layout_tweens.erase(die)


func _update_idle_spin(delta: float) -> void:
	if not idle_spin_enabled:
		return
	var axis := get_stage_vertical_direction()
	for die in _dice:
		if die == null or not is_instance_valid(die):
			continue
		if not die.visible:
			continue
		if _is_die_rolling(die) or _layout_tweens.has(die):
			continue
		if _finished_results.has(die) and not idle_spin_after_result:
			continue
		_ensure_idle_spin_for_die(die)
		var speed: float = _idle_spin_speeds.get(die, 0.0)
		var current_transform := _get_die_transform(die)
		current_transform.basis = Basis(axis, speed * delta) * current_transform.basis
		_set_die_transform(die, current_transform)


func _is_die_rolling(die: DiceDie3D) -> bool:
	for roll in _active_rolls:
		if roll.get("die", null) == die:
			return true
	return false


func _ensure_idle_spin_for_die(die: DiceDie3D) -> void:
	if die == null or _idle_spin_speeds.has(die):
		return
	_randomize_idle_spin_for_die(die)


func _randomize_idle_spin_for_die(die: DiceDie3D) -> void:
	if die == null:
		return
	var min_speed := minf(idle_spin_speed_min_degrees, idle_spin_speed_max_degrees)
	var max_speed := maxf(idle_spin_speed_min_degrees, idle_spin_speed_max_degrees)
	var direction := -1.0 if randf() < 0.5 else 1.0
	_idle_spin_speeds[die] = deg_to_rad(randf_range(min_speed, max_speed)) * direction


func _remove_active_rolls_for_die(die: DiceDie3D) -> void:
	var index := _active_rolls.size() - 1
	while index >= 0:
		var roll := _active_rolls[index]
		if roll.get("die", null) == die:
			_active_rolls.remove_at(index)
		index -= 1


func _get_option(options: Dictionary, key: String, default_value: Variant) -> Variant:
	if options.has(key):
		return options[key]
	var key_name := StringName(key)
	if options.has(key_name):
		return options[key_name]
	return default_value


func _get_option_float(options: Dictionary, key: String, default_value: float) -> float:
	return float(_get_option(options, key, default_value))


func _ease_out_cubic(value: float) -> float:
	var inverse := 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverse * inverse * inverse


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()


func _get_debug_edge_material() -> StandardMaterial3D:
	if _debug_edge_material == null:
		_debug_edge_material = StandardMaterial3D.new()
		_debug_edge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_debug_edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_update_debug_materials()
	return _debug_edge_material


func _update_debug_materials() -> void:
	if _debug_edge_material != null:
		_debug_edge_material.albedo_color = Color(0.2, 0.75, 1.0, debug_edge_alpha)
