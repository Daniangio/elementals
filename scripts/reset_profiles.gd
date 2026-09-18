extends SceneTree

func _init() -> void:
	for user_path in ["user://accounts.json", "user://profile.json", "user://elementals_debug_profile.json"]:
		var absolute := ProjectSettings.globalize_path(user_path)
		if FileAccess.file_exists(user_path):
			var error := DirAccess.remove_absolute(absolute)
			print("Removed %s (%s)" % [absolute, error_string(error)])
		else:
			print("Not present: %s" % absolute)
	quit()
