class_name Balloon
extends AnimatableBody3D
## The crew's patchwork hot-air balloon. Host simulates; clients smooth snapshots.
## Origin = centre of the basket floor. The rig swings like a pendulum about the
## envelope ring PIVOT_H above the floor, so crowding one side tips the basket.

const PIVOT_H := 4.6
const HALF := 2.3          # inner half-width of the basket
const WALL_H := 1.15
const ENVELOPE_Y := 10.5    # envelope centre above floor
const ENVELOPE_R := 5.6
const RIG_MASS := 3.2       # basket + burner, in "courier" units

var anchor := Vector3(0, 40, 0) # world position of the pivot ring
var vel := Vector3.ZERO
var yaw := 0.0
var yaw_vel := 0.0
var tilt := Vector2.ZERO      # x = pitch about local X, y = roll about local Z
var tilt_vel := Vector2.ZERO
var heat := 0.5
var venting := {}             # peer -> true
var helm_peer := 0
var helm_steer := 0.0
var helm_thrust := 0.0
var landed := false
var leaks := 0
var _leak_nodes: Array[Node3D] = []
var _hiss: AudioStreamPlayer3D
var _bramble_cd := 0.0
var load_units := 0.0
var game: Game
var islands: Array = []

# client smoothing targets
var _t_anchor := anchor
var _t_vel := Vector3.ZERO
var _t_yaw := 0.0
var _t_tilt := Vector2.ZERO
var _has_snap := false

var _flame: MeshInstance3D
var _flame_light: OmniLight3D
var _envelope_mat: ShaderMaterial
var _prop: Node3D
var _burst := 0.0
var _roar: AudioStreamPlayer
var _creak_t := 0.0
var stations: Array[Station] = []
var _vane: Node3D

func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	add_to_group("balloon")
	_build()
	if Sfx.has_sound("roar_loop"):
		_roar = Sfx.make_loop("roar_loop")
		_roar.volume_db = -40.0
	_apply_transform()

# ---------------------------------------------------------------- building
func _build() -> void:
	var wick := ShaderMaterial.new()
	wick.shader = preload("res://shaders/wicker.gdshader")
	var wo := ShaderMaterial.new()
	wo.shader = preload("res://shaders/outline.gdshader")
	wo.set_shader_parameter("width", 0.03)
	wick.next_pass = wo
	var wick_d := Pal.toon(Pal.WICKER_DARK, 0.0, 0.03, 0.1, 0.1)
	var w := HALF + 0.15
	# floor
	_col(Vector3(w * 2, 0.3, w * 2), Vector3(0, -0.15, 0))
	Pal.add(self, Pal.box(Vector3(w * 2, 0.3, w * 2)), wick_d, Vector3(0, -0.16, 0))
	# walls (collision a bit taller than the visual rim so nobody clips out by accident)
	for s in [-1.0, 1.0]:
		_col(Vector3(w * 2 + 0.3, WALL_H + 0.1, 0.3), Vector3(0, (WALL_H + 0.1) / 2, s * (w)))
		_col(Vector3(0.3, WALL_H + 0.1, w * 2 + 0.3), Vector3(s * (w), (WALL_H + 0.1) / 2, 0))
		Pal.add(self, Pal.box(Vector3(w * 2 + 0.3, WALL_H, 0.3)), wick, Vector3(0, WALL_H / 2, s * w))
		Pal.add(self, Pal.box(Vector3(0.3, WALL_H, w * 2 + 0.3)), wick, Vector3(s * w, WALL_H / 2, 0))
		# padded leather rim
		Pal.add(self, Pal.box(Vector3(w * 2 + 0.45, 0.16, 0.42)), Pal.toon(Color("7a4a2a"), 0.3, 0.03), Vector3(0, WALL_H, s * w))
		Pal.add(self, Pal.box(Vector3(0.42, 0.16, w * 2 + 0.45)), Pal.toon(Color("7a4a2a"), 0.3, 0.03), Vector3(s * w, WALL_H, 0))
	# woven bands
	for i in 3:
		var y := 0.22 + i * 0.32
		for s in [-1.0, 1.0]:
			Pal.add(self, Pal.box(Vector3(w * 2 + 0.34, 0.06, 0.34)), wick_d, Vector3(0, y, s * w))
			Pal.add(self, Pal.box(Vector3(0.34, 0.06, w * 2 + 0.34)), wick_d, Vector3(s * w, y, 0))
	# ropes from corners to the load ring + burner frame
	var ring_y := PIVOT_H - 0.6
	var rope := Pal.toon(Color("d8c7a0"), 0.0, 0.0, 0.1)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var a := Vector3(cx * w, WALL_H, cz * w)
			var b := Vector3(cx * 0.9, ring_y, cz * 0.9)
			_rope(a, b, rope, 0.035)
			_rope(b, Vector3(cx * 2.6, PIVOT_H + 2.6, cz * 2.6), rope, 0.03)
			# sandbags
			var sp := Vector3(cx * (w + 0.24), 0.45, cz * (w * 0.55))
			Pal.add(self, Pal.sphere(0.15, 10, 6), Pal.toon(Color("cfb58a"), 0.0, 0.02, 0.1, 0.15), sp, Vector3.ZERO, Vector3(1, 1.3, 1))
			Pal.add(self, Pal.cyl(0.05, 0.08, 0.1, 6), Pal.toon(Color("a08860"), 0.0, 0.0), sp + Vector3(0, 0.22, 0))
			_rope(sp + Vector3(0, 0.25, 0), Vector3(cx * (w + 0.1), WALL_H, cz * (w * 0.55)), Pal.toon(Color("d8c7a0"), 0.0, 0.0), 0.015)
	# burner frame + burner
	Pal.add(self, Pal.box(Vector3(1.9, 0.08, 0.08)), Pal.toon(Pal.BRASS, 0.6, 0.02), Vector3(0, ring_y, 0))
	Pal.add(self, Pal.box(Vector3(0.08, 0.08, 1.9)), Pal.toon(Pal.BRASS, 0.6, 0.02), Vector3(0, ring_y, 0))
	Pal.add(self, Pal.cyl(0.32, 0.22, 0.5), Pal.toon(Color("5b5b66"), 0.7, 0.03), Vector3(0, ring_y + 0.1, 0))
	Pal.add(self, Pal.cyl(0.36, 0.36, 0.08), Pal.toon(Pal.BRASS, 0.7, 0.02), Vector3(0, ring_y + 0.35, 0))
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.62, 0.2, 0.85)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flame = Pal.add(self, Pal.cyl(0.0, 0.26, 1.2, 10), fm, Vector3(0, ring_y + 0.95, 0))
	var core := Pal.add(_flame, Pal.cyl(0.0, 0.13, 0.8, 8), Pal.unshaded(Color(1.0, 0.95, 0.7)), Vector3(0, -0.15, 0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame_light = OmniLight3D.new()
	_flame_light.light_color = Color(1.0, 0.6, 0.25)
	_flame_light.omni_range = 9.0
	_flame_light.light_energy = 0.0
	_flame_light.position = Vector3(0, ring_y + 0.6, 0)
	add_child(_flame_light)
	# envelope
	_envelope_mat = ShaderMaterial.new()
	_envelope_mat.shader = preload("res://shaders/envelope.gdshader")
	var o := ShaderMaterial.new()
	o.shader = preload("res://shaders/outline.gdshader")
	o.set_shader_parameter("width", 0.06)
	_envelope_mat.next_pass = o
	var env := SphereMesh.new()
	env.radius = 1.0
	env.height = 2.0
	env.radial_segments = 36
	env.rings = 18
	Pal.add(self, env, _envelope_mat, Vector3(0, ENVELOPE_Y, 0), Vector3.ZERO, Vector3(ENVELOPE_R, ENVELOPE_R * 1.12, ENVELOPE_R))
	# skirt / throat
	Pal.add(self, Pal.cyl(2.9, 1.25, 2.6, 18), Pal.toon(Color("e8574a"), 0.0, 0.04, 0.2), Vector3(0, PIVOT_H + 2.9, 0))
	Pal.add(self, Pal.cyl(1.3, 1.3, 0.14, 18), Pal.toon(Pal.CREAM, 0.0, 0.03), Vector3(0, PIVOT_H + 1.6, 0))
	# crown cap
	Pal.add(self, Pal.cyl(0.9, 1.4, 0.5, 18), Pal.toon(Pal.CREAM, 0.0, 0.04), Vector3(0, ENVELOPE_Y + ENVELOPE_R * 1.1, 0))
	# name plate on the front of the basket
	var plate := Label3D.new()
	plate.text = "WINDBAGS AIRMAIL  No.7"
	plate.font = Pal.title_font
	plate.font_size = 40
	plate.outline_size = 0
	plate.modulate = Pal.CREAM
	plate.pixel_size = 0.0075
	plate.position = Vector3(0, 0.62, -w - 0.17)
	plate.rotation.y = PI
	add_child(plate)
	Pal.add(self, Pal.box(Vector3(2.7, 0.34, 0.04)), Pal.toon(Pal.NAVY, 0.2, 0.0), Vector3(0, 0.62, -w - 0.16))
	# propeller + helm at the back (+Z)
	var helm_base := Pal.add(self, Pal.cyl(0.08, 0.1, 0.9), Pal.toon(Pal.WICKER_DARK, 0.2, 0.02), Vector3(0, 0.45, w - 0.55))
	helm_base.name = "HelmPost"
	var wheel := Pal.add(self, _torus(0.34, 0.05), Pal.toon(Color("a0612e"), 0.3, 0.02), Vector3(0, 1.0, w - 0.55), Vector3(PI / 2 - 0.5, 0, 0))
	for i in 4:
		Pal.add(wheel, Pal.box(Vector3(0.7, 0.04, 0.04)), Pal.toon(Color("a0612e"), 0.3, 0.0), Vector3.ZERO, Vector3(0, i * PI / 4, 0))
	_prop = Node3D.new()
	_prop.position = Vector3(0, 0.75, w + 0.55)
	add_child(_prop)
	Pal.add(self, Pal.cyl(0.12, 0.12, 0.7), Pal.toon(Color("5b5b66"), 0.6, 0.02), Vector3(0, 0.75, w + 0.3), Vector3(PI / 2, 0, 0))
	for i in 3:
		var blade := Pal.add(_prop, Pal.box(Vector3(0.16, 0.85, 0.04)), Pal.toon(Pal.CREAM, 0.2, 0.02), Vector3(0, 0.0, 0), Vector3(0, 0, i * TAU / 3))
		blade.position = Vector3(sin(i * TAU / 3) * -0.42, cos(i * TAU / 3) * 0.42, 0)
	# pump (bellows) front-left, vent cord front-right
	var pump := Pal.add(self, Pal.box(Vector3(0.55, 0.5, 0.75)), Pal.toon(Color("8a3b2e"), 0.2, 0.03), Vector3(-1.55, 0.25, -1.55))
	Pal.add(pump, Pal.box(Vector3(0.6, 0.06, 0.8)), Pal.toon(Color("6a4a2a"), 0.2, 0.02), Vector3(0, 0.28, 0))
	Pal.add(pump, Pal.cyl(0.035, 0.035, 0.9), Pal.toon(Pal.BRASS, 0.6, 0.02), Vector3(0, 0.6, 0.25), Vector3(-0.4, 0, 0))
	_rope(Vector3(-1.55, 0.9, -1.3), Vector3(-0.2, ring_y, -0.2), Pal.toon(Color("4a4a55"), 0.4, 0.0), 0.05)
	_rope(Vector3(1.55, 1.45, -1.55), Vector3(0.4, PIVOT_H + 5.0, -0.4), Pal.toon(Color("d23c35"), 0.0, 0.0), 0.03)
	Pal.add(self, Pal.cyl(0.06, 0.06, 0.28), Pal.toon(Color("f4e3c2"), 0.0, 0.02), Vector3(1.55, 1.35, -1.55))
	# pennants along a rope
	for i in 7:
		var t := i / 6.0
		var p := Vector3(-w, WALL_H, -w).lerp(Vector3(-0.9, ring_y, -0.9), t)
		var fl := Pal.add(self, Pal.prism(Vector3(0.22, 0.3, 0.02)), Pal.toon(Pal.ISLAND_COLORS[i % 5], 0.0, 0.0), p + Vector3(0, -0.18, 0), Vector3(0, 0, PI))
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# wind vane on the front-left corner: points where the current layer blows
	Pal.add(self, Pal.cyl(0.03, 0.03, 0.9, 6), Pal.toon(Pal.INK, 0.4, 0.0), Vector3(-w, WALL_H + 0.45, -w))
	_vane = Node3D.new()
	_vane.position = Vector3(-w, WALL_H + 0.9, -w)
	add_child(_vane)
	Pal.add(_vane, Pal.cyl(0.0, 0.07, 0.25, 6), Pal.toon(Pal.BRASS, 0.8, 0.012), Vector3(0, 0, -0.3), Vector3(-PI / 2, 0, 0))
	Pal.add(_vane, Pal.box(Vector3(0.02, 0.05, 0.6)), Pal.toon(Pal.BRASS, 0.8, 0.0), Vector3.ZERO)
	Pal.add(_vane, Pal.box(Vector3(0.02, 0.22, 0.2)), Pal.toon(Color("e8574a"), 0.2, 0.012), Vector3(0, 0, 0.3))
	# stations
	_station(Station.Kind.PUMP, Vector3(-1.55, 0.6, -1.55))
	_station(Station.Kind.VENT, Vector3(1.55, 0.9, -1.55))
	_station(Station.Kind.HELM, Vector3(0, 0.8, w - 0.55))
	# patch kit: a sewing basket hung on the front wall
	var kit := Pal.add(self, Pal.cyl(0.26, 0.2, 0.26, 12), Pal.toon(Color("d8a65a"), 0.0, 0.025, 0.1, 0.15), Vector3(0, 0.95, -w + 0.3))
	Pal.add(kit, Pal.sphere(0.08, 8, 6), Pal.toon(Color("e8574a"), 0.0, 0.0), Vector3(0.08, 0.16, 0))
	Pal.add(kit, Pal.sphere(0.07, 8, 6), Pal.toon(Color("3fb3a6"), 0.0, 0.0), Vector3(-0.08, 0.15, 0.04))
	Pal.add(kit, Pal.cyl(0.01, 0.01, 0.3, 4), Pal.toon(Color("cccccc"), 0.8, 0.0), Vector3(0, 0.22, -0.05), Vector3(0.6, 0, 0.3))
	_station(Station.Kind.PATCH, Vector3(0, 0.95, -w + 0.3))
	# leak jets on the envelope (hidden until pricked)
	var jet_mat := Pal.unshaded(Color(1, 1, 1, 0.55))
	for i in 4:
		var a := i * 1.7 + 0.4
		var yy := 0.1 - i * 0.18
		var n := Vector3(cos(a), yy, sin(a)).normalized()
		var base := Vector3(0, ENVELOPE_Y, 0) + Vector3(n.x * ENVELOPE_R, n.y * ENVELOPE_R * 1.12, n.z * ENVELOPE_R)
		var jet := Node3D.new()
		add_child(jet)
		jet.position = base
		jet.look_at_from_position(base, base + n * 2.0, Vector3.UP)
		var cone := Pal.add(jet, Pal.cyl(0.05, 0.45, 1.6, 8), jet_mat, Vector3(0, 0, -0.8), Vector3(PI / 2, 0, 0))
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Pal.add(jet, Pal.box(Vector3(0.7, 0.7, 0.05)), Pal.toon(Color("6a4a8a"), 0.0, 0.02), Vector3.ZERO)
		jet.visible = false
		_leak_nodes.append(jet)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.position = Vector3(0, ENVELOPE_Y, 0)
	_hiss.unit_size = 10.0
	add_child(_hiss)

func _station(k: Station.Kind, pos: Vector3) -> void:
	var s := Station.new()
	s.kind = k
	s.balloon = self
	s.position = pos
	s.add_to_group("interactable")
	add_child(s)
	stations.append(s)

func _col(size: Vector3, pos: Vector3) -> void:
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	c.shape = b
	c.position = pos
	add_child(c)

func _rope(a: Vector3, b: Vector3, mat: Material, r: float) -> void:
	var d := b - a
	var mi := Pal.add(self, Pal.cyl(r, r, d.length(), 5), mat, (a + b) / 2)
	mi.look_at_from_position((a + b) / 2, b, Vector3.FORWARD if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _torus(r: float, t: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = r - t
	m.outer_radius = r + t
	m.rings = 16
	m.ring_segments = 6
	return m

# ---------------------------------------------------------------- queries
func floor_y() -> float:
	return xform().origin.y

func altitude() -> float:
	return anchor.y - PIVOT_H

func is_inside(world_pos: Vector3, margin := 0.0) -> bool:
	var l := local_of(world_pos)
	return absf(l.x) < HALF + 0.2 + margin and absf(l.z) < HALF + 0.2 + margin and l.y > -0.6 and l.y < 3.2

func equilibrium_heat() -> float:
	return 0.34 + load_units * 0.045

func vertical_speed() -> float:
	return vel.y

# ---------------------------------------------------------------- requests (any peer)
func request_pump() -> void:
	_srv_pump.rpc_id(1)

func request_patch() -> void:
	_srv_patch.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _srv_patch() -> void:
	if not multiplayer.is_server() or leaks <= 0:
		return
	leaks -= 1
	_fx_patched.rpc(leaks)

@rpc("authority", "call_local", "reliable")
func _fx_patched(n: int) -> void:
	leaks = n
	Sfx.play3d("grab", global_position + Vector3(0, 1, -2), 0.7, 0.0)
	Sfx.play3d("coin", global_position + Vector3(0, 1, -2), 0.8, -6.0)

@rpc("authority", "call_local", "reliable")
func _fx_pricked(n: int) -> void:
	leaks = n
	Sfx.play3d("pop", global_position + Vector3(0, ENVELOPE_Y, 0), 0.7, 4.0)
	if game:
		game.toast("Hssss! The envelope's been pricked. Patch it with the sewing basket!", Color("8a70d6"))

func request_vent(on: bool) -> void:
	_srv_vent.rpc_id(1, on)

func request_helm(on: bool) -> void:
	_srv_helm.rpc_id(1, on)

func send_helm_input(steer: float, thrust: float) -> void:
	if multiplayer.is_server():
		helm_steer = steer
		helm_thrust = thrust
	else:
		_srv_helm_input.rpc_id(1, steer, thrust)

@rpc("any_peer", "call_local", "reliable")
func _srv_pump() -> void:
	if not multiplayer.is_server():
		return
	heat = minf(heat + 0.075, 1.0)
	_fx_pump.rpc()

@rpc("any_peer", "call_local", "reliable")
func _srv_vent(on: bool) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	if on:
		venting[id] = true
	else:
		venting.erase(id)

@rpc("any_peer", "call_local", "reliable")
func _srv_helm(on: bool) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	if on and helm_peer == 0:
		helm_peer = id
	elif not on and helm_peer == id:
		helm_peer = 0
		helm_steer = 0.0
		helm_thrust = 0.0

@rpc("any_peer", "unreliable_ordered")
func _srv_helm_input(steer: float, thrust: float) -> void:
	if multiplayer.get_remote_sender_id() == helm_peer:
		helm_steer = clampf(steer, -1, 1)
		helm_thrust = clampf(thrust, -1, 1)

@rpc("authority", "call_local", "reliable")
func _fx_pump() -> void:
	_burst = 1.0
	Sfx.play3d("roar", global_position + Vector3(0, PIVOT_H, 0), randf_range(0.9, 1.1), -2.0)
	Sfx.play3d("pump", global_position + Vector3(-1.5, 0.5, -1.5), randf_range(0.95, 1.05), -4.0)

func release_peer(id: int) -> void:
	venting.erase(id)
	if helm_peer == id:
		helm_peer = 0
		helm_steer = 0.0
		helm_thrust = 0.0

# ---------------------------------------------------------------- simulation
func _physics_process(dt: float) -> void:
	if multiplayer.is_server():
		_simulate(dt)
	else:
		_smooth(dt)
	_apply_transform()
	_animate(dt)

func _simulate(dt: float) -> void:
	var t: float = game.clock if game else 0.0
	# --- load & tilt moment
	var moment := Vector2.ZERO
	load_units = 0.0
	for n in get_tree().get_nodes_in_group("weight"):
		var node := n as Node3D
		if node == null or not is_inside(node.global_position):
			continue
		var wgt: float = node.get("weight")
		var l := local_of(node.global_position)
		load_units += wgt
		moment += Vector2(l.x, l.z) * wgt
	var total := RIG_MASS + load_units
	var target := Vector2(atan(moment.y / (total * PIVOT_H)), -atan(moment.x / (total * PIVOT_H)))
	# wind gusts rock the basket
	var g := Wind.gust(t)
	target += Vector2(sin(t * 1.7), cos(t * 1.3)) * g * 0.06
	tilt_vel += ((target - tilt) * 7.0 - tilt_vel * 1.6) * dt
	tilt += tilt_vel * dt
	tilt = tilt.clamp(Vector2(-0.55, -0.55), Vector2(0.55, 0.55))
	if game and game.phase == "dock":
		# moored to the Post Office until someone rings the bell
		heat = clampf(heat - 0.0105 * dt, 0.0, 1.0)
		vel = Vector3.ZERO
		return
	# --- heat
	var cool := 0.0105 + (0.09 if not venting.is_empty() else 0.0) + leaks * 0.012
	heat = clampf(heat - cool * dt, 0.0, 1.0)
	var alt := altitude()
	var thin := clampf((alt - 150.0) / 40.0, 0.0, 1.0) # thin air near the ceiling
	var lift := (heat - equilibrium_heat()) * 7.0 - thin * 3.0
	vel.y += (lift - vel.y * 0.55) * dt
	vel.y = clampf(vel.y, -6.0, 4.5)
	# --- horizontal: drift toward wind, plus a little helm thrust
	var wind := Wind.at(alt, t) * (1.0 + g * 0.5)
	if landed:
		wind = Vector3.ZERO
	var hv := Vector3(vel.x, 0, vel.z)
	hv += (wind - hv) * 0.22 * dt
	yaw_vel += (helm_steer * 0.55 - yaw_vel) * 2.0 * dt
	yaw += yaw_vel * dt
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	hv += fwd * helm_thrust * 0.75 * dt
	vel.x = hv.x
	vel.z = hv.z
	anchor += vel * dt
	# --- cloud sea floor: the basket bobs on the fluff
	var floor_alt := anchor.y - PIVOT_H
	if floor_alt < 2.0:
		vel.y += (2.0 - floor_alt) * 3.0 * dt
		vel *= 1.0 - 0.8 * dt
	# --- world bounds: a soft wall of weather
	var flat := Vector2(anchor.x, anchor.z)
	if flat.length() > 520.0:
		var push := -flat.normalized() * (flat.length() - 520.0) * 0.08
		vel.x += push.x * dt
		vel.z += push.y * dt
	_collide_islands(dt)
	# bramble clouds prick the envelope
	_bramble_cd = maxf(_bramble_cd - dt, 0.0)
	if game and _bramble_cd <= 0.0 and leaks < 4:
		var ec := anchor + Vector3(0, ENVELOPE_Y - PIVOT_H, 0)
		for b in game.brambles:
			if b.active and b.hits(ec, ENVELOPE_R * 0.9):
				_bramble_cd = 2.5
				_fx_pricked.rpc(leaks + 1)
				tilt_vel += Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
				break

func _collide_islands(dt: float) -> void:
	landed = false
	var bottom := anchor.y - PIVOT_H - 0.3
	var top := anchor.y + ENVELOPE_Y - PIVOT_H + ENVELOPE_R
	for isl in islands:
		var c: Vector3 = isl.top_center
		var r: float = isl.radius
		var d := Vector2(anchor.x - c.x, anchor.z - c.z)
		var dist := d.length()
		if bottom > c.y + 0.4 or top < isl.bottom_y:
			continue
		if dist < r + 1.2 and bottom > c.y - 2.4:
			# resting on the island top
			if bottom < c.y:
				anchor.y += c.y - bottom
				vel.y = maxf(vel.y, 0.0)
			if bottom < c.y + 0.1 and vel.y <= 0.05:
				vel.x *= 1.0 - minf(4.0 * dt, 1.0)
				vel.z *= 1.0 - minf(4.0 * dt, 1.0)
				landed = true
			# shove off obstacles (cottages, trees) on top
			for ob in isl.obs:
				var od := Vector2(anchor.x - ob.x, anchor.z - ob.z)
				var need: float = ob.w + 2.9
				if od.length() < need:
					var n := od.normalized() if od.length() > 0.01 else Vector2.RIGHT
					var fix := n * (need - od.length())
					anchor.x += fix.x * minf(6.0 * dt, 1.0)
					anchor.z += fix.y * minf(6.0 * dt, 1.0)
		elif dist < r + 3.0:
			# side bump against the rock (or envelope against the underside)
			if bottom < c.y - 2.4 and anchor.y + 4.0 < isl.bottom_y + (c.y - isl.bottom_y) * 0.5:
				# we're under it - push down
				vel.y = minf(vel.y, -0.5)
			var n := d.normalized() if dist > 0.01 else Vector2.RIGHT
			anchor.x = c.x + n.x * (r + 3.0)
			anchor.z = c.z + n.y * (r + 3.0)
			var into := vel.x * n.x + vel.z * n.y
			if into < 0:
				vel.x -= n.x * into * 1.4
				vel.z -= n.y * into * 1.4
				if into < -1.2:
					tilt_vel += Vector2(n.y, -n.x) * 0.6
					Sfx.play3d("creak", global_position, 0.9)

func _smooth(dt: float) -> void:
	if not _has_snap:
		return
	_t_anchor += _t_vel * dt
	var k := 1.0 - exp(-10.0 * dt)
	anchor = anchor.lerp(_t_anchor, k)
	if anchor.distance_to(_t_anchor) > 12.0:
		anchor = _t_anchor
	yaw = lerp_angle(yaw, _t_yaw, k)
	tilt = tilt.lerp(_t_tilt, k)
	vel = _t_vel

## The rig's true current transform (the node's own transform lags a physics
## sync behind because of sync_to_physics).
func xform() -> Transform3D:
	var b := Basis(Vector3.UP, yaw) * Basis.from_euler(Vector3(tilt.x, 0.0, tilt.y))
	return Transform3D(b, anchor + b * Vector3(0, -PIVOT_H, 0))

func local_of(world_pos: Vector3) -> Vector3:
	return xform().affine_inverse() * world_pos

func _apply_transform() -> void:
	global_transform = xform()

func _animate(dt: float) -> void:
	_burst = maxf(_burst - dt * 1.6, 0.0)
	var f := clampf(heat * 0.6 + _burst * 1.2, 0.08, 1.6)
	var flick := 1.0 + sin(Time.get_ticks_msec() * 0.031) * 0.08 + sin(Time.get_ticks_msec() * 0.017) * 0.06
	_flame.scale = Vector3(0.6 + f * 0.5, f * flick, 0.6 + f * 0.5)
	_flame_light.light_energy = (0.3 + f * 1.6) * flick
	_envelope_mat.set_shader_parameter("glow", f * 0.5)
	_prop.rotate_z(dt * (helm_thrust * 18.0 + 0.4))
	if game:
		var wv := Wind.at(altitude(), game.clock)
		var target := atan2(-wv.x, -wv.z) - yaw
		_vane.rotation = Vector3(-tilt.x, lerp_angle(_vane.rotation.y, target, minf(dt * 3.0, 1.0)), -tilt.y)
	for i in _leak_nodes.size():
		var on := i < leaks
		_leak_nodes[i].visible = on
		if on:
			_leak_nodes[i].scale = Vector3.ONE * (0.8 + sin(Time.get_ticks_msec() * 0.05 + i) * 0.2)
	if _hiss:
		if leaks > 0 and not _hiss.playing and Sfx.has_sound("wind_loop"):
			var lp := Sfx.make_loop("wind_loop")
			_hiss.stream = lp.stream
			lp.queue_free()
			_hiss.pitch_scale = 3.2
			_hiss.play()
		elif leaks == 0 and _hiss.playing:
			_hiss.stop()
		_hiss.volume_db = -8.0 + leaks * 2.0
	if _roar:
		_roar.volume_db = lerpf(_roar.volume_db, linear_to_db(clampf(0.08 + _burst * 0.5, 0.001, 1.0)), 0.1)
	_creak_t -= dt
	if _creak_t < 0.0 and tilt_vel.length() > 0.25:
		_creak_t = randf_range(0.8, 1.6)
		Sfx.play3d("creak", global_position + Vector3(0, 0.6, 0), randf_range(0.8, 1.2), -6.0)

# ---------------------------------------------------------------- net state
func get_state() -> Array:
	return [anchor, vel, yaw, tilt, heat, not venting.is_empty(), helm_peer, helm_thrust, load_units, landed, leaks]

func set_state(s: Array) -> void:
	_t_anchor = s[0]
	_t_vel = s[1]
	_t_yaw = s[2]
	_t_tilt = s[3]
	heat = s[4]
	helm_peer = s[6]
	helm_thrust = s[7]
	load_units = s[8]
	landed = s[9]
	leaks = s[10]
	if not _has_snap:
		anchor = _t_anchor
		yaw = _t_yaw
		tilt = _t_tilt
		_has_snap = true

func is_venting_now(s_venting: bool) -> bool:
	return s_venting
