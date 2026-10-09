extends Node
## Playtest v02 hazards: gull, bramble pop, carry & throw, fragile smash, patch.
var main: Node
const OUT := "/tmp/claude-0/-home-user-friendslop3/4bd29a08-0e08-53e0-b582-50343e0fcfef/scratchpad/mh"

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [OUT, n])

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var g: Game = main.game
	var me: Courier = g.local_courier()
	print("flavors=", g.parcels.values().map(func(p): return p.flavor))
	# take off
	for i in 8:
		g.balloon.request_pump()
		await get_tree().create_timer(0.3).timeout
	# gull
	g._gull_t = 0.0
	g.day = 2
	await get_tree().create_timer(4.0).timeout
	me.look_yaw = 0.6
	me.look_pitch = -0.1
	await shot("a_gull")
	print("gulls=", g.gulls.size(), " state=", g.gulls.values().map(func(x): return x.state))
	await get_tree().create_timer(6.0).timeout
	print("after dive gulls=", g.gulls.values().map(func(x): return [x.state, x.carrying]), " flat=", me.flat, " pop=", me.pop_t)
	me._do_squeak(1.0)
	await get_tree().create_timer(0.2).timeout
	print("after squeak=", g.gulls.values().map(func(x): return x.state))
	# pop + flat
	me.pop(Vector3.RIGHT)
	await get_tree().create_timer(2.0).timeout
	print("flat=", me.flat)
	await shot("b_flat")
	# prick envelope
	g.balloon._fx_pricked(2)
	await get_tree().create_timer(0.5).timeout
	me.look_pitch = 0.6
	await shot("c_leaks")
	g.balloon._srv_patch()
	print("leaks=", g.balloon.leaks)
	me.reinflate()
	# smash fragile: throw it down hard against the floor
	for p in g.parcels.values():
		if p.flavor == "fragile":
			p.global_position = g.balloon.xform() * Vector3(0, 3, 0)
			p.linear_velocity = Vector3(0, -16, 0) + g.balloon.vel
			p.air_time = 1.0
	for i in 8:
		await get_tree().physics_frame
		for p in g.parcels.values():
			if p.flavor == "fragile":
				print(p.global_position, p._prev_v, p.linear_velocity, p.freeze, p.holder)
	await get_tree().create_timer(1.0).timeout
	print("lost=", g.lost_count, " parcels=", g.parcels.size())
	get_tree().quit()
