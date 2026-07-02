extends RefCounted


const DEFAULT_ROUNDED_EDGE_RADIUS := 0.10
const DEFAULT_ROUNDED_EDGE_SEGMENTS := 10
const _HALF_SIZE := 0.5
const _ROUNDING_EPSILON := 0.0001


static func make_box_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	return mesh


static func make_default_rounded_box_mesh() -> Mesh:
	return make_rounded_box_mesh(DEFAULT_ROUNDED_EDGE_RADIUS, DEFAULT_ROUNDED_EDGE_SEGMENTS)


static func make_rounded_box_mesh(edge_rounding: float, edge_rounding_segments: int) -> Mesh:
	var radius := clampf(edge_rounding, 0.0, 0.45)
	if radius <= _ROUNDING_EPSILON:
		return make_box_mesh()

	var segments := max(edge_rounding_segments, 1)
	var inner := _HALF_SIZE - radius
	var coordinate_values := _make_coordinate_values(inner, segments)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var vertex_cache := {}

	_add_projected_face(vertices, normals, uvs, indices, vertex_cache, Vector3.AXIS_X, 1.0, Vector3.AXIS_Y, Vector3.AXIS_Z, coordinate_values, inner, radius)
	_add_projected_face(vertices, normals, uvs, indices, vertex_cache, Vector3.AXIS_X, -1.0, Vector3.AXIS_Y, Vector3.AXIS_Z, coordinate_values, inner, radius)
	_add_projected_face(vertices, normals, uvs, indices, vertex_cache, Vector3.AXIS_Y, 1.0, Vector3.AXIS_X, Vector3.AXIS_Z, coordinate_values, inner, radius)
	_add_projected_face(vertices, normals, uvs, indices, vertex_cache, Vector3.AXIS_Y, -1.0, Vector3.AXIS_X, Vector3.AXIS_Z, coordinate_values, inner, radius)
	_add_projected_face(vertices, normals, uvs, indices, vertex_cache, Vector3.AXIS_Z, 1.0, Vector3.AXIS_X, Vector3.AXIS_Y, coordinate_values, inner, radius)
	_add_projected_face(vertices, normals, uvs, indices, vertex_cache, Vector3.AXIS_Z, -1.0, Vector3.AXIS_X, Vector3.AXIS_Y, coordinate_values, inner, radius)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _make_coordinate_values(inner: float, segments: int) -> PackedFloat32Array:
	var values := PackedFloat32Array()

	for index in range(segments + 1):
		values.append(lerpf(-_HALF_SIZE, -inner, float(index) / float(segments)))

	values.append(inner)

	for index in range(1, segments + 1):
		values.append(lerpf(inner, _HALF_SIZE, float(index) / float(segments)))

	return values


static func _add_projected_face(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	vertex_cache: Dictionary,
	fixed_axis: int,
	fixed_sign: float,
	u_axis: int,
	v_axis: int,
	coordinate_values: PackedFloat32Array,
	inner: float,
	radius: float
) -> void:
	var expected_normal := _axis_vector(fixed_axis, fixed_sign)
	var grid: Array = []

	for u_index in range(coordinate_values.size()):
		var row: Array[int] = []
		for v_index in range(coordinate_values.size()):
			var cube_point := Vector3.ZERO
			cube_point[fixed_axis] = fixed_sign * _HALF_SIZE
			cube_point[u_axis] = coordinate_values[u_index]
			cube_point[v_axis] = coordinate_values[v_index]
			row.append(_get_or_add_projected_vertex(vertices, normals, uvs, vertex_cache, cube_point, u_axis, v_axis, inner, radius))
		grid.append(row)

	for u_index in range(coordinate_values.size() - 1):
		for v_index in range(coordinate_values.size() - 1):
			var a: int = grid[u_index][v_index]
			var b: int = grid[u_index + 1][v_index]
			var c: int = grid[u_index + 1][v_index + 1]
			var d: int = grid[u_index][v_index + 1]
			_add_oriented_triangle(vertices, indices, a, b, c, expected_normal)
			_add_oriented_triangle(vertices, indices, a, c, d, expected_normal)


static func _get_or_add_projected_vertex(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	vertex_cache: Dictionary,
	cube_point: Vector3,
	u_axis: int,
	v_axis: int,
	inner: float,
	radius: float
) -> int:
	var key := _vertex_key(cube_point)
	if vertex_cache.has(key):
		return int(vertex_cache[key])

	var normal := _rounded_box_normal(cube_point, inner)
	var inner_point := Vector3(
		clampf(cube_point.x, -inner, inner),
		clampf(cube_point.y, -inner, inner),
		clampf(cube_point.z, -inner, inner)
	)
	var index := vertices.size()
	vertex_cache[key] = index
	vertices.append(inner_point + normal * radius)
	normals.append(normal)
	uvs.append(Vector2(cube_point[u_axis] + _HALF_SIZE, cube_point[v_axis] + _HALF_SIZE))
	return index


static func _rounded_box_normal(cube_point: Vector3, inner: float) -> Vector3:
	var inner_point := Vector3(
		clampf(cube_point.x, -inner, inner),
		clampf(cube_point.y, -inner, inner),
		clampf(cube_point.z, -inner, inner)
	)
	var offset := cube_point - inner_point
	if offset.length_squared() <= 0.000001:
		return cube_point.normalized()
	return offset.normalized()


static func _vertex_key(point: Vector3) -> String:
	return "%.5f,%.5f,%.5f" % [point.x, point.y, point.z]


static func _axis_vector(axis: int, sign: float) -> Vector3:
	var vector := Vector3.ZERO
	vector[axis] = sign
	return vector


static func _add_oriented_triangle(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	a: int,
	b: int,
	c: int,
	expected_normal: Vector3
) -> void:
	var actual_normal := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
	if actual_normal.dot(expected_normal) >= 0.0:
		indices.append(a)
		indices.append(c)
		indices.append(b)
	else:
		indices.append(a)
		indices.append(b)
		indices.append(c)
