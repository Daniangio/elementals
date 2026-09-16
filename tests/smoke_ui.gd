extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Control = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	for screen_name in ["Collection", "Fusion", "Deck", "Match"]:
		scene._show_screen(screen_name)
		await process_frame
		var screen: Control = scene.content.get_child(0)
		print("PASS UI: %s viewport=%s minimum=%s actual=%s" % [screen_name, scene.size, screen.get_combined_minimum_size(), screen.size])
	quit(0)
