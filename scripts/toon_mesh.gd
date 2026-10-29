extends RefCounted
## Builds rounded "superquadric" parts into one ArrayMesh.
## Part roundness e = Vector2(vertical, horizontal): (1, 1) ball, (0.25, 0.25) soft box, (0.25, 1) cylinder.
## Vertex color alpha = lit flag (0 = flat, unlit color); UV.x = outline weight.

const BOX := Vector2(0.25, 0.25)
const CYL := Vector2(0.25, 1.0)
const BALL := Vector2(1.0, 1.0)
const FLAT := Vector2(0.0, 0.0)   # sharp box with flat faces (walls, floor tiles)
const SHARP := 0.1
const _FACES := [   # normal, u, v with u × v = normal
	[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
]


static func part(col: String, s: Vector3, t: Vector3, e := BALL, opts := {}) -> Dictionary:
	return {
		"col": Color(col), "s": s, "t": t, "e": e,
		"r": opts.get("r", Vector3.ZERO),  # (ry, rx, rz): applied z, then x, then y
		"lit": opts.get("lit", 1.0), "out": opts.get("out", 1.0),
		"seg": opts.get("seg", Vector2i.ZERO),
	}


static func rot(v: Vector3, r: Vector3) -> Vector3:
	var x := v.x
	var y := v.y
	var z := v.z
	var c := cos(r.z)
	var s := sin(r.z)
	var nx := x * c - y * s
	var ny := x * s + y * c
	x = nx
	y = ny
	c = cos(r.y)
	s = sin(r.y)
	ny = y * c - z * s
	var nz := y * s + z * c
	y = ny
	z = nz
	c = cos(r.x)
	s = sin(r.x)
	nx = x * c + z * s
	nz = -x * s + z * c
	return Vector3(nx, y, nz)


static func _sp(t: float, e: float) -> float:
	return signf(t) * pow(absf(t), e)


static func _box(p: Dictionary, linear: bool, verts: PackedVector3Array, norms: PackedVector3Array,
		cols: PackedColorArray, uvs: PackedVector2Array, idx: PackedInt32Array) -> void:
	var s: Vector3 = p.s
	var t: Vector3 = p.t
	var r: Vector3 = p.r
	var base_col: Color = p.col
	var col := base_col.srgb_to_linear() if linear else base_col
	col.a = p.lit
	for f in _FACES:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var b := verts.size()
		for corner in [-u - v, u - v, u + v, -u + v]:
			verts.append(rot((n + corner) * s, r) + t)
			norms.append(rot(n, r))
			cols.append(col)
			uvs.append(Vector2(p.out, 0.0))
		idx.append_array([b, b + 2, b + 1, b, b + 3, b + 2])


static func build(parts: Array, seg := Vector2i(20, 12)) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# Forward+ / Mobile shade in linear space; the Compatibility renderer takes sRGB colors as-is.
	var linear := RenderingServer.get_current_rendering_method() != "gl_compatibility"
	for p in parts:
		var base := verts.size()
		if p.e.x <= SHARP:
			_box(p, linear, verts, norms, cols, uvs, idx)
			continue
		var pseg: Vector2i = p.seg
		var sg: int = pseg.x if pseg.x > 0 else seg.x
		var rg: int = pseg.y if pseg.y > 0 else seg.y
		var e: Vector2 = p.e
		var n1 := 2.0 / e.x
		var n2 := 2.0 / e.y
		var s: Vector3 = p.s
		var t: Vector3 = p.t
		var r: Vector3 = p.r
		var base_col: Color = p.col
		var col := base_col.srgb_to_linear() if linear else base_col
		col.a = p.lit
		var out: float = p.out
		for i in rg + 1:
			var th := float(i) / rg * PI
			var st := sin(th)
			var ct := cos(th)
			for j in sg + 1:
				var ph := float(j) / sg * TAU
				var ux := _sp(st, e.x) * _sp(cos(ph), e.y)
				var uy := _sp(ct, e.x)
				var uz := _sp(st, e.x) * _sp(sin(ph), e.y)
				var rr := maxf(pow(absf(ux), n2) + pow(absf(uz), n2), 1e-9)
				var k := pow(rr, e.y / e.x - 1.0)
				var gx := k * pow(absf(ux), n2 - 1.0) * signf(ux)
				var gy := pow(absf(uy), n1 - 1.0) * signf(uy)
				var gz := k * pow(absf(uz), n2 - 1.0) * signf(uz)
				verts.append(rot(Vector3(ux * s.x, uy * s.y, uz * s.z), r) + t)
				var n := rot(Vector3(gx / s.x, gy / s.y, gz / s.z), r)
				norms.append(n.normalized() if n.length_squared() > 0.0 else Vector3.UP)
				cols.append(col)
				uvs.append(Vector2(out, 0.0))
		# Godot treats clockwise triangles as front faces.
		for i in rg:
			for j in sg:
				var a := base + i * (sg + 1) + j
				var b := a + sg + 1
				idx.append_array([a, b, a + 1, b, b + 1, a + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
