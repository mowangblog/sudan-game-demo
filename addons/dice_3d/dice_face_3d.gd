class_name DiceFace3D
extends Resource


@export_category("Dice Face")
## Numeric value returned when this face is the roll result.
@export var value: int = 0
## Stable gameplay identifier returned in DiceRollResult.face_id.
@export var face_id: StringName = &""
## Human-readable label returned in DiceRollResult.display_name.
@export var display_name: String = ""
## Optional image drawn as a flat face decoration.
@export var texture: Texture2D
## Optional material used for the face decoration. Overrides the generated texture material.
@export var material: Material
## Optional mesh attached to this face as a visual decoration.
@export var decoration_mesh: Mesh
## Optional scene instantiated on this face as a visual decoration.
@export var decoration_scene: PackedScene
## Free-form data copied with this face definition for game-specific use.
@export var metadata: Dictionary = {}


static func new_face(
	p_value: int,
	p_face_id: StringName,
	p_texture: Texture2D = null,
	p_display_name: String = "",
	p_material: Material = null,
	p_decoration_mesh: Mesh = null,
	p_decoration_scene: PackedScene = null,
	p_metadata: Dictionary = {}
) -> DiceFace3D:
	var face := DiceFace3D.new()
	face.value = p_value
	face.face_id = p_face_id
	face.display_name = p_display_name if not p_display_name.is_empty() else str(p_face_id)
	face.texture = p_texture
	face.material = p_material
	face.decoration_mesh = p_decoration_mesh
	face.decoration_scene = p_decoration_scene
	face.metadata = p_metadata.duplicate(true)
	return face


static func numbered_d6() -> Array[DiceFace3D]:
	return [
		DiceFace3D.new_face(1, &"one", null, "One"),
		DiceFace3D.new_face(6, &"six", null, "Six"),
		DiceFace3D.new_face(2, &"two", null, "Two"),
		DiceFace3D.new_face(5, &"five", null, "Five"),
		DiceFace3D.new_face(3, &"three", null, "Three"),
		DiceFace3D.new_face(4, &"four", null, "Four"),
	]


static func numbered_faces(count: int) -> Array[DiceFace3D]:
	var faces: Array[DiceFace3D] = []
	for value in range(1, count + 1):
		faces.append(DiceFace3D.new_face(value, StringName(str(value)), null, _number_display_name(value)))
	return faces


static func _number_display_name(value: int) -> String:
	var names := {
		1: "One",
		2: "Two",
		3: "Three",
		4: "Four",
		5: "Five",
		6: "Six",
		7: "Seven",
		8: "Eight",
		9: "Nine",
		10: "Ten",
		11: "Eleven",
		12: "Twelve",
		13: "Thirteen",
		14: "Fourteen",
		15: "Fifteen",
		16: "Sixteen",
		17: "Seventeen",
		18: "Eighteen",
		19: "Nineteen",
		20: "Twenty",
	}
	return names.get(value, str(value))


func get_asset_path() -> String:
	if texture != null and not texture.resource_path.is_empty():
		return texture.resource_path
	if material != null and not material.resource_path.is_empty():
		return material.resource_path
	if decoration_mesh != null and not decoration_mesh.resource_path.is_empty():
		return decoration_mesh.resource_path
	if decoration_scene != null and not decoration_scene.resource_path.is_empty():
		return decoration_scene.resource_path
	return ""


func get_asset_name() -> String:
	var path := get_asset_path()
	if path.is_empty():
		return ""
	return path.get_file().get_basename()
