extends Node3D
## Cottage decorating prototype: grid placement, pick up / rotate / stash, and a groundhog that walks around.

const Models := preload("res://scripts/models.gd")
const TM := preload("res://scripts/toon_mesh.gd")
const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")

const GRID := 8
const SAVE_PATH := "user://room.json"
const GHOST_OK := Color(0.45, 0.78, 0.5, 0.5)
const GHOST_BAD := Color(0.9, 0.35, 0.32, 0.5)
const GROUNDHOG_SCALE := 0.46

var material: ShaderMaterial
var meshes := {}
var camera: Camera3D
var cam_yaw := 0.75
var cam_pitch := 0.78
var cam_dist := 18.0
var cam_attr: CameraAttributesPractical

var items: Array = []        # {type, cell: Vector2i, rot, node}
var carried = null           # the piece in hand, same shape as an item
var carried_from = null      # where it was picked up, for cancel
var astar := AStarGrid2D.new()
var path: Array[Vector2i] = []

var groundhog: MeshInstance3D
var gh_idle := 0.0
var gh_walk := 0.0
var footprint: MeshInstance3D
var footprint_mat: StandardMaterial3D

var status_label: Label
var count_label: Label
var catalog_buttons := {}
var press_pos = null
var press_cam := Vector2.ZERO
var dragging := false
var debug_hover = null       # fixed floor point for screenshots


func _ready() -> void:
	_setup_input()
	_setup_material()
	_setup_world()
	_setup_ui()
	astar.region = Rect2i(0, 0, GRID, GRID)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	_load_room()
	say("點家具拿起來，或從右邊選一件新的。")
	_debug_args()


# ---------- setup ----------
func _setup_input() -> void:
	for pair in [["rotate_item", KEY_R], ["stash_item", KEY_DELETE]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var ev := InputEventKey.new()
			ev.physical_keycode = pair[1]
			InputMap.action_add_event(pair[0], ev)


func _setup_material() -> void:
	material = ShaderMaterial.new()
	material.shader = TOON
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	material.next_pass = outline


func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#F4EADA")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# contact shading where furniture meets the floor (Forward+ only)
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 1.8
	env.ssao_light_affect = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3(0.45, 1.0, 0.7) * 10.0, Vector3.ZERO)
	sun.light_color = Color("#FFF4E2")
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 40.0

	# warm pool of light falling in from the window
	var window_light := SpotLight3D.new()
	add_child(window_light)
	window_light.look_at_from_position(Vector3(1.5, 2.7, -3.7), Vector3(2.3, 0, -0.9))
	window_light.light_color = Color("#FFD59A")
	window_light.light_energy = 1.2
	window_light.spot_range = 6.0
	window_light.spot_angle = 30.0
	window_light.spot_attenuation = 0.6

	_add_dust()

	camera = Camera3D.new()
	camera.fov = 34.0
	cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_near_enabled = true
	cam_attr.dof_blur_amount = 0.05
	camera.attributes = cam_attr
	add_child(camera)
	camera.current = true
	_update_camera()

	_spawn(TM.build(Models.room(), Vector2i(20, 12)))
	for type in Models.CATALOG:
		meshes[type] = TM.build(Models.furniture(type))
	groundhog = _spawn(TM.build(Models.groundhog(GROUNDHOG_SCALE), Vector2i(24, 14)))
	groundhog.position = Vector3(1.5, 0, 2.5)

	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	footprint_mat = StandardMaterial3D.new()
	footprint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	footprint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	footprint = MeshInstance3D.new()
	footprint.mesh = plane
	footprint.material_override = footprint_mat
	footprint.visible = false
	footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(footprint)


## Slow-drifting specks of dust catching the light.
func _add_dust() -> void:
	var dust := CPUParticles3D.new()
	dust.amount = 56
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.position = Vector3(0, 1.5, 0)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(3.6, 1.2, 3.6)
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.03
	dust.initial_velocity_max = 0.12
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 0.96, 0.85, 0))
	fade.set_color(1, Color(1, 0.96, 0.85, 0))
	fade.add_point(0.5, Color(1, 0.96, 0.85, 0.85))
	dust.color_ramp = fade
	var speck := SphereMesh.new()
	speck.radius = 0.018
	speck.height = 0.036
	speck.radial_segments = 6
	speck.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	speck.material = mat
	dust.mesh = speck
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)


func _spawn(mesh: Mesh, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat if mat else material
	add_child(mi)
	return mi


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.theme = _make_theme()
	var box := _box(Color("#FBF6EC"), 0, 22)
	box.shadow_color = Color(0.23, 0.16, 0.12, 0.12)
	box.shadow_size = 18
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(300, 0)
	layer.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -320
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var kicker := _label("可玩原型", 13)
	kicker.add_theme_color_override("font_color", Color("#4F6B3C"))
	col.add_child(kicker)
	var title := _label("小屋佈置", 36)
	title.add_theme_font_override("font", _font(700))
	col.add_child(title)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("#F1E5D1"), 16, 14))
	col.add_child(card)
	status_label = _label("", 16)
	status_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	status_label.custom_minimum_size = Vector2(240, 44)
	card.add_child(status_label)

	count_label = _label("", 14)
	count_label.add_theme_color_override("font_color", Color("#6E5847"))
	col.add_child(count_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for type in Models.CATALOG:
		var f: Dictionary = Models.CATALOG[type]
		var b := _button("%s  %d×%d" % [f.name, f.w, f.d])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(126, 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = _swatch(Color(f.color))
		b.pressed.connect(choose.bind(type))
		grid.add_child(b)
		catalog_buttons[type] = b

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	col.add_child(actions)
	for spec in [["旋轉 (R)", rotate_carried], ["取消 (Esc)", cancel], ["收回 (Del)", stash]]:
		var b := _button(spec[0])
		b.pressed.connect(spec[1])
		actions.add_child(b)

	var help := _label("點地板：土撥鼠走過去\n拖曳：轉視角　滾輪：縮放\n綠色＝可放　紅色＝擋住\n地毯可以墊在家具底下", 14)
	help.add_theme_color_override("font_color", Color("#6E5847"))
	col.add_child(help)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var reset := _button("恢復預設擺設")
	reset.pressed.connect(reset_room)
	col.add_child(reset)


func _font(weight := 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans TC", "Microsoft JhengHei UI", "Microsoft JhengHei", "PingFang TC", "sans-serif"])
	f.font_weight = weight
	return f


func _box(bg: Color, radius: int, margin: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if border.a > 0.0:
		sb.border_width_bottom = 3
		sb.border_color = border
	return sb


## Rounded cream buttons; the selected furniture turns moss green.
func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = _font(500)
	th.default_font_size = 15
	var normal := _box(Color("#F1E5D1"), 14, 10, Color("#E0CDAE"))
	var pressed := _box(Color("#4F6B3C"), 14, 10, Color("#3A5229"))
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", _box(Color("#EADBC1"), 14, 10, Color("#D9C4A2")))
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("hover_pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", normal)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_focus_color"]:
		th.set_color(key, "Button", Color("#3B2A20"))
	for key in ["font_pressed_color", "font_hover_pressed_color"]:
		th.set_color(key, "Button", Color("#FFFDF8"))
	th.set_constant("h_separation", "Button", 10)
	return th


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#3B2A20"))
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 15)
	return b


func _swatch(c: Color) -> ImageTexture:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	for y in 20:
		for x in 20:
			var d := Vector2(x - 9.5, y - 9.5).length()
			var edge := Color("#3B2A20").lerp(c, clampf(8.0 - d, 0.0, 1.0))   # thin dark rim
			img.set_pixel(x, y, Color(edge, clampf(10.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func say(text: String) -> void:
	status_label.text = text
	count_label.text = "房間裡 %d 件家具" % items.size()
	for type in catalog_buttons:
		catalog_buttons[type].set_pressed_no_signal(carried != null and carried.type == type)


# ---------- grid helpers ----------
func size_of(it) -> Vector2i:
	var f: Dictionary = Models.CATALOG[it.type]
	return Vector2i(f.d, f.w) if it.rot % 2 == 1 else Vector2i(f.w, f.d)


func layer_of(it) -> String:
	return Models.CATALOG[it.type].layer


func place_node(it, lift := 0.0) -> void:
	var s := size_of(it)
	it.node.position = Vector3(it.cell.x + s.x / 2.0 - GRID / 2.0, lift, it.cell.y + s.y / 2.0 - GRID / 2.0)
	it.node.rotation = Vector3(0, it.rot * PI / 2, 0)


## Squash-and-settle when a piece lands.
func _bounce(node: Node3D) -> void:
	node.scale = Vector3(1.12, 0.8, 1.12)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func groundhog_cell() -> Vector2i:
	return Vector2i(floori(groundhog.position.x + GRID / 2.0), floori(groundhog.position.z + GRID / 2.0))


func fits(it) -> bool:
	var r := Rect2i(it.cell, size_of(it))
	if not Rect2i(0, 0, GRID, GRID).encloses(r):
		return false
	for other in items:
		if layer_of(other) == layer_of(it) and Rect2i(other.cell, size_of(other)).intersects(r):
			return false
	return not (layer_of(it) == "solid" and r.has_point(groundhog_cell()))


func solid_at(cell: Vector2i) -> bool:
	return astar.is_point_solid(cell)


func refresh_solids() -> void:
	astar.fill_solid_region(astar.region, false)
	for it in items:
		if layer_of(it) == "solid":
			astar.fill_solid_region(Rect2i(it.cell, size_of(it)), true)


func floor_hit(pos: Vector2):
	var hit = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(pos), camera.project_ray_normal(pos))
	if hit == null or absf(hit.x) > 4.6 or absf(hit.z) > 4.6:
		return null
	return hit


func set_tint(it, c: Color) -> void:
	var mat: ShaderMaterial = it.node.material_override
	mat.set_shader_parameter("tint", c)


func new_item(type: String, cell: Vector2i, rot: int) -> Dictionary:
	# each piece gets its own material copy so the ghost tint stays on that piece
	var node := _spawn(meshes[type], material.duplicate())
	if type == "lamp":
		var glow := OmniLight3D.new()
		glow.position = Vector3(0, 1.3, 0)
		glow.light_color = Color("#FFCF8A")
		glow.light_energy = 0.55
		glow.omni_range = 2.2
		node.add_child(glow)
	var it := {"type": type, "cell": cell, "rot": rot, "node": node}
	place_node(it)
	return it


# ---------- frame ----------
func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	footprint.visible = false
	if carried:
		var hit = debug_hover if debug_hover != null else floor_hit(get_viewport().get_mouse_position())
		if hit != null:
			var s := size_of(carried)
			carried.cell = Vector2i(
				clampi(roundi(hit.x + GRID / 2.0 - s.x / 2.0), 0, GRID - s.x),
				clampi(roundi(hit.z + GRID / 2.0 - s.y / 2.0), 0, GRID - s.y))
			# held pieces float and sway a little
			place_node(carried, 0.22 + sin(t * 5.0) * 0.04)
			carried.node.rotation.z = sin(t * 3.0) * 0.04
			var ok := fits(carried)
			set_tint(carried, GHOST_OK if ok else GHOST_BAD)
			footprint.visible = true
			footprint.position = Vector3(carried.node.position.x, 0.012, carried.node.position.z)
			footprint.scale = Vector3(s.x, 1, s.y)
			footprint_mat.albedo_color = Color(GHOST_OK if ok else GHOST_BAD, 0.5)
	_move_groundhog(delta, t)


func _move_groundhog(delta: float, t: float) -> void:
	var br := sin(t * 2.2) * 0.015
	var hop := 0.0
	if path.is_empty():
		gh_idle += delta
		if gh_idle > 6.0:
			gh_idle = 0.0
			_wander()
	else:
		var cell := path[0]
		if solid_at(cell):
			path.clear()
		else:
			var target := Vector3(cell.x - GRID / 2.0 + 0.5, 0, cell.y - GRID / 2.0 + 0.5)
			var to := target - Vector3(groundhog.position.x, 0, groundhog.position.z)
			var step := 1.7 * delta
			if to.length() <= step:
				groundhog.position.x = target.x
				groundhog.position.z = target.z
				path.remove_at(0)
			else:
				groundhog.position += to.normalized() * step
			if to.length_squared() > 0.0001:
				groundhog.rotation.y = lerp_angle(groundhog.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 12.0))
			gh_walk += delta
			hop = absf(sin(gh_walk * 9.0)) * 0.08
			gh_idle = 0.0
	groundhog.position.y = hop
	groundhog.scale = Vector3(1 - br * 0.5, 1 + br, 1 - br * 0.5)


func _wander() -> void:
	var from := groundhog_cell()
	var options: Array[Vector2i] = []
	for x in GRID:
		for z in GRID:
			var c := Vector2i(x, z)
			if c != from and not solid_at(c) and absi(x - from.x) + absi(z - from.y) <= 4:
				options.append(c)
	if options.is_empty():
		return
	walk_to(options.pick_random())


func walk_to(cell: Vector2i) -> void:
	if solid_at(cell) or solid_at(groundhog_cell()):
		return
	var p := astar.get_id_path(groundhog_cell(), cell)
	if p.size() > 1:
		p.remove_at(0)
		path = p


# ---------- input ----------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				press_pos = mb.position
				press_cam = Vector2(cam_yaw, cam_pitch)
				dragging = false
			elif press_pos != null:
				if not dragging:
					on_click(floor_hit(mb.position))
				press_pos = null
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(9.0, cam_dist - 1.2)
			_update_camera()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(22.0, cam_dist + 1.2)
			_update_camera()
	elif e is InputEventMouseMotion and press_pos != null:
		var mm := e as InputEventMouseMotion
		if not dragging and mm.position.distance_to(press_pos) > 6.0:
			dragging = true
		if dragging:
			cam_yaw = clampf(press_cam.x - (mm.position.x - press_pos.x) * 0.006, 0.1, 1.47)
			cam_pitch = clampf(press_cam.y + (mm.position.y - press_pos.y) * 0.005, 0.35, 1.25)
			_update_camera()
	elif e.is_action_pressed("rotate_item"):
		rotate_carried()
	elif e.is_action_pressed("ui_cancel"):
		cancel()
	elif e.is_action_pressed("stash_item"):
		stash()


func _update_camera() -> void:
	var target := Vector3(0.9, 0.4, 0)   # nudged right so the room sits clear of the side panel
	camera.position = target + Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * cam_dist
	camera.look_at(target)
	# tilt-shift: keep the room sharp, soften what is nearer and farther, like a miniature
	cam_attr.dof_blur_far_distance = cam_dist + 4.0
	cam_attr.dof_blur_far_transition = 6.0
	cam_attr.dof_blur_near_distance = cam_dist - 7.0
	cam_attr.dof_blur_near_transition = 3.0


func on_click(hit) -> void:
	if hit == null:
		return
	if carried:
		if not fits(carried):
			say("這裡放不下，換個位置或按 R 旋轉。")
			return
		set_tint(carried, Color(0, 0, 0, 0))
		place_node(carried)
		_bounce(carried.node)
		items.append(carried)
		var piece: String = Models.CATALOG[carried.type].name
		carried = null
		refresh_solids()
		_save_room()
		say("放好了！" + piece + "在新位置。")
		return
	var cell := Vector2i(clampi(floori(hit.x + GRID / 2.0), 0, GRID - 1), clampi(floori(hit.z + GRID / 2.0), 0, GRID - 1))
	var under := items.filter(func(it): return Rect2i(it.cell, size_of(it)).has_point(cell))
	if under.is_empty():
		walk_to(cell)
		return
	var picked = under[0]
	for it in under:
		if layer_of(it) == "solid":
			picked = it
	items.erase(picked)
	carried = picked
	carried_from = {"cell": picked.cell, "rot": picked.rot}
	refresh_solids()
	say("拿起" + Models.CATALOG[picked.type].name + "：移到新位置後點一下放下。")


func choose(type: String) -> void:
	cancel()
	carried = new_item(type, Vector2i.ZERO, 0)
	carried_from = null
	say("移到房間裡，綠色時點一下放下。")


func rotate_carried() -> void:
	if carried:
		carried.rot = (carried.rot + 1) % 4
		say("轉了 90 度。")


func cancel() -> void:
	if not carried:
		return
	var restored := carried_from != null
	if restored:
		carried.cell = carried_from.cell
		carried.rot = carried_from.rot
		set_tint(carried, Color(0, 0, 0, 0))
		place_node(carried)
		_bounce(carried.node)
		items.append(carried)
		refresh_solids()
	else:
		carried.node.queue_free()
	carried = null
	say("放回原位。" if restored else "取消了。")


func stash() -> void:
	if not carried:
		return
	var piece: String = Models.CATALOG[carried.type].name
	carried.node.queue_free()
	carried = null
	_save_room()
	say(piece + "收進倉庫了。")


func reset_room() -> void:
	if carried:
		carried.node.queue_free()
		carried = null
	for it in items:
		it.node.queue_free()
	items.clear()
	_apply_layout(Models.DEFAULT_LAYOUT)
	groundhog.position = Vector3(1.5, 0, 2.5)
	path.clear()
	_save_room()
	say("恢復成預設擺設。")


# ---------- save ----------
func _save_room() -> void:
	var out := []
	for it in items:
		out.append({"type": it.type, "x": it.cell.x, "z": it.cell.y, "rot": it.rot})
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))


func _load_room() -> void:
	var layout: Array = Models.DEFAULT_LAYOUT
	if FileAccess.file_exists(SAVE_PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if typeof(saved) == TYPE_ARRAY:
			layout = saved
	_apply_layout(layout)


func _apply_layout(layout: Array) -> void:
	for s in layout:
		if typeof(s) == TYPE_DICTIONARY and Models.CATALOG.has(s.get("type", "")):
			items.append(new_item(s.type, Vector2i(int(s.x), int(s.z)), int(s.rot)))
	refresh_solids()


# ---------- screenshots for checking the look: -- --screenshot out.png [--carry sofa] ----------
func _debug_args() -> void:
	var args := OS.get_cmdline_user_args()
	var ci := args.find("--carry")
	if ci >= 0 and ci + 1 < args.size():
		choose(args[ci + 1])
		debug_hover = Vector3(1.0, 0, 1.6)
	var si := args.find("--screenshot")
	if si >= 0 and si + 1 < args.size():
		for _i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(args[si + 1])
		get_tree().quit()
