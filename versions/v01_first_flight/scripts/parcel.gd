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

var _t_local := Vector3.ZERO
var _t_rot := Quaternion.IDENTITY
var _has_snap := false
var _prev_v := Vector3.ZERO
var _prev_pos := Vector3.ZERO
var _thud_cd := 0.0

func setup(id: int, k: int, addr: int, g: Node) -> void:
	pid = id
	kind = k
	address = addr
	game = g
	weight = WEIGHTS[k]
	name = "Parcel%d" % id

func _ready() -> void:
	add_to_group("parcel")
	add_to_group("interactable")
	add_to_group("weight")
	collision_layer = 4
	collision_mask = 1 | 4
	mass = 2.0 + kind * 2.0
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
	var paper := Pal.toon(Color("c99a62").lerp(Color("d8b07a"), randf()), 0.0, 0.022, 0.15, 0.1)
	Pal.add(self, Pal.box(size), paper)
	var twine := Pal.toon(Color("efe2c4"), 0.0, 0.0)
	Pal.add(self, Pal.box(Vector3(size.x + 0.01, size.y + 0.01, 0.04)), twine)
	Pal.add(self, Pal.box(Vector3(0.04, size.y + 0.01, size.z + 0.01)), twine)
	Pal.add(self, Pal.sphere(0.05, 8, 5), twine, Vector3(0, size.y / 2 + 0.02, 0), Vector3.ZERO, Vector3(1.6, 0.6, 1.0))
	# address tag in island colour + a stamp
	var c: Color = Pal.ISLAND_COLORS[address % Pal.ISLAND_COLORS.size()]
	Pal.add(self, Pal.box(Vector3(size.x * 0.42, 0.02, size.z * 0.32)), Pal.toon(c, 0.0, 0.0), Vector3(size.x * 0.2, size.y / 2 + 0.005, size.z * 0.22))
	Pal.add(self, Pal.box(Vector3(0.12, 0.022, 0.14)), Pal.toon(Pal.CREAM, 0.0, 0.0), Vector3(-size.x * 0.28, size.y / 2 + 0.006, -size.z * 0.26))
	for s in [-1.0, 1.0]:
		Pal.add(self, Pal.box(Vector3(size.x * 0.42, size.y * 0.32, 0.02)), Pal.toon(c, 0.0, 0.0), Vector3(size.x * 0.2, 0, s * (size.z / 2 + 0.005)))
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_prev_pos = global_position

func _physics_process(dt: float) -> void:
	_thud_cd = maxf(_thud_cd - dt, 0.0)
	if holder != 0:
		var c: Node = game.courier(holder)
		if c and not c.lost:
			global_transform = c.hand_transform()
		_prev_pos = global_position
		return
	if multiplayer.is_server():
		if not freeze:
			if linear_velocity.y < -0.5 or linear_velocity.length() > 2.0:
				air_time += dt
			else:
				air_time = 0.0
		if global_position.y < -3.0:
			game.parcel_lost(self)
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
