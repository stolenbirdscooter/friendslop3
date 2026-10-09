extends Node
var main: Node
func _ready() -> void:
	var g: Game = main.game
	for i in 30:
		await get_tree().create_timer(0.5).timeout
		var me: Courier = g.local_courier()
		if me:
			print("HOST t=%.1f carried_by=%d pos=%s couriers=%d phase=%s" % [i * 0.5, me.carried_by, me.global_position.snapped(Vector3.ONE * 0.1), g.couriers.size(), g.phase])
	get_tree().quit()
