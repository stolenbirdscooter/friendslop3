extends Node
var main: Node
const OUT := "/tmp/claude-0/-home-user-friendslop3/4bd29a08-0e08-53e0-b582-50343e0fcfef/scratchpad/mp"
func _ready() -> void:
	await get_tree().create_timer(4.0).timeout
	var g: Game = main.game
	var me: Courier = g.local_courier()
	var host: Courier = g.courier(1)
	print("CLIENT couriers=", g.couriers.size(), " parcels=", g.parcels.size(), " phase=", g.phase)
	g.request_depart()
	await get_tree().create_timer(0.5).timeout
	print("CLIENT phase after bell=", g.phase)
	me.global_position = host.global_position + Vector3(0.8, 0.2, 0)
	await get_tree().create_timer(0.3).timeout
	host.carry_request.rpc_id(1, me.peer)
	await get_tree().create_timer(0.8).timeout
	print("CLIENT carrying=", me.carrying, " host.carried_by=", host.carried_by)
	me.look_yaw = PI / 2
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "_carry.png")
	me.charge = 1.0
	me._throw()
	await get_tree().create_timer(1.0).timeout
	print("CLIENT after throw carrying=", me.carrying, " host pos=", host.global_position.snapped(Vector3.ONE * 0.1))
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
