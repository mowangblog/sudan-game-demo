class_name DiceDieDefinition3D
extends Resource


@export_category("Dice Die Definition")
@export_group("Identity")
## Name assigned to dice spawned from this definition.
@export var display_name: String = "Die"
## Number of dice this definition spawns when the roll box builds dice from definitions.
@export_range(1, 32, 1) var count: int = 1
## Extra user data copied only into this resource for gameplay or tooling.
@export var metadata: Dictionary = {}

@export_group("Shape")
## Polyhedral shape used by dice spawned from this definition.
@export_enum("D6", "D20") var die_shape: int = DiceDie3D.DieShape.D6:
	set(value):
		die_shape = clampi(value, DiceDie3D.DieShape.D6, DiceDie3D.DieShape.D20)
## Primary size for dice spawned from this definition. For D6 this is the cube edge length; for D20 it scales the generated polyhedron.
@export var edge_length: float = 1.0:
	set(value):
		edge_length = max(value, 0.05)
## Body shape used by dice spawned from this definition.
@export_enum("Sharp", "Rounded") var body_shape: int = DiceDie3D.BodyShape.ROUNDED:
	set(value):
		body_shape = clampi(value, DiceDie3D.BodyShape.SHARP, DiceDie3D.BodyShape.ROUNDED)
## Optional full body material. When empty, a StandardMaterial3D is generated from color/roughness/specular.
@export var body_material: Material
## Color used by the generated die body material.
@export var body_color: Color = Color(1.0, 0.98, 0.92, 1.0)
## Roughness used by the generated die body material.
@export_range(0.0, 1.0, 0.01) var body_roughness: float = 0.38
## Strength of reflected light on the generated die body material.
@export_range(0.0, 1.0, 0.01) var body_specular: float = 0.45
## Strength of the glossy clearcoat layer on the generated die body material.
@export_range(0.0, 1.0, 0.01) var body_clearcoat: float = 0.22
## Roughness of the clearcoat layer. Lower values create tighter highlights.
@export_range(0.0, 1.0, 0.01) var body_clearcoat_roughness: float = 0.2
## Contact margin used by the simple box collision shape.
@export_range(0.0, 0.5, 0.001) var side_smoothing: float = 0.0
## Reserved for future collision smoothing behavior.
@export_range(1, 8, 1) var side_smoothing_segments: int = 4

@export_group("Roll Defaults")
## Minimum launch impulse copied to dice spawned from this definition.
@export var roll_impulse_min: float = 4.0
## Maximum launch impulse copied to dice spawned from this definition.
@export var roll_impulse_max: float = 8.0
## Minimum spin impulse copied to dice spawned from this definition.
@export var roll_torque_min: float = 8.0
## Maximum spin impulse copied to dice spawned from this definition.
@export var roll_torque_max: float = 16.0

@export_group("Settling")
## Linear velocity below which dice spawned from this definition may be considered settled.
@export var settle_linear_velocity: float = 0.05
## Angular velocity below which dice spawned from this definition may be considered settled.
@export var settle_angular_velocity: float = 0.05
## Time dice must remain below velocity thresholds before settling.
@export var settle_duration: float = 0.35

@export_group("Face Visuals")
## Small outward offset used to keep face art from z-fighting with the die body.
@export var face_decoration_offset: float = 0.008
## Scale applied to texture, mesh, and scene face decorations.
@export var face_decoration_scale: float = 0.72
## Face resources in this definition's shape slot order. D6 uses +Y, -Y, +Z, -Z, +X, -X.
@export var faces: Array[DiceFace3D] = []


func create_die() -> DiceDie3D:
	var die := DiceDie3D.new()
	apply_to_die(die)
	die._rebuild_die()
	return die


func apply_to_die(die: DiceDie3D) -> void:
	if die == null:
		return

	if not display_name.is_empty():
		die.name = display_name
	die.die_shape = die_shape
	die.edge_length = edge_length
	die.body_shape = body_shape
	die.body_material = body_material
	die.body_color = Color(body_color.r, body_color.g, body_color.b, 1.0)
	die.body_roughness = body_roughness
	die.body_specular = body_specular
	die.body_clearcoat = body_clearcoat
	die.body_clearcoat_roughness = body_clearcoat_roughness
	die.side_smoothing = side_smoothing
	die.side_smoothing_segments = side_smoothing_segments
	die.roll_impulse_min = roll_impulse_min
	die.roll_impulse_max = roll_impulse_max
	die.roll_torque_min = roll_torque_min
	die.roll_torque_max = roll_torque_max
	die.settle_linear_velocity = settle_linear_velocity
	die.settle_angular_velocity = settle_angular_velocity
	die.settle_duration = settle_duration
	die.face_decoration_offset = face_decoration_offset
	die.face_decoration_scale = face_decoration_scale
	if not faces.is_empty():
		die.set_faces(faces)
	if die.is_inside_tree():
		die._rebuild_die()


static func numbered_d6() -> DiceDieDefinition3D:
	var definition := DiceDieDefinition3D.new()
	definition.display_name = "NumberDie"
	definition.die_shape = DiceDie3D.DieShape.D6
	definition.faces = DiceFace3D.numbered_d6()
	return definition


static func numbered_d20() -> DiceDieDefinition3D:
	var definition := DiceDieDefinition3D.new()
	definition.display_name = "D20Die"
	definition.die_shape = DiceDie3D.DieShape.D20
	definition.body_shape = DiceDie3D.BodyShape.SHARP
	definition.faces = DiceFace3D.numbered_faces(20)
	return definition


static func custom(p_display_name: String, p_faces: Array[DiceFace3D]) -> DiceDieDefinition3D:
	var definition := DiceDieDefinition3D.new()
	definition.display_name = p_display_name
	definition.faces = p_faces
	return definition
