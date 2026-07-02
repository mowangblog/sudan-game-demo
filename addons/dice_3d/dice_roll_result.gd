class_name DiceRollResult
extends RefCounted


var die: DiceDie3D
var roll_box: DiceRollBox3D
var face: DiceFace3D
var value: int = 0
var face_id: StringName = &""
var display_name: String = ""
var asset_path: String = ""
var asset_name: String = ""
var top_normal: Vector3 = Vector3.UP
var gravity_direction: Vector3 = Vector3.DOWN
var flatness: float = 1.0
var is_flat: bool = true
var reroll_count: int = 0


static func from_face(
	p_die: DiceDie3D,
	p_roll_box: DiceRollBox3D,
	p_face: DiceFace3D,
	p_top_normal: Vector3,
	p_gravity_direction: Vector3,
	p_flatness: float = 1.0,
	p_is_flat: bool = true,
	p_reroll_count: int = 0
) -> DiceRollResult:
	var result := DiceRollResult.new()
	result.die = p_die
	result.roll_box = p_roll_box
	result.face = p_face
	result.top_normal = p_top_normal
	result.gravity_direction = p_gravity_direction
	result.flatness = p_flatness
	result.is_flat = p_is_flat
	result.reroll_count = p_reroll_count

	if p_face != null:
		result.value = p_face.value
		result.face_id = p_face.face_id
		result.display_name = p_face.display_name
		result.asset_path = p_face.get_asset_path()
		result.asset_name = p_face.get_asset_name()

	return result
