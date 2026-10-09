class_name Bramble
extends Node3D
## A thorny storm-cloud drifting on its layer's wind. Touching one pops couriers
## and pricks the envelope. Position is a pure function of the shared clock, so
## every peer agrees without syncing anything.

var base := Vector3.ZERO
var drift := Vector3.ZERO
var radius := 7.0
var active := false
var game: Game
var _flash := 0.0
var _mat: ShaderMaterial
var _spin: Node3D

func setup(b: Vector3, r: float, g: Game) -> void:
	base = b
	radius = r
	game = g
	var w := Wind.at(b.y, 0.0)
	drift = w.normalized() * 1.6

func _ready() -> void:
	_spin = Node3D.new()
	add_child(_spin)
	_mat = Pal.toon(Color("6a5a8e"), 0.0, 0.06, 0.35).duplicate()
	var dark := Pal.toon(Color("4a3f6e"), 0.0, 0.05, 0.2)
	var thorn := Pal.toon(Color("2f2648"), 0.4, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base.x * 13.0 + base.z * 7.0)
	for i in 6:
		var o := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.25, 0.3), rng.randf_range(-0.6, 0.6)) * radius
		var s := radius * rng.randf_range(0.42, 0.62)
		Pal.add(_spin, Pal.sphere(1.0, 12, 8), _mat if i % 2 == 0 else dark, o, Vector3.ZERO, Vector3(s, s * 0.8, s))
	for i in 26:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 0.8), rng.randf_range(-1, 1)).normalized()
		var p := d * radius * 0.82
		var t := Pal.add(_spin, Pal.cyl(0.0, 0.32, 1.9, 5), thorn, p + d * 0.7)
		t.look_at_from_position(p + d * 0.7, p + d * 3.0, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
		t.rotate_object_local(Vector3.RIGHT, -PI / 2)
	visible = false

func pos() -> Vector3:
	var p := base + drift * (game.clock if game else 0.0)
	p.x = wrapf(p.x, -560.0, 560.0)
	p.z = wrapf(p.z, -560.0, 560.0)
	return p

func hits(point: Vector3, r: float) -> bool:
	return active and point.distance_to(pos()) < radius * 0.85 + r

func _process(dt: float) -> void:
	visible = active
	if not active:
		return
	global_position = pos()
	_spin.rotate_y(dt * 0.15)
	_flash -= dt
	if _flash < -randf_range(2.0, 7.0):
		_flash = 0.12
	_mat.set_shader_parameter("albedo", Color("c8b8ff") if _flash > 0.0 else Color("6a5a8e"))
