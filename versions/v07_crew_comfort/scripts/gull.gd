class_name Gull
extends Node3D
## A post-hating gull. Circles the balloon, then dives to steal a parcel or peck
## a courier (pop!). Squeaks, shoves and thrown parcels scare it off.

enum S { CIRCLE, DIVE, FLEE, SCARED }

var gid := 0
var game: Game
var state := S.CIRCLE
var vel := Vector3.ZERO
var carrying := 0
var target_parcel := 0
var target_peer := 0
var _t := 0.0
var _orbit := 0.0
var _wing_l: Node3D
var _wing_r: Node3D
var _goal := Vector3.ZERO
var _squawk_t := 2.0

func _ready() -> void:
	add_to_group("gull")
	var white := Pal.toon(Color("fbf7ee"), 0.2, 0.03, 0.3)
	var grey := Pal.toon(Color("9aa3b5"), 0.0, 0.025)
	var tip := Pal.toon(Color("3a3f52"), 0.0, 0.0)
	var m := Node3D.new()
	m.scale = Vector3.ONE * 1.6
	add_child(m)
	Pal.add(m, Pal.sphere(1.0, 14, 8), white, Vector3.ZERO, Vector3.ZERO, Vector3(0.3, 0.26, 0.55))
	Pal.add(m, Pal.sphere(0.2, 12, 8), white, Vector3(0, 0.12, -0.5))
	var beak := Pal.add(m, Pal.cyl(0.0, 0.07, 0.3, 6), Pal.toon(Color("f2a33d"), 0.3, 0.015), Vector3(0, 0.08, -0.75), Vector3(-PI / 2, 0, 0))
	beak.scale = Vector3(1, 1, 0.8)
	for s in [-1.0, 1.0]:
		Pal.add(m, Pal.sphere(0.035, 6, 4), Pal.toon(Pal.INK, 0.5, 0.0), Vector3(s * 0.11, 0.18, -0.64))
		# scowl
		Pal.add(m, Pal.box(Vector3(0.1, 0.022, 0.02)), Pal.toon(Pal.INK, 0.0, 0.0), Vector3(s * 0.1, 0.24, -0.65), Vector3(0, 0, s * 0.45))
	Pal.add(m, Pal.prism(Vector3(0.36, 0.3, 0.05)), grey, Vector3(0, 0.02, 0.62), Vector3(-PI / 2, 0, 0))
	_wing_l = Node3D.new()
	_wing_r = Node3D.new()
	for w in [[_wing_l, -1.0], [_wing_r, 1.0]]:
		var piv: Node3D = w[0]
		var sd: float = w[1]
		piv.position = Vector3(sd * 0.22, 0.1, -0.05)
		m.add_child(piv)
		Pal.add(piv, Pal.box(Vector3(0.8, 0.04, 0.36)), grey, Vector3(sd * 0.42, 0, 0))
		Pal.add(piv, Pal.box(Vector3(0.3, 0.045, 0.3)), tip, Vector3(sd * 0.92, 0, 0.02))

func carry_point() -> Transform3D:
	return Transform3D(global_basis, global_position + global_basis * Vector3(0, -0.45, -0.2))

func _process(dt: float) -> void:
	_t += dt
	var flap := 12.0 if state != S.CIRCLE else 5.0
	var a := sin(_t * flap) * 0.7
	if state == S.CIRCLE and fmod(_t, 3.0) > 1.6:
		a = 0.15
	_wing_l.rotation.z = a
	_wing_r.rotation.z = -a
	_squawk_t -= dt
	if _squawk_t <= 0.0:
		_squawk_t = randf_range(3.0, 7.0) if state == S.CIRCLE else randf_range(0.8, 1.6)
		Sfx.play3d("squawk" if Sfx.has_sound("squawk") else "squeak", global_position, randf_range(0.9, 1.15), -2.0)

## Host only.
func simulate(dt: float) -> void:
	var bal := game.balloon
	var bt := bal.xform()
	match state:
		S.CIRCLE:
			_orbit += dt * 0.55
			var c := bt.origin + Vector3(0, 5.0, 0)
			_goal = c + Vector3(cos(_orbit) * 11.0, sin(_t * 0.8) * 2.0, sin(_orbit) * 11.0)
			_steer(_goal, 10.0, dt)
			if _t > 6.0:
				_pick_target()
		S.DIVE:
			var tp := _target_pos()
			if tp == Vector3.INF or _t > 7.0:
				state = S.CIRCLE
				_t = 0.0
			else:
				_steer(tp + Vector3(0, 0.35, 0), 12.5, dt)
				if global_position.distance_to(tp) < 1.0:
					_strike()
		S.FLEE, S.SCARED:
			var away := global_position - bt.origin
			away.y = 0
			_goal = global_position + away.normalized() * 20.0 + Vector3(0, 6, 0)
			_steer(_goal, 9.0, dt)
			if global_position.distance_to(bt.origin) > 70.0:
				if carrying != 0:
					var p: Parcel = game.parcels.get(carrying)
					if p:
						game.parcel_stolen(p)
				game.despawn_gull(gid)
				return
	# thrown parcels bonk us
	if state != S.SCARED:
		for p in game.parcels.values():
			if p.holder == 0 and p.linear_velocity.length() > 5.0 and p.global_position.distance_to(global_position) < 1.3:
				game.add_stat(p.last_thrower, "bonks", 1)
				game.toast("BONK! %s beaned a gull." % Net.pname(p.last_thrower), Color("f2b33d"))
				scare()
				break

func _steer(goal: Vector3, speed: float, dt: float) -> void:
	var want := (goal - global_position).limit_length(speed)
	if want.length() < speed * 0.5:
		want = want.normalized() * speed * 0.5
	vel = vel.move_toward(want, 18.0 * dt)
	global_position += vel * dt
	if vel.length() > 0.5:
		var f := vel.normalized()
		var b := Basis.looking_at(f, Vector3.UP)
		global_basis = global_basis.slerp(b, minf(dt * 6.0, 1.0)).orthonormalized()

func _pick_target() -> void:
	var bal := game.balloon
	var loose: Array = []
	for p in game.parcels.values():
		if p.holder == 0 and bal.is_inside(p.global_position):
			loose.append(p)
	var crew: Array = []
	for c in game.couriers.values():
		if not c.lost and not c.flat and c.pop_t <= 0.0 and c.carried_by == 0 and bal.is_inside(c.global_position):
			crew.append(c)
	_t = 0.0
	if not loose.is_empty() and (crew.is_empty() or randf() < 0.7):
		target_parcel = loose[randi() % loose.size()].pid
		target_peer = 0
		state = S.DIVE
	elif not crew.is_empty():
		target_peer = crew[randi() % crew.size()].peer
		target_parcel = 0
		state = S.DIVE
	else:
		_t = 3.0

func _target_pos() -> Vector3:
	if target_parcel != 0:
		var p: Parcel = game.parcels.get(target_parcel)
		if p and p.holder == 0:
			return p.global_position
	elif target_peer != 0:
		var c: Courier = game.courier(target_peer)
		if c and not c.lost and not c.flat:
			return c.global_position + Vector3(0, 1.0, 0)
	return Vector3.INF

func _strike() -> void:
	if target_parcel != 0:
		carrying = target_parcel
		game.gull_grab(self, target_parcel)
	elif target_peer != 0:
		var c: Courier = game.courier(target_peer)
		if c:
			c.pop.rpc_id(c.peer, vel.normalized())
			game.toast("A gull pecked %s! POP!" % c.pname, Color("e8574a"))
	state = S.FLEE
	_t = 0.0

func scare() -> void:
	if state == S.SCARED:
		return
	state = S.SCARED
	_t = 0.0
	vel += Vector3(0, 6, 0)
	if carrying != 0:
		game.gull_drop(self, carrying)
		carrying = 0
