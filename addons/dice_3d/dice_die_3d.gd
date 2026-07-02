class_name DiceDie3D
extends RigidBody3D


signal roll_started(die: DiceDie3D)
signal settled(die: DiceDie3D)

const SLOT_POS_Y: StringName = &"+Y"
const SLOT_NEG_Y: StringName = &"-Y"
const SLOT_POS_Z: StringName = &"+Z"
const SLOT_NEG_Z: StringName = &"-Z"
const SLOT_POS_X: StringName = &"+X"
const SLOT_NEG_X: StringName = &"-X"

const FACE_SLOTS: Array[StringName] = DiceDieShape3D.D6_FACE_SLOTS
const FACE_NORMALS := DiceDieShape3D.D6_FACE_NORMALS

const _VISUAL_NAME := "_DiceVisual"
const _COLLISION_NAME := "_DiceCollision"
const _FACE_ROOT_NAME := "_DiceFaces"
const _GENERATED_LABEL_FONT_SIZE := 96
const _GENERATED_LABEL_HEIGHT_RATIO := 0.44
const _GENERATED_D20_LABEL_HEIGHT_RATIO := 0.3
const _GENERATED_LABEL_OUTLINE_SIZE := 8
const _GENERATED_D20_LABEL_OUTLINE_SIZE := 5
const DEFAULT_ROUNDED_BODY_MESH: Mesh = DiceDieShape3D.DEFAULT_ROUNDED_D6_MESH

enum DieShape {
	D6,
	D20,
}

enum BodyShape {
	SHARP,
	ROUNDED,
}

@export_category("Dice Die")
@export_group("Shape")
## Polyhedral die shape used for body geometry, face slots, face anchors, and result normals.
@export_enum("D6", "D20") var die_shape: int = DieShape.D6:
	set(value):
		die_shape = clampi(value, DieShape.D6, DieShape.D20)
		_fill_missing_faces()
		if is_inside_tree():
			_rebuild_die()
## Primary die size in 3D units. For D6 this is the cube edge length; for D20 it scales the generated polyhedron.
@export var edge_length: float = 1.0:
	set(value):
		edge_length = max(value, 0.05)
		if is_inside_tree():
			_rebuild_die()
## Generated body shape used for the visible die body.
@export_enum("Sharp", "Rounded") var body_shape: int = BodyShape.SHARP:
	set(value):
		body_shape = clampi(value, BodyShape.SHARP, BodyShape.ROUNDED)
		if is_inside_tree():
			_rebuild_die()
## Optional material used for the visible die body. When empty, a StandardMaterial3D is generated from the color/roughness/specular settings.
@export var body_material: Material:
	set(value):
		body_material = value
		if is_inside_tree():
			_apply_visual_material()
## Color used for the generated die body mesh.
@export var body_color: Color = Color(1.0, 0.98, 0.92, 1.0):
	set(value):
		body_color = value
		if is_inside_tree():
			_apply_visual_material()
## Roughness of the generated die body material. Lower values create sharper light reflections.
@export_range(0.0, 1.0, 0.01) var body_roughness: float = 0.38:
	set(value):
		body_roughness = clampf(value, 0.0, 1.0)
		if is_inside_tree():
			_apply_visual_material()
## Strength of reflected light on the generated die body material.
@export_range(0.0, 1.0, 0.01) var body_specular: float = 0.45:
	set(value):
		body_specular = clampf(value, 0.0, 1.0)
		if is_inside_tree():
			_apply_visual_material()
## Strength of the generated die body's glossy clearcoat layer.
@export_range(0.0, 1.0, 0.01) var body_clearcoat: float = 0.22:
	set(value):
		body_clearcoat = clampf(value, 0.0, 1.0)
		if is_inside_tree():
			_apply_visual_material()
## Roughness of the clearcoat layer. Lower values create tighter highlights.
@export_range(0.0, 1.0, 0.01) var body_clearcoat_roughness: float = 0.2:
	set(value):
		body_clearcoat_roughness = clampf(value, 0.0, 1.0)
		if is_inside_tree():
			_apply_visual_material()

@export_group("Roll")
## Minimum launch impulse used by standalone die rolls.
@export var roll_impulse_min: float = 4.0
## Maximum launch impulse used by standalone die rolls.
@export var roll_impulse_max: float = 8.0
## Minimum spin impulse used by standalone die rolls.
@export var roll_torque_min: float = 8.0
## Maximum spin impulse used by standalone die rolls.
@export var roll_torque_max: float = 16.0

@export_group("Settling")
## Linear velocity below which the die may be considered settled.
@export var settle_linear_velocity: float = 0.05
## Angular velocity below which the die may be considered settled.
@export var settle_angular_velocity: float = 0.05
## Time the die must remain below velocity thresholds before settling.
@export var settle_duration: float = 0.35

@export_group("Smoothing")
## Contact margin used by the simple box collision shape. This does not change the visible body.
@export_range(0.0, 0.5, 0.001) var side_smoothing: float = 0.0:
	set(value):
		side_smoothing = max(value, 0.0)
		if is_inside_tree():
			_rebuild_die()
## Reserved for future collision smoothing behavior.
@export_range(1, 8, 1) var side_smoothing_segments: int = 4:
	set(value):
		side_smoothing_segments = max(value, 1)
		if is_inside_tree():
			_rebuild_die()

@export_group("Faces")
## Small outward offset used to keep face art from z-fighting with the die body.
@export var face_decoration_offset: float = 0.008:
	set(value):
		face_decoration_offset = max(value, 0.0)
		if is_inside_tree():
			_rebuild_face_visuals()
## Scale multiplier for texture quads, meshes, and scenes attached to each die face.
@export var face_decoration_scale: float = 0.72:
	set(value):
		face_decoration_scale = max(value, 0.05)
		if is_inside_tree():
			_rebuild_face_visuals()

var _faces: Dictionary = {}
var _roll_box: DiceRollBox3D
var _rolling := false
var _settle_elapsed := 0.0
var _face_root: Node3D


static func get_face_normal(slot: StringName) -> Vector3:
	return DiceDieShape3D.get_face_normal(DieShape.D6, slot)


func _ready() -> void:
	if _faces.is_empty():
		_fill_missing_faces()
	_rebuild_die()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _roll_box != null and not sleeping and _roll_box.should_apply_gravity_to_die(self):
		apply_central_force(_roll_box.get_gravity_vector() * mass)

	if not _rolling:
		return

	var linear_ok := linear_velocity.length() <= settle_linear_velocity
	var angular_ok := angular_velocity.length() <= settle_angular_velocity
	if linear_ok and angular_ok:
		_settle_elapsed += delta
		if _settle_elapsed >= settle_duration:
			_rolling = false
			sleeping = true
			settled.emit(self)
	else:
		_settle_elapsed = 0.0


func set_faces(faces: Array) -> void:
	_faces.clear()
	var slots := get_face_slots()
	for index in min(faces.size(), slots.size()):
		var face := faces[index] as DiceFace3D
		if face != null:
			_faces[slots[index]] = face
	_fill_missing_faces()
	if is_inside_tree():
		_rebuild_face_visuals()


func set_faces_by_slot(slot_faces: Dictionary) -> void:
	for slot in slot_faces:
		set_face(slot, slot_faces[slot])


func set_face(slot: Variant, face: DiceFace3D) -> void:
	var slot_name := _slot_from_variant(slot)
	if not has_face_slot(slot_name):
		push_warning("Unknown dice face slot: %s" % slot_name)
		return
	_faces[slot_name] = face
	if is_inside_tree():
		_rebuild_face_visuals()


func get_face(slot: Variant) -> DiceFace3D:
	return _faces.get(_slot_from_variant(slot), null)


func get_face_slots() -> Array[StringName]:
	return DiceDieShape3D.get_face_slots(die_shape)


func get_face_count() -> int:
	return DiceDieShape3D.get_face_count(die_shape)


func has_face_slot(slot: StringName) -> bool:
	return DiceDieShape3D.has_face_slot(die_shape, slot)


func get_local_face_normal(slot: StringName) -> Vector3:
	return DiceDieShape3D.get_face_normal(die_shape, slot)


func get_default_idle_slot() -> StringName:
	return DiceDieShape3D.get_default_idle_slot(die_shape)


func roll(options: DiceRollOptions = null) -> void:
	if _roll_box != null:
		_roll_box.roll(self, options)
		return
	_start_roll(options, null)


func is_rolling() -> bool:
	return _rolling


func is_settled() -> bool:
	return not _rolling


func _set_roll_box(roll_box: DiceRollBox3D) -> void:
	_roll_box = roll_box
	gravity_scale = 0.0 if roll_box != null else 1.0


func _start_roll(options: DiceRollOptions = null, source_box: DiceRollBox3D = null) -> void:
	var active_options := options if options != null else DiceRollOptions.defaults()
	var active_box := source_box if source_box != null else _roll_box
	_roll_box = active_box

	sleeping = false
	freeze = false
	_rolling = true
	_settle_elapsed = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	var roll_impulse := active_options.impulse
	if roll_impulse.length_squared() <= 0.000001:
		roll_impulse = _random_roll_impulse(active_box)

	var roll_torque := active_options.torque
	if roll_torque.length_squared() <= 0.000001:
		roll_torque = _random_spin_torque()

	if is_inside_tree():
		apply_central_impulse(roll_impulse)
		apply_torque_impulse(roll_torque)
	else:
		linear_velocity = roll_impulse / max(mass, 0.001)
		angular_velocity = roll_torque
	roll_started.emit(self)


func _fill_missing_faces() -> void:
	var defaults := DiceDieShape3D.get_default_faces(die_shape)
	var slots := get_face_slots()
	for index in slots.size():
		var slot := slots[index]
		if index < defaults.size() and (not _faces.has(slot) or _faces[slot] == null):
			_faces[slot] = defaults[index]


func _slot_from_variant(slot: Variant) -> StringName:
	if typeof(slot) == TYPE_INT:
		var index := int(slot)
		var slots := get_face_slots()
		if index >= 0 and index < slots.size():
			return slots[index]
	return StringName(str(slot))


func _random_roll_impulse(active_box: DiceRollBox3D) -> Vector3:
	var up := Vector3.UP
	if active_box != null:
		up = active_box.get_up_direction()
	var side := _random_perpendicular(up)
	var upward_strength := randf_range(roll_impulse_min, roll_impulse_max)
	var side_strength := randf_range(roll_impulse_min * 0.25, roll_impulse_max * 0.5)
	return up * upward_strength + side * side_strength


func _random_perpendicular(axis: Vector3) -> Vector3:
	var safe_axis := axis.normalized()
	if safe_axis.length_squared() <= 0.000001:
		safe_axis = Vector3.UP
	var candidate := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)
	var perpendicular := candidate - safe_axis * candidate.dot(safe_axis)
	if perpendicular.length_squared() <= 0.000001:
		perpendicular = safe_axis.cross(Vector3.RIGHT)
		if perpendicular.length_squared() <= 0.000001:
			perpendicular = safe_axis.cross(Vector3.FORWARD)
	return perpendicular.normalized()


func _random_spin_torque() -> Vector3:
	var axis := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)
	if axis.length_squared() <= 0.000001:
		axis = Vector3.UP
	var min_spin := min(roll_torque_min, roll_torque_max)
	var max_spin := max(roll_torque_min, roll_torque_max)
	return axis.normalized() * randf_range(min_spin, max_spin)


func _rebuild_die() -> void:
	_ensure_visual()
	_ensure_collision()
	_ensure_face_root()
	_rebuild_face_visuals()


func _ensure_visual() -> void:
	var visual := get_node_or_null(_VISUAL_NAME) as MeshInstance3D
	if visual == null:
		visual = MeshInstance3D.new()
		visual.name = _VISUAL_NAME
		add_child(visual)

	visual.mesh = _make_die_mesh()
	visual.scale = Vector3.ONE * edge_length
	visual.material_override = _make_base_material()


func _apply_visual_material() -> void:
	var visual := get_node_or_null(_VISUAL_NAME) as MeshInstance3D
	if visual != null:
		visual.material_override = _make_base_material()


func _ensure_collision() -> void:
	var collision := get_node_or_null(_COLLISION_NAME) as CollisionShape3D
	if collision == null:
		collision = CollisionShape3D.new()
		collision.name = _COLLISION_NAME
		add_child(collision)

	collision.shape = DiceDieShape3D.make_collision_shape(die_shape, edge_length, _get_smoothing_radius())


func _ensure_face_root() -> void:
	_face_root = get_node_or_null(_FACE_ROOT_NAME) as Node3D
	if _face_root == null:
		_face_root = Node3D.new()
		_face_root.name = _FACE_ROOT_NAME
		add_child(_face_root)


func _rebuild_face_visuals() -> void:
	_ensure_face_root()
	for child in _face_root.get_children():
		_face_root.remove_child(child)
		child.free()

	for slot in get_face_slots():
		var face := get_face(slot)
		if face == null:
			continue
		var anchor := Node3D.new()
		anchor.name = "Face_%s" % str(slot).replace("+", "Pos").replace("-", "Neg")
		anchor.transform = DiceDieShape3D.make_face_transform(die_shape, slot, edge_length, face_decoration_offset)
		_face_root.add_child(anchor)
		_add_face_content(anchor, face)


func _add_face_content(anchor: Node3D, face: DiceFace3D) -> void:
	if face.texture != null or face.material != null:
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE * edge_length * face_decoration_scale
		quad.mesh = mesh
		quad.material_override = _make_face_material(face)
		anchor.add_child(quad)

	if face.decoration_mesh != null:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = face.decoration_mesh
		mesh_instance.scale = Vector3.ONE * face_decoration_scale
		anchor.add_child(mesh_instance)

	if face.decoration_scene != null:
		var scene_instance := face.decoration_scene.instantiate()
		anchor.add_child(scene_instance)
		if scene_instance is Node3D:
			(scene_instance as Node3D).scale = Vector3.ONE * face_decoration_scale

	if face.texture == null and face.material == null and face.decoration_mesh == null and face.decoration_scene == null:
		_add_generated_face_label(anchor, face)


func _add_generated_face_label(anchor: Node3D, face: DiceFace3D) -> void:
	var label := Label3D.new()
	label.text = str(face.value)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.font_size = _GENERATED_LABEL_FONT_SIZE
	label.pixel_size = edge_length * face_decoration_scale * _get_generated_label_height_ratio() / float(_GENERATED_LABEL_FONT_SIZE)
	label.modulate = _get_generated_label_color()
	label.outline_modulate = _get_generated_label_outline_color()
	label.outline_size = _get_generated_label_outline_size()
	anchor.add_child(label)


func _get_generated_label_height_ratio() -> float:
	if die_shape == DieShape.D20:
		return _GENERATED_D20_LABEL_HEIGHT_RATIO
	return _GENERATED_LABEL_HEIGHT_RATIO


func _get_generated_label_outline_size() -> int:
	if die_shape == DieShape.D20:
		return _GENERATED_D20_LABEL_OUTLINE_SIZE
	return _GENERATED_LABEL_OUTLINE_SIZE


func _get_generated_label_color() -> Color:
	if die_shape == DieShape.D20:
		return Color(0.92, 0.84, 0.62, 1.0)
	return Color(0.04, 0.04, 0.04, 1.0)


func _get_generated_label_outline_color() -> Color:
	if die_shape == DieShape.D20:
		return Color(0.02, 0.018, 0.014, 0.86)
	return Color(1.0, 0.96, 0.84, 0.72)


func _make_base_material() -> Material:
	if body_material != null:
		return body_material

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(body_color.r, body_color.g, body_color.b, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.roughness = body_roughness
	material.metallic = 0.0
	material.metallic_specular = body_specular
	material.clearcoat_enabled = body_clearcoat > 0.001
	material.clearcoat = body_clearcoat
	material.clearcoat_roughness = body_clearcoat_roughness
	return material


func _make_die_mesh() -> Mesh:
	return DiceDieShape3D.make_body_mesh(die_shape, body_shape)


func _get_smoothing_radius() -> float:
	return min(side_smoothing, edge_length * 0.45)


func _make_face_material(face: DiceFace3D) -> Material:
	if face.material != null:
		return face.material

	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = face.texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.42
	material.metallic_specular = 0.2
	return material
