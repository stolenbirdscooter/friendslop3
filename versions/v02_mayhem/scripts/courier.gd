class_name Courier
extends CharacterBody3D
## An inflatable rubber postal courier. The owning peer simulates it; everyone
## else interpolates. While inside the basket, position is kept in balloon-local
## space so the moving, tilting basket carries you perfectly.

const SPEED := 4.6
const ACCEL := 32.0
const AIR_ACCEL := 7.0
const JUMP := 6.6
const GRAV := 19.0
const PUFF_FALL := 1.7
const SEND_RATE := 1.0 / 20.0

var peer := 1
var pname := "Windbag"
var color := Color.RED
var weight := 1.0
var game: Game
var balloon: Balloon
var is_local := false

var air := 1.0
var puffed := false
var holding := 0
var at_helm := false
var lost := false
var lost_t := 0.0
var on_board := false
var charge := -1.0          # >=0 while winding up a throw
var squeak_t := 0.0
var shove_cd := 0.0
var facing := 0.0           # model yaw (world when off board, balloon-relative when on)
var look_yaw := 0.0
var look_pitch := -0.25
var target: Node = null     # interactable under consideration
var vent_held := false
var carried_by := 0         # peer carrying us
var carrying := 0           # peer we are carrying
var pop_t := 0.0            # >0 while zipping about after a pop
var flat := false           # deflated pancake: needs reinflating
var flat_t := 0.0
var wriggle := 0
var patch_t := 0.0
var _zip_dir := Vector3.ZERO

var _board_local := Vector3.ZERO
var _last_bal_yaw := 0.0
var _send_t := 0.0
var _anim_t := 0.0
var _step_t := 0.0
var _was_floor := true
var _blink_t := 2.0
var _land_squash := 0.0
var _mouse_delta := Vector2.ZERO

# remote interpolation
var _r_board := false
var _r_pos := Vector3.ZERO
var _r_vel := Vector3.ZERO
var _r_face := 0.0
var _r_init := false

# model parts
var model: Node3D
var body: MeshInstance3D
var arm_l: Node3D
var arm_r: Node3D
var foot_l: Node3D
var foot_r: Node3D
var eyes: Node3D
var mouth: MeshInstance3D
var tag: Label3D
var cam_rig: Node3D
var spring: SpringArm3D
var cam: Camera3D

func _ready() -> void:
	add_to_group("courier")
	add_to_group("weight")
	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(52)
	floor_stop_on_slope = false
	floor_snap_length = 0.25
	platform_floor_layers = 0
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.22
	cs.shape = cap
	cs.position.y = 0.61
	add_child(cs)
	_build_model()
	if is_local:
		_build_camera()
	else:
		tag = Pal.label3d(pname, 40, color.darkened(0.35))
		tag.position.y = 1.85
		tag.pixel_size = 0.006
		tag.no_depth_test = true
		add_child(tag)
	if balloon:
		_last_bal_yaw = balloon.yaw

func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var rubber := Pal.toon(color, 1.0, 0.028, 0.3)
	var dark := Pal.toon(Pal.INK, 0.4, 0.0)
	body = Pal.add(model, Pal.sphere(0.42, 22, 14), rubber, Vector3(0, 0.64, 0), Vector3.ZERO, Vector3(1.0, 1.22, 0.96))
	# belly sheen: lighter oval
	Pal.add(body, Pal.sphere(0.3, 14, 8), Pal.toon(color.lightened(0.25), 1.0, 0.0, 0.2), Vector3(0, -0.12, -0.17), Vector3.ZERO, Vector3(1, 1, 0.55))
	# face
	eyes = Node3D.new()
	eyes.position = Vector3(0, 0.88, -0.33)
	model.add_child(eyes)
	for s in [-1.0, 1.0]:
		var e := Pal.add(eyes, Pal.sphere(0.095, 12, 8), Pal.toon(Color.WHITE, 0.8, 0.012), Vector3(s * 0.13, 0, 0), Vector3.ZERO, Vector3(1, 1.15, 0.7))
		Pal.add(e, Pal.sphere(0.055, 10, 6), dark, Vector3(s * -0.01, -0.01, -0.06))
		Pal.add(e, Pal.sphere(0.018, 6, 4), Pal.unshaded(Color.WHITE), Vector3(s * -0.03, 0.025, -0.1))
		Pal.add(model, Pal.sphere(0.06, 8, 6), Pal.toon(Color("f39aa0"), 0.0, 0.0), Vector3(s * 0.23, 0.74, -0.34), Vector3.ZERO, Vector3(1, 0.6, 0.4))
	mouth = Pal.add(model, Pal.capsule(0.03, 0.12), dark, Vector3(0, 0.71, -0.4), Vector3(0, 0, PI / 2))
	# postal cap with the balloon knot poking through
	var capn := Node3D.new()
	capn.position = Vector3(0, 1.12, 0.02)
	capn.rotation.x = -0.12
	model.add_child(capn)
	Pal.add(capn, Pal.cyl(0.27, 0.29, 0.17, 16), Pal.toon(Pal.NAVY, 0.2, 0.022), Vector3(0, 0.05, 0))
	Pal.add(capn, Pal.cyl(0.3, 0.3, 0.035, 16), Pal.toon(Pal.NAVY.darkened(0.2), 0.2, 0.015), Vector3(0, 0.0, -0.13), Vector3.ZERO, Vector3(0.95, 1, 0.9))
	Pal.add(capn, Pal.box(Vector3(0.1, 0.07, 0.03)), Pal.toon(Pal.BRASS, 0.9, 0.0), Vector3(0, 0.07, -0.27))
	Pal.add(capn, Pal.cyl(0.0, 0.06, 0.12, 8), rubber, Vector3(0, 0.19, 0))
	Pal.add(capn, Pal.sphere(0.045, 8, 6), rubber, Vector3(0, 0.25, 0))
	# satchel
	Pal.add(model, Pal.box(Vector3(0.12, 0.3, 0.38)), Pal.toon(Color("8a5a32"), 0.2, 0.02, 0.1, 0.1), Vector3(0.43, 0.48, 0.05), Vector3(0, 0, -0.15))
	# limbs
	arm_l = _limb(Vector3(-0.4, 0.72, 0), rubber, 0.09, 0.4)
	arm_r = _limb(Vector3(0.4, 0.72, 0), rubber, 0.09, 0.4)
	foot_l = Node3D.new()
	foot_r = Node3D.new()
	for f in [[foot_l, -0.17], [foot_r, 0.17]]:
		var n: Node3D = f[0]
		n.position = Vector3(f[1], 0.09, -0.02)
		model.add_child(n)
		Pal.add(n, Pal.sphere(0.13, 10, 6), rubber, Vector3(0, 0, -0.05), Vector3.ZERO, Vector3(1, 0.62, 1.35))

func _limb(pos: Vector3, mat: Material, r: float, h: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	model.add_child(pivot)
	Pal.add(pivot, Pal.capsule(r, h), mat, Vector3(0, -h * 0.4, 0))
	return pivot

func _build_camera() -> void:
	cam_rig = Node3D.new()
	cam_rig.top_level = true
	add_child(cam_rig)
	spring = SpringArm3D.new()
	spring.spring_length = 4.6
	spring.collision_mask = 1
	spring.margin = 0.3
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	spring.shape = sph
	cam_rig.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 70
	cam.near = 0.08
	cam.far = 2400.0
	spring.add_child(cam)
	cam.current = true
	if balloon:
		spring.add_excluded_object(balloon.get_rid())
	spring.add_excluded_object(get_rid())
	cam_rig.global_position = global_position + Vector3(0, 1.3, 0)

# ------------------------------------------------------------------ input
func _unhandled_input(e: InputEvent) -> void:
	if not is_local or game == null or not game.input_enabled():
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += e.relative
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring.spring_length = maxf(spring.spring_length - 0.4, 2.2)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring.spring_length = minf(spring.spring_length + 0.4, 9.0)
	if lost or pop_t > 0.0:
		return
	if carried_by != 0:
		if e.is_action_pressed("jump"):
			wriggle += 1
			_land_squash = 0.3
			Sfx.play3d("squeak_short", global_position, 1.6, -4.0)
			if wriggle >= 5:
				_break_free()
		if e.is_action_pressed("squeak"):
			_do_squeak.rpc(clampf(1.15 - look_pitch * 0.9, 0.55, 1.9))
		return
	if flat:
		if e.is_action_pressed("squeak"):
			_do_squeak.rpc(0.5)
		return
	if e.is_action_pressed("interact"):
		_interact(true)
	elif e.is_action_released("interact"):
		_interact(false)
	if e.is_action_pressed("squeak"):
		_do_squeak.rpc(clampf(1.15 - look_pitch * 0.9, 0.55, 1.9))
	if e.is_action_pressed("action"):
		if holding != 0 or carrying != 0:
			charge = 0.0
		elif not at_helm:
			_shove()
	elif e.is_action_released("action") and charge >= 0.0:
		_throw()

func _interact(pressed: bool) -> void:
	if at_helm:
		if pressed:
			toggle_helm()
		return
	if not pressed:
		if vent_held:
			vent_held = false
			balloon.request_vent(false)
		return
	if holding != 0:
		game.request_drop(holding, _hand_world(), velocity_world() * 0.5)
		return
	if carrying != 0:
		var other: Courier = game.courier(carrying)
		if other and other.flat and target is Station and target.kind == Station.Kind.PUMP:
			other.reinflate.rpc_id(other.peer)
			target.use(self, true)
			game.add_stat(peer, "rescues", 1)
		elif other:
			other.thrown.rpc_id(other.peer, velocity_world() * 0.5 + Vector3.UP * 2.0, peer)
		return
	if target == null:
		return
	if target is Courier:
		target.carry_request.rpc_id(target.peer, peer)
	elif target is Parcel:
		game.request_pickup(target.pid)
	elif target is Station:
		if target.kind == Station.Kind.VENT:
			vent_held = true
		target.use(self, true)

# ------------------------------------------------------------------ carrying crewmates
@rpc("any_peer", "call_local", "reliable")
func carry_request(by: int) -> void:
	if not is_local or carried_by != 0 or lost or carrying != 0 or by == peer:
		return
	var c: Courier = game.courier(by)
	if c == null or c.carrying != 0 or c.holding != 0 or c.global_position.distance_to(global_position) > 3.0:
		return
	if holding != 0 and false:
		pass
	if at_helm:
		toggle_helm()
	carried_by = by
	wriggle = 0
	puffed = false
	_set_carry.rpc(by, peer, true)

@rpc("any_peer", "call_local", "reliable")
func thrown(vel: Vector3, by: int) -> void:
	if not is_local or carried_by != by:
		return
	carried_by = 0
	_update_board()
	velocity = vel - (balloon.vel if on_board else Vector3.ZERO)
	_land_squash = 0.4
	_set_carry.rpc(by, peer, false)
	if vel.length() > 6.0:
		game.add_stat(by, "tosses", 1)

func _break_free() -> void:
	var by := carried_by
	carried_by = 0
	_update_board()
	velocity = Vector3(randf_range(-2, 2), 5.0, randf_range(-2, 2))
	_set_carry.rpc(by, peer, false)
	Sfx.play3d("boing", global_position, 1.3, -2.0)

@rpc("any_peer", "call_local", "reliable")
func _set_carry(carrier: int, carried: int, on: bool) -> void:
	var c: Courier = game.courier(carrier)
	if c:
		c.carrying = carried if on else 0
		if not on:
			c.charge = -1.0
	if carried == peer:
		carried_by = carrier if on else 0
	if on:
		Sfx.play3d("grab", global_position, 0.8, -2.0)

# ------------------------------------------------------------------ popping
@rpc("any_peer", "call_local", "reliable")
func pop(dir: Vector3) -> void:
	if not is_local or pop_t > 0.0 or flat or lost:
		return
	if carried_by != 0:
		_set_carry.rpc(carried_by, peer, false)
		carried_by = 0
	if carrying != 0:
		var o: Courier = game.courier(carrying)
		if o:
			o.thrown.rpc_id(o.peer, Vector3.UP * 3.0, peer)
	if at_helm:
		toggle_helm()
	if holding != 0:
		game.request_drop(holding, _hand_world(), velocity_world())
	pop_t = 1.5
	_zip_dir = (dir + Vector3(randf_range(-1, 1), 0.8, randf_range(-1, 1))).normalized()
	velocity += _zip_dir * 9.0
	game.add_stat(peer, "pops", 1)
	_fx_pop.rpc()

@rpc("any_peer", "call_local", "reliable")
func _fx_pop() -> void:
	Sfx.play3d("pop", global_position + Vector3(0, 0.8, 0), 1.0, 2.0)
	Sfx.play3d("deflate", global_position, randf_range(0.9, 1.15), 0.0)
	if game.hud:
		game.hud.burst(global_position + Vector3(0, 0.8, 0))

@rpc("any_peer", "call_local", "reliable")
func reinflate() -> void:
	if not is_local or not flat:
		return
	flat = false
	velocity.y = 6.0
	_land_squash = -0.5
	_fx_reinflate.rpc()

@rpc("any_peer", "call_local", "reliable")
func _fx_reinflate() -> void:
	Sfx.play3d("puff", global_position, 1.2, 0.0)
	Sfx.play3d("boing", global_position, 0.8, -3.0)

func toggle_helm() -> void:
	at_helm = not at_helm
	balloon.request_helm(at_helm)
	if not at_helm:
		balloon.send_helm_input(0, 0)

# ------------------------------------------------------------------ simulation
func _physics_process(dt: float) -> void:
	_anim_t += dt
	squeak_t = maxf(squeak_t - dt, 0.0)
	if is_local:
		_local_step(dt)
	else:
		_remote_step(dt)
	_animate(dt)

func _check_brambles() -> void:
	if pop_t > 0.0 or flat or puffed and false:
		return
	for b in game.brambles:
		if b.active and b.hits(global_position + Vector3(0, 0.6, 0), 0.5):
			pop(global_position - b.pos())
			game.toast("%s got pricked by a bramble cloud!" % pname, Color("8a70d6"))
			return

func _patch_step(dt: float) -> void:
	var holding_patch: bool = target is Station and target.kind == Station.Kind.PATCH and game.input_enabled() and Input.is_action_pressed("interact")
	if holding_patch and balloon.leaks > 0:
		patch_t += dt
		if patch_t >= 2.0:
			patch_t = 0.0
			balloon.request_patch()
			game.add_stat(peer, "patches", 1)
	else:
		patch_t = 0.0

func velocity_world() -> Vector3:
	return velocity + (balloon.vel if on_board and balloon else Vector3.ZERO)

func _local_step(dt: float) -> void:
	if not game.input_enabled():
		_mouse_delta = Vector2.ZERO
	# camera look
	var sens := 0.0025 * game.mouse_sens
	look_yaw -= _mouse_delta.x * sens
	look_pitch = clampf(look_pitch - _mouse_delta.y * sens, -1.35, 0.9)
	_mouse_delta = Vector2.ZERO
	shove_cd = maxf(shove_cd - dt, 0.0)
	if charge >= 0.0:
		charge = minf(charge + dt * 1.4, 1.0)
	if lost:
		lost_t -= dt
		if lost_t <= 0.0:
			_respawn()
		_update_camera(dt)
		_send(dt)
		return
	if carried_by != 0:
		var c: Courier = game.courier(carried_by)
		if c == null or c.lost or c.carrying != peer and c.is_local:
			carried_by = 0
		else:
			global_position = c.hand_transform().origin + Vector3(0, -0.35, 0)
			velocity = Vector3.ZERO
			facing = c.facing
			model.rotation.y = facing
			_update_board()
			_update_camera(dt)
			_send(dt)
			return
	# ride the basket
	if on_board and balloon:
		global_position = balloon.xform() * _board_local
		var dyaw := wrapf(balloon.yaw - _last_bal_yaw, -PI, PI)
		look_yaw += dyaw
	if balloon:
		_last_bal_yaw = balloon.yaw
	var input := Vector2.ZERO
	if game.input_enabled() and not at_helm and pop_t <= 0.0:
		input = Input.get_vector("left", "right", "forward", "back")
	if flat:
		input *= 0.3
		flat_t -= dt
		if flat_t <= 0.0:
			flat = true
			reinflate()
			game.toast("%s blew themselves back up." % pname)
	_check_brambles()
	_patch_step(dt)
	var basis_yaw := Basis(Vector3.UP, look_yaw)
	var wish := basis_yaw * Vector3(input.x, 0, input.y)
	if at_helm:
		_helm_step(dt)
	var grounded := is_on_floor()
	var hv := Vector3(velocity.x, 0, velocity.z)
	var target_v := wish * SPEED * (0.8 if holding != 0 or carrying != 0 else 1.0)
	hv = hv.move_toward(target_v, (ACCEL if grounded else AIR_ACCEL) * dt)
	# puffing: hold jump while falling to inflate and glide
	var want_puff := game.input_enabled() and Input.is_action_pressed("jump") and not grounded and velocity.y < 1.0 and air > 0.0 and not flat and pop_t <= 0.0
	if want_puff != puffed:
		puffed = want_puff
		if puffed:
			Sfx.play3d("puff", global_position, randf_range(0.9, 1.1), -4.0)
	if pop_t > 0.0:
		# zipping about like a let-go balloon
		pop_t -= dt
		if randf() < dt * 7.0:
			_zip_dir = (_zip_dir + Vector3(randf_range(-1.4, 1.4), randf_range(-0.3, 1.0), randf_range(-1.4, 1.4))).normalized()
		hv = hv.move_toward(_zip_dir * 7.0, 40.0 * dt)
		velocity.y = move_toward(velocity.y, _zip_dir.y * 6.0, 30.0 * dt)
		if pop_t <= 0.0:
			flat = true
			flat_t = 22.0
	elif puffed:
		air = maxf(air - dt * 0.11, 0.0)
		var wind := Wind.at(global_position.y, game.clock) * (0.0 if on_board else 0.55)
		hv = hv.move_toward(target_v * 0.75 + Vector3(wind.x, 0, wind.z), 6.0 * dt)
		velocity.y = move_toward(velocity.y, -(PUFF_FALL + (1.0 if holding != 0 else 0.0)), 30.0 * dt)
	else:
		velocity.y -= GRAV * dt
	if grounded:
		air = minf(air + dt * 0.5, 1.0)
		# tilted basket: you slide downhill
		var n := get_floor_normal()
		var slope := Vector3(n.x, 0, n.z)
		if slope.length() > 0.14:
			hv += slope * (slope.length() - 0.1) * 26.0 * dt
		if game.input_enabled() and Input.is_action_just_pressed("jump") and not at_helm and not flat and pop_t <= 0.0:
			velocity.y = JUMP
			Sfx.play3d("boing", global_position, randf_range(0.92, 1.08), -6.0)
	elif at_helm:
		at_helm = false
		balloon.request_helm(false)
	velocity.x = hv.x
	velocity.z = hv.z
	if wish.length() > 0.1 and not at_helm:
		facing = lerp_angle(facing, atan2(-wish.x, -wish.z), 1.0 - exp(-12.0 * dt))
	elif charge >= 0.0 or holding != 0:
		facing = lerp_angle(facing, look_yaw, 1.0 - exp(-10.0 * dt))
	model.rotation.y = facing
	var pre_vy := velocity.y
	move_and_slide()
	if is_on_floor() and not _was_floor and pre_vy < -4.0:
		_land_squash = clampf(-pre_vy / 12.0, 0.2, 0.6)
		Sfx.play3d("squeak_short", global_position, 0.8, -4.0)
	_was_floor = is_on_floor()
	_update_board()
	_find_target()
	if global_position.y < -1.5:
		_go_lost()
	_update_camera(dt)
	_send(dt)

func _helm_step(_dt: float) -> void:
	var steer := 0.0
	var thrust := 0.0
	if game.input_enabled():
		steer = Input.get_axis("right", "left")
		thrust = Input.get_axis("back", "forward")
	balloon.send_helm_input(steer, thrust)
	# stand behind the wheel
	var spot := balloon.xform() * Vector3(0, 0.05, Balloon.HALF - 0.05)
	global_position = global_position.lerp(Vector3(spot.x, global_position.y, spot.z), 0.25)
	facing = lerp_angle(facing, balloon.yaw, 0.2)

func _update_board() -> void:
	if balloon == null:
		return
	var inside := balloon.is_inside(global_position)
	if inside != on_board:
		if inside:
			velocity -= balloon.vel
		else:
			velocity += balloon.vel
			facing += 0.0
		on_board = inside
	if on_board:
		_board_local = balloon.local_of(global_position)

func _find_target() -> void:
	target = null
	if holding != 0 or at_helm or flat or pop_t > 0.0:
		return
	if carrying != 0:
		# only the pump matters while hauling a pancake to it
		var o: Courier = game.courier(carrying)
		for st in balloon.stations:
			if o and o.flat and st.kind == Station.Kind.PUMP and st.global_position.distance_to(global_position + Vector3(0, 0.6, 0)) < 2.0:
				target = st
		return
	var best := 1.9
	var here := global_position + Vector3(0, 0.6, 0)
	var fwd := Basis(Vector3.UP, look_yaw) * Vector3.FORWARD
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node3D
		if n is Parcel and n.holder != 0:
			continue
		var d := node.global_position - here
		var dist := d.length()
		var reach: float = node.reach if n is Station else 1.9
		if dist > reach:
			continue
		var score := dist - fwd.dot(d.normalized()) * 0.6
		if score < best:
			best = score
			target = n
	if target is Station and target.prompt(self) == "":
		target = null
	if carrying != 0:
		return
	for c in game.couriers.values():
		if c == self or c.lost or c.carried_by != 0 or c.carrying != 0:
			continue
		var d: Vector3 = c.global_position + Vector3(0, 0.6, 0) - here
		var score := d.length() - fwd.dot(d.normalized()) * 0.6
		if d.length() < 1.7 and score < best:
			best = score
			target = c

func _shove() -> void:
	shove_cd = 0.55
	var fwd := Basis(Vector3.UP, look_yaw) * Vector3.FORWARD
	facing = look_yaw
	velocity += fwd * 2.5
	_anim_shove.rpc()
	for c in get_tree().get_nodes_in_group("courier"):
		if c == self or c.lost:
			continue
		var d: Vector3 = c.global_position - global_position
		if d.length() < 1.5 and fwd.dot(d.normalized()) > 0.3:
			var imp := (fwd * 7.5 + Vector3.UP * 4.0)
			c.shoved.rpc_id(c.peer, imp)
			game.add_stat(peer, "shoves", 1)
	# shoving a loose parcel knocks it about
	for p in get_tree().get_nodes_in_group("parcel"):
		if p.holder != 0:
			continue
		var d: Vector3 = p.global_position - global_position
		if d.length() < 1.4 and fwd.dot(d.normalized()) > 0.3:
			game.request_poke(p.pid, fwd * 5.0 + Vector3.UP * 2.0 + velocity_world())

@rpc("any_peer", "call_local", "reliable")
func shoved(impulse: Vector3) -> void:
	if not is_local:
		return
	if at_helm:
		toggle_helm()
	velocity += impulse
	_land_squash = 0.5
	Sfx.play3d("squeak", global_position, randf_range(1.3, 1.6), -2.0)

@rpc("any_peer", "call_local", "reliable")
func _anim_shove() -> void:
	_land_squash = -0.35
	Sfx.play3d("throw", global_position, 1.3, -8.0)
	if multiplayer.is_server():
		game.scare_gulls(global_position + Vector3(0, 0.8, 0), 2.8)

func _throw() -> void:
	var c := clampf(charge, 0.15, 1.0)
	charge = -1.0
	var aim := Basis(Vector3.UP, look_yaw) * Basis(Vector3.RIGHT, clampf(look_pitch + 0.35, -0.6, 1.2)) * Vector3.FORWARD
	if carrying != 0:
		var o: Courier = game.courier(carrying)
		if o:
			o.thrown.rpc_id(o.peer, aim * lerpf(5.0, 15.0, c) + velocity_world(), peer)
		return
	var p: Parcel = game.parcels.get(holding)
	var power := lerpf(5.0, 19.0, c) * (0.5 if p and p.flavor == "heavy" else 1.0)
	var v := aim * power + velocity_world()
	game.request_throw(holding, _hand_world() + Vector3(0, 0.25, 0), v)

func _hand_world() -> Vector3:
	var off := Vector3(0, 0.95, -0.62)
	if charge >= 0.0:
		off = Vector3(0, 1.55, 0.15)
	return global_position + Basis(Vector3.UP, model.rotation.y + (balloon.yaw if on_board else 0.0) * 0.0) * off

func hand_transform() -> Transform3D:
	var b := model.global_transform.basis.orthonormalized()
	var off := Vector3(0, 0.95, -0.66)
	if charge >= 0.0:
		off = Vector3(0, 1.6, 0.2)
	if puffed:
		off = Vector3(0, 1.75, 0)
	return Transform3D(b, global_position + b * off)

func _update_camera(dt: float) -> void:
	if cam_rig == null:
		return
	var focus := global_position + Vector3(0, 1.35, 0)
	cam_rig.global_position = cam_rig.global_position.lerp(focus, 1.0 - exp(-18.0 * dt))
	if cam_rig.global_position.distance_to(focus) > 6.0:
		cam_rig.global_position = focus
	cam_rig.rotation = Vector3(look_pitch, look_yaw, 0)
	spring.position = Vector3(0.35, 0, 0)

func _go_lost() -> void:
	lost = true
	lost_t = 4.0
	puffed = false
	at_helm = false
	velocity = Vector3.ZERO
	if holding != 0:
		game.request_drop(holding, global_position, Vector3.ZERO)
	if carrying != 0:
		var o: Courier = game.courier(carrying)
		if o:
			o.thrown.rpc_id(o.peer, Vector3.ZERO, peer)
	if carried_by != 0:
		_set_carry.rpc(carried_by, peer, false)
		carried_by = 0
	flat = false
	pop_t = 0.0
	game.add_stat(peer, "overboard", 1)
	game.announce_overboard.rpc(peer)
	visible = false

func _respawn() -> void:
	lost = false
	visible = true
	air = 1.0
	if balloon:
		var spot := Vector3(randf_range(-1.2, 1.2), 0.6, randf_range(-0.5, 1.2))
		global_position = balloon.xform() * spot
		on_board = true
		_board_local = spot
		velocity = Vector3(0, 3, 0)
	_land_squash = 0.6
	Sfx.play3d("pop", global_position, 1.4, -4.0)

func _send(dt: float) -> void:
	_send_t -= dt
	if _send_t > 0.0 or not multiplayer.has_multiplayer_peer() or not Net.online:
		return
	_send_t = SEND_RATE
	var pos := _board_local if on_board else global_position
	var f := facing - (balloon.yaw if on_board and balloon else 0.0)
	var flags := int(puffed) | int(lost) << 1 | int(at_helm) << 2 | int(charge >= 0.0) << 3 | int(flat) << 4 | int(pop_t > 0.0) << 5
	_state.rpc(on_board, pos, velocity, f, flags)

@rpc("authority", "unreliable_ordered")
func _state(board: bool, pos: Vector3, vel: Vector3, face: float, flags: int) -> void:
	_r_board = board
	_r_pos = pos
	_r_vel = vel
	_r_face = face
	puffed = flags & 1 != 0
	var was_lost := lost
	lost = flags & 2 != 0
	at_helm = flags & 4 != 0
	charge = 0.5 if flags & 8 != 0 else -1.0
	flat = flags & 16 != 0
	pop_t = 0.5 if flags & 32 != 0 else 0.0
	visible = not lost
	if was_lost and not lost:
		_r_init = false
	if not _r_init:
		_r_init = true
		on_board = board
		global_position = _world_of(board, pos)

func _world_of(board: bool, pos: Vector3) -> Vector3:
	if board and balloon:
		return balloon.xform() * pos
	return pos

func _remote_step(dt: float) -> void:
	if not _r_init:
		return
	if carried_by != 0 and game.courier(carried_by):
		global_position = game.courier(carried_by).hand_transform().origin + Vector3(0, -0.35, 0)
		facing = game.courier(carried_by).facing
		model.rotation.y = facing
		return
	if not _r_board:
		_r_pos += _r_vel * dt
	on_board = _r_board
	var goal := _world_of(_r_board, _r_pos)
	if global_position.distance_to(goal) > 6.0:
		global_position = goal
	else:
		global_position = global_position.lerp(goal, 1.0 - exp(-14.0 * dt))
	var f := _r_face + (balloon.yaw if _r_board and balloon else 0.0)
	facing = lerp_angle(facing, f, 1.0 - exp(-12.0 * dt))
	model.rotation.y = facing
	velocity = _r_vel
	var g := absf(_r_vel.y) < 0.5
	if g and not _was_floor and _r_vel.y > -0.5:
		pass
	_was_floor = g

# ------------------------------------------------------------------ anim + fx
@rpc("any_peer", "call_local", "unreliable")
func _do_squeak(pitch: float) -> void:
	squeak_t = 0.35
	Sfx.play3d("squeak", global_position + Vector3(0, 1, 0), pitch, 0.0)
	if multiplayer.is_server():
		game.scare_gulls(global_position, 8.0)
	if is_local:
		game.add_stat(peer, "squeaks", 1)

func _animate(dt: float) -> void:
	var hv := Vector2(velocity.x, velocity.z).length()
	var grounded := is_on_floor() if is_local else absf(velocity.y) < 0.6
	_land_squash = move_toward(_land_squash, 0.0, dt * 2.5)
	var s := Vector3.ONE
	if puffed:
		s = Vector3(1.5, 1.32, 1.5)
	elif flat:
		s = Vector3(1.45, 0.22, 1.45)
	elif pop_t > 0.0:
		s = Vector3(0.8, 1.1 + sin(_anim_t * 50.0) * 0.15, 0.8)
	var walk := 0.0
	if grounded and hv > 0.4:
		walk = _anim_t * 13.0
		_step_t -= dt * hv
		if _step_t <= 0.0:
			_step_t = 1.4
			Sfx.play3d("squeak_short", global_position, randf_range(0.9, 1.25), -16.0)
	var bob := absf(sin(walk)) * 0.07 if walk != 0.0 else sin(_anim_t * 2.2) * 0.012
	var squash := _land_squash + (0.12 if squeak_t > 0.0 else 0.0) * sin(_anim_t * 40.0)
	var target_scale := Vector3(s.x * (1.0 + squash * 0.5), s.y * (1.0 - squash * 0.6) + bob * 0.6, s.z * (1.0 + squash * 0.5))
	model.scale = model.scale.lerp(target_scale, 1.0 - exp(-18.0 * dt))
	model.position.y = bob
	if not grounded and not puffed:
		model.rotation.x = lerpf(model.rotation.x, clampf(-velocity.y * 0.03, -0.3, 0.3), 0.1)
	else:
		model.rotation.x = lerpf(model.rotation.x, hv * 0.03 if grounded else 0.0, 0.15)
	# limbs
	var carry := holding != 0 or carrying != 0
	var swing := sin(walk) * 0.7 if walk != 0.0 else 0.0
	if carry:
		arm_l.rotation = arm_l.rotation.lerp(Vector3(-1.5 if charge < 0.0 else -2.8, 0, -0.2), 0.3)
		arm_r.rotation = arm_r.rotation.lerp(Vector3(-1.5 if charge < 0.0 else -2.8, 0, 0.2), 0.3)
	elif puffed:
		arm_l.rotation = arm_l.rotation.lerp(Vector3(0, 0, -1.3), 0.2)
		arm_r.rotation = arm_r.rotation.lerp(Vector3(0, 0, 1.3), 0.2)
	elif at_helm:
		arm_l.rotation = arm_l.rotation.lerp(Vector3(-1.2, 0, -0.3 + sin(_anim_t * 3.0) * 0.2), 0.2)
		arm_r.rotation = arm_r.rotation.lerp(Vector3(-1.2, 0, 0.3 + sin(_anim_t * 3.0) * 0.2), 0.2)
	elif not grounded:
		arm_l.rotation = arm_l.rotation.lerp(Vector3(0, 0, -2.2), 0.15)
		arm_r.rotation = arm_r.rotation.lerp(Vector3(0, 0, 2.2), 0.15)
	else:
		arm_l.rotation = arm_l.rotation.lerp(Vector3(swing, 0, -0.25), 0.3)
		arm_r.rotation = arm_r.rotation.lerp(Vector3(-swing, 0, 0.25), 0.3)
	foot_l.position.z = -0.02 + (sin(walk) * 0.16 if walk != 0.0 else 0.0)
	foot_r.position.z = -0.02 - (sin(walk) * 0.16 if walk != 0.0 else 0.0)
	foot_l.position.y = 0.09 + (maxf(cos(walk), 0.0) * 0.08 if walk != 0.0 else 0.0)
	foot_r.position.y = 0.09 + (maxf(-cos(walk), 0.0) * 0.08 if walk != 0.0 else 0.0)
	# face
	_blink_t -= dt
	var blink := 1.0
	if _blink_t < 0.0:
		blink = 0.1
		if _blink_t < -0.12:
			_blink_t = randf_range(1.5, 4.5)
	eyes.scale = Vector3(1, lerpf(eyes.scale.y, blink, 0.6), 1)
	if carried_by != 0:
		model.rotation.z = sin(_anim_t * 9.0) * 0.25
	else:
		model.rotation.z = lerpf(model.rotation.z, 0.0, 0.2)
	if squeak_t > 0.0 or pop_t > 0.0:
		mouth.scale = Vector3(2.2, 0.7, 1.0)
	elif puffed:
		mouth.scale = Vector3(0.7, 0.5, 1.0)
	else:
		mouth.scale = Vector3(1, 1, 1)
