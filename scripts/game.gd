extends Node2D
## Original vector art is drawn here; no external art or service dependencies.
const SAVE := "user://prospector.json"
const GOLD := Color("ffda83")
const MINT := Color("a6efd6")
const INK := Color("111c38")
var astronaut := "boy"
var gold := 0
var diamonds := 0
var parts: Array = []
var installed := 0
var upgrades: Array = []
var collected: Array = []
var pos := Vector2(150, 390)
var velocity := Vector2.ZERO
var safe := Vector2(150, 390)
var camera_x := 0.0
var grounded := true
var mode := "title"
var clock := 0.0
var toast := ""
var toast_time := 0.0
var held := {"left": false, "right": false, "jet": false}
var touch_ids := {}
var ui: Control
var hud: Label
var hint: Label
var modal: PanelContainer
var islands: Array[Vector3] = [Vector3(150, 420, 150), Vector3(480, 390, 105), Vector3(790, 330, 115), Vector3(1100, 420, 120), Vector3(1410, 350, 110), Vector3(1740, 400, 140), Vector3(2040, 320, 100)]
var loot: Array[Dictionary] = []
var save_enabled := true
var save_path := SAVE

func _ready() -> void:
	if "--smoke-test" in OS.get_cmdline_user_args():
		save_enabled = false
	build_loot()
	load_progress()
	make_ui()
	show_title()

func build_loot() -> void:
	for i in range(islands.size()):
		var a := islands[i]
		for j in range(3):
			loot.append({"pos": Vector2(a.x - 55 + j * 55, a.y - 45), "kind": "gold", "id": "g%d_%d" % [i,j]})
		loot.append({"pos": Vector2(a.x, a.y - 110), "kind": "diamond", "id": "d%d" % i})
	for i in [1, 3, 5]:
		loot.append({"pos": Vector2(islands[i].x + 25, islands[i].y - 70), "kind": "part", "id": "p%d" % i})

func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("172744")
	s.border_color = Color("52768a")
	s.set_border_width_all(2)
	s.set_corner_radius_all(22)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	return s

func button(text_value: String, action: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func label(text_value: String, size: int, parent: Node) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	hud = label("", 20, ui)
	hud.position = Vector2(24, 18)
	hint = label("", 18, ui)
	hint.position = Vector2(24, 57)
	var ship_button := button("Ship [B]", show_workshop, ui)
	ship_button.position = Vector2(796, 16)
	ship_button.size.x = 140
	var home_button := button("Home [R]", return_home, ui)
	home_button.position = Vector2(796, 96)
	home_button.size.x = 140
	# Drawn pads use independent touch indices for simultaneous steering + lift.
	modal = PanelContainer.new()
	modal.position = Vector2(190, 80)
	modal.size = Vector2(580, 400)
	modal.add_theme_stylebox_override("panel", panel_style())
	ui.add_child(modal)

func clear_modal() -> VBoxContainer:
	for c in modal.get_children():
		modal.remove_child(c)
		c.queue_free()
	modal.show()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	modal.add_child(box)
	return box

func show_title() -> void:
	mode = "title"
	var box := clear_modal()
	label("LITTLE SPACE\nPROSPECTOR", 36, box)
	label("A small adventure. A ship of your own.", 20, box)
	label("Find 3 parts • Build • Make it yours", 20, box)
	button("Explore the asteroid garden", show_character, box)
	label("No rush. Your discoveries are saved automatically.", 16, box)

func show_character() -> void:
	mode = "choice"
	var box := clear_modal()
	label("Choose your astronaut", 30, box)
	label("Same lovely jetpack. Same big dreams.", 19, box)
	button("Boy astronaut  •  blue suit", func(): start_game("boy"), box)
	button("Girl astronaut  •  coral suit", func(): start_game("girl"), box)
	button("Back", show_title, box)

func start_game(choice: String) -> void:
	astronaut = choice
	mode = "play"
	modal.hide()
	reset_input()
	save_progress()
	announce("Hold JET to float. Steer to the glowing parts to the right.")

func reset_input() -> void:
	held = {"left": false, "right": false, "jet": false}
	touch_ids.clear()

func show_workshop() -> void:
	if mode == "title" or mode == "choice":
		return
	mode = "workshop"
	reset_input()
	var box := clear_modal()
	label("YOUR LITTLE SHIP   %d / 3" % installed, 28, box)
	label("Hull > cabin > engines" if installed < 3 else "Ready for stargazing! Keep decorating.", 19, box)
	var install_button := button("Install next part (%d in backpack)" % (parts.size() - installed), install_part, box)
	install_button.disabled = parts.size() <= installed or installed == 3
	for item in [["Golden fins", 6, 0], ["Crystal window", 0, 3], ["Garden lights", 8, 2]]:
		var name_value: String = item[0]
		var cost_g: int = item[1]
		var cost_d: int = item[2]
		var buy := button(("Owned: " + name_value) if name_value in upgrades else "%s  •  %d gold + %d diamonds" % [name_value, cost_g, cost_d], func(): buy_upgrade(name_value, cost_g, cost_d), box)
		buy.disabled = name_value in upgrades or gold < cost_g or diamonds < cost_d
	button("Back to exploring", func(): mode = "play"; modal.hide(), box)

func install_part() -> void:
	if installed < mini(3, parts.size()):
		installed += 1
		save_progress()
		announce("Your little spaceship is complete!" if installed == 3 else "Ship part installed. Looking good!")
		show_workshop()

func buy_upgrade(item: String, cost_g: int, cost_d: int) -> void:
	if item not in upgrades and gold >= cost_g and diamonds >= cost_d:
		gold -= cost_g
		diamonds -= cost_d
		upgrades.append(item)
		save_progress()
		show_workshop()

func announce(message: String) -> void:
	toast = message
	toast_time = 5.0

func return_home() -> void:
	if mode != "play":
		return
	pos = Vector2(150, 390)
	safe = pos
	velocity = Vector2.ZERO
	grounded = true
	# Resources regrow for unlimited decorating; unique parts never duplicate.
	collected = collected.filter(func(id): return str(id).begins_with("p"))
	save_progress()
	announce("Welcome home. Fresh crystals are growing in the garden!")

func pad_at(p: Vector2) -> String:
	if p.y > 520:
		if p.x < 118: return "left"
		if p.x < 238: return "right"
		if p.x > 790: return "jet"
	return ""

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B: show_workshop()
		if event.keycode == KEY_R: return_home()
		if event.keycode == KEY_ESCAPE and mode == "workshop":
			mode = "play"
			modal.hide()
	if mode != "play": return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_ids[event.index] = pad_at(event.position)
		else:
			touch_ids.erase(event.index)
	if event is InputEventScreenDrag and touch_ids.has(event.index):
		touch_ids[event.index] = pad_at(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1:
		reset_mouse()
		var pad := pad_at(event.position)
		if event.pressed and pad != "": held[pad] = true

func reset_mouse() -> void:
	for key in held: held[key] = false

func pressed(action: String) -> bool:
	var keys := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "jet": [KEY_SPACE, KEY_W, KEY_UP]}
	return (action == "jet" and (held["left"] or held["right"])) or held[action] or action in touch_ids.values() or Input.is_physical_key_pressed(keys[action][0]) or Input.is_physical_key_pressed(keys[action][1]) or (action == "jet" and Input.is_physical_key_pressed(KEY_UP))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_input()
		save_progress()

func _physics_process(delta: float) -> void:
	clock += delta
	toast_time -= delta
	if mode == "play":
		step_motion(delta, float(pressed("right")) - float(pressed("left")), pressed("jet"))
		collect_nearby()
	camera_x = lerpf(camera_x, clampf(pos.x - 360, 0, 1250), 1 - exp(-delta * 5))
	hud.text = "GOLD  %d    DIAMONDS  %d    PARTS  %d / 3" % [gold, diamonds, parts.size()]
	hint.text = toast if toast_time > 0 else ("Ship complete! Collect & decorate.  •  R / Home regrows gems" if installed == 3 else "A/D or arrows: move   •   Hold Space: hop & jet   •   B: build")
	queue_redraw()

func step_motion(delta: float, direction: float, jet: bool) -> void:
	velocity.x = move_toward(velocity.x, direction * 230, 650 * delta)
	if jet:
		if grounded: velocity.y = -230
		velocity.y = maxf(velocity.y - 460 * delta, -230)
		grounded = false
	else:
		velocity.y = minf(velocity.y + 310 * delta, 300)
	var previous := pos
	pos += velocity * delta
	pos.x = clampf(pos.x, -80, 2230)
	pos.y = maxf(pos.y, 110)
	grounded = false
	if velocity.y >= 0:
		for a in islands:
			if absf(pos.x - a.x) < a.z - 12 and previous.y + 30 <= a.y + 2 and pos.y + 30 >= a.y:
				pos.y = a.y - 30
				velocity.y = 0
				grounded = true
				safe = Vector2(clampf(pos.x, a.x - a.z + 25, a.x + a.z - 25), a.y - 30)
	if pos.y > 710:
		pos = safe
		velocity = Vector2.ZERO
		announce("A soft landing back on your last asteroid. Try again!")

func collect_nearby() -> void:
	for item in loot:
		if item.id in collected: continue
		if pos.distance_to(item.pos) < 43:
			collected.append(item.id)
			match item.kind:
				"gold": gold += 1
				"diamond": diamonds += 1
				"part":
					if item.id not in parts: parts.append(item.id)
					announce("Ship component found! Open Ship [B] to install it.")
			save_progress()

func save_progress() -> void:
	if not save_enabled: return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 1, "astronaut": astronaut, "gold": gold, "diamonds": diamonds, "parts": parts, "installed": installed, "upgrades": upgrades, "collected": collected}))

func load_progress() -> void:
	if not save_enabled or not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: return
	astronaut = "girl" if data.get("astronaut") == "girl" else "boy"
	gold = maxi(0, int(data.get("gold", 0)))
	diamonds = maxi(0, int(data.get("diamonds", 0)))
	for id in data.get("parts", []):
		if id in ["p1", "p3", "p5"] and id not in parts: parts.append(id)
	installed = clampi(int(data.get("installed", 0)), 0, parts.size())
	for item in data.get("upgrades", []):
		if item in ["Golden fins", "Crystal window", "Garden lights"] and item not in upgrades: upgrades.append(item)
	for id in data.get("collected", []):
		if id is String and id not in collected: collected.append(id)
	for id in parts:
		if id not in collected: collected.append(id)

func text_at(p: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	for i in range(85):
		var star := Vector2(fposmod(i * 137.3 - camera_x * 0.12, 960), fposmod(i * 83.7, 510))
		draw_circle(star, 1.0 + (i % 3) * 0.5, Color(0.65, 0.83, 0.9, 0.35 + sin(clock + i) * 0.15))
	draw_circle(Vector2(805, 230), 74, Color("20354c"))
	draw_arc(Vector2(805, 230), 93, -0.3, 3.5, 64, Color("385369"), 5, true)
	for i in range(islands.size()):
		var a := islands[i]
		var x := a.x - camera_x
		var poly := PackedVector2Array([Vector2(x-a.z,a.y), Vector2(x-a.z*0.85,a.y+45), Vector2(x-a.z*0.35,a.y+85), Vector2(x+a.z*0.5,a.y+70), Vector2(x+a.z,a.y+25), Vector2(x+a.z,a.y)])
		draw_colored_polygon(poly, Color("485773"))
		draw_line(Vector2(x-a.z,a.y), Vector2(x+a.z,a.y), MINT, 7, true)
		draw_circle(Vector2(x-25,a.y+35), 16, Color("36445f"))
		draw_circle(Vector2(x+45,a.y+42), 9, Color("36445f"))
		text_at(Vector2(x-40,a.y+115), "HOME" if i == 0 else "GARDEN %02d" % i, 14, Color("8198b3"))
	for item in loot:
		if item.id in collected: continue
		var p: Vector2 = item.pos - Vector2(camera_x, 0) + Vector2(0, sin(clock * 2 + item.pos.x) * 4)
		draw_circle(p, 19, Color(0.6, 0.85, 0.85, 0.07))
		match item.kind:
			"gold":
				draw_circle(p, 9, GOLD)
				draw_line(p + Vector2(-2,-5), p + Vector2(-2,4), Color.WHITE, 2)
			"diamond":
				draw_colored_polygon(PackedVector2Array([p+Vector2(0,-13),p+Vector2(10,0),p+Vector2(0,14),p+Vector2(-10,0)]), Color("9ee7ff"))
			"part":
				draw_style_box(panel_style(), Rect2(p-Vector2(14,14),Vector2(28,28)))
				text_at(p+Vector2(-8,7), "+", 26, MINT)
				text_at(p+Vector2(-22,-24), "PART", 14, MINT)
	draw_ship(Vector2(150-camera_x, 385), 0.7)
	draw_astronaut(pos-Vector2(camera_x,0))
	if mode == "play":
		for data in [[Rect2(18, 532, 96, 88), "<", "left"], [Rect2(132, 532, 96, 88), ">", "right"], [Rect2(802, 532, 140, 88), "JET", "jet"]]:
			draw_style_box(panel_style(), data[0])
			text_at(data[0].position + Vector2(23, 55), data[1], 27, GOLD if pressed(data[2]) else MINT)
		text_at(Vector2(284, 592), "A quiet corner of the universe", 18, Color("8198b3"))
	if mode == "workshop":
		draw_ship(Vector2(92, 255), 0.9)

func draw_astronaut(p: Vector2) -> void:
	var suit := Color("f59e9c") if astronaut == "girl" else Color("92c9ed")
	if mode == "play" and pressed("jet"):
		draw_colored_polygon(PackedVector2Array([p+Vector2(-20,10),p+Vector2(-8,10),p+Vector2(-14,40+sin(clock*25)*8)]), GOLD)
	draw_style_box(panel_style(), Rect2(p+Vector2(-24,-6),Vector2(15,25)))
	draw_line(p+Vector2(-7,15),p+Vector2(-9,28),suit,9,true)
	draw_line(p+Vector2(7,15),p+Vector2(10,28),suit,9,true)
	draw_circle(p+Vector2(0,5),16,suit)
	draw_circle(p+Vector2(0,-16),21,Color("eff5e9"))
	draw_circle(p+Vector2(2,-16),15,Color("284663"))
	draw_circle(p+Vector2(7,-20),4,Color("88b5cb"))
	draw_line(p+Vector2(12,1),p+Vector2(20,10),suit,7,true)

func draw_ship(p: Vector2, scale_value: float) -> void:
	draw_set_transform(p, 0, Vector2.ONE * scale_value)
	draw_line(Vector2(-58,35),Vector2(58,35),Color("7895ac"),5)
	if installed >= 1:
		draw_colored_polygon(PackedVector2Array([Vector2(-40,25),Vector2(-30,-25),Vector2(30,-25),Vector2(40,25)]), MINT)
	if installed >= 2:
		draw_circle(Vector2(0,-30),30,MINT)
		draw_circle(Vector2(0,-32),20,Color("9ee7ff") if "Crystal window" in upgrades else Color("395a79"))
	if installed >= 3:
		for x in [-35, 35]:
			draw_rect(Rect2(x-9,10,18,30),Color("f59e9c"))
			draw_circle(Vector2(x,42),7,GOLD)
	if "Golden fins" in upgrades:
		for side in [-1,1]:
			draw_colored_polygon(PackedVector2Array([Vector2(side*30,-15),Vector2(side*65,25),Vector2(side*30,20)]),GOLD)
	if "Garden lights" in upgrades:
		for i in range(7): draw_circle(Vector2(-48+i*16,30),4,Color("f59e9c") if i%2 else GOLD)
	if installed == 0: text_at(Vector2(-45,15), "SHIPYARD", 15, MINT)
	draw_set_transform(Vector2.ZERO)
