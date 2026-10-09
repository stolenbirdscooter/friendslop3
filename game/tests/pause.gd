extends Node
var main: Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	main.game.hud.toggle_pause()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-user-friendslop3/4bd29a08-0e08-53e0-b582-50343e0fcfef/scratchpad/pause.png")
	main.game.hud.toggle_pause()
	print("pause ok, prefs saved")
	get_tree().quit()
