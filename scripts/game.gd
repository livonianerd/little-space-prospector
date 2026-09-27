extends Node3D
## Positions remain in world space. A parallel-transported tangent frame has no poles.
const SAVE := "user://prospector.json"
const NAMES := ["Hearth", "Honey drift", "Blue hush", "The listening stone", "Copper orchard", "Moonwater", "Quiet pebble", "Lost observatory", "Rose lantern"]
const CLUES := ["Your little ship", "Warm glints in the rock", "A cool blue shimmer", "Something answers the stars", "Straight edges among the stones", "Pale crystal seams", "Still and silent", "An old signal", "Metal beneath pink moss"]
var gold := 0
var diamonds := 0
var parts: Array = []
var installed := 0
var upgrades: Array = []
var collected: Array = []
var music_on := true
var save_enabled := true
var save_path := SAVE
var mode := "title"
var current := 0
var normal := Vector3.UP
var forward := Vector3.FORWARD
var asteroids: Array[Dictionary] = []
var loot: Array[Dictionary] = []
var reachable: Array[int] = []
var selected := 0
var pilot: Node3D
var ship: Node3D
var camera: Camera3D
var hud: Label
var hint: Label
var location_label: Label
var target_box: HBoxContainer
var modal: PanelContainer
var music_button: Button
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var audio_started := false
var touch_ids := {}
var mouse_pad := ""
var toast := ""
var toast_time := 0.0
var elapsed := 0.0
var hop_time := -1.0
var hop_start := Vector3.ZERO
var hop_end := Vector3.ZERO
var hop_up := Vector3.UP
var departure_normal := Vector3.UP
var departure_forward := Vector3.FORWARD
var hop_target := -1
var hop_side := Vector3.ZERO
var hop_height := 5.0
var camera_up := Vector3.UP
var camera_back := Vector3.BACK
var markers: Array[MeshInstance3D] = []
var beacon_labels: Array[Label3D] = []
var legs: Array[Node3D] = []
var jet: MeshInstance3D
var ui: Control
var pad_controls: Dictionary = {}
var browser_test := false

func _ready() -> void:
	save_enabled = not "--smoke-test" in OS.get_cmdline_user_args()
	load_progress()
	var prototype := "--prototype" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		prototype = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('prototype')"))
		browser_test = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('test')"))
	build_world(3 if prototype else 9)
	build_audio()
	make_ui()
	refresh_destinations()
	place_pilot()
	update_camera(1.0, true)
	show_title()

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func sphere(parent: Node3D, position_value: Vector3, size_value: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.radius = 1.0
	mesh.height = 2.0
	return mesh_node(parent, mesh, position_value, size_value, color, glow)

func mesh_node(parent: Node3D, mesh: Mesh, p: Vector3, s: Vector3, c: Color, glow: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(c, glow)
	parent.add_child(node)
	node.position = p
	node.scale = s
	return node

func box(parent: Node3D, p: Vector3, s: Vector3, c: Color) -> MeshInstance3D:
	return mesh_node(parent, BoxMesh.new(), p, s, c)

func surface_radius(index: int, n: Vector3) -> float:
	var a := asteroids[index]
	# Small smooth undulations: the same function positions feet, rocks, and resources.
	return a.radius * (1.0 + 0.045 * sin(n.x * 5.0 + index) * sin(n.z * 4.0 + n.y * 3.0))

func surface_point(index: int, n: Vector3, lift: float = 0.0) -> Vector3:
	return asteroids[index].center + n * (surface_radius(index, n) + lift)

func frame(n: Vector3, f: Vector3) -> Basis:
	var tangent := (f - n * f.dot(n)).normalized()
	if tangent.length_squared() < 0.1:
		tangent = n.cross(Vector3.RIGHT).normalized()
	return Basis(tangent.cross(n).normalized(), n, -tangent).orthonormalized()

func build_world(count: int) -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("101b30")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bdd3e5")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_color = Color("ffe4bb")
	sun.light_energy = 1.5
	add_child(sun)
	var centers := [Vector3.ZERO, Vector3(-10, 2, -14), Vector3(10, -1, -16), Vector3(-2, 7, -30), Vector3(-22, -3, -34), Vector3(21, 5, -36), Vector3(6, -7, -46), Vector3(-13, 2, -52), Vector3(23, 0, -55)]
	var radii := [5.0, 3.6, 4.3, 3.0, 5.1, 3.7, 2.8, 4.2, 3.4]
	var colors := [Color("6f9189"), Color("aa8e6b"), Color("687f99"), Color("8d849c"), Color("9a7767"), Color("769da0"), Color("777e89"), Color("788497"), Color("a47e90")]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41987
	for i in range(count):
		asteroids.append({"center": centers[i], "radius": radii[i]})
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for lat in range(16):
			for lon in range(24):
				for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
					var theta: float = (lat + corner.y) / 16.0 * PI
					var phi: float = (lon + corner.x) / 24.0 * TAU
					var n := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
					st.set_color(colors[i].lightened(rng.randf_range(-0.035, 0.035)))
					st.add_vertex(n * surface_radius(i, n))
		st.generate_normals()
		var rock := MeshInstance3D.new()
		rock.mesh = st.commit()
		var mat := material(colors[i])
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color.WHITE
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		rock.material_override = mat
		add_child(rock)
		rock.position = centers[i]
		for j in range(12):
			var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			var pebble := sphere(self, surface_point(i, n, 0.05), Vector3(0.3, 0.13, 0.4) * rng.randf_range(0.6, 1.8), colors[i].lightened(0.14))
			pebble.basis = frame(n, Vector3.FORWARD).scaled(pebble.scale)
		var ring := TorusMesh.new()
		ring.inner_radius = radii[i] + 0.35
		ring.outer_radius = radii[i] + 0.40
		ring.rings = 32
		ring.ring_segments = 6
		markers.append(mesh_node(self, ring, centers[i], Vector3.ONE, Color("9fe4d0"), 0.5))
		var beacon := Label3D.new()
		beacon.text = NAMES[i]
		beacon.font_size = 32
		beacon.pixel_size = 0.014
		beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		beacon.modulate = Color("c4e4d9")
		add_child(beacon)
		beacon_labels.append(beacon)
		if i != 6:
			var amount: int = [5, 8, 4, 2, 7, 6, 0, 3, 5][i]
			for j in range(amount):
				var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.9, 1), rng.randf_range(-1, 1)).normalized()
				if j == 0: n = Vector3(0.22, 0.96, -0.18).normalized()
				add_loot(i, n, "diamond" if (i in [2, 5] or j == 3) else "gold", "v2_%d_%d" % [i, j])
		if i in [1, 4, 8]:
			add_loot(i, Vector3(-0.65, 0.35, -0.67).normalized(), "part", ["p1", "p3", "p5"][[1, 4, 8].find(i)])
		if i == 3 or i == 7:
			add_loot(i, Vector3(0.7, 0.5, 0.3).normalized(), "discovery", "wonder%d" % i)
	# Shared mesh/material keeps the distant sky inexpensive.
	var stars := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.12
	star_mesh.height = 0.24
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	star_mesh.material = material(Color("b6c5d7"), 0.8)
	multi.mesh = star_mesh
	multi.instance_count = 190
	for i in range(190):
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, direction * rng.randf_range(85, 140)))
	stars.multimesh = multi
	add_child(stars)
	pilot = Node3D.new()
	add_child(pilot)
	sphere(pilot, Vector3(0, 0.63, 0), Vector3(0.26, 0.34, 0.2), Color("df967d"))
	sphere(pilot, Vector3(0, 1.03, 0), Vector3.ONE * 0.31, Color("f1ebd9"))
	sphere(pilot, Vector3(0, 1.05, -0.19), Vector3(0.24, 0.21, 0.17), Color("263e55"))
	sphere(pilot, Vector3(-0.09, 1.13, -0.33), Vector3(0.06, 0.035, 0.02), Color("badcde"), 0.3)
	box(pilot, Vector3(0, 0.66, 0.26), Vector3(0.4, 0.43, 0.2), Color("738e92"))
	for side in [-1, 1]:
		legs.append(box(pilot, Vector3(side * 0.14, 0.22, 0), Vector3(0.16, 0.43, 0.2), Color("ede5d2")))
		box(pilot, Vector3(side * 0.34, 0.63, 0), Vector3(0.13, 0.4, 0.16), Color("ede5d2"))
	jet = sphere(pilot, Vector3(0, 0.16, 0.27), Vector3(0.13, 0.35, 0.13), Color("a4e3df"), 1.0)
	ship = Node3D.new()
	add_child(ship)
	ship.position = surface_point(0, Vector3(-0.45, 0.89, 0).normalized(), 0.03)
	ship.basis = frame(Vector3(-0.45, 0.89, 0).normalized(), Vector3.FORWARD)
	rebuild_ship()
	camera = Camera3D.new()
	camera.fov = 62
	camera.far = 220
	add_child(camera)

func add_loot(index: int, n: Vector3, kind: String, id: String) -> void:
	var root_node := Node3D.new()
	add_child(root_node)
	root_node.position = surface_point(index, n)
	root_node.basis = frame(n, Vector3.FORWARD)
	match kind:
		"gold":
			sphere(root_node, Vector3(0, 0.17, 0), Vector3(0.28, 0.22, 0.21), Color("efc779"), 0.15)
			sphere(root_node, Vector3(0.19, 0.1, 0.1), Vector3.ONE * 0.13, Color("e6b66a"))
		"diamond":
			var crystal := CylinderMesh.new()
			crystal.top_radius = 0
			crystal.bottom_radius = 0.23
			crystal.height = 0.7
			crystal.radial_segments = 5
			mesh_node(root_node, crystal, Vector3(0, 0.3, 0), Vector3.ONE, Color("9bdddf"), 0.3)
		"part":
			box(root_node, Vector3(0, 0.3, 0), Vector3(0.65, 0.5, 0.5), Color("ddab83"))
			box(root_node, Vector3(0, 0.57, 0), Vector3(0.5, 0.05, 0.12), Color("b6f4d3"))
		"discovery":
			for j in range(3):
				var stem := CylinderMesh.new()
				stem.top_radius = 0.045
				stem.bottom_radius = 0.09
				stem.height = 0.6 + j * 0.25
				mesh_node(root_node, stem, Vector3(j * 0.3 - 0.3, stem.height / 2, 0), Vector3.ONE, Color("bdabbf"))
				sphere(root_node, Vector3(j * 0.3 - 0.3, stem.height, 0), Vector3(0.22, 0.12, 0.22), Color("e3bad2"), 0.4)
	root_node.visible = id not in collected
	loot.append({"asteroid": index, "normal": n, "kind": kind, "id": id, "node": root_node})

func rebuild_ship() -> void:
	for child in ship.get_children():
		ship.remove_child(child)
		child.queue_free()
	box(ship, Vector3(0, 0.12, 0), Vector3(2.4, 0.18, 1.7), Color("566f78"))
	sphere(ship, Vector3(0, 0.6, 0), Vector3(0.85, 0.46 + installed * 0.1, 0.65), Color("bdccc0"))
	if installed >= 1:
		sphere(ship, Vector3(0, 1.1, -0.13), Vector3(0.55, 0.5, 0.5), Color("e8ded0"))
		sphere(ship, Vector3(0, 1.2, -0.48), Vector3(0.35, 0.26, 0.12), Color("8ed5de"))
	if installed >= 2 or "Golden fins" in upgrades:
		for side in [-1, 1]:
			var fin := box(ship, Vector3(side * 0.9, 0.6, 0.12), Vector3(0.16, 0.9, 0.9), Color("e6b773"))
			fin.rotation.z = side * -0.3
	if installed >= 3:
		for side in [-1, 1]:
			sphere(ship, Vector3(side * 0.5, 0.4, 0.6), Vector3(0.22, 0.22, 0.4), Color("9fd8d6"), 0.4)
	if "Crystal window" in upgrades:
		box(ship, Vector3(0, 1.65, 0), Vector3(0.05, 0.8, 0.05), Color("c0d6d3"))
		sphere(ship, Vector3(0, 2.06, 0), Vector3(0.26, 0.1, 0.26), Color("9bdddf"), 0.5)
	if "Garden lights" in upgrades:
		for j in range(7):
			sphere(ship, Vector3(-1.05 + j * 0.35, 0.24, -0.8), Vector3.ONE * 0.07, Color("f2c98d"), 0.8)

func hop_range() -> float:
	return 17.0 + (4.0 if "Golden fins" in upgrades else 0.0) + installed * 0.6

func destinations(index: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(asteroids.size()):
		if i != index and asteroids[index].center.distance_to(asteroids[i].center) - asteroids[index].radius - asteroids[i].radius <= hop_range():
			result.append(i)
	return result

func refresh_destinations() -> void:
	reachable = destinations(current)
	if selected not in reachable and not reachable.is_empty(): selected = reachable[0]
	for i in range(markers.size()):
		markers[i].visible = i in reachable
		beacon_labels[i].visible = i in reachable
		markers[i].material_override.albedo_color = Color("f5d697") if i == selected else Color("7caaa5")
	if not is_instance_valid(target_box): return
	for child in target_box.get_children():
		target_box.remove_child(child)
		child.queue_free()
	for i in reachable:
		var text_value: String = ("• " if selected == i else "") + NAMES[i]
		var b := button(text_value, func(): select_target(i), target_box)
		b.custom_minimum_size = Vector2(100, 38)
		b.add_theme_font_size_override("font_size", 14)
		b.tooltip_text = CLUES[i]
	update_labels()

func select_target(index: int) -> void:
	selected = index
	refresh_destinations()
	var clue: String = CLUES[index]
	if "Crystal window" in upgrades:
		var counts := {"gold": 0, "diamond": 0, "part": 0, "discovery": 0}
		for item in loot:
			if item.asteroid == index and item.id not in collected: counts[item.kind] += 1
		clue += "  •  Scanner: %d gold / %d crystal / %d parts" % [counts.gold, counts.diamond, counts.part]
	announce(NAMES[index] + " — " + clue)

func step_surface(delta: float, direction: Vector2) -> void:
	if direction.length() > 1: direction = direction.normalized()
	if direction.length_squared() < 0.001: return
	var right := forward.cross(normal).normalized()
	var tangent := (right * direction.x + forward * -direction.y).normalized()
	var axis := normal.cross(tangent).normalized()
	var angle := 2.8 * delta * direction.length() / surface_radius(current, normal)
	var turn := Quaternion(axis, angle)
	normal = (turn * normal).normalized()
	forward = (turn * forward).normalized()
	forward = (forward - normal * forward.dot(normal)).normalized()
	place_pilot()

func place_pilot() -> void:
	pilot.position = surface_point(current, normal, 0.045)
	pilot.basis = frame(normal, forward)

func start_hop(target: int = -2) -> void:
	if mode != "play" or hop_time >= 0: return
	if target == -2: target = selected
	departure_normal = normal
	departure_forward = forward
	hop_start = pilot.position
	hop_up = normal
	hop_target = target if target in reachable else -1
	hop_time = 0
	hop_side = Vector3.ZERO
	hop_height = 5.0
	if hop_target >= 0:
		# Arrive on the same hemisphere; gentle automatic landing is intentional.
		hop_end = surface_point(hop_target, normal, 0.045)
		if not plan_hop(): hop_target = -1
	else:
		hop_end = hop_start + forward * 6
	play_sound(0)
	announce("Drifting to " + NAMES[hop_target] if hop_target >= 0 else "Your tether will bring you gently back")

func hop_position(t: float) -> Vector3:
	var smooth_t := t * t * (3 - 2 * t)
	return hop_start.lerp(hop_end, smooth_t) + hop_up * sin(t * PI) * hop_height + hop_side * pow(sin(t * PI), 2)

func hop_path_clear() -> bool:
	for sample_index in range(1, 80):
		var p := hop_position(sample_index / 80.0)
		for i in range(asteroids.size()):
			var offset: Vector3 = p - asteroids[i].center
			if offset.length() < surface_radius(i, offset.normalized()) + 0.02: return false
	return true

func plan_hop() -> bool:
	# Usually a small arc suffices. On the far side, bend around the departure
	# stone instead of crossing its interior; also avoid intervening neighbors.
	if hop_path_clear(): return true
	var sideways := forward.cross(normal).normalized()
	for height in [7.0, 12.0, 20.0, 30.0]:
		hop_height = height
		for direction in [forward, -forward, sideways, -sideways]:
			hop_side = direction * height
			if hop_path_clear(): return true
	return false

func step_hop(delta: float) -> void:
	hop_time += delta / 2.2
	var t := clampf(hop_time, 0, 1)
	if hop_target < 0:
		pilot.position = hop_start + hop_up * sin(t * PI) * 2.0
	else:
		pilot.position = hop_position(t)
	if hop_time >= 1:
		if hop_target >= 0:
			current = hop_target
			announce(NAMES[current] + "  •  " + CLUES[current])
		else:
			normal = departure_normal
			forward = departure_forward
			announce("Safely back on your departure stone")
		hop_time = -1
		place_pilot()
		refresh_destinations()
		play_sound(1)

func update_camera(delta: float, immediate: bool = false) -> void:
	var weight := 1.0 if immediate else 1.0 - exp(-delta * 7)
	# Interpolate a quaternion rather than world-up vectors, including at the poles.
	var desired := frame(normal, forward)
	var camera_frame := Basis(Quaternion(frame(camera_up, -camera_back)).slerp(Quaternion(desired), weight))
	camera_up = camera_frame.y
	camera_back = camera_frame.z
	var target := pilot.position + camera_up * 0.65
	var offset := camera_up * 6.0 + camera_back * 10.5
	var distance := offset.length()
	var ray := offset / distance
	# Keep both the camera and its sightline outside nearby stones.
	for i in range(asteroids.size()):
		var relative: Vector3 = target - asteroids[i].center
		var radius: float = asteroids[i].radius * 1.05 + 0.15
		var b := relative.dot(ray)
		var discriminant := b * b - (relative.length_squared() - radius * radius)
		if discriminant > 0:
			var entry := -b - sqrt(discriminant)
			if entry > 0: distance = minf(distance, maxf(1.2, entry - 0.2))
	camera.position = target + ray * distance
	camera.look_at(target + -camera_back * 1.7, camera_up)

func collect_nearby() -> void:
	if hop_time >= 0: return
	for item in loot:
		if item.asteroid != current or item.id in collected: continue
		if pilot.position.distance_to(item.node.position) > 0.85: continue
		collected.append(item.id)
		item.node.hide()
		match item.kind:
			"gold": gold += 1
			"diamond": diamonds += 1
			"part":
				if item.id not in parts: parts.append(item.id)
				announce("A ship component! Bring it home to your workshop.")
			"discovery": announce("Starbells. They have been singing to the sky all this time.")
		play_sound(3 if item.kind in ["part", "discovery"] else 2)
		save_progress()

func _physics_process(delta: float) -> void:
	elapsed += delta
	toast_time -= delta
	if mode == "play":
		if hop_time >= 0: step_hop(delta)
		else:
			var direction := movement_input()
			step_surface(delta, direction)
			for i in range(legs.size()): legs[i].rotation.x = sin(elapsed * 11 + i * PI) * direction.length() * 0.4
			collect_nearby()
	jet.visible = hop_time >= 0
	update_camera(delta)
	for i in range(markers.size()):
		if markers[i].visible:
			beacon_labels[i].position = asteroids[i].center + normal * (asteroids[i].radius + 1.0)
			markers[i].basis = frame(normal, forward)
			markers[i].scale = Vector3.ONE * (1.025 + sin(elapsed * 2 + i) * 0.012 if selected == i else 1.0)
	update_labels()
	if browser_test and Engine.get_physics_frames() % 15 == 0:
		JavaScriptBridge.eval("window.prospector = " + JSON.stringify({"current": current, "mode": mode, "normal": [normal.x, normal.y, normal.z], "gold": gold, "diamonds": diamonds, "music_on": music_on, "audio_started": audio_started, "music_playing": music.playing, "hop_time": hop_time, "selected": selected, "reachable": reachable, "touches": touch_ids.size()}))

func movement_input() -> Vector2:
	var value := Vector2.ZERO
	for entry in [["left", KEY_A, KEY_LEFT, Vector2.LEFT], ["right", KEY_D, KEY_RIGHT, Vector2.RIGHT], ["up", KEY_W, KEY_UP, Vector2.UP], ["down", KEY_S, KEY_DOWN, Vector2.DOWN]]:
		if Input.is_physical_key_pressed(entry[1]) or Input.is_physical_key_pressed(entry[2]) or entry[0] in touch_ids.values() or mouse_pad == entry[0]: value += entry[3]
	return value.limit_length()

func pad_at(p: Vector2) -> String:
	for key in pad_controls:
		if pad_controls[key].get_global_rect().has_point(p): return key
	return ""

func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed: begin_audio()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and mode == "workshop": close_modal()
		if mode != "play": return
		match event.keycode:
			KEY_SPACE: start_hop()
			KEY_TAB, KEY_E:
				if not reachable.is_empty(): select_target(reachable[(reachable.find(selected) + 1) % reachable.size()])
			KEY_B: show_workshop()
			KEY_R: return_home()
	if event is InputEventScreenTouch:
		if event.pressed and mode == "play": touch_ids[event.index] = pad_at(event.position)
		else: touch_ids.erase(event.index)
	if event is InputEventScreenDrag and touch_ids.has(event.index): touch_ids[event.index] = pad_at(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1:
		mouse_pad = pad_at(event.position) if event.pressed and mode == "play" else ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		touch_ids.clear()
		mouse_pad = ""
		save_progress()

func announce(message: String) -> void:
	toast = message
	toast_time = 6.0

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.12, 0.18, 0.94)
	style.border_color = Color("526c74")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func label(text_value: String, size_value: int, parent: Node) -> Label:
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", size_value)
	node.add_theme_color_override("font_color", Color("e5e6d9"))
	node.add_theme_color_override("font_shadow_color", Color("101b30"))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(node)
	return node

func button(text_value: String, action: Callable, parent: Node) -> Button:
	var node := Button.new()
	node.text = text_value
	node.custom_minimum_size = Vector2(0, 44)
	node.add_theme_stylebox_override("normal", panel_style())
	var hover := panel_style()
	hover.bg_color = Color("29424e")
	node.add_theme_stylebox_override("hover", hover)
	var pressed_style := panel_style()
	pressed_style.bg_color = Color("39585d")
	node.add_theme_stylebox_override("pressed", pressed_style)
	node.add_theme_font_size_override("font_size", 16)
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(func(): begin_audio(); action.call())
	parent.add_child(node)
	return node

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := VBoxContainer.new()
	ui.add_child(top)
	top.position = Vector2(24, 18)
	label("L I T T L E   S P A C E   P R O S P E C T O R", 13, top)
	location_label = label("Hearth", 28, top)
	hud = label("", 16, top)
	var menu := HBoxContainer.new()
	ui.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu.position = Vector2(606, 18)
	button("Ship · B", show_workshop, menu).custom_minimum_size.y = 72
	button("Home · R", return_home, menu).custom_minimum_size.y = 72
	music_button = button("", toggle_music, menu)
	music_button.custom_minimum_size.y = 72
	var bottom := VBoxContainer.new()
	ui.add_child(bottom)
	bottom.position = Vector2(24, 422)
	label("WITHIN REACH   /   tap a destination · E to cycle", 13, bottom)
	var target_scroll := ScrollContainer.new()
	target_scroll.custom_minimum_size = Vector2(912, 50)
	target_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom.add_child(target_scroll)
	target_box = HBoxContainer.new()
	target_scroll.add_child(target_box)
	hint = label("", 15, ui)
	hint.position = Vector2(24, 114)
	hint.custom_minimum_size.x = 910
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for entry in [["left", "‹", Vector2(20, 548)], ["right", "›", Vector2(180, 548)], ["up", "^", Vector2(100, 504)], ["down", "v", Vector2(100, 574)]]:
		var pad := button(entry[1], func(): pass, ui)
		pad.position = entry[2]
		pad.size = Vector2(76, 64)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad_controls[entry[0]] = pad
	var hop := button("JETPACK\nSpace", start_hop, ui)
	hop.position = Vector2(778, 544)
	hop.size = Vector2(158, 72)
	label("WASD / arrows to wander\nWalk around every side of a stone", 14, ui).position = Vector2(290, 560)
	modal = PanelContainer.new()
	ui.add_child(modal)
	modal.position = Vector2(205, 125)
	modal.size = Vector2(550, 300)
	modal.add_theme_stylebox_override("panel", panel_style())

func clear_modal() -> VBoxContainer:
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	modal.show()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	modal.add_child(content)
	return content

func show_title() -> void:
	mode = "title"
	var content := clear_modal()
	label("A little further into the quiet.", 28, content)
	label("Wander around tiny worlds. Follow a glimmer.\nBring something lovely home.", 19, content)
	button("Begin wandering", start_game, content)
	label("WASD to walk · Choose a stone · Space to drift\nNo danger, no hurry. Your discoveries are saved.", 16, content)

func start_game() -> void:
	begin_audio()
	close_modal()
	announce("Walk toward a glimmer, or choose a nearby stone below.")

func close_modal() -> void:
	mode = "play"
	modal.hide()
	touch_ids.clear()
	mouse_pad = ""

func show_workshop() -> void:
	if mode == "title" or hop_time >= 0: return
	if current != 0:
		announce("Your workshop is at Hearth. Home / R returns you safely.")
		return
	mode = "workshop"
	touch_ids.clear()
	mouse_pad = ""
	var content := clear_modal()
	label("The Hearth workshop   ·   %d / 3" % installed, 26, content)
	var install := button("Fit a component  ·  %d in your pack" % (parts.size() - installed), install_part, content)
	install.disabled = installed >= parts.size() or installed >= 3
	for entry in [["Golden fins", 6, 0, "+4m jetpack reach"], ["Crystal window", 0, 3, "scan a destination's contents"], ["Garden lights", 8, 2, "a warm welcome home"]]:
		var item: String = entry[0]
		var b := button(("Fitted · " + item) if item in upgrades else "%s · %dg %dd · %s" % [item, entry[1], entry[2], entry[3]], func(): buy_upgrade(item), content)
		b.disabled = item in upgrades or gold < entry[1] or diamonds < entry[2]
	button("Back to the stars", close_modal, content)

func install_part() -> void:
	if current != 0 or installed >= mini(3, parts.size()): return
	installed += 1
	rebuild_ship()
	refresh_destinations()
	save_progress()
	play_sound(3)
	show_workshop()
	announce("Your ship is ready for a lifetime of stargazing." if installed == 3 else "A little more ship. A little more reach.")

func buy_upgrade(item: String) -> void:
	var costs := {"Golden fins": Vector2i(6, 0), "Crystal window": Vector2i(0, 3), "Garden lights": Vector2i(8, 2)}
	if current != 0 or item not in costs or item in upgrades: return
	var cost: Vector2i = costs[item]
	if gold < cost.x or diamonds < cost.y: return
	gold -= cost.x
	diamonds -= cost.y
	upgrades.append(item)
	rebuild_ship()
	refresh_destinations()
	save_progress()
	play_sound(3)
	show_workshop()

func return_home() -> void:
	if mode != "play": return
	current = 0
	normal = Vector3.UP
	forward = Vector3.FORWARD
	hop_time = -1
	place_pilot()
	update_camera(1, true)
	refresh_destinations()
	announce("Welcome to Hearth. B opens your workshop.")

func update_labels() -> void:
	if not is_instance_valid(hud): return
	hud.text = "%d gold   ·   %d crystals   ·   %d/3 components" % [gold, diamonds, parts.size()]
	location_label.text = NAMES[current]
	hint.text = toast if toast_time > 0 else (NAMES[selected] + "  ·  " + CLUES[selected] + "  ·  Space to drift")
	music_button.text = "Music " + ("On" if music_on else "Off")

func toggle_music() -> void:
	music_on = not music_on
	if music_on and audio_started: music.play()
	else: music.stop()
	save_progress()
	update_labels()

func build_audio() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	music.stream = load("res://assets/quiet-orbit.wav")
	music.volume_db = -14
	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	sfx.volume_db = -17

func begin_audio() -> void:
	if audio_started: return
	audio_started = true
	if music_on: music.play()

func play_sound(index: int) -> void:
	if not audio_started: return
	sfx.stream = load("res://assets/" + ["drift", "land", "glint", "discovery"][index] + ".wav")
	sfx.pitch_scale = 1.0 + sin(elapsed * 3.71) * 0.065
	sfx.play()

func save_progress() -> void:
	if not save_enabled: return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 2, "gold": gold, "diamonds": diamonds, "parts": parts, "installed": installed, "upgrades": upgrades, "collected": collected, "music_on": music_on}))

func load_progress() -> void:
	if not save_enabled or not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: return
	gold = maxi(0, int(data.get("gold", 0)))
	diamonds = maxi(0, int(data.get("diamonds", 0)))
	parts = []
	upgrades = []
	collected = []
	if data.get("parts", []) is Array:
		for id in data.get("parts", []):
			if id in ["p1", "p3", "p5"] and id not in parts: parts.append(id)
	installed = clampi(int(data.get("installed", 0)), 0, parts.size())
	if data.get("upgrades", []) is Array:
		for item in data.get("upgrades", []):
			if item in ["Golden fins", "Crystal window", "Garden lights"] and item not in upgrades: upgrades.append(item)
	if data.get("collected", []) is Array:
		for id in data.get("collected", []):
			if id is String and id not in collected: collected.append(id)
	for id in parts:
		if id not in collected: collected.append(id)
	music_on = bool(data.get("music_on", true))
