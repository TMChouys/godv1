extends RefCounted
## Furniture catalog plus the part lists for every model in the cottage.
## Furniture origin = footprint center on the floor, front faces +Z. One grid cell = 1 unit.

const TM := preload("res://scripts/toon_mesh.gd")

const CATALOG := {
	"bed": {"name": "小床", "w": 2, "d": 3, "layer": "solid", "color": "#F0A7A0"},
	"sofa": {"name": "沙發", "w": 2, "d": 1, "layer": "solid", "color": "#E9B25E"},
	"shelf": {"name": "書櫃", "w": 2, "d": 1, "layer": "solid", "color": "#C8935F"},
	"table": {"name": "圓桌", "w": 1, "d": 1, "layer": "solid", "color": "#E2B988"},
	"stool": {"name": "小凳", "w": 1, "d": 1, "layer": "solid", "color": "#9CCBB0"},
	"lamp": {"name": "立燈", "w": 1, "d": 1, "layer": "solid", "color": "#F5E3C3"},
	"plant": {"name": "盆栽", "w": 1, "d": 1, "layer": "solid", "color": "#7FAE6A"},
	"rug": {"name": "地毯", "w": 2, "d": 2, "layer": "rug", "color": "#8FB3D9"},
}

const DEFAULT_LAYOUT := [
	{"type": "bed", "x": 0, "z": 0, "rot": 0},
	{"type": "shelf", "x": 3, "z": 0, "rot": 0},
	{"type": "lamp", "x": 2, "z": 0, "rot": 0},
	{"type": "plant", "x": 7, "z": 0, "rot": 0},
	{"type": "rug", "x": 3, "z": 3, "rot": 0},
	{"type": "table", "x": 4, "z": 3, "rot": 0},
	{"type": "stool", "x": 3, "z": 4, "rot": 0},
]

const WOOD := "#C8935F"
const WOOD_DARK := "#946640"
const WOOD_LIGHT := "#E2B988"
const CREAM := "#F5E3C3"


static func furniture(type: String) -> Array:
	var a: Array = []
	var B := func(col: String, s: Vector3, t: Vector3, opts := {}) -> void: a.append(TM.part(col, s, t, TM.BOX, opts))
	var C := func(col: String, s: Vector3, t: Vector3, opts := {}) -> void: a.append(TM.part(col, s, t, TM.CYL, opts))
	var S := func(col: String, s: Vector3, t: Vector3, opts := {}) -> void: a.append(TM.part(col, s, t, TM.BALL, opts))
	match type:
		"bed":
			B.call(WOOD, Vector3(0.95, 0.16, 1.45), Vector3(0, 0.28, 0))
			for x in [-0.85, 0.85]:
				for z in [-1.35, 1.35]:
					B.call(WOOD_DARK, Vector3(0.08, 0.1, 0.08), Vector3(x, 0.1, z))
			B.call(CREAM, Vector3(0.9, 0.12, 1.36), Vector3(0, 0.52, 0.02))
			B.call("#F0A7A0", Vector3(0.93, 0.1, 0.92), Vector3(0, 0.6, 0.45))
			B.call("#FFFDF6", Vector3(0.6, 0.09, 0.24), Vector3(0, 0.68, -1.02))
			B.call(WOOD, Vector3(0.98, 0.55, 0.09), Vector3(0, 0.6, -1.42))
		"sofa":
			B.call("#E9B25E", Vector3(0.95, 0.2, 0.4), Vector3(0, 0.32, 0.04))
			B.call("#E9B25E", Vector3(0.95, 0.36, 0.13), Vector3(0, 0.72, -0.32))
			for sx in [-1.0, 1.0]:
				B.call("#DDA04A", Vector3(0.13, 0.28, 0.42), Vector3(0.86 * sx, 0.48, 0.02))
				B.call("#F4D08C", Vector3(0.36, 0.07, 0.32), Vector3(0.38 * sx, 0.58, 0.08))
				for z in [-0.3, 0.3]:
					B.call(WOOD_DARK, Vector3(0.06, 0.07, 0.06), Vector3(0.8 * sx, 0.07, z))
		"shelf":
			for sx in [-1.0, 1.0]:
				B.call(WOOD, Vector3(0.06, 1.0, 0.38), Vector3(0.9 * sx, 1.0, -0.05))
			B.call(WOOD_DARK, Vector3(0.86, 1.0, 0.04), Vector3(0, 1.0, -0.4))
			for y in [0.06, 0.7, 1.34, 1.96]:
				B.call(WOOD, Vector3(0.88, 0.05, 0.38), Vector3(0, y, -0.05))
			var books := ["#D9785F", "#6F9BC2", "#E6C25A", "#7FA36B", "#B784A7", "#6F9BC2", "#D9785F"]
			for row in 2:
				var yb: float = [0.75, 1.39][row]
				var x := -0.74
				for i in 6:
					var h := 0.18 + ((i * 7 + row * 3) % 5) * 0.025
					var wdt := 0.06 + ((i + row) % 3) * 0.015
					B.call(books[(i + row * 2) % books.size()], Vector3(wdt, h, 0.24), Vector3(x + wdt, yb + h, 0.0), {"out": 0.6})
					x += wdt * 2 + 0.04
			S.call("#7FAE6A", Vector3(0.16, 0.14, 0.16), Vector3(0.5, 0.25, 0.02))
		"table":
			C.call(WOOD_LIGHT, Vector3(0.44, 0.05, 0.44), Vector3(0, 0.72, 0))
			C.call(WOOD_DARK, Vector3(0.07, 0.34, 0.07), Vector3(0, 0.37, 0))
			C.call(WOOD_DARK, Vector3(0.24, 0.04, 0.24), Vector3(0, 0.04, 0))
			C.call("#FFFDF6", Vector3(0.07, 0.07, 0.07), Vector3(0.14, 0.84, 0.06), {"out": 0.6})
		"stool":
			C.call("#9CCBB0", Vector3(0.3, 0.07, 0.3), Vector3(0, 0.46, 0))
			for leg in [Vector2(0, -0.18), Vector2(0.16, 0.1), Vector2(-0.16, 0.1)]:
				C.call(WOOD, Vector3(0.04, 0.21, 0.04), Vector3(leg.x, 0.2, leg.y), {"out": 0.6})
		"lamp":
			C.call("#5B4636", Vector3(0.2, 0.04, 0.2), Vector3(0, 0.04, 0))
			C.call("#5B4636", Vector3(0.03, 0.7, 0.03), Vector3(0, 0.76, 0), {"out": 0.6})
			S.call("#FFF1C2", Vector3(0.1, 0.1, 0.1), Vector3(0, 1.34, 0), {"lit": 0.5, "out": 0.0})
			C.call(CREAM, Vector3(0.28, 0.2, 0.28), Vector3(0, 1.5, 0))
		"plant":
			C.call("#D07E5A", Vector3(0.22, 0.22, 0.22), Vector3(0, 0.22, 0))
			C.call("#D07E5A", Vector3(0.26, 0.04, 0.26), Vector3(0, 0.44, 0))
			S.call("#7FAE6A", Vector3(0.24, 0.3, 0.24), Vector3(0, 0.75, 0))
			S.call("#6A9A58", Vector3(0.18, 0.22, 0.18), Vector3(0.15, 0.62, 0.1))
			S.call("#6A9A58", Vector3(0.16, 0.2, 0.16), Vector3(-0.14, 0.66, -0.07))
		"rug":
			C.call("#8FB3D9", Vector3(0.95, 0.015, 0.92), Vector3(0, 0.016, 0), {"out": 0.4})
			C.call("#F3DDB0", Vector3(0.68, 0.018, 0.64), Vector3(0, 0.022, 0), {"out": 0.0})
			C.call("#8FB3D9", Vector3(0.36, 0.02, 0.33), Vector3(0, 0.026, 0), {"out": 0.0})
	return a


static func room() -> Array:
	var a: Array = []
	var tile := {"out": 0.0, "seg": Vector2i(8, 6)}
	var flat := TM.FLAT
	for x in 8:
		for z in 8:
			a.append(TM.part("#E5C79E" if (x + z) % 2 else "#DDBD92", Vector3(0.5, 0.05, 0.5), Vector3(-3.5 + x, -0.05, -3.5 + z), flat, tile))
	a.append(TM.part("#F3E6CF", Vector3(4.2, 1.35, 0.1), Vector3(0.1, 1.3, -4.1), flat, {"out": 0.0}))
	a.append(TM.part("#EAD9BD", Vector3(0.1, 1.35, 4.1), Vector3(-4.1, 1.3, 0), flat, {"out": 0.0}))
	a.append(TM.part(WOOD_DARK, Vector3(4.0, 0.08, 0.04), Vector3(0, 0.08, -3.98), TM.BOX, {"out": 0.5}))
	a.append(TM.part(WOOD_DARK, Vector3(0.04, 0.08, 4.0), Vector3(-3.98, 0.08, 0), TM.BOX, {"out": 0.5}))
	a.append(TM.part(WOOD_LIGHT, Vector3(0.78, 0.58, 0.04), Vector3(1.5, 1.55, -3.97), TM.BOX))
	a.append(TM.part("#BFDCEB", Vector3(0.66, 0.46, 0.03), Vector3(1.5, 1.55, -3.95), TM.BOX, {"lit": 0.0, "out": 0.0}))
	a.append(TM.part(WOOD_LIGHT, Vector3(0.03, 0.46, 0.035), Vector3(1.5, 1.55, -3.93), TM.BOX, {"out": 0.0}))
	a.append(TM.part(WOOD_LIGHT, Vector3(0.66, 0.03, 0.035), Vector3(1.5, 1.55, -3.93), TM.BOX, {"out": 0.0}))
	a.append(TM.part(WOOD_DARK, Vector3(0.04, 0.36, 0.46), Vector3(-3.97, 1.6, -0.6), TM.BOX))
	a.append(TM.part("#9CCBB0", Vector3(0.03, 0.28, 0.38), Vector3(-3.95, 1.6, -0.6), TM.BOX, {"out": 0.0}))
	return a


## The chibi groundhog, 1.8 units tall before `scale`; faces +Z, feet at y = 0.
static func groundhog(scale := 1.0) -> Array:
	var fur := "#B98A5E"
	var dark := "#83603F"
	var a: Array = []
	var add := func(col: String, s: Vector3, t: Vector3, opts := {}) -> void:
		a.append(TM.part(col, s * scale, t * scale, TM.BALL, opts))
	add.call(fur, Vector3(0.62, 0.62, 0.55), Vector3(0, 0.62, 0))
	add.call(CREAM, Vector3(0.44, 0.46, 0.34), Vector3(0, 0.55, 0.25))
	add.call(fur, Vector3(0.6, 0.52, 0.52), Vector3(0, 1.32, 0.03))
	for sx in [1.0, -1.0]:
		add.call(fur, Vector3(0.22, 0.17, 0.2), Vector3(0.28 * sx, 1.17, 0.3))
		add.call("#F3A6A0", Vector3(0.08, 0.045, 0.025), Vector3(0.37 * sx, 1.19, 0.47), {"r": Vector3(0.55 * sx, 0, 0), "lit": 0.0, "out": 0.0})
		add.call(fur, Vector3(0.13, 0.12, 0.07), Vector3(0.4 * sx, 1.7, 0.0), {"r": Vector3(0, 0, -0.4 * sx)})
		add.call("#E2A595", Vector3(0.075, 0.07, 0.04), Vector3(0.4 * sx, 1.71, 0.045), {"r": Vector3(0, 0, -0.4 * sx), "out": 0.5})
		add.call(fur, Vector3(0.12, 0.17, 0.11), Vector3(0.23 * sx, 0.86, 0.5), {"r": Vector3(0, 0, -0.6 * sx)})
		add.call(dark, Vector3(0.075, 0.065, 0.065), Vector3(0.12 * sx, 0.74, 0.58))
		add.call(dark, Vector3(0.16, 0.08, 0.2), Vector3(0.24 * sx, 0.07, 0.28), {"r": Vector3(0.25 * sx, 0, 0)})
		add.call("#FFFDF6", Vector3(0.03, 0.05, 0.02), Vector3(0.032 * sx, 1.0, 0.52), {"out": 0.6})
		# eye disc and highlight, turned slightly outward
		var turn := Vector3(0.4 * sx, 0, 0)
		var eye := Vector3(0.22 * sx, 1.38, 0.49)
		add.call("#2A1C15", Vector3(0.075, 0.09, 0.04), eye, {"r": turn, "out": 0.0})
		add.call("#FFFFFF", Vector3(0.026, 0.03, 0.012), eye + TM.rot(Vector3(-0.022, 0.03, 0.036), turn), {"r": turn, "lit": 0.0, "out": 0.0})
	add.call(CREAM, Vector3(0.27, 0.18, 0.16), Vector3(0, 1.18, 0.45))
	add.call("#5B3B2B", Vector3(0.075, 0.055, 0.05), Vector3(0, 1.27, 0.59), {"out": 0.6})
	add.call(dark, Vector3(0.17, 0.1, 0.22), Vector3(0, 0.22, -0.52), {"r": Vector3(0, 0.4, 0)})
	return a
