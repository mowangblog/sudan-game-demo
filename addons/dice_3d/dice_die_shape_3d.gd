class_name DiceDieShape3D
extends RefCounted


enum ShapeType {
	D6,
	D20,
}

enum BodyStyle {
	SHARP,
	ROUNDED,
}

const SLOT_POS_Y: StringName = &"+Y"
const SLOT_NEG_Y: StringName = &"-Y"
const SLOT_POS_Z: StringName = &"+Z"
const SLOT_NEG_Z: StringName = &"-Z"
const SLOT_POS_X: StringName = &"+X"
const SLOT_NEG_X: StringName = &"-X"

const D6_FACE_SLOTS: Array[StringName] = [
	SLOT_POS_Y,
	SLOT_NEG_Y,
	SLOT_POS_Z,
	SLOT_NEG_Z,
	SLOT_POS_X,
	SLOT_NEG_X,
]

const D6_FACE_NORMALS := {
	SLOT_POS_Y: Vector3.UP,
	SLOT_NEG_Y: Vector3.DOWN,
	SLOT_POS_Z: Vector3.BACK,
	SLOT_NEG_Z: Vector3.FORWARD,
	SLOT_POS_X: Vector3.RIGHT,
	SLOT_NEG_X: Vector3.LEFT,
}

const D20_FACE_SLOTS: Array[StringName] = [
	&"F1",
	&"F2",
	&"F3",
	&"F4",
	&"F5",
	&"F6",
	&"F7",
	&"F8",
	&"F9",
	&"F10",
	&"F11",
	&"F12",
	&"F13",
	&"F14",
	&"F15",
	&"F16",
	&"F17",
	&"F18",
	&"F19",
	&"F20",
]

const DEFAULT_ROUNDED_D6_MESH: Mesh = preload("res://addons/dice_3d/assets/meshes/d6_rounded.tres")
const _ICO_SHORT := 0.2628655561
const _ICO_LONG := 0.4253254042


static func get_face_slots(shape_type: int) -> Array[StringName]:
	match shape_type:
		ShapeType.D6:
			return D6_FACE_SLOTS.duplicate()
		ShapeType.D20:
			return D20_FACE_SLOTS.duplicate()
		_:
			return D6_FACE_SLOTS.duplicate()


static func get_face_count(shape_type: int) -> int:
	return get_face_slots(shape_type).size()


static func has_face_slot(shape_type: int, slot: StringName) -> bool:
	return get_face_slots(shape_type).has(slot)


static func get_face_normal(shape_type: int, slot: StringName) -> Vector3:
	match shape_type:
		ShapeType.D6:
			return D6_FACE_NORMALS.get(slot, Vector3.UP)
		ShapeType.D20:
			return _get_poly_face_normal(shape_type, slot)
		_:
			return D6_FACE_NORMALS.get(slot, Vector3.UP)


static func get_face_center(shape_type: int, slot: StringName) -> Vector3:
	match shape_type:
		ShapeType.D6:
			return get_face_normal(shape_type, slot) * 0.5
		ShapeType.D20:
			return _get_poly_face_center(shape_type, slot)
		_:
			return get_face_normal(shape_type, slot) * 0.5


static func get_default_faces(shape_type: int) -> Array[DiceFace3D]:
	match shape_type:
		ShapeType.D6:
			return DiceFace3D.numbered_d6()
		ShapeType.D20:
			return DiceFace3D.numbered_faces(20)
		_:
			return DiceFace3D.numbered_d6()


static func get_default_idle_slot(shape_type: int) -> StringName:
	match shape_type:
		ShapeType.D6:
			return SLOT_NEG_Z
		ShapeType.D20:
			return D20_FACE_SLOTS[0]
		_:
			return SLOT_NEG_Z


static func make_body_mesh(shape_type: int, body_style: int) -> Mesh:
	match shape_type:
		ShapeType.D6:
			if body_style == BodyStyle.ROUNDED:
				return DEFAULT_ROUNDED_D6_MESH
			var mesh := BoxMesh.new()
			mesh.size = Vector3.ONE
			return mesh
		ShapeType.D20:
			return _make_poly_mesh(shape_type)
		_:
			var mesh := BoxMesh.new()
			mesh.size = Vector3.ONE
			return mesh


static func make_collision_shape(shape_type: int, size: float, smoothing_radius: float) -> Shape3D:
	match shape_type:
		ShapeType.D6:
			var shape := BoxShape3D.new()
			shape.size = Vector3.ONE * size
			shape.margin = min(smoothing_radius, size * 0.25)
			return shape
		ShapeType.D20:
			var shape := ConvexPolygonShape3D.new()
			var points := PackedVector3Array()
			for vertex in _get_poly_vertices(shape_type):
				points.append(vertex * size)
			shape.points = points
			return shape
		_:
			var shape := BoxShape3D.new()
			shape.size = Vector3.ONE * size
			shape.margin = min(smoothing_radius, size * 0.25)
			return shape


static func make_face_transform(shape_type: int, slot: StringName, size: float, outward_offset: float) -> Transform3D:
	if shape_type == ShapeType.D20:
		return _make_poly_face_anchor_transform(shape_type, slot, size, outward_offset)
	var normal := get_face_normal(shape_type, slot)
	var center := get_face_center(shape_type, slot) * size
	return _make_normal_anchor_transform(normal, center + normal * outward_offset)


static func _make_normal_anchor_transform(normal: Vector3, origin: Vector3) -> Transform3D:
	var z_axis := normal.normalized()
	var reference_up := Vector3.UP
	if absf(z_axis.dot(reference_up)) > 0.95:
		reference_up = Vector3.FORWARD
	var x_axis := reference_up.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Transform3D(Basis(x_axis, y_axis, z_axis), origin)


static func _make_poly_face_anchor_transform(shape_type: int, slot: StringName, size: float, outward_offset: float) -> Transform3D:
	var vertices := _get_poly_vertices(shape_type)
	var face := _get_oriented_poly_face(shape_type, slot)
	if vertices.is_empty() or face.is_empty():
		return _make_normal_anchor_transform(get_face_normal(shape_type, slot), get_face_center(shape_type, slot) * size)

	var a: Vector3 = vertices[int(face[0])]
	var b: Vector3 = vertices[int(face[1])]
	var c: Vector3 = vertices[int(face[2])]
	var center := (a + b + c) / 3.0
	var z_axis := (b - a).cross(c - a).normalized()
	var reference_up := Vector3.UP - z_axis * Vector3.UP.dot(z_axis)
	if reference_up.length_squared() <= 0.0001:
		reference_up = Vector3.FORWARD - z_axis * Vector3.FORWARD.dot(z_axis)
	reference_up = reference_up.normalized()

	var face_vertices := [a, b, c]
	var apex: Vector3 = face_vertices[0]
	var best_score := -INF
	for vertex in face_vertices:
		var score: float = (vertex - center).normalized().dot(reference_up)
		if score > best_score:
			best_score = score
			apex = vertex

	var y_axis := (apex - center).normalized()
	var x_axis := y_axis.cross(z_axis).normalized()
	return Transform3D(Basis(x_axis, y_axis, z_axis), center * size + z_axis * outward_offset)


static func _get_poly_vertices(shape_type: int) -> Array[Vector3]:
	match shape_type:
		ShapeType.D20:
			return [
				Vector3(-_ICO_SHORT, _ICO_LONG, 0.0),
				Vector3(_ICO_SHORT, _ICO_LONG, 0.0),
				Vector3(-_ICO_SHORT, -_ICO_LONG, 0.0),
				Vector3(_ICO_SHORT, -_ICO_LONG, 0.0),
				Vector3(0.0, -_ICO_SHORT, _ICO_LONG),
				Vector3(0.0, _ICO_SHORT, _ICO_LONG),
				Vector3(0.0, -_ICO_SHORT, -_ICO_LONG),
				Vector3(0.0, _ICO_SHORT, -_ICO_LONG),
				Vector3(_ICO_LONG, 0.0, -_ICO_SHORT),
				Vector3(_ICO_LONG, 0.0, _ICO_SHORT),
				Vector3(-_ICO_LONG, 0.0, -_ICO_SHORT),
				Vector3(-_ICO_LONG, 0.0, _ICO_SHORT),
			]
		_:
			return []


static func _get_poly_faces(shape_type: int) -> Array[Array]:
	match shape_type:
		ShapeType.D20:
			return [
				[0, 11, 5],
				[0, 5, 1],
				[0, 1, 7],
				[0, 7, 10],
				[0, 10, 11],
				[1, 5, 9],
				[5, 11, 4],
				[11, 10, 2],
				[10, 7, 6],
				[7, 1, 8],
				[3, 9, 4],
				[3, 4, 2],
				[3, 2, 6],
				[3, 6, 8],
				[3, 8, 9],
				[4, 9, 5],
				[2, 4, 11],
				[6, 2, 10],
				[8, 6, 7],
				[9, 8, 1],
			]
		_:
			return []


static func _get_poly_face_index(shape_type: int, slot: StringName) -> int:
	var slots := get_face_slots(shape_type)
	var index := slots.find(slot)
	return max(index, 0)


static func _get_oriented_poly_face(shape_type: int, slot: StringName) -> Array:
	var vertices := _get_poly_vertices(shape_type)
	var faces := _get_poly_faces(shape_type)
	if vertices.is_empty() or faces.is_empty():
		return []

	var face: Array = faces[_get_poly_face_index(shape_type, slot)].duplicate()
	var a: Vector3 = vertices[int(face[0])]
	var b: Vector3 = vertices[int(face[1])]
	var c: Vector3 = vertices[int(face[2])]
	var center := (a + b + c) / 3.0
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot(center) < 0.0:
		var swap: int = int(face[1])
		face[1] = face[2]
		face[2] = swap
	return face


static func _get_poly_face_center(shape_type: int, slot: StringName) -> Vector3:
	var vertices := _get_poly_vertices(shape_type)
	var face := _get_oriented_poly_face(shape_type, slot)
	if vertices.is_empty() or face.is_empty():
		return Vector3.ZERO
	return (
		vertices[int(face[0])]
		+ vertices[int(face[1])]
		+ vertices[int(face[2])]
	) / 3.0


static func _get_poly_face_normal(shape_type: int, slot: StringName) -> Vector3:
	var vertices := _get_poly_vertices(shape_type)
	var face := _get_oriented_poly_face(shape_type, slot)
	if vertices.is_empty() or face.is_empty():
		return Vector3.UP
	var a: Vector3 = vertices[int(face[0])]
	var b: Vector3 = vertices[int(face[1])]
	var c: Vector3 = vertices[int(face[2])]
	return (b - a).cross(c - a).normalized()


static func _make_poly_mesh(shape_type: int) -> ArrayMesh:
	var vertices := _get_poly_vertices(shape_type)
	var faces := _get_poly_faces(shape_type)
	var mesh_vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()

	for index in range(faces.size()):
		var slot := get_face_slots(shape_type)[index]
		var face := _get_oriented_poly_face(shape_type, slot)
		var normal := _get_poly_face_normal(shape_type, slot)
		var center := _get_poly_face_center(shape_type, slot)
		var basis := _make_face_uv_basis(normal)
		for face_index in [face[0], face[2], face[1]]:
			var vertex: Vector3 = vertices[int(face_index)]
			mesh_vertices.append(vertex)
			normals.append(normal)
			var relative := vertex - center
			uvs.append(Vector2(relative.dot(basis.x), relative.dot(basis.y)) + Vector2(0.5, 0.5))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mesh_vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _make_face_uv_basis(normal: Vector3) -> Basis:
	var z_axis := normal.normalized()
	var reference_up := Vector3.UP
	if absf(z_axis.dot(reference_up)) > 0.95:
		reference_up = Vector3.FORWARD
	var x_axis := reference_up.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)
