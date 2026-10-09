extends Node
var main: Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var g: Game = main.game
	var me: Courier = g.local_courier()
	var best: Island
	for isl in g.islands:
		if not isl.is_home and isl.get_child_count() > 0:
			for c in isl.get_children():
				if c is MeshInstance3D and c.mesh is QuadMesh:
					best = isl
	if best:
		me.global_position = best.top_center + Vector3(30, 5, 30)
		me.on_board = false
		me.puffed = true
		me.look_yaw = atan2(30, 30)
		me.look_pitch = -0.15
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-user-friendslop3/4bd29a08-0e08-53e0-b582-50343e0fcfef/scratchpad/vista.png")
	get_tree().quit()
