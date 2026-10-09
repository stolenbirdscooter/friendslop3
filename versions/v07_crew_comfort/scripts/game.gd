class_name Game
extends Node3D
## Builds the sky world and runs the airmail day. The host owns the truth
## (balloon, parcels, clock, deliveries); clients mirror it.

const SNAP_RATE := 1.0 / 20.0
const HOME_POS := Vector3(0, 34, 0)

var world_seed := 0
var attract := true
var clock := 0.0
var day := 1
var day_t := 0.0
var day_len := 330.0
var phase := "attract" # attract | flying | results
var quota := 3
var day_parcels := 5
var delivered := 0
var lost_count := 0
var stamps := 0
var mouse_sens := 1.0

var balloon: Balloon
var islands: Array[Island] = []
var couriers := {}
var parcels := {}
var next_pid := 1
var stats := {}
var hud: Node
var main: Node
var menu_open := false
var brambles: Array[Bramble] = []
var gulls := {}
var next_gid := 1
var _gull_t := 60.0
var _hints := {}
var _mood := ""
var bell: Station
var ready_peers: Array = [1] # peers whose world is built
var postcards: Postcards

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var sea: MeshInstance3D
var sea_mat: ShaderMaterial
var orbit_cam: Camera3D
var _snap_t := 0.0
var _wind_loop: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _seeds: Array = []

func setup(seed_: int, is_attract: bool) -> void:
	world_seed = seed_
	attract = is_attract
	_rng.seed = seed_
	Wind.seed_angle = _rng.randf() * TAU
	_build_environment()
	_build_sea()
	_build_islands()
	_build_brambles()
	_build_clouds()
	_build_seeds()
	balloon = Balloon.new()
	balloon.name = "Balloon"
	balloon.game = self
	balloon.islands = islands
	add_child(balloon)
	if bell:
		bell.balloon = balloon
	_park_balloon()
	var pc := Node3D.new()
	pc.name = "Parcels"
	add_child(pc)
	var cc := Node3D.new()
	cc.name = "Couriers"
	add_child(cc)
	if Sfx.has_sound("wind_loop"):
		_wind_loop = Sfx.make_loop("wind_loop")
		_wind_loop.volume_db = -14.0
	if attract:
		orbit_cam = Camera3D.new()
		orbit_cam.fov = 60
		orbit_cam.far = 2400
		add_child(orbit_cam)
		orbit_cam.current = true
		day_t = day_len * 0.18
	postcards = Postcards.new()
	postcards.game = self
	add_child(postcards)
	hud = preload("res://scripts/hud.gd").new()
	hud.game = self
	add_child(hud)
	_update_sky()

func _exit_tree() -> void:
	if _wind_loop:
		_wind_loop.queue_free()

# ================================================================ world build
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8f86c9")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 60.0
	env.fog_depth_end = 900.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.05
	sun.light_energy = 1.25
	add_child(sun)

func _build_sea() -> void:
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = preload("res://shaders/cloudsea.gdshader")
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_PERLIN
	fn.frequency = 0.012
	fn.fractal_octaves = 3
	fn.seed = world_seed
	nt.noise = fn
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	nt.generate_mipmaps = true
	sea_mat.set_shader_parameter("noise", nt)
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 2400)
	pm.subdivide_width = 199
	pm.subdivide_depth = 199
	sea = MeshInstance3D.new()
	sea.mesh = pm
	sea.material_override = sea_mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position.y = -4.0
	add_child(sea)

func _build_islands() -> void:
	var home := Island.new()
	home.game = self
	home.build(0, HOME_POS, 17.0, _rng.randi(), true)
	add_child(home)
	islands.append(home)
	var count := 10
	var tries := 0
	while islands.size() < count + 1 and tries < 400:
		tries += 1
		var ring := 90.0 + _rng.randf() * 330.0
		var a := _rng.randf() * TAU
		var p := Vector3(cos(a) * ring, _rng.randf_range(16.0, 115.0), sin(a) * ring)
		var r := _rng.randf_range(8.5, 14.0)
		var ok := true
		for o in islands:
			if Vector2(o.position.x - p.x, o.position.z - p.z).length() < o.radius + r + 45.0:
				ok = false
				break
		if not ok:
			continue
		var isl := Island.new()
		isl.game = self
		isl.build(islands.size(), p, r, _rng.randi())
		add_child(isl)
		islands.append(isl)
	if home.bell_spot:
		bell = Station.new()
		bell.kind = Station.Kind.BELL
		bell.balloon = null
		bell.reach = 2.2
		bell.position = Vector3(0, 1.6, 0)
		bell.add_to_group("interactable")
		home.bell_spot.add_child(bell)

func _build_brambles() -> void:
	for i in 14:
		var b := Bramble.new()
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(120.0, 480.0)
		b.setup(Vector3(cos(a) * d, _rng.randf_range(28.0, 125.0), sin(a) * d), _rng.randf_range(5.5, 9.0), self)
		add_child(b)
		brambles.append(b)

func _set_brambles(n: int) -> void:
	for i in brambles.size():
		brambles[i].active = i < (1 + n * 2 if n > 0 else 0) and not attract

func music() -> Node:
	return get_node_or_null("/root/Music")

func _build_clouds() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 14
	sm.rings = 8
	mm.mesh = sm
	var xforms: Array[Transform3D] = []
	for i in 70:
		var far := i < 22
		var dist := _rng.randf_range(650, 1050) if far else _rng.randf_range(40, 520)
		var a := _rng.randf() * TAU
		var y := _rng.randf_range(10, 60) if far else _rng.randf_range(12, 150)
		var c := Vector3(cos(a) * dist, y, sin(a) * dist)
		var size := _rng.randf_range(30, 60) if far else _rng.randf_range(5, 13)
		var puffs := 5 + _rng.randi() % 5
		for j in puffs:
			var o := Vector3(_rng.randf_range(-1.6, 1.6), _rng.randf_range(-0.2, 0.5), _rng.randf_range(-0.8, 0.8)) * size
			var s := size * _rng.randf_range(0.45, 0.85) * (1.0 - absf(o.x) / (size * 2.6))
			xforms.append(Transform3D(Basis.from_scale(Vector3(s, s * 0.72, s)), c + o))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/cloudpuff.gdshader")
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

## Dandelion-like seeds drifting in each wind layer: they show which way the sky flows.
func _build_seeds() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	mm.mesh = q
	mm.instance_count = 260
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var spokes := 0.55 + 0.45 * absf(sin(atan2(y - 15.5, x - 15.5) * 6.0))
			var a := clampf(1.0 - d, 0.0, 1.0) * spokes + clampf(1.0 - d * 5.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.98, 0.9, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Seeds"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	for i in 260:
		_seeds.append(Vector3(_rng.randf_range(-40, 40), _rng.randf_range(-30, 30), _rng.randf_range(-40, 40)))

func _update_seeds(dt: float, center: Vector3) -> void:
	var mmi := get_node_or_null("Seeds") as MultiMeshInstance3D
	if mmi == null:
		return
	var mm := mmi.multimesh
	for i in _seeds.size():
		var p: Vector3 = _seeds[i]
		var w := Wind.at(p.y, clock)
		p += (w * 1.6 + Vector3(0, sin(clock * 0.7 + i) * 0.3, 0)) * dt
		var rel := p - center
		if absf(rel.x) > 40.0:
			p.x -= signf(rel.x) * 80.0
		if absf(rel.z) > 40.0:
			p.z -= signf(rel.z) * 80.0
		if absf(rel.y) > 30.0:
			p.y -= signf(rel.y) * 60.0
		_seeds[i] = p
		mm.set_instance_transform(i, Transform3D(Basis(), p))

func _park_balloon() -> void:
	var home: Island = islands[0]
	balloon.anchor = home.top_center + Vector3(0, Balloon.PIVOT_H + 0.3, 5.0)
	balloon.vel = Vector3.ZERO
	balloon.yaw = 0.0
	balloon.tilt = Vector2.ZERO
	balloon.heat = 0.42
	balloon._apply_transform()

# ================================================================ sessions
func begin_host() -> void:
	attract = false
	if orbit_cam:
		orbit_cam.queue_free()
		orbit_cam = null
	for id in Net.roster:
		_spawn_courier(id, Net.roster[id].name, Net.roster[id].color, Net.roster[id].get("hat", 0))
	_start_day(1)
	Net.peer_registered.connect(_on_peer_registered)
	Net.peer_left.connect(_on_peer_left)

func begin_client(state: Dictionary) -> void:
	attract = false
	if orbit_cam:
		orbit_cam.queue_free()
		orbit_cam = null
	day = state.day
	quota = state.quota
	day_parcels = state.day_parcels
	delivered = state.delivered
	lost_count = state.lost
	stamps = state.stamps
	clock = state.clock
	day_t = state.day_t
	phase = state.phase
	_set_brambles(day)
	Net.peer_left.connect(_on_peer_left)
	_client_ready.rpc_id(1)

func world_state() -> Dictionary:
	return {"day": day, "quota": quota, "day_parcels": day_parcels, "delivered": delivered, "lost": lost_count,
		"stamps": stamps, "clock": clock, "day_t": day_t, "phase": phase}

func _on_peer_registered(id: int) -> void:
	Net.welcome(id, world_seed, world_state())

@rpc("any_peer", "reliable")
func _client_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not ready_peers.has(id):
		ready_peers.append(id)
	_set_ready_peers.rpc(ready_peers)
	# tell the newcomer about everyone already here, then everyone about the newcomer
	for pid in couriers:
		_spawn_courier.rpc_id(id, pid, Net.pname(pid), Net.roster.get(pid, {}).get("color", 0), Net.roster.get(pid, {}).get("hat", 0))
	for k in parcels:
		var p: Parcel = parcels[k]
		_spawn_parcel.rpc_id(id, p.pid, p.kind, p.address, balloon.local_of(p.global_position), p.flavor)
		if p.holder != 0:
			_set_holder.rpc_id(id, p.pid, p.holder)
	for g in gulls.values():
		_spawn_gull.rpc_id(id, g.gid, g.global_position)
	_spawn_courier.rpc(id, Net.pname(id), Net.roster[id].color, Net.roster[id].get("hat", 0))
	toast.rpc("%s climbed aboard!" % Net.pname(id))

@rpc("authority", "call_local", "reliable")
func _set_ready_peers(list: Array) -> void:
	ready_peers = list

func send_to_ready(callable: Callable, args: Array) -> void:
	var me := multiplayer.get_unique_id()
	for id in ready_peers:
		if id != me and Net.roster.has(id):
			callable.get_object().callv("rpc_id", [id, callable.get_method()] + args)

func _on_peer_left(id: int) -> void:
	ready_peers.erase(id)
	if couriers.has(id):
		var c: Courier = couriers[id]
		if multiplayer.is_server():
			if c.holding != 0:
				_set_holder.rpc(c.holding, 0)
			balloon.release_peer(id)
		couriers.erase(id)
		c.queue_free()
		toast("%s drifted off home." % Net.pname(id))

@rpc("authority", "call_local", "reliable")
func _spawn_courier(id: int, pname: String, color_idx: int, hat := 0) -> void:
	if couriers.has(id):
		return
	var c := Courier.new()
	c.name = "C%d" % id
	c.peer = id
	c.pname = pname
	c.color = Pal.RUBBER[color_idx % Pal.RUBBER.size()]
	c.hat = hat
	c.game = self
	c.balloon = balloon
	c.is_local = id == multiplayer.get_unique_id()
	c.set_multiplayer_authority(id)
	var spot := Vector3(randf_range(-1.3, 1.3), 0.5, randf_range(-0.6, 1.3))
	c.position = balloon.xform() * spot
	c.on_board = true
	c._board_local = spot
	$Couriers.add_child(c)
	couriers[id] = c
	if not stats.has(id):
		stats[id] = {}
	if c.is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func courier(id: int) -> Courier:
	return couriers.get(id)

func local_courier() -> Courier:
	return couriers.get(multiplayer.get_unique_id())

func input_enabled() -> bool:
	return not menu_open and phase != "results" and not attract

# ================================================================ the day
func _start_day(n: int) -> void:
	day = n
	day_t = 0.0
	delivered = 0
	lost_count = 0
	phase = "dock"
	day_parcels = mini(4 + n, 11)
	quota = ceili(day_parcels * (0.55 + minf(n * 0.03, 0.2)))
	for id in stats:
		stats[id] = {}
	for k in parcels.keys():
		_remove_parcel(k)
	_park_balloon()
	_day_started.rpc(day, quota, day_parcels)
	# fill the basket
	var addrs: Array[int] = []
	var pool: Array[int] = []
	for i in range(1, islands.size()):
		pool.append(i)
	pool.shuffle()
	var dests := mini(2 + n, pool.size())
	for i in day_parcels:
		addrs.append(pool[i % dests])
	var flavors: Array[String] = []
	flavors.append("fragile")
	if n >= 2:
		flavors.append("hen")
		flavors.append("heavy")
	if n >= 3:
		flavors.append("express")
		flavors.append(["fragile", "hen", "express", "heavy"][randi() % 4])
	if n >= 5:
		flavors.append(["fragile", "hen", "express", "heavy"][randi() % 4])
	for i in day_parcels:
		var k := 0 if randf() < 0.45 else (1 if randf() < 0.75 else 2)
		var fl: String = flavors[i] if i < flavors.size() else "normal"
		var spot := Vector3(-1.4 + (i % 4) * 0.95, 0.4 + (i / 4) * 0.8, -0.2 + ((i / 4) % 2) * 0.9)
		_spawn_parcel.rpc(next_pid, k, addrs[i], spot, fl)
		next_pid += 1
	for g in gulls.keys():
		despawn_gull(g)
	_gull_t = 75.0 if n == 1 else randf_range(30.0, 50.0)

@rpc("authority", "call_local", "reliable")
func _day_started(n: int, q: int, count: int) -> void:
	day = n
	quota = q
	day_parcels = count
	delivered = 0
	lost_count = 0
	day_t = 0.0
	phase = "dock"
	for id in stats:
		stats[id] = {}
	_set_brambles(n)
	postcards.reset()
	var me := local_courier()
	if me and n > 0:
		me.flat = false
		me._respawn()
	if hud:
		hud.hide_results()
		hud.banner("Day %d" % n, "Deliver %d of %d parcels before sunset" % [q, count])
		toast("Docked at the Post Office. Ring the bell on the porch when the crew's aboard.", Color("3f7fd9"))

@rpc("authority", "call_local", "reliable")
func _spawn_parcel(pid: int, kind: int, addr: int, local_pos: Vector3, flavor := "normal") -> void:
	if parcels.has(pid):
		return
	var p := Parcel.new()
	p.setup(pid, kind, addr, self, flavor)
	p.spawn_t = day_t
	p.position = balloon.xform() * local_pos
	p.rotation.y = balloon.yaw + randf_range(-0.3, 0.3)
	$Parcels.add_child(p)
	parcels[pid] = p
	if multiplayer.is_server():
		p.linear_velocity = balloon.vel

func _remove_parcel(pid: int) -> void:
	if not parcels.has(pid):
		return
	var p: Parcel = parcels[pid]
	if p.holder != 0 and couriers.has(p.holder):
		couriers[p.holder].holding = 0
	parcels.erase(pid)
	p.queue_free()

func request_depart() -> void:
	_srv_depart.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _srv_depart() -> void:
	if multiplayer.is_server() and phase == "dock":
		_departed.rpc(Net.pname(_sender()))

@rpc("authority", "call_local", "reliable")
func _departed(by: String) -> void:
	phase = "flying"
	day_t = 0.0
	Sfx.play("whistle")
	Sfx.play3d("bell", bell.global_position if bell else Vector3.ZERO, 1.3, 0.0)
	toast("%s rang the bell. Off you go!" % by, Color("5e9e4a"))
	if music():
		music().stinger("day")

func island_name(i: int) -> String:
	return islands[i].iname if i >= 0 and i < islands.size() else "?"

# --- requests from couriers -------------------------------------------------
func request_pickup(pid: int) -> void:
	_srv_pickup.rpc_id(1, pid)

func request_throw(pid: int, pos: Vector3, v: Vector3) -> void:
	_srv_release.rpc_id(1, pid, pos, v, true)

func request_drop(pid: int, pos: Vector3, v: Vector3) -> void:
	_srv_release.rpc_id(1, pid, pos, v, false)

func request_poke(pid: int, v: Vector3) -> void:
	_srv_poke.rpc_id(1, pid, v)

func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return 1 if id == 0 else id

@rpc("any_peer", "call_local", "reliable")
func _srv_pickup(pid: int) -> void:
	if not multiplayer.is_server() or not parcels.has(pid):
		return
	var id := _sender()
	var p: Parcel = parcels[pid]
	var c := courier(id)
	if p.holder != 0 or c == null or c.holding != 0 or c.lost:
		return
	if c.global_position.distance_to(p.global_position) > 3.5:
		return
	_set_holder.rpc(pid, id)

@rpc("any_peer", "call_local", "reliable")
func _srv_release(pid: int, pos: Vector3, v: Vector3, thrown: bool) -> void:
	if not multiplayer.is_server() or not parcels.has(pid):
		return
	var id := _sender()
	var p: Parcel = parcels[pid]
	if p.holder != id:
		return
	_set_holder.rpc(pid, 0)
	p.global_position = pos
	p.linear_velocity = v.limit_length(26.0)
	p.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)) if thrown else Vector3.ZERO
	p.last_thrower = id
	p.air_time = 0.0
	if thrown:
		_fx_throw.rpc(pos)

@rpc("any_peer", "call_local", "reliable")
func _srv_poke(pid: int, v: Vector3) -> void:
	if not multiplayer.is_server() or not parcels.has(pid):
		return
	var p: Parcel = parcels[pid]
	if p.holder == 0:
		p.linear_velocity = v.limit_length(14.0)
		p.last_thrower = _sender()

@rpc("authority", "call_local", "reliable")
func _set_holder(pid: int, peer: int) -> void:
	if not parcels.has(pid):
		return
	var p: Parcel = parcels[pid]
	if p.holder != 0 and couriers.has(p.holder):
		couriers[p.holder].holding = 0
	p.set_held(peer)
	if peer < 0:
		Sfx.play3d("squawk" if Sfx.has_sound("squawk") else "squeak", p.global_position, 1.0, 2.0)
		postcards.snap("A gull stole the post for %s" % island_name(p.address), 4, 0.3)
	if peer != 0 and couriers.has(peer):
		couriers[peer].holding = pid
		Sfx.play3d("grab", p.global_position, randf_range(0.9, 1.1), -4.0)

@rpc("authority", "call_local", "reliable")
func _fx_throw(pos: Vector3) -> void:
	Sfx.play3d("throw", pos, randf_range(0.9, 1.1), -3.0)

# --- outcomes (host) --------------------------------------------------------
func on_chute(isl: Island, p: Parcel) -> void:
	if not multiplayer.is_server() or p.holder != 0 or not parcels.has(p.pid) or phase != "flying":
		return
	if p.address == isl.index:
		var airmail := p.air_time > 1.2
		var pts := 10 + (10 if airmail else 0) + p.kind * 5
		if p.flavor == "express" and day_t - p.spawn_t < 150.0:
			pts += 25
		elif p.flavor in ["fragile", "hen", "heavy"]:
			pts += 10
		delivered += 1
		stamps += pts
		add_stat(p.last_thrower, "delivered", 1)
		_delivered.rpc(p.pid, isl.index, p.last_thrower, pts, airmail)
		_remove_parcel(p.pid)
	else:
		p.linear_velocity = Vector3(randf_range(-3, 3), 11.0, randf_range(-3, 3))
		p.angular_velocity = Vector3(8, 3, 5)
		_returned.rpc(p.pid, isl.index)

@rpc("authority", "call_local", "reliable")
func _delivered(pid: int, island_idx: int, by: int, pts: int, airmail: bool) -> void:
	var pos: Vector3 = islands[island_idx].chute_pos + Vector3(0, 2.5, 0)
	Sfx.play3d("deliver", pos, 1.0, 2.0)
	Sfx.play("coin", 1.0, -6.0)
	if music():
		music().stinger("deliver")
	if not multiplayer.is_server():
		delivered += 1
		stamps += pts
		_remove_parcel(pid)
	var who := Net.pname(by) if by != 0 else "The wind"
	if airmail:
		toast("AIRMAIL!  %s landed it in %s  +%d" % [who, island_name(island_idx), pts], Color("f2b33d"))
	else:
		toast("%s delivered to %s  +%d" % [who, island_name(island_idx), pts], Color("8cc152"))
	if hud:
		hud.burst(pos)
	_confetti(pos)
	if airmail or by == multiplayer.get_unique_id():
		postcards.snap(("AIRMAIL! " if airmail else "") + "%s → %s" % [who, island_name(island_idx)], 3 if airmail else 2, 0.2)

func _confetti(pos: Vector3) -> void:
	var cp := CPUParticles3D.new()
	cp.one_shot = true
	cp.amount = 70
	cp.lifetime = 2.4
	cp.explosiveness = 0.95
	cp.direction = Vector3.UP
	cp.spread = 50.0
	cp.initial_velocity_min = 6.0
	cp.initial_velocity_max = 11.0
	cp.gravity = Vector3(0, -5, 0)
	cp.damping_min = 1.5
	cp.damping_max = 3.0
	cp.angular_velocity_min = -400
	cp.angular_velocity_max = 400
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	cp.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Pal.RUBBER[0], Pal.RUBBER[1], Pal.RUBBER[2], Pal.RUBBER[3], Pal.RUBBER[4]])
	cp.color_initial_ramp = g
	cp.position = pos
	add_child(cp)
	cp.emitting = true
	get_tree().create_timer(3.0).timeout.connect(cp.queue_free)

@rpc("authority", "call_local", "reliable")
func _returned(_pid: int, island_idx: int) -> void:
	Sfx.play3d("wrong", islands[island_idx].chute_pos + Vector3(0, 2.5, 0), 1.0, 2.0)
	toast("RETURN TO SENDER - that's not %s's post!" % island_name(island_idx), Color("e8574a"))

func parcel_lost(p: Parcel) -> void:
	if not parcels.has(p.pid):
		return
	lost_count += 1
	add_stat(p.last_thrower, "lost", 1)
	_parcel_lost.rpc(p.pid, p.address)

@rpc("authority", "call_local", "reliable")
func _parcel_lost(pid: int, addr: int) -> void:
	if parcels.has(pid):
		Sfx.play3d("splash", parcels[pid].global_position, 0.9)
	if not multiplayer.is_server():
		lost_count += 1
	_remove_parcel(pid)
	toast("A parcel for %s sank into the fluff." % island_name(addr), Color("8a70d6"))

func parcel_broken(p: Parcel) -> void:
	if not parcels.has(p.pid):
		return
	lost_count += 1
	add_stat(p.last_thrower, "lost", 1)
	_parcel_gone.rpc(p.pid, p.address, "smash")

func parcel_stolen(p: Parcel) -> void:
	if not parcels.has(p.pid):
		return
	lost_count += 1
	_parcel_gone.rpc(p.pid, p.address, "gull")

@rpc("authority", "call_local", "reliable")
func _parcel_gone(pid: int, addr: int, why: String) -> void:
	if parcels.has(pid):
		var pos: Vector3 = parcels[pid].global_position
		if why == "smash":
			Sfx.play3d("shatter" if Sfx.has_sound("shatter") else "pop", pos, 1.0, 3.0)
			if hud:
				hud.burst(pos)
	if not multiplayer.is_server():
		lost_count += 1
	_remove_parcel(pid)
	postcards.snap("CRASH." if why == "smash" else "Stop, thief!", 3)
	if why == "smash":
		toast("CRASH. That was the fragile one for %s." % island_name(addr), Color("e8574a"))
	else:
		toast("A gull made off with the post for %s!" % island_name(addr), Color("e8574a"))

@rpc("authority", "call_local", "unreliable")
func fx_cluck(pid: int) -> void:
	if parcels.has(pid):
		Sfx.play3d("cluck" if Sfx.has_sound("cluck") else "squeak_short", parcels[pid].global_position, randf_range(0.9, 1.2), 0.0)

# --- gulls (host simulates, snapshot mirrors) ---------------------------------
@rpc("authority", "call_local", "reliable")
func _spawn_gull(gid: int, pos: Vector3) -> void:
	if gulls.has(gid):
		return
	var g := Gull.new()
	g.gid = gid
	g.game = self
	g.position = pos
	add_child(g)
	gulls[gid] = g
	if not _hints.has("gull"):
		_hints["gull"] = true
		toast("GULL! It wants your post. Squeak (Q) or shove (LMB) to scare it.", Color("e8574a"))

func despawn_gull(gid: int) -> void:
	if multiplayer.is_server():
		_despawn_gull.rpc(gid)

@rpc("authority", "call_local", "reliable")
func _despawn_gull(gid: int) -> void:
	if gulls.has(gid):
		var g: Gull = gulls[gid]
		if g.carrying != 0 and parcels.has(g.carrying) and parcels[g.carrying].holder == -gid:
			parcels[g.carrying].set_held(0)
		gulls.erase(gid)
		g.queue_free()

func gull_grab(g: Gull, pid: int) -> void:
	_set_holder.rpc(pid, -g.gid)

func gull_drop(g: Gull, pid: int) -> void:
	if not parcels.has(pid):
		return
	var p: Parcel = parcels[pid]
	_set_holder.rpc(pid, 0)
	p.linear_velocity = g.vel * 0.5
	p.last_thrower = 0

func scare_gulls(pos: Vector3, r: float) -> void:
	for g in gulls.values():
		if g.global_position.distance_to(pos) < r and g.state != Gull.S.SCARED:
			g.scare()
			Sfx.play3d("squawk" if Sfx.has_sound("squawk") else "squeak", g.global_position, 1.3, 3.0)

func _update_gulls(dt: float) -> void:
	_gull_t -= dt
	var cap := mini(day, 4)
	if _gull_t <= 0.0 and gulls.size() < cap and phase == "flying":
		_gull_t = randf_range(40.0, 80.0) / (1.0 + day * 0.25)
		var a := randf() * TAU
		var pos := balloon.xform().origin + Vector3(cos(a) * 45.0, 12.0, sin(a) * 45.0)
		_spawn_gull.rpc(next_gid, pos)
		next_gid += 1
	for g in gulls.values():
		g.simulate(dt)

@rpc("any_peer", "call_local", "reliable")
func announce_overboard(id: int) -> void:
	Sfx.play("splash", 1.0, -2.0)
	var lines := ["%s fell into the clouds!", "%s has gone overboard!", "Courier down! %s is in the fluff.", "%s discovered gravity."]
	toast(lines[randi() % lines.size()] % Net.pname(id), Color("3f7fd9"))

func add_stat(id: int, key: String, n: int) -> void:
	if id <= 0:
		return
	if multiplayer.is_server():
		_add_stat(id, key, n)
	else:
		_add_stat.rpc_id(1, id, key, n)

@rpc("any_peer", "reliable")
func _add_stat(id: int, key: String, n: int) -> void:
	if not stats.has(id):
		stats[id] = {}
	stats[id][key] = stats[id].get(key, 0) + n

@rpc("authority", "call_local", "reliable")
func toast(text: String, col := Color("2b1d2a")) -> void:
	if hud:
		hud.toast(text, col)

func _check_day_end() -> void:
	var resolved := delivered + lost_count >= day_parcels
	if day_t >= day_len or resolved:
		var ok := delivered >= quota
		if resolved and ok and day_t < day_len:
			stamps += int((day_len - day_t) * 0.2)
		_day_over.rpc(ok, delivered, quota, stamps, _awards())

func _awards() -> Array:
	var defs := [["delivered", "Golden Arm", "most parcels delivered"], ["overboard", "Frequent Flyer", "most trips overboard"],
		["squeaks", "Loudest Windbag", "squeaked the most"], ["shoves", "Menace to Aviation", "shoved the most crewmates"],
		["lost", "Butterfingers", "lost the most parcels"], ["rescues", "Lifeguard", "reinflated the most crewmates"],
		["tosses", "Crew Cannon", "threw the most crewmates"], ["bonks", "Gull Bonker", "beaned the most gulls"],
		["pops", "Pincushion", "got popped the most"], ["patches", "Seamstress", "patched the most leaks"]]
	var out := []
	for d in defs:
		var best := 0
		var who := -1
		for id in stats:
			var v: int = stats[id].get(d[0], 0)
			if v > best:
				best = v
				who = id
		if who != -1:
			out.append([d[1], Net.pname(who), "%s (%d)" % [d[2], best], who])
	return out

@rpc("authority", "call_local", "reliable")
func _day_over(ok: bool, got: int, q: int, total: int, awards: Array) -> void:
	phase = "results"
	Net.lifetime_stamps += maxi(total - stamps, 0) if ok else 0
	if main and main.has_method("save_prefs"):
		main.save_prefs()
	stamps = total
	Sfx.play("bell")
	if music() and not ok:
		music().stinger("fail")
	for g in gulls.keys():
		_despawn_gull(g)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if hud:
		hud.show_results(ok, day, got, q, total, awards)

func host_continue(ok: bool) -> void:
	if not multiplayer.is_server():
		return
	if ok:
		_start_day(day + 1)
	else:
		stamps = 0
		_start_day(1)

# ================================================================ loop
func _physics_process(dt: float) -> void:
	if multiplayer.is_server():
		clock += dt
		if phase == "flying":
			day_t += dt
			_check_day_end()
			_update_gulls(dt)
			_update_hints()
		elif attract:
			day_t = fmod(day_t + dt * 4.0, day_len)
		_snap_t -= dt
		if _snap_t <= 0.0 and Net.online and not attract:
			_snap_t = SNAP_RATE
			var pd := []
			for k in parcels:
				var p: Parcel = parcels[k]
				if p.holder == 0:
					var lt := balloon.xform().affine_inverse() * p.global_transform
					pd.append([p.pid, lt.origin, lt.basis.get_rotation_quaternion()])
			var gd := []
			for g in gulls.values():
				gd.append([g.gid, g.global_position, g.global_basis.get_rotation_quaternion(), g.state])
			send_to_ready(_snap, [clock, day_t, balloon.get_state(), pd, gd])
	else:
		clock += dt
		if phase == "flying":
			day_t += dt

@rpc("authority", "unreliable_ordered")
func _snap(c: float, dt_: float, bs: Array, pd: Array, gd: Array) -> void:
	for e in gd:
		var g: Gull = gulls.get(e[0])
		if g:
			g.global_position = g.global_position.lerp(e[1], 0.5) if g.global_position.distance_to(e[1]) < 10.0 else e[1]
			g.global_basis = Basis(e[2])
			g.state = e[3]
	if absf(clock - c) > 0.5:
		clock = c
	else:
		clock = lerpf(clock, c, 0.1)
	day_t = dt_
	balloon.set_state(bs)
	for e in pd:
		var p: Parcel = parcels.get(e[0])
		if p:
			p.set_snap(e[1], e[2])

func _update_hints() -> void:
	if day != 1:
		return
	var me := local_courier()
	if day_t > 3.0 and not _hints.has("pump"):
		_hints["pump"] = true
		toast("Pump the bellows (front-left) to heat the balloon and take off!", Color("3f7fd9"))
	if balloon.altitude() > islands[0].top_center.y + 12.0 and not _hints.has("wind"):
		_hints["wind"] = true
		toast("Every altitude blows a different way. Read the arrows on the right and ride the layer you need.", Color("3f7fd9"))
	if me and me.holding != 0 and not _hints.has("throw"):
		_hints["throw"] = true
		toast("Hold LMB to wind up, release to throw it into the chute with the matching colour.", Color("3f7fd9"))

func _update_music() -> void:
	var m := music()
	if m == null:
		return
	var want := "menu"
	if not attract:
		var f := day_frac()
		want = "results" if phase == "results" else ("morning" if f < 0.72 else ("dusk" if f < 0.95 else "night"))
	if want != _mood:
		_mood = want
		m.set_mood(want)
	if not attract and phase == "flying":
		var danger := 0.0
		for g in gulls.values():
			danger = maxf(danger, 0.5 if g.state == Gull.S.CIRCLE else 1.0)
		danger = maxf(danger, clampf(balloon.leaks * 0.3, 0.0, 1.0))
		m.set_intensity(clampf(danger * 0.7 + day_frac() * 0.3, 0.0, 1.0))

func _process(dt: float) -> void:
	_update_sky()
	_update_music()
	var cam := get_viewport().get_camera_3d()
	if orbit_cam:
		var t := Time.get_ticks_msec() * 0.00006
		var c := balloon.global_position + Vector3(0, 6, 0)
		orbit_cam.global_position = c + Vector3(cos(t) * 26.0, 4.0 + sin(t * 1.3) * 3.0, sin(t) * 26.0)
		orbit_cam.look_at(c, Vector3.UP)
	if cam:
		sea.global_position = Vector3(snappedf(cam.global_position.x, 12.0), -4.0, snappedf(cam.global_position.z, 12.0))
		_update_seeds(dt, cam.global_position)
		if _wind_loop:
			var h := clampf((cam.global_position.y - 20.0) / 120.0, 0.0, 1.0)
			_wind_loop.volume_db = lerpf(-20.0, -9.0, h)

const SKY_KEYS := [
	# frac, top, horizon, sun colour, sun energy, ambient
	[0.0, Color("6f86c4"), Color("ffc59a"), Color("ffb27a"), 0.9, Color("8a7fc4")],
	[0.18, Color("5b98d6"), Color("ffe2bd"), Color("fff0d0"), 1.25, Color("8f8ccc")],
	[0.55, Color("4f95dc"), Color("d9ecf5"), Color("fffaf0"), 1.35, Color("8f97cf")],
	[0.82, Color("5a7fc4"), Color("ffcf8a"), Color("ffc27a"), 1.2, Color("9a86c0")],
	[0.94, Color("4a4f9a"), Color("ff9a6a"), Color("ff8a5a"), 0.9, Color("7c6aac")],
	[1.0, Color("2f3270"), Color("e07a7a"), Color("ff7a5a"), 0.6, Color("5a5294")],
]

func day_frac() -> float:
	return clampf(day_t / day_len, 0.0, 1.0)

func _update_sky() -> void:
	var f := day_frac()
	var a: Array = SKY_KEYS[0]
	var b: Array = SKY_KEYS[0]
	for i in range(SKY_KEYS.size() - 1):
		if f >= SKY_KEYS[i][0] and f <= SKY_KEYS[i + 1][0]:
			a = SKY_KEYS[i]
			b = SKY_KEYS[i + 1]
			break
	var t: float = 0.0 if b[0] == a[0] else (f - a[0]) / (b[0] - a[0])
	t = smoothstep(0.0, 1.0, t)
	var top: Color = a[1].lerp(b[1], t)
	var hor: Color = a[2].lerp(b[2], t)
	var sc: Color = a[3].lerp(b[3], t)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", hor)
	sky_mat.set_shader_parameter("bottom_color", hor.lerp(Color.WHITE, 0.3))
	sky_mat.set_shader_parameter("sun_color", sc)
	sky_mat.set_shader_parameter("star_amount", smoothstep(0.9, 1.0, f) * 0.8)
	sun.light_color = sc
	sun.light_energy = lerpf(a[4], b[4], t)
	env.ambient_light_color = a[5].lerp(b[5], t)
	env.fog_light_color = hor.lerp(top, 0.15)
	var elev := sin(f * PI) * 52.0 + 6.0
	sun.rotation_degrees = Vector3(-elev, 35.0 + f * 120.0, 0)
	sea_mat.set_shader_parameter("top_color", Color(1, 0.99, 0.96).lerp(hor, 0.25))
	sea_mat.set_shader_parameter("low_color", Color("c6bde8").lerp(top, 0.2))
	var pending := {}
	for p in parcels.values():
		pending[p.address] = true
	for isl in islands:
		isl.set_dusk(f)
		if isl.beacon:
			isl.beacon.visible = not attract and phase != "results" and (pending.has(isl.index) or (isl.is_home and parcels.is_empty()))
