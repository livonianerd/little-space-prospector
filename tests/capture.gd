extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.save_enabled = false
	game.start_game()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/prospector-game.png")
	game.parts = ["p1", "p3", "p5"]
	game.installed = 3
	game.upgrades = ["Golden fins", "Crystal window", "Garden lights"]
	game.rebuild_ship()
	game.show_workshop()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/prospector-workshop.png")
	quit()
