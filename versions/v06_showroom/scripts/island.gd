class_name Island
extends Node3D
## A floating rock with cottages, trees and a big brass-rimmed mail chute.

const NAMES: Array[String] = ["Teaspoon Rock", "Lower Bramblewick", "Gullhaven", "Old Mossback",
	"Pickle Spire", "Thimbleton", "Hushing Pines", "Kettle Bluff", "Saint Puddle",
	"Nettlecombe", "Drizzle End", "Button Isle", "Gumboot Hollow", "Mizzle Top"]

var index := 0
var iname := ""
var color := Color.WHITE
var radius := 12.0
var top_center := Vector3.ZERO
var bottom_y := 0.0
var game: Game
var chute: Area3D
var chute_pos := Vector3.ZERO
var is_home := false
var bell_spot: Node3D
var beacon: MeshInstance3D
var _flag: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _windows: Array[MeshInstance3D] = []

class Obstacle:
	var x: float
	var z: float
	var w: float
	func _init(px: float, pz: float, pw: float) -> void:
		x = px
		z = pz
		w = pw

var obs: Array = []

func build(idx: int, pos: Vector3, r: float, seed_: int, home := false) -> void:
	index = idx
	is_home = home
	radius = r
	_rng.seed = seed_
	iname = "Windbag Post Office" if home else NAMES[idx % NAMES.size()]
	color = Pal.CREAM if home else Pal.ISLAND_COLORS[idx % Pal.ISLAND_COLORS.size()]
	position = pos
	top_center = pos
	var depth := r * _rng.randf_range(1.3, 1.9)
	bottom_y = pos.y - depth
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	# grass cap
	var grass := Pal.toon(Pal.MOSS, 0.0, 0.05, 0.15, 0.08)
	Pal.add(self, Pal.cyl(r, r * 0.97, 0.9, 14), grass, Vector3(0, -0.45, 0))
	Pal.add(self, Pal.cyl(r * 1.01, r * 0.99, 0.35, 14), Pal.toon(Pal.MOSS_DARK, 0.0, 0.0), Vector3(0, -0.95, 0))
	_shape(body, _cyl_shape(r, 1.0), Vector3(0, -0.5, 0))
	# faceted rock, tapering to a point
	var rock := Pal.toon(Pal.ROCK, 0.0, 0.06, 0.12, 0.14)
	var rock_d := Pal.toon(Pal.ROCK_DARK, 0.0, 0.05, 0.1, 0.14)
	var y := -1.0
	var rr := r * 0.98
	var segs := [0.35, 0.33, 0.32]
	for i in 3:
		var h: float = depth * segs[i]
		var nr: float = rr * (0.62 if i < 2 else 0.0)
		var m := Pal.add(self, Pal.cyl(rr, nr, h, 9), rock if i % 2 == 0 else rock_d, Vector3(_rng.randf_range(-0.4, 0.4), y - h / 2, _rng.randf_range(-0.4, 0.4)), Vector3(0, _rng.randf() * TAU, 0))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		y -= h * 0.92
		rr = nr
	_shape(body, _cyl_shape(r * 0.75, depth * 0.5), Vector3(0, -1.0 - depth * 0.25, 0))
	# little boulders hanging off the rim + roots
	for i in int(r * 0.6):
		var a := _rng.randf() * TAU
		var p := Vector3(cos(a) * r * 0.92, -1.4 - _rng.randf() * 1.5, sin(a) * r * 0.92)
		Pal.add(self, Pal.sphere(_rng.randf_range(0.6, 1.3), 7, 5), rock_d, p, Vector3(_rng.randf(), _rng.randf(), 0), Vector3(1, 0.8, 1))
		if _rng.randf() < 0.6:
			var len := _rng.randf_range(1.5, 4.0)
			Pal.add(self, Pal.cyl(0.06, 0.02, len, 5), Pal.toon(Color("6a8a3a"), 0.0, 0.0), Vector3(cos(a + 0.2) * r * 0.97, -1.0 - len / 2, sin(a + 0.2) * r * 0.97))
	if home:
		_build_post_office(body)
	else:
		_build_village(body)
	_build_chute(body)

func _shape(body: StaticBody3D, s: Shape3D, pos: Vector3, rot := Vector3.ZERO) -> void:
	var c := CollisionShape3D.new()
	c.shape = s
	c.position = pos
	c.rotation = rot
	body.add_child(c)

func _cyl_shape(r: float, h: float) -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	return c

func _box_shape(s: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = s
	return b

func _cottage(body: StaticBody3D, pos: Vector3, rot: float, scl: float, roof_col: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	n.scale = Vector3.ONE * scl
	add_child(n)
	var wall := Pal.toon(Pal.WALL, 0.0, 0.04, 0.15, 0.05)
	Pal.add(n, Pal.box(Vector3(2.4, 1.9, 2.1)), wall, Vector3(0, 0.95, 0))
	Pal.add(n, Pal.prism(Vector3(2.9, 1.4, 2.5)), Pal.toon(roof_col, 0.0, 0.04, 0.15, 0.1), Vector3(0, 2.6, 0))
	Pal.add(n, Pal.box(Vector3(0.4, 1.0, 0.4)), Pal.toon(Color("a8705a"), 0.0, 0.03), Vector3(0.7, 3.0, 0.3))
	Pal.add(n, Pal.box(Vector3(0.55, 1.0, 0.06)), Pal.toon(Color("6a3f2a"), 0.0, 0.0), Vector3(-0.4, 0.5, -1.06))
	for wx in [0.55]:
		var w := Pal.add(n, Pal.box(Vector3(0.5, 0.5, 0.06)), Pal.toon(Color("7aa0c8"), 0.6, 0.0), Vector3(wx, 1.15, -1.06))
		_windows.append(w)
		Pal.add(n, Pal.box(Vector3(0.62, 0.08, 0.1)), Pal.toon(Pal.WALL.darkened(0.2), 0.0, 0.0), Vector3(wx, 0.86, -1.08))
	_shape(body, _box_shape(Vector3(2.4, 2.6, 2.1) * scl), pos + Vector3(0, 1.3 * scl, 0), Vector3(0, rot, 0))
	obs.append(Obstacle.new(position.x + pos.x, position.z + pos.z, 1.7 * scl))

func _tree(body: StaticBody3D, pos: Vector3) -> void:
	var h := _rng.randf_range(1.2, 2.2)
	Pal.add(self, Pal.cyl(0.14, 0.2, h, 6), Pal.toon(Color("7a5236"), 0.0, 0.03), pos + Vector3(0, h / 2, 0))
	var leaf := Pal.toon(Color("5f9e4a").lerp(Color("88b84e"), _rng.randf()), 0.0, 0.04, 0.2, 0.1)
	for i in 3:
		var rr := _rng.randf_range(0.6, 0.95) * (1.0 - i * 0.18)
		Pal.add(self, Pal.sphere(rr, 9, 6), leaf, pos + Vector3(_rng.randf_range(-0.3, 0.3), h + i * 0.55, _rng.randf_range(-0.3, 0.3)))
	_shape(body, _cyl_shape(0.25, h), pos + Vector3(0, h / 2, 0))
	obs.append(Obstacle.new(position.x + pos.x, position.z + pos.z, 0.8))

func _build_village(body: StaticBody3D) -> void:
	var houses := 1 + _rng.randi() % 3
	var base := _rng.randf() * TAU
	for i in houses:
		var a := base + i * 1.1
		var d := radius * 0.62
		var roof := Pal.ROOF_A if _rng.randf() < 0.5 else Pal.ROOF_B
		roof = roof.lerp(color, 0.25)
		_cottage(body, Vector3(cos(a) * d, 0, sin(a) * d), -a + PI / 2, _rng.randf_range(0.85, 1.15), roof)
	for i in int(radius * 0.35):
		var a := base + PI * 0.5 + _rng.randf_range(0.6, 3.0)
		var d := radius * _rng.randf_range(0.55, 0.85)
		_tree(body, Vector3(cos(a) * d, 0, sin(a) * d))
	# flowers
	for i in int(radius * 1.5):
		var a := _rng.randf() * TAU
		var d := radius * sqrt(_rng.randf()) * 0.9
		var fc: Color = [Color("ffffff"), Color("f7d24a"), Color("ef7fae"), Color("b48ae0")][_rng.randi() % 4]
		var f := Pal.add(self, Pal.sphere(0.09, 6, 4), Pal.toon(fc, 0.0, 0.0), Vector3(cos(a) * d, 0.08, sin(a) * d))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chute_pos = Vector3(cos(base + PI) * radius * 0.5, 0, sin(base + PI) * radius * 0.5)
	if _rng.randf() < 0.55:
		_waterfall(base + PI * 0.5 + _rng.randf_range(-0.4, 0.4))

func _waterfall(a: float) -> void:
	var dir := Vector3(cos(a), 0, sin(a))
	# a little stream across the meadow to the rim
	var from := dir * radius * 0.35
	var to := dir * radius * 1.0
	var stream := Pal.add(self, Pal.box(Vector3(0.9, 0.06, (to - from).length())), Pal.toon(Color("7cc4e8"), 0.8, 0.0), (from + to) / 2 + Vector3(0, 0.02, 0))
	stream.look_at_from_position(stream.position, to + Vector3(0, 0.02, 0), Vector3.UP)
	Pal.add(self, Pal.sphere(1.1, 10, 6), Pal.toon(Color("7cc4e8"), 0.8, 0.0), from + Vector3(0, -0.15, 0), Vector3.ZERO, Vector3(1, 0.15, 1))
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 34.0)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/waterfall.gdshader")
	var fall := Pal.add(self, q, m, to + dir * 0.35 + Vector3(0, -17.0, 0))
	fall.rotation.y = atan2(dir.x, dir.z)
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_post_office(body: StaticBody3D) -> void:
	# a proud depot with a clock and a giant sign
	var n := Node3D.new()
	n.position = Vector3(0, 0, -radius * 0.55)
	add_child(n)
	var wall := Pal.toon(Color("f4dfb8"), 0.0, 0.05, 0.15, 0.05)
	Pal.add(n, Pal.box(Vector3(8.0, 4.0, 4.5)), wall, Vector3(0, 2.0, 0))
	Pal.add(n, Pal.prism(Vector3(9.0, 2.2, 5.2)), Pal.toon(Color("c0453a"), 0.0, 0.05, 0.15, 0.1), Vector3(0, 5.1, 0))
	Pal.add(n, Pal.box(Vector3(1.6, 2.4, 0.1)), Pal.toon(Color("2f3d6b"), 0.3, 0.0), Vector3(0, 1.2, 2.26))
	for wx in [-2.6, 2.6]:
		var w := Pal.add(n, Pal.box(Vector3(1.2, 1.2, 0.1)), Pal.toon(Color("7aa0c8"), 0.6, 0.0), Vector3(wx, 2.2, 2.26))
		_windows.append(w)
	var tower := Pal.add(n, Pal.box(Vector3(2.0, 3.0, 2.0)), wall, Vector3(0, 7.0, 0))
	Pal.add(tower, Pal.prism(Vector3(2.4, 1.6, 2.4)), Pal.toon(Pal.NAVY, 0.0, 0.05), Vector3(0, 2.3, 0))
	Pal.add(tower, Pal.cyl(0.7, 0.7, 0.08, 20), Pal.toon(Pal.CREAM, 0.0, 0.03), Vector3(0, 0.2, 1.03), Vector3(PI / 2, 0, 0))
	Pal.add(tower, Pal.box(Vector3(0.06, 0.5, 0.04)), Pal.toon(Pal.INK, 0.0, 0.0), Vector3(0, 0.38, 1.09))
	Pal.add(tower, Pal.box(Vector3(0.36, 0.06, 0.04)), Pal.toon(Pal.INK, 0.0, 0.0), Vector3(0.15, 0.2, 1.09))
	var sign := Pal.label3d("WINDBAG AIRMAIL", 120, Pal.CREAM, Pal.NAVY)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.position = Vector3(0, 3.6, 2.35)
	sign.pixel_size = 0.012
	n.add_child(sign)
	_shape(body, _box_shape(Vector3(8, 6, 4.5)), n.position + Vector3(0, 3, 0))
	obs.append(Obstacle.new(position.x, position.z - radius * 0.55, 4.6))
	# stacks of parcels on the porch, purely decorative
	for i in 6:
		var p := Pal.add(self, Pal.box(Vector3(0.6, 0.45, 0.5)), Pal.toon(Color("c99a62"), 0.0, 0.02, 0.1, 0.1), Vector3(-4.8 + (i % 3) * 0.7, 0.23 + (i / 3) * 0.46, -radius * 0.55 + 2.8), Vector3(0, _rng.randf() * 0.4, 0))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# lamp posts around the landing meadow
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var lp := Vector3(cos(a) * radius * 0.82, 0, sin(a) * radius * 0.82)
		Pal.add(self, Pal.cyl(0.07, 0.09, 2.4, 6), Pal.toon(Pal.INK, 0.4, 0.0), lp + Vector3(0, 1.2, 0))
		var lamp := Pal.add(self, Pal.sphere(0.22, 10, 6), Pal.unshaded(Color("ffe7a8")), lp + Vector3(0, 2.5, 0))
		_windows.append(lamp)
	chute_pos = Vector3(radius * 0.6, 0, radius * 0.1)
	# departure bell on a wooden frame by the porch
	var bf := Node3D.new()
	bf.position = Vector3(-3.2, 0, -radius * 0.55 + 3.6)
	add_child(bf)
	var wood := Pal.toon(Color("8d5a2b"), 0.0, 0.03, 0.1, 0.1)
	Pal.add(bf, Pal.box(Vector3(0.14, 2.4, 0.14)), wood, Vector3(-0.6, 1.2, 0))
	Pal.add(bf, Pal.box(Vector3(0.14, 2.4, 0.14)), wood, Vector3(0.6, 1.2, 0))
	Pal.add(bf, Pal.box(Vector3(1.5, 0.14, 0.18)), wood, Vector3(0, 2.4, 0))
	var bellm := Pal.add(bf, Pal.cyl(0.14, 0.38, 0.5, 14), Pal.toon(Pal.BRASS, 0.9, 0.03), Vector3(0, 2.0, 0))
	bellm.name = "BellMesh"
	_shape(body, _box_shape(Vector3(1.5, 2.4, 0.3)), bf.position + Vector3(0, 1.2, 0))
	bell_spot = bf

func _build_chute(body: StaticBody3D) -> void:
	var n := Node3D.new()
	n.position = chute_pos
	add_child(n)
	var c := color if not is_home else Color("c0453a")
	Pal.add(n, Pal.cyl(0.18, 0.22, 1.5, 8), Pal.toon(Pal.INK, 0.3, 0.02), Vector3(0, 0.75, 0))
	Pal.add(n, Pal.cyl(1.35, 0.4, 1.1, 18), Pal.toon(c, 0.3, 0.045, 0.25), Vector3(0, 1.95, 0))
	Pal.add(n, Pal.cyl(1.42, 1.42, 0.14, 18), Pal.toon(Pal.BRASS, 0.8, 0.03), Vector3(0, 2.5, 0))
	Pal.add(n, Pal.cyl(1.0, 1.0, 0.05, 18), Pal.toon(Pal.INK, 0.0, 0.0), Vector3(0, 2.3, 0))
	Pal.add(n, Pal.cyl(0.05, 0.05, 3.6, 6), Pal.toon(Pal.INK, 0.3, 0.0), Vector3(1.5, 1.8, 0))
	_flag = Pal.add(n, Pal.box(Vector3(1.1, 0.6, 0.04)), Pal.toon(c, 0.0, 0.025), Vector3(2.07, 3.25, 0))
	_shape(body, _cyl_shape(0.25, 1.5), chute_pos + Vector3(0, 0.75, 0))
	var label := Pal.label3d(iname, 110, c.darkened(0.45) if not is_home else Pal.NAVY, Pal.CREAM)
	label.position = Vector3(0, 5.2, 0)
	label.fixed_size = true
	label.font_size = 64
	label.outline_size = 16
	label.pixel_size = 0.00045
	n.add_child(label)
	chute = Area3D.new()
	chute.collision_layer = 0
	chute.collision_mask = 4
	chute.monitoring = true
	var cs := CollisionShape3D.new()
	cs.shape = _cyl_shape(1.15, 0.9)
	cs.position = Vector3(0, 2.0, 0)
	chute.add_child(cs)
	n.add_child(chute)
	# a soft light pillar shown while this island is waiting for post
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://shaders/beacon.gdshader")
	bm.set_shader_parameter("tint", c)
	beacon = Pal.add(n, Pal.cyl(1.1, 1.1, 60.0, 16), bm, Vector3(0, 32.5, 0))
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.visible = false
	chute.body_entered.connect(func(b): if b is Parcel and game: game.on_chute(self, b))
	chute_pos = n.global_position if is_inside_tree() else position + chute_pos

func _process(_dt: float) -> void:
	if _flag:
		var t := Time.get_ticks_msec() * 0.001 + index
		_flag.rotation.y = sin(t * 2.3) * 0.25 + sin(t * 5.1) * 0.08
		_flag.position.x = 1.5 + 0.57 * cos(_flag.rotation.y)
		_flag.position.z = -0.57 * sin(_flag.rotation.y)

var _lit := -1
func set_dusk(amount: float) -> void:
	var lit := 1 if amount > 0.45 else 0
	if lit == _lit:
		return
	_lit = lit
	for w in _windows:
		w.material_override = Pal.unshaded(Color("ffd27a")) if amount > 0.45 else (Pal.unshaded(Color("ffe7a8")) if w.mesh is SphereMesh else Pal.toon(Color("7aa0c8"), 0.6, 0.0))
