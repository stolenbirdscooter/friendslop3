class_name Settings
extends RefCounted
## Player comfort settings, persisted by main.gd in user://prefs.cfg.

static var fov := 70.0
static var invert_y := false
static var sens := 1.0
static var master := 1.0
static var music := 1.0

static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.001)))
	var tree := Engine.get_main_loop() as SceneTree
	var m: Node = tree.root.get_node_or_null("Music") if tree else null
	if m and m.has_method("set_volume_db"):
		m.set_volume_db(-12.0 + linear_to_db(maxf(music, 0.001)))
