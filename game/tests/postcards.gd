extends Node
var main: Node
const OUT := "/tmp/claude-0/-home-user-friendslop3/4bd29a08-0e08-53e0-b582-50343e0fcfef/scratchpad/pc"
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [OUT, n])
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var g: Game = main.game
	var me: Courier = g.local_courier()
	g._srv_depart()
	me.look_yaw = 2.4
	await get_tree().create_timer(0.5).timeout
	me.pop(Vector3.LEFT)
	await get_tree().create_timer(4.0).timeout
	# deliver a parcel by dropping it into its chute
	var p: Parcel = g.parcels.values()[1]
	var isl: Island = g.islands[p.address]
	me.reinflate()
	me.global_position = isl.chute_pos + Vector3(3, 1, 3)
	me.on_board = false
	me.look_yaw = atan2(3, 3)
	me.look_pitch = -0.3
	p.global_position = isl.chute_pos + Vector3(0, 4.5, 0)
	p.linear_velocity = Vector3.ZERO
	p.air_time = 2.0
	await get_tree().create_timer(0.5).timeout
	await shot("a_confetti")
	await get_tree().create_timer(3.0).timeout
	print("delivered=", g.delivered, " cards=", g.postcards.cards.size())
	g.day_t = g.day_len
	await get_tree().create_timer(1.0).timeout
	await shot("b_results")
	get_tree().quit()
