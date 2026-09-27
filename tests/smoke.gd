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
	game.start_game("girl")
	check(game.astronaut == "girl" and game.mode == "play", "Character selection")
	# Fly the actual physics route to each part, then land on its asteroid.
	for index in [1, 3, 5]:
		var target: Vector3 = game.islands[index]
		for frame in range(1800):
			var dx: float = target.x + 25 - game.pos.x
			var direction: float = clampf(dx / 55.0, -1, 1)
			game.step_motion(1.0 / 60.0, direction, game.pos.y > target.y - 75)
			game.collect_nearby()
			if "p%d" % index in game.parts: break
		check("p%d" % index in game.parts, "Reachable component %d" % index)
	game.show_workshop()
	for i in range(3): game.install_part()
	check(game.installed == 3, "Complete spaceship")
	game.install_part()
	check(game.installed == 3, "No duplicate installation")
	game.gold = 20
	game.diamonds = 8
	game.buy_upgrade("Golden fins", 6, 0)
	game.buy_upgrade("Golden fins", 6, 0)
	check(game.gold == 14 and game.upgrades.size() == 1, "Purchase charged once")
	game.safe = Vector2(480, 360)
	game.pos = Vector2(600, 720)
	game.step_motion(1.0/60, 0, false)
	check(game.pos == game.safe, "Missed jump recovery")
	game.mode = "play"
	game.return_home()
	check(game.parts.size() == 3 and game.collected.size() == 3, "Regrowth preserves unique parts")
	print("SMOKE: %d failures" % failures)
	quit(1 if failures else 0)
