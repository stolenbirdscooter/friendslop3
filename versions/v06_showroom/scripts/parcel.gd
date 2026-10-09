class_name Parcel
extends RigidBody3D
## A brown-paper parcel tied with string and tagged in its island's colour.
## Host simulates it; clients show it kinematically from snapshots.

const SIZES := [Vector3(0.5, 0.4, 0.5), Vector3(0.75, 0.5, 0.6), Vector3(0.95, 0.75, 0.9)]
const WEIGHTS := [0.2, 0.35, 0.6]

var pid := 0
var kind := 0
var address := 0
var holder := 0
var last_thrower := 0
var weight := 0.2
var game: Game
var reach := 1.9
var thrown_from_alt := 0.0
var air_time := 0.0
var flavor := "normal" # normal | fragile | heavy | hen | express
var spawn_t := 0.0
var _hop_t := 3.0
var _last_lv := Vector3.ZERO

var _t_local := Vector3.ZERO
var _t_rot := Quaternion.IDENTITY
var _has_snap := false
var _prev_v := Vector3.ZERO
var _prev_pos := Vector3.ZERO
var _thud_cd := 0.0

func setup(id: int, k: int, addr: int, g: Game, fl := "normal") -> void:
	pid = id
	kind = k
	address = addr
	game = g
	flavor = fl
	if flavor == "heavy":
		kind = 1
	elif flavor == "hen":
		kind = 0
	weight = WEIGHTS[kind] if flavor != "heavy" else 1.5
	name = "Parcel%d" % id

func _ready() -> void:
	add_to_group("parcel")
	add_to_group("interactable")
	add_to_group("weight")
	collision_layer = 4
	collision_mask = 1 | 4
	mass = 2.0 + kind * 2.0 if flavor != "heavy" else 14.0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.42
	pm.bounce = 0.18
	physics_material_override = pm
	continuous_cd = true
	var size: Vector3 = SIZES[kind]
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	add_child(cs)
	var c: Color = Pal.ISLAND_COLORS[address % Pal.ISLAND_COLORS.size()]
	if flavor == "hen":
		_build_hen(c)
		_finish_ready()
		return
	var base_col := Color("c99a62").lerp(Color("d8b07a"), randf())
	if flavor == "fragile":
		base_col = Color("dfe8ee")
	elif flavor == "heavy":
		base_col = Color("5d6272")
	var paper := Pal.toon(base_col, 0.5 if flavor == "heavy" else 0.0, 0.022, 0.15, 0.1)
	Pal.add(self, Pal.box(size), paper)
	var twine := Pal.toon(Color("f2b33d") if flavor == "express" else (Color("3a3f4e") if flavor == "heavy" else Color("efe2c4")), 0.6 if flavor == "express" else 0.0, 0.0)
	Pal.add(self, Pal.box(Vector3(size.x + 0.01, size.y + 0.01, 0.04)), twine)
	Pal.add(self, Pal.box(Vector3(0.04, size.y + 0.01, size.z + 0.01)), twine)
	Pal.add(self, Pal.sphere(0.05, 8, 5), twine, Vector3(0, size.y / 2 + 0.02, 0), Vector3.ZERO, Vector3(1.6, 0.6, 1.0))
	# address tag in island colour + a stamp
	Pal.add(self, Pal.box(Vector3(size.x * 0.42, 0.02, size.z * 0.32)), Pal.toon(c, 0.0, 0.0), Vector3(size.x * 0.2, size.y / 2 + 0.005, size.z * 0.22))
	Pal.add(self, Pal.box(Vector3(0.12, 0.022, 0.14)), Pal.toon(Pal.CREAM, 0.0, 0.0), Vector3(-size.x * 0.28, size.y / 2 + 0.006, -size.z * 0.26))
	for s in [-1.0, 1.0]:
		Pal.add(self, Pal.box(Vector3(size.x * 0.42, size.y * 0.32, 0.02)), Pal.toon(c, 0.0, 0.0), Vector3(size.x * 0.2, 0, s * (size.z / 2 + 0.005)))
	if flavor == "heavy":
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				Pal.add(self, Pal.sphere(0.04, 6, 4), Pal.toon(Pal.BRASS, 0.8, 0.0), Vector3(x * size.x * 0.42, size.y * 0.5, z * size.z * 0.42))
		_side_label("HEAVY", Color("f2b33d"), size)
	elif flavor == "fragile":
		Pal.add(self, Pal.box(Vector3(size.x + 0.012, 0.09, size.z + 0.012)), Pal.toon(Color("d23c35"), 0.0, 0.0), Vector3(0, -size.y * 0.25, 0))
		_side_label("FRAGILE", Color("d23c35"), size)
	elif flavor == "express":
		_side_label("EXPRESS", Color("c78a1a"), size)
	_finish_ready()

func _finish_ready() -> void:
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_prev_pos = global_position

func _side_label(t: String, col: Color, size: Vector3) -> void:
	for sd in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = t
		l.font = Pal.title_font
		l.font_size = 48
		l.outline_size = 10
		l.modulate = col
		l.outline_modulate = Pal.CREAM
		l.pixel_size = 0.004
		l.position = Vector3(sd * (size.x / 2 + 0.012), size.y * 0.12, 0)
		l.rotation.y = sd * PI / 2
		add_child(l)

func _build_hen(c: Color) -> void:
	# a wicker hatbox with an indignant hen poking out
	var wick := Pal.toon(Pal.WICKER, 0.0, 0.022, 0.15, 0.15)
	Pal.add(self, Pal.cyl(0.27, 0.25, 0.4, 12), wick)
	Pal.add(self, Pal.cyl(0.29, 0.29, 0.06, 12), Pal.toon(c, 0.0, 0.02), Vector3(0, 0.18, 0))
	var hen := Node3D.new()
	hen.name = "Hen"
	hen.position = Vector3(0, 0.3, 0)
	add_child(hen)
	Pal.add(hen, Pal.sphere(0.17, 12, 8), Pal.toon(Color("fbf3e4"), 0.2, 0.02), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1.1))
	Pal.add(hen, Pal.sphere(0.11, 10, 6), Pal.toon(Color("fbf3e4"), 0.2, 0.02), Vector3(0, 0.17, -0.1))
	Pal.add(hen, Pal.box(Vector3(0.03, 0.08, 0.1)), Pal.toon(Color("e8392e"), 0.0, 0.0), Vector3(0, 0.29, -0.1))
	Pal.add(hen, Pal.cyl(0.0, 0.035, 0.08, 5), Pal.toon(Color("f2b33d"), 0.0, 0.0), Vector3(0, 0.16, -0.23), Vector3(-PI / 2, 0, 0))
	for sd in [-1.0, 1.0]:
		Pal.add(hen, Pal.sphere(0.02, 5, 4), Pal.toon(Pal.INK, 0.5, 0.0), Vector3(sd * 0.06, 0.2, -0.19))
	# tag
	Pal.add(self, Pal.box(Vector3(0.18, 0.12, 0.02)), Pal.toon(c, 0.0, 0.0), Vector3(0, 0.0, -0.27))

func _physics_process(dt: float) -> void:
	_thud_cd = maxf(_thud_cd - dt, 0.0)
	if holder > 0:
		var c: Courier = game.courier(holder)
		if c and not c.lost:
			global_transform = c.hand_transform()
		_prev_pos = global_position
		return
	elif holder < 0:
		var g: Gull = game.gulls.get(-holder)
		if g:
			global_transform = g.carry_point()
		_prev_pos = global_position
		return
	var hen := get_node_or_null("Hen")
	if hen:
		hen.rotation.y = sin(Time.get_ticks_msec() * 0.003 + pid) * 0.8
	if multiplayer.is_server():
		if not freeze:
			if linear_velocity.y < -0.5 or linear_velocity.length() > 2.0:
				air_time += dt
			else:
				air_time = 0.0
		if global_position.y < -3.0:
			game.parcel_lost(self)
			return
		if flavor == "fragile" and (_last_lv - linear_velocity).length() > 9.0 and air_time > 0.15:
			game.parcel_broken(self)
			return
		_last_lv = linear_velocity
		if flavor == "hen" and linear_velocity.length() < 0.6:
			_hop_t -= dt
			if _hop_t <= 0.0:
				_hop_t = randf_range(2.5, 6.0)
				var a := randf() * TAU
				linear_velocity += Vector3(cos(a) * 2.2, 3.6, sin(a) * 2.2)
				angular_velocity = Vector3(0, randf_range(-4, 4), 0)
				game.fx_cluck.rpc(pid)
	elif _has_snap and game.balloon:
		var goal: Transform3D = game.balloon.xform() * Transform3D(Basis(_t_rot), _t_local)
		var k := 1.0 - exp(-14.0 * dt)
		var gp := global_position.lerp(goal.origin, k)
		if gp.distance_to(goal.origin) > 8.0:
			gp = goal.origin
		global_transform = Transform3D(global_basis.orthonormalized().slerp(goal.basis.orthonormalized(), k), gp)
	# thud detection (works identically on every peer)
	var v := (global_position - _prev_pos) / maxf(dt, 0.0001)
	if _prev_v.length() > 3.0 and (v - _prev_v).length() > 3.5 and _thud_cd <= 0.0:
		_thud_cd = 0.25
		Sfx.play3d("thud", global_position, randf_range(0.85, 1.1) - kind * 0.1, clampf(_prev_v.length() * 1.2 - 14.0, -18.0, 0.0))
	_prev_v = v
	_prev_pos = global_position

func set_snap(local_pos: Vector3, rot: Quaternion) -> void:
	_t_local = local_pos
	_t_rot = rot
	if not _has_snap and game.balloon:
		global_transform = game.balloon.xform() * Transform3D(Basis(rot), local_pos)
	_has_snap = true

func set_held(peer: int) -> void:
	holder = peer
	if multiplayer.is_server():
		freeze = peer != 0
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	collision_layer = 0 if peer != 0 else 4
