@tool
class_name DiceRollBox3D
extends Node3D


signal die_added(die: DiceDie3D)
signal die_removed(die: DiceDie3D)
signal roll_started(die: DiceDie3D)
signal roll_finished(result: DiceRollResult)
signal unflat_reroll_requested(die: DiceDie3D, flatness: float, reroll_count: int)
signal all_dice_settled(results: Dictionary)

const DEFAULT_DICE_LAYER := 1 << 20
const _ENVIRONMENT_ROOT_NAME := "_DiceEnvironment"
const _DICE_ROOT_NAME := "_Dice"

enum BoxSide {
	POS_Y,
	NEG_Y,
	POS_Z,
	NEG_Z,
	POS_X,
	NEG_X,
}

enum RollSource {
	RANDOM_INSIDE,
	NEG_X_NEG_Z_CORNER,
	POS_X_NEG_Z_CORNER,
	NEG_X_POS_Z_CORNER,
	POS_X_POS_Z_CORNER,
	NEG_X_SIDE,
	POS_X_SIDE,
	NEG_Z_SIDE,
	POS_Z_SIDE,
	CUSTOM_LOCAL,
}

@export_category("Dice Roll Box")
@export_group("Box")
## Interior width, height, and depth of the roll box in local 3D units.
@export var size: Vector3 = Vector3(6.0, 3.0, 6.0):
	set(value):
		size = Vector3(max(value.x, 0.5), max(value.y, 0.5), max(value.z, 0.5))
		if is_inside_tree():
			rebuild()
## Thickness of the invisible collision walls used to contain dice.
@export var wall_thickness: float = 0.2:
	set(value):
		wall_thickness = max(value, 0.02)
		if is_inside_tree():
			rebuild()

@export_group("Gravity")
## Local side of this box that acts as the bottom. Gravity pulls toward this side.
@export_enum("+Y", "-Y", "+Z", "-Z", "+X", "-X") var bottom_side: int = BoxSide.NEG_Y
## Strength of the roll box gravity applied to registered dice.
@export var gravity_strength: float = 9.8

@export_group("Collision")
## Physics layer assigned to the roll box walls and auto-configured dice.
@export_flags_3d_physics var dice_collision_layer: int = DEFAULT_DICE_LAYER:
	set(value):
		dice_collision_layer = value
		_apply_collision_settings()
## Physics mask assigned to the roll box walls and auto-configured dice.
@export_flags_3d_physics var dice_collision_mask: int = DEFAULT_DICE_LAYER:
	set(value):
		dice_collision_mask = value
		_apply_collision_settings()
## When enabled, dice added to this box are assigned the box collision layer and mask.
@export var auto_configure_collision: bool = true
## Friction shared by the roll box walls and registered dice.
@export_range(0.0, 4.0, 0.01) var dice_friction: float = 1.0:
	set(value):
		dice_friction = max(value, 0.0)
		_update_physics_material()
		_apply_physics_materials()
## Bounce shared by the roll box walls and registered dice. 0 absorbs impacts, 1 rebounds strongly.
@export_range(0.0, 1.0, 0.01) var dice_bounce: float = 0.0:
	set(value):
		dice_bounce = clampf(value, 0.0, 1.0)
		_update_physics_material()
		_apply_physics_materials()

@export_group("Bounds")
## Enables the collision plane on the local -Y side of the box.
@export var floor_enabled: bool = true:
	set(value):
		floor_enabled = value
		if is_inside_tree():
			rebuild()
## Enables the four side collision walls.
@export var walls_enabled: bool = true:
	set(value):
		walls_enabled = value
		if is_inside_tree():
			rebuild()
## Enables the collision plane on the local +Y side so dice stay enclosed.
@export var ceiling_enabled: bool = true:
	set(value):
		ceiling_enabled = value
		if is_inside_tree():
			rebuild()
## Shows translucent blue preview meshes for the otherwise invisible roll box bounds.
@export var debug_visible: bool = false:
	set(value):
		debug_visible = value
		if is_inside_tree():
			rebuild()
## Opacity of the debug wall surfaces. Keep this at 0 for an edge-only preview.
@export_range(0.0, 1.0, 0.001) var debug_surface_alpha: float = 0.0:
	set(value):
		debug_surface_alpha = clampf(value, 0.0, 1.0)
		_update_debug_materials()
## Opacity of the debug box edge lines.
@export_range(0.0, 1.0, 0.001) var debug_edge_alpha: float = 0.45:
	set(value):
		debug_edge_alpha = clampf(value, 0.0, 1.0)
		_update_debug_materials()
## Minimum distance kept between spawned dice and the box bounds.
@export var spawn_padding: float = 0.5

@export_group("Dice Definitions")
## When enabled, the roll box creates dice from Dice Definitions on scene start.
@export var spawn_dice_from_definitions_on_ready: bool = true
## Inspector-authored dice this roll box owns. Each definition can spawn one or more dice.
@export var dice_definitions: Array[DiceDieDefinition3D] = []

@export_group("Default Dice Roll")
## When enabled, dice added to this box inherit the roll impulse and spin defaults below.
@export var auto_configure_dice_roll_settings: bool = true
## Minimum launch impulse used when a roll does not provide an explicit impulse.
@export var default_roll_impulse_min: float = 4.0
## Maximum launch impulse used when a roll does not provide an explicit impulse.
@export var default_roll_impulse_max: float = 8.0
## Minimum initial spin impulse copied to dice created or registered by this box.
@export var default_initial_spin_min: float = 8.0
## Maximum initial spin impulse copied to dice created or registered by this box.
@export var default_initial_spin_max: float = 16.0

@export_group("Roll Direction")
## Local source area used when reset or roll places dice before launch. The bottom-side axis is placed near the active top.
@export_enum("Random Inside", "-X -Z Corner", "+X -Z Corner", "-X +Z Corner", "+X +Z Corner", "-X Side", "+X Side", "-Z Side", "+Z Side", "Custom Local") var roll_source: int = RollSource.NEG_X_NEG_Z_CORNER
## Custom source vector used when Roll Source is Custom Local. Values are normalized local box coordinates, and the bottom-side axis is placed near the active top.
@export var custom_roll_source_local: Vector3 = Vector3(-1.0, 0.0, -1.0):
	set(value):
		custom_roll_source_local = Vector3(
			clampf(value.x, -1.0, 1.0),
			clampf(value.y, -1.0, 1.0),
			clampf(value.z, -1.0, 1.0)
		)
## Random local-unit spread around the selected source area.
@export_range(0.0, 3.0, 0.01) var roll_source_spread: float = 0.35
## Moves the roll source outside the selected wall or corner. Matching source walls briefly open when this is greater than zero.
@export_range(0.0, 10.0, 0.01) var roll_source_outside_distance: float = 0.0
## When enabled, rolls without an explicit impulse are aimed from the source toward the center of the box.
@export var roll_toward_center: bool = true
## Random local-unit spread around the center target.
@export_range(0.0, 3.0, 0.01) var roll_target_spread: float = 0.25
## Fraction of launch impulse applied upward, away from the bottom side.
@export_range(0.0, 2.0, 0.01) var roll_upward_bias: float = 0.25
## Seconds source walls stay open when rolling from outside the box.
@export_range(0.0, 3.0, 0.01) var launch_opening_duration: float = 0.45
## When launching from outside the box, gravity waits until the die center enters the box bounds.
@export var suspend_gravity_until_inside: bool = true
## Safety timeout for suspended launch gravity. Set to 0 to wait indefinitely.
@export_range(0.0, 5.0, 0.01) var suspended_gravity_timeout: float = 1.25
## Extra local margin used when detecting that an outside-launched die has entered the box.
@export_range(0.0, 1.0, 0.001) var launch_entry_margin: float = 0.05

@export_group("Unflat Reroll")
## Automatically rerolls a die when it settles too tilted for a confident top face result.
@export var reroll_unflat_results: bool = false
## Minimum top-face alignment score required to count as a flat result. 1.0 is perfectly flat.
@export_range(0.5, 1.0, 0.01) var flat_result_threshold: float = 0.92
## Maximum number of automatic rerolls attempted for one unflat roll.
@export_range(0, 10, 1) var max_unflat_rerolls: int = 1

var _environment_root: Node3D
var _dice_root: Node3D
var _dice: Array[DiceDie3D] = []
var _spawned_definition_dice: Array[DiceDie3D] = []
var _rolling_dice: Dictionary = {}
var _settled_results: Dictionary = {}
var _unflat_reroll_counts: Dictionary = {}
var _debug_material: StandardMaterial3D
var _debug_edge_material: StandardMaterial3D
var _physics_material: PhysicsMaterial
var _launch_gate_generation := 0
var _launch_gate_open_walls: Array[StringName] = []
var _gravity_suspended_dice: Dictionary = {}


func _ready() -> void:
	randomize()
	_ensure_internal_nodes()
	rebuild()
	if not Engine.is_editor_hint() and spawn_dice_from_definitions_on_ready:
		spawn_dice_from_definitions()


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
			reset_die(die)
			spawned.append(die)
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
		reset_die(die)
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

	die._set_roll_box(self)
	if auto_configure_collision:
		_configure_die_collision(die)
	if auto_configure_dice_roll_settings:
		apply_default_roll_settings(die)
	die._rebuild_die()
	if not die.settled.is_connected(_on_die_settled):
		die.settled.connect(_on_die_settled)

	die_added.emit(die)


func remove_die(die: DiceDie3D) -> void:
	if die == null:
		return
	_dice.erase(die)
	_spawned_definition_dice.erase(die)
	_rolling_dice.erase(die)
	_settled_results.erase(die)
	_gravity_suspended_dice.erase(die)
	if die.settled.is_connected(_on_die_settled):
		die.settled.disconnect(_on_die_settled)
	die._set_roll_box(null)
	die_removed.emit(die)


func roll(die: DiceDie3D, options: DiceRollOptions = null) -> void:
	if die == null:
		return
	if not _dice.has(die):
		add_die(die)

	var active_options := _copy_roll_options(options) if options != null else DiceRollOptions.defaults()
	_unflat_reroll_counts[die] = 0
	_roll_die_internal(die, active_options)


func _roll_die_internal(die: DiceDie3D, active_options: DiceRollOptions) -> void:
	if active_options.reset_before_roll:
		_reset_die_with_options(die, active_options)

	if roll_toward_center and active_options.impulse.length_squared() <= 0.000001:
		active_options.impulse = _make_centered_roll_impulse(die)

	if _should_suspend_launch_gravity(die, active_options):
		_suspend_gravity_until_inside(die)
	else:
		_gravity_suspended_dice.erase(die)

	if _should_open_launch_gate(active_options):
		_open_launch_gate_if_needed()

	_settled_results.erase(die)
	_rolling_dice[die] = true
	die._start_roll(active_options, self)
	roll_started.emit(die)


func roll_all(options: DiceRollOptions = null) -> void:
	_settled_results.clear()
	for die in _dice:
		roll(die, options)


func reset_die(die: DiceDie3D) -> void:
	var options := DiceRollOptions.new()
	options.reset_before_roll = true
	options.use_spawn_position = true
	options.randomize_rotation = true
	_reset_die_with_options(die, options)


func reset_all() -> void:
	for die in _dice:
		reset_die(die)


func get_top_face(die: DiceDie3D) -> DiceFace3D:
	return _get_top_face_info(die).get("face", null)


func get_result(die: DiceDie3D) -> DiceRollResult:
	var info := _get_top_face_info(die)
	return _make_result_from_info(die, info, _unflat_reroll_counts.get(die, 0))


func get_random_spawn_position() -> Vector3:
	var padding := _get_effective_spawn_padding(null)
	var local_position := Vector3(
		_random_axis_position(Vector3.AXIS_X, padding),
		_random_axis_position(Vector3.AXIS_Y, padding),
		_random_axis_position(Vector3.AXIS_Z, padding)
	)
	local_position = _move_spawn_toward_top(local_position, padding)
	var box_transform := global_transform if is_inside_tree() else transform
	return box_transform * local_position


func get_roll_source_position(die: DiceDie3D = null) -> Vector3:
	if roll_source == RollSource.RANDOM_INSIDE:
		return _get_random_spawn_position_for_die(die)
	var box_transform := global_transform if is_inside_tree() else transform
	return box_transform * _get_roll_source_local_position(die)


func get_roll_direction_to_center(from_world_position: Vector3) -> Vector3:
	var box_transform := global_transform if is_inside_tree() else transform
	var up := get_up_direction()
	var to_center := box_transform.origin - from_world_position
	to_center -= up * to_center.dot(up)
	if to_center.length_squared() <= 0.000001:
		return _fallback_roll_direction()
	return to_center.normalized()


func get_registered_dice() -> Array[DiceDie3D]:
	return _dice.duplicate()


func get_up_direction() -> Vector3:
	return -get_gravity_vector().normalized()


func get_gravity_vector() -> Vector3:
	var box_basis := global_transform.basis if is_inside_tree() else transform.basis
	return box_basis * get_bottom_side_normal() * gravity_strength


func should_apply_gravity_to_die(die: DiceDie3D) -> bool:
	if die == null:
		return true
	if not _gravity_suspended_dice.has(die):
		return true
	if is_die_inside_roll_box(die, launch_entry_margin):
		_gravity_suspended_dice.erase(die)
		return true
	var expires_at: float = _gravity_suspended_dice.get(die, 0.0)
	if expires_at > 0.0 and Time.get_ticks_msec() * 0.001 >= expires_at:
		_gravity_suspended_dice.erase(die)
		return true
	return false


func is_die_inside_roll_box(die: DiceDie3D, margin: float = 0.0) -> bool:
	if die == null:
		return false
	var world_position := die.global_position if die.is_inside_tree() else die.position
	return is_world_position_inside_roll_box(world_position, margin)


func is_world_position_inside_roll_box(world_position: Vector3, margin: float = 0.0) -> bool:
	var box_transform := global_transform if is_inside_tree() else transform
	var local_position := box_transform.affine_inverse() * world_position
	var safe_margin := max(margin, 0.0)
	return (
		absf(local_position.x) <= size.x * 0.5 + safe_margin
		and absf(local_position.y) <= size.y * 0.5 + safe_margin
		and absf(local_position.z) <= size.z * 0.5 + safe_margin
	)


func get_bottom_side_normal() -> Vector3:
	match bottom_side:
		BoxSide.POS_Y:
			return Vector3.UP
		BoxSide.NEG_Y:
			return Vector3.DOWN
		BoxSide.POS_Z:
			return Vector3.BACK
		BoxSide.NEG_Z:
			return Vector3.FORWARD
		BoxSide.POS_X:
			return Vector3.RIGHT
		BoxSide.NEG_X:
			return Vector3.LEFT
		_:
			return Vector3.DOWN


func apply_default_roll_settings(die: DiceDie3D) -> void:
	if die == null:
		return
	die.roll_impulse_min = default_roll_impulse_min
	die.roll_impulse_max = default_roll_impulse_max
	die.roll_torque_min = default_initial_spin_min
	die.roll_torque_max = default_initial_spin_max


func apply_default_dice_settings(die: DiceDie3D) -> void:
	apply_default_roll_settings(die)


func rebuild() -> void:
	_ensure_internal_nodes()
	_clear_children(_environment_root)

	if floor_enabled:
		_create_wall(
			"Floor",
			Vector3(0.0, -size.y * 0.5 - wall_thickness * 0.5, 0.0),
			Vector3(size.x + wall_thickness * 2.0, wall_thickness, size.z + wall_thickness * 2.0)
		)

	if ceiling_enabled:
		_create_wall(
			"Ceiling",
			Vector3(0.0, size.y * 0.5 + wall_thickness * 0.5, 0.0),
			Vector3(size.x + wall_thickness * 2.0, wall_thickness, size.z + wall_thickness * 2.0)
		)

	if walls_enabled:
		var wall_height := size.y + wall_thickness * 2.0
		_create_wall(
			"Wall_PosX",
			Vector3(size.x * 0.5 + wall_thickness * 0.5, 0.0, 0.0),
			Vector3(wall_thickness, wall_height, size.z + wall_thickness * 2.0)
		)
		_create_wall(
			"Wall_NegX",
			Vector3(-size.x * 0.5 - wall_thickness * 0.5, 0.0, 0.0),
			Vector3(wall_thickness, wall_height, size.z + wall_thickness * 2.0)
		)
		_create_wall(
			"Wall_PosZ",
			Vector3(0.0, 0.0, size.z * 0.5 + wall_thickness * 0.5),
			Vector3(size.x, wall_height, wall_thickness)
		)
		_create_wall(
			"Wall_NegZ",
			Vector3(0.0, 0.0, -size.z * 0.5 - wall_thickness * 0.5),
			Vector3(size.x, wall_height, wall_thickness)
		)

	if debug_visible:
		_create_debug_bounds_edges()


func _ensure_internal_nodes() -> void:
	_environment_root = get_node_or_null(_ENVIRONMENT_ROOT_NAME) as Node3D
	if _environment_root == null:
		_environment_root = Node3D.new()
		_environment_root.name = _ENVIRONMENT_ROOT_NAME
		add_child(_environment_root)

	_dice_root = get_node_or_null(_DICE_ROOT_NAME) as Node3D
	if _dice_root == null:
		_dice_root = Node3D.new()
		_dice_root.name = _DICE_ROOT_NAME
		add_child(_dice_root)


func _create_wall(wall_name: String, local_position: Vector3, shape_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = wall_name
	body.position = local_position
	body.collision_layer = dice_collision_layer
	body.collision_mask = dice_collision_mask
	body.physics_material_override = _get_physics_material()
	_environment_root.add_child(body)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = shape_size
	shape.shape = box_shape
	body.add_child(shape)

	if debug_visible and debug_surface_alpha > 0.0:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape_size
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _get_debug_material()
		body.add_child(mesh_instance)


func _create_debug_bounds_edges() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DebugBoundsEdges"
	mesh_instance.mesh = _make_debug_bounds_edge_mesh()
	mesh_instance.material_override = _get_debug_edge_material()
	_environment_root.add_child(mesh_instance)


func _make_debug_bounds_edge_mesh() -> ArrayMesh:
	var half := size * 0.5
	var corners := [
		Vector3(-half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, half.z),
		Vector3(-half.x, -half.y, half.z),
		Vector3(-half.x, half.y, -half.z),
		Vector3(half.x, half.y, -half.z),
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
		vertices.append(corners[index])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()


func _apply_collision_settings() -> void:
	if not is_inside_tree():
		return
	_ensure_internal_nodes()
	for body in _environment_root.get_children():
		if body is CollisionObject3D:
			body.collision_layer = dice_collision_layer
			body.collision_mask = dice_collision_mask
	for die in _dice:
		_configure_die_collision(die)


func _configure_die_collision(die: DiceDie3D) -> void:
	die.collision_layer = dice_collision_layer
	die.collision_mask = dice_collision_mask
	die.physics_material_override = _get_physics_material()


func _apply_physics_materials() -> void:
	if not is_inside_tree():
		return
	_ensure_internal_nodes()
	for body in _environment_root.get_children():
		if body is CollisionObject3D:
			body.physics_material_override = _get_physics_material()
	for die in _dice:
		die.physics_material_override = _get_physics_material()


func _get_physics_material() -> PhysicsMaterial:
	if _physics_material == null:
		_physics_material = PhysicsMaterial.new()
	_update_physics_material()
	return _physics_material


func _update_physics_material() -> void:
	if _physics_material == null:
		return
	_physics_material.friction = dice_friction
	_physics_material.bounce = dice_bounce


func _copy_roll_options(options: DiceRollOptions) -> DiceRollOptions:
	var copy := DiceRollOptions.new()
	if options == null:
		return copy
	copy.reset_before_roll = options.reset_before_roll
	copy.use_spawn_position = options.use_spawn_position
	copy.spawn_position = options.spawn_position
	copy.randomize_rotation = options.randomize_rotation
	copy.impulse = options.impulse
	copy.torque = options.torque
	return copy


func _get_random_spawn_position_for_die(die: DiceDie3D) -> Vector3:
	var padding := _get_effective_spawn_padding(die)
	var local_position := Vector3(
		_random_axis_position(Vector3.AXIS_X, padding),
		_random_axis_position(Vector3.AXIS_Y, padding),
		_random_axis_position(Vector3.AXIS_Z, padding)
	)
	local_position = _move_spawn_toward_top(local_position, padding)
	var box_transform := global_transform if is_inside_tree() else transform
	return box_transform * local_position


func _get_default_spawn_position(die: DiceDie3D) -> Vector3:
	return get_roll_source_position(die)


func _get_effective_spawn_padding(die: DiceDie3D) -> float:
	var die_half := _get_die_half_extent(die)
	var unclamped_padding: float = max(spawn_padding, 0.0) + die_half
	return min(unclamped_padding, min(size.x, min(size.y, size.z)) * 0.45)


func _get_die_half_extent(die: DiceDie3D) -> float:
	if die == null:
		return 0.0
	return max(die.edge_length, 0.0) * 0.5


func _random_axis_position(axis: int, padding: float) -> float:
	var extent: float = max(_axis_extent(axis) - padding, 0.0)
	return randf_range(-extent, extent)


func _move_spawn_toward_top(local_position: Vector3, padding: float) -> Vector3:
	var local_top := -get_bottom_side_normal()
	var axis: int = _dominant_axis(local_top)
	var top_sign: float = sign(_get_axis_value(local_top, axis))
	var top_extent: float = max(_axis_extent(axis) - padding, 0.0)
	if top_sign >= 0.0:
		local_position = _with_axis_value(local_position, axis, randf_range(0.0, top_extent))
	else:
		local_position = _with_axis_value(local_position, axis, randf_range(-top_extent, 0.0))
	return local_position


func _dominant_axis(vector: Vector3) -> int:
	var absolute := vector.abs()
	if absolute.x >= absolute.y and absolute.x >= absolute.z:
		return Vector3.AXIS_X
	if absolute.y >= absolute.z:
		return Vector3.AXIS_Y
	return Vector3.AXIS_Z


func _axis_extent(axis: int) -> float:
	match axis:
		Vector3.AXIS_X:
			return size.x * 0.5
		Vector3.AXIS_Y:
			return size.y * 0.5
		Vector3.AXIS_Z:
			return size.z * 0.5
		_:
			return size.y * 0.5


func _get_axis_value(vector: Vector3, axis: int) -> float:
	match axis:
		Vector3.AXIS_X:
			return vector.x
		Vector3.AXIS_Y:
			return vector.y
		Vector3.AXIS_Z:
			return vector.z
		_:
			return 0.0


func _with_axis_value(vector: Vector3, axis: int, value: float) -> Vector3:
	var result := vector
	match axis:
		Vector3.AXIS_X:
			result.x = value
		Vector3.AXIS_Y:
			result.y = value
		Vector3.AXIS_Z:
			result.z = value
	return result


func _get_roll_source_local_position(die: DiceDie3D) -> Vector3:
	var source_vector := _get_roll_source_vector()
	var top_normal := -get_bottom_side_normal()
	var top_axis: int = _dominant_axis(top_normal)
	var top_sign: float = sign(_get_axis_value(top_normal, top_axis))
	if top_sign == 0.0:
		top_sign = 1.0

	var padding := _get_effective_spawn_padding(die)
	var die_half := _get_die_half_extent(die)
	var local_position := Vector3.ZERO
	for axis in [Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Z]:
		var axis_extent := _axis_extent(axis)
		if axis == top_axis:
			local_position = _with_axis_value(local_position, axis, top_sign * max(axis_extent - padding, 0.0))
			continue

		var source_component := _get_axis_value(source_vector, axis)
		var source_sign: float = sign(source_component)
		if source_sign == 0.0:
			var center_spread: float = min(roll_source_spread, max(axis_extent - padding, 0.0))
			local_position = _with_axis_value(local_position, axis, randf_range(-center_spread, center_spread))
			continue

		if roll_source_outside_distance > 0.0:
			var outside_jitter: float = randf_range(0.0, roll_source_spread)
			local_position = _with_axis_value(local_position, axis, source_sign * (axis_extent + die_half + roll_source_outside_distance + outside_jitter))
		else:
			var inward_spread: float = min(roll_source_spread, max(axis_extent - padding, 0.0))
			local_position = _with_axis_value(local_position, axis, source_sign * max(axis_extent - padding - randf_range(0.0, inward_spread), 0.0))

	return local_position


func _get_roll_source_vector() -> Vector3:
	var source_vector := Vector3.ZERO
	match roll_source:
		RollSource.NEG_X_NEG_Z_CORNER:
			source_vector = Vector3(-1.0, 0.0, -1.0)
		RollSource.POS_X_NEG_Z_CORNER:
			source_vector = Vector3(1.0, 0.0, -1.0)
		RollSource.NEG_X_POS_Z_CORNER:
			source_vector = Vector3(-1.0, 0.0, 1.0)
		RollSource.POS_X_POS_Z_CORNER:
			source_vector = Vector3(1.0, 0.0, 1.0)
		RollSource.NEG_X_SIDE:
			source_vector = Vector3.LEFT
		RollSource.POS_X_SIDE:
			source_vector = Vector3.RIGHT
		RollSource.NEG_Z_SIDE:
			source_vector = Vector3.FORWARD
		RollSource.POS_Z_SIDE:
			source_vector = Vector3.BACK
		RollSource.CUSTOM_LOCAL:
			source_vector = custom_roll_source_local
		_:
			source_vector = Vector3.ZERO

	var floor_axis: int = _dominant_axis(get_bottom_side_normal())
	source_vector = _with_axis_value(source_vector, floor_axis, 0.0)
	if source_vector.length_squared() <= 0.000001:
		source_vector = _get_fallback_source_vector(floor_axis)
	return source_vector


func _get_fallback_source_vector(floor_axis: int) -> Vector3:
	match floor_axis:
		Vector3.AXIS_X:
			return Vector3.FORWARD
		Vector3.AXIS_Y:
			return Vector3.LEFT
		Vector3.AXIS_Z:
			return Vector3.LEFT
		_:
			return Vector3.LEFT


func _make_centered_roll_impulse(die: DiceDie3D) -> Vector3:
	if die == null:
		return Vector3.ZERO

	var from_position := die.global_position if die.is_inside_tree() else die.position
	var target_position := _get_roll_target_world_position()
	var up := get_up_direction()
	var direction := target_position - from_position
	direction -= up * direction.dot(up)
	if direction.length_squared() <= 0.000001:
		direction = _fallback_roll_direction()
	else:
		direction = direction.normalized()

	var min_impulse: float = min(die.roll_impulse_min, die.roll_impulse_max)
	var max_impulse: float = max(die.roll_impulse_min, die.roll_impulse_max)
	var strength: float = randf_range(min_impulse, max_impulse)
	return direction * strength + up * strength * roll_upward_bias


func _get_roll_target_world_position() -> Vector3:
	var floor_axis: int = _dominant_axis(get_bottom_side_normal())
	var local_target := Vector3.ZERO
	for axis in [Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Z]:
		if axis == floor_axis:
			continue
		var spread: float = min(roll_target_spread, _axis_extent(axis))
		local_target = _with_axis_value(local_target, axis, randf_range(-spread, spread))
	var box_transform := global_transform if is_inside_tree() else transform
	return box_transform * local_target


func _fallback_roll_direction() -> Vector3:
	var box_basis := global_transform.basis if is_inside_tree() else transform.basis
	var source_vector := _get_roll_source_vector()
	var up := get_up_direction()
	var fallback := box_basis * -source_vector.normalized()
	fallback -= up * fallback.dot(up)
	if fallback.length_squared() <= 0.000001:
		fallback = up.cross(Vector3.RIGHT)
	if fallback.length_squared() <= 0.000001:
		fallback = up.cross(Vector3.FORWARD)
	return fallback.normalized()


func _should_open_launch_gate(options: DiceRollOptions) -> bool:
	if roll_source == RollSource.RANDOM_INSIDE:
		return false
	if roll_source_outside_distance <= 0.0 or launch_opening_duration <= 0.0:
		return false
	if options == null or not options.reset_before_roll or not options.use_spawn_position:
		return false
	return options.spawn_position.length_squared() <= 0.000001


func _should_suspend_launch_gravity(die: DiceDie3D, options: DiceRollOptions) -> bool:
	if not suspend_gravity_until_inside:
		return false
	if die == null:
		return false
	if roll_source_outside_distance <= 0.0 and (options == null or options.spawn_position.length_squared() <= 0.000001):
		return false
	return not is_die_inside_roll_box(die, launch_entry_margin)


func _suspend_gravity_until_inside(die: DiceDie3D) -> void:
	if die == null:
		return
	var expires_at := 0.0
	if suspended_gravity_timeout > 0.0:
		expires_at = Time.get_ticks_msec() * 0.001 + suspended_gravity_timeout
	_gravity_suspended_dice[die] = expires_at


func _open_launch_gate_if_needed() -> void:
	if not is_inside_tree():
		return
	var wall_names := _get_launch_wall_names()
	if wall_names.is_empty():
		return

	_launch_gate_generation += 1
	for wall_name in wall_names:
		if not _launch_gate_open_walls.has(wall_name):
			_launch_gate_open_walls.append(wall_name)
	_set_launch_wall_collisions(wall_names, true)
	_close_launch_gate_after_delay(_launch_gate_generation)


func _close_launch_gate_after_delay(generation: int) -> void:
	await get_tree().create_timer(launch_opening_duration).timeout
	if generation != _launch_gate_generation:
		return
	_set_launch_wall_collisions(_launch_gate_open_walls, false)
	_launch_gate_open_walls.clear()


func _get_launch_wall_names() -> Array[StringName]:
	var wall_names: Array[StringName] = []
	if roll_source_outside_distance <= 0.0 or roll_source == RollSource.RANDOM_INSIDE:
		return wall_names

	var source_vector := _get_roll_source_vector()
	_append_launch_wall_for_axis(wall_names, Vector3.AXIS_X, source_vector.x)
	_append_launch_wall_for_axis(wall_names, Vector3.AXIS_Y, source_vector.y)
	_append_launch_wall_for_axis(wall_names, Vector3.AXIS_Z, source_vector.z)
	return wall_names


func _append_launch_wall_for_axis(wall_names: Array[StringName], axis: int, value: float) -> void:
	if absf(value) <= 0.000001:
		return
	var wall_name: StringName
	match axis:
		Vector3.AXIS_X:
			wall_name = &"Wall_PosX" if value > 0.0 else &"Wall_NegX"
		Vector3.AXIS_Y:
			wall_name = &"Ceiling" if value > 0.0 else &"Floor"
		Vector3.AXIS_Z:
			wall_name = &"Wall_PosZ" if value > 0.0 else &"Wall_NegZ"
		_:
			return
	if not wall_names.has(wall_name):
		wall_names.append(wall_name)


func _set_launch_wall_collisions(wall_names: Array[StringName], disabled: bool) -> void:
	_ensure_internal_nodes()
	for wall_name in wall_names:
		var wall := _environment_root.get_node_or_null(String(wall_name))
		if wall == null:
			continue
		for child in wall.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred("disabled", disabled)


func _reset_die_with_options(die: DiceDie3D, options: DiceRollOptions) -> void:
	if die == null:
		return
	_gravity_suspended_dice.erase(die)

	var target_position := die.global_position if die.is_inside_tree() else die.position
	if options.use_spawn_position:
		target_position = options.spawn_position if options.spawn_position.length_squared() > 0.000001 else _get_default_spawn_position(die)

	var target_basis := die.global_transform.basis if die.is_inside_tree() else die.transform.basis
	if options.randomize_rotation:
		target_basis = _random_basis()

	die.freeze = false
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
	if die.is_inside_tree():
		die.global_transform = Transform3D(target_basis, target_position)
	else:
		die.transform = Transform3D(target_basis, target_position)
	die.sleeping = true


func _random_basis() -> Basis:
	var quaternion := Quaternion(Vector3.RIGHT, randf() * TAU)
	quaternion *= Quaternion(Vector3.UP, randf() * TAU)
	quaternion *= Quaternion(Vector3.BACK, randf() * TAU)
	return Basis(quaternion)


func _get_top_face_info(die: DiceDie3D) -> Dictionary:
	if die == null:
		return {}

	var up := get_up_direction()
	var best_slot := die.get_default_idle_slot()
	var best_normal := Vector3.UP
	var best_dot := -INF

	for slot in die.get_face_slots():
		var die_basis := die.global_transform.basis if die.is_inside_tree() else die.transform.basis
		var world_normal := (die_basis * die.get_local_face_normal(slot)).normalized()
		var score := world_normal.dot(up)
		if score > best_dot:
			best_dot = score
			best_slot = slot
			best_normal = world_normal

	return {
		"slot": best_slot,
		"face": die.get_face(best_slot),
		"normal": best_normal,
		"score": best_dot,
	}


func _on_die_settled(die: DiceDie3D) -> void:
	if not _dice.has(die):
		return

	var info := _get_top_face_info(die)
	var flatness: float = info.get("score", 0.0)
	var reroll_count: int = _unflat_reroll_counts.get(die, 0)
	if reroll_unflat_results and flatness < flat_result_threshold and reroll_count < max_unflat_rerolls:
		reroll_count += 1
		_unflat_reroll_counts[die] = reroll_count
		unflat_reroll_requested.emit(die, flatness, reroll_count)
		_roll_die_internal(die, DiceRollOptions.defaults())
		return

	_rolling_dice.erase(die)
	var result := _make_result_from_info(die, info, reroll_count)
	_settled_results[die] = result
	roll_finished.emit(result)

	if _rolling_dice.is_empty() and not _settled_results.is_empty():
		all_dice_settled.emit(_settled_results.duplicate())


func _make_result_from_info(die: DiceDie3D, info: Dictionary, reroll_count: int = 0) -> DiceRollResult:
	var flatness: float = info.get("score", 0.0)
	return DiceRollResult.from_face(
		die,
		self,
		info.get("face", null),
		info.get("normal", Vector3.UP),
		get_gravity_vector().normalized(),
		flatness,
		flatness >= flat_result_threshold,
		reroll_count
	)


func _get_debug_material() -> StandardMaterial3D:
	if _debug_material == null:
		_debug_material = StandardMaterial3D.new()
		_debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_update_debug_materials()
	return _debug_material


func _get_debug_edge_material() -> StandardMaterial3D:
	if _debug_edge_material == null:
		_debug_edge_material = StandardMaterial3D.new()
		_debug_edge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_debug_edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_update_debug_materials()
	return _debug_edge_material


func _update_debug_materials() -> void:
	if _debug_material != null:
		_debug_material.albedo_color = Color(0.2, 0.75, 1.0, debug_surface_alpha)
	if _debug_edge_material != null:
		_debug_edge_material.albedo_color = Color(0.2, 0.75, 1.0, debug_edge_alpha)
