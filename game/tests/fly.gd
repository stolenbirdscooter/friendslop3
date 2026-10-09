extends Node
## Scripted playtest: pump up, catch a wind, pick up and throw a parcel, screenshot along the way.
var main: Node
const OUT := "/tmp/claude-0/-home-user-friendslop3/4bd29a08-0e08-53e0-b582-50343e0fcfef/scratchpad/fly"

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [OUT, n])

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var g: Game = main.game
	var me: Courier = g.local_courier()
	me.look_yaw = PI * 0.8
	me.look_pitch = -0.35
	await get_tree().create_timer(0.5).timeout
	await shot("a_basket")
	# pick up a parcel
	var p: Parcel = g.parcels.values()[0]
	me.global_position = p.global_position + Vector3(0.6, 0, 0.6)
	await get_tree().create_timer(0.2).timeout
	g.request_pickup(p.pid)
	await get_tree().create_timer(0.3).timeout
	print("holding=", me.holding)
	me.charge = 0.0
	await get_tree().create_timer(0.4).timeout
	await shot("b_charge")
	me._throw()
	await get_tree().create_timer(0.5).timeout
	await shot("c_thrown")
	for i in 14:
		g.balloon.request_pump()
		await get_tree().create_timer(0.6).timeout
	print("alt=", g.balloon.altitude(), " heat=", g.balloon.heat, " vel=", g.balloon.vel)
	await shot("d_rising")
	await get_tree().create_timer(8.0).timeout
	print("alt=", g.balloon.altitude(), " heat=", g.balloon.heat, " vel=", g.balloon.vel, " landed=", g.balloon.landed)
	me.look_pitch = -0.1
	await shot("e_flying")
	# jump overboard to test puffing
	me.global_position = g.balloon.xform() * Vector3(3.5, 1.5, 0)
	me.on_board = false
	Input.action_press("jump")
	await get_tree().create_timer(1.5).timeout
	await shot("f_puff")
	print("puffed=", me.puffed, " air=", me.air, " vy=", me.velocity.y)
	Input.action_release("jump")
	g.day_t = g.day_len * 0.93
	await get_tree().create_timer(2.0).timeout
	await shot("g_dusk")
	print("parcels=", g.parcels.size(), " lost=", g.lost_count, " delivered=", g.delivered)
	get_tree().quit()
