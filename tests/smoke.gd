extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.save_enabled = false
	game.start_game()
	game.set_physics_process(false)
	for index in range(game.asteroids.size()):
		check(game.destinations(index).size() >= 2, "Two branches from asteroid %d" % index)
	# Walk more than a full great circle, including both poles; measure every frame.
	var lowest := 1.0
	for direction in [Vector2.UP, Vector2.RIGHT]:
		game.normal = Vector3.UP
		game.forward = Vector3.FORWARD
		for i in range(1500):
			game.step_surface(1.0/60, direction)
			game.update_camera(1.0/60)
			lowest = minf(lowest, game.normal.y)
			check(absf(game.normal.dot(game.forward)) < 0.001, "Tangent frame remains orthogonal")
			check(game.camera.transform.is_finite(), "Camera finite through poles")
			for a in game.asteroids:
				check(game.camera.position.distance_to(a.center) > a.radius * 1.045, "Camera stays outside stones")
			check(absf(game.pilot.position.distance_to(game.asteroids[0].center) - game.surface_radius(0, game.normal) - .045) < .001, "Feet follow surface")
	check(lowest < -.99, "Reached underside")
	game.return_home()
	for destination in [1, 2, 0]:
		game.start_hop(destination)
		for i in range(135): game.step_hop(1.0/60) if game.hop_time >= 0 else null
		check(game.current == destination and game.hop_time < 0, "Landing on %d" % destination)
	# Every edge must have a clear assisted route from all six sides of a stone.
	for origin in range(game.asteroids.size()):
		for destination in game.destinations(origin):
			for n in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				game.current = origin
				game.normal = n
				game.forward = Vector3.FORWARD if absf(n.z) < 0.5 else Vector3.UP
				game.place_pilot()
				game.refresh_destinations()
				game.start_hop(destination)
				check(game.hop_target == destination and game.hop_path_clear(), "Clear hop %d -> %d from %s" % [origin, destination, n])
				game.hop_time = -1
	game.return_home()
	var safe_position: Vector3 = game.pilot.position
	game.start_hop(999)
	for i in range(135):
		if game.hop_time >= 0: game.step_hop(1.0/60)
	check(game.current == 0 and game.pilot.position.distance_to(safe_position) < .001, "Miss safely returns to departure")
	# Approach every resource using real tangent motion, not direct collection calls at teleported loot positions.
	for item in game.loot:
		game.current = item.asteroid
		game.normal = Vector3.UP
		game.forward = Vector3.FORWARD
		game.place_pilot()
		for i in range(800):
			var tangent: Vector3 = item.normal - game.normal * item.normal.dot(game.normal)
			if tangent.length() < .0001: break
			tangent = tangent.normalized()
			var right: Vector3 = game.forward.cross(game.normal)
			game.step_surface(1.0/60, Vector2(tangent.dot(right), -tangent.dot(game.forward)))
			game.collect_nearby()
			if item.id in game.collected: break
		check(item.id in game.collected, "Reach surface resource " + item.id)
	var previous_gold: int = game.gold
	game.collect_nearby()
	check(game.gold == previous_gold, "No duplicate collection")
	game.return_home()
	game.gold = 30
	game.diamonds = 15
	var initial_range: float = game.hop_range()
	game.buy_upgrade("Golden fins")
	game.buy_upgrade("Golden fins")
	check(game.gold == 24 and game.hop_range() == initial_range + 4, "Fins charged once and extend range")
	game.buy_upgrade("Crystal window")
	game.close_modal()
	game.select_target(1)
	check("Scanner" in game.toast, "Scanner reveals remaining contents")
	game.parts = ["p1", "p3", "p5"]
	for id in game.parts:
		if id not in game.collected: game.collected.append(id)
	for i in range(4): game.install_part()
	check(game.installed == 3, "Install all components only once")
	game.close_modal()
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.pressed = true
	touch.position = Vector2(180, 570)
	game._input(touch)
	check(game.movement_input().x == 1, "Touch movement")
	touch.pressed = false
	game._input(touch)
	check(game.movement_input() == Vector2.ZERO, "Touch release clears movement")
	game.music_on = false
	game.save_path = "user://smoke-save.json"
	game.save_enabled = true
	game.save_progress()
	var restored = load("res://main.tscn").instantiate()
	root.add_child(restored)
	restored.save_path = game.save_path
	restored.save_enabled = true
	restored.load_progress()
	check(restored.installed == 3 and restored.parts.size() == 3, "Ship save round trip")
	check(restored.gold == 24 and restored.diamonds == 12, "Inventory save round trip")
	check(not restored.music_on and restored.collected == game.collected, "Audio and collected resources save round trip")
	check(game.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Music loops")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	game.save_enabled = false
	restored.save_enabled = false
	game.music.stop()
	game.sfx.stop()
	restored.music.stop()
	restored.sfx.stop()
	await create_timer(0.15).timeout
	game.queue_free()
	restored.queue_free()
	await process_frame
	await process_frame
	print("SMOKE: %d failures; %d asteroids" % [failures, 3 if "--prototype" in OS.get_cmdline_user_args() else 9])
	quit(1 if failures else 0)
