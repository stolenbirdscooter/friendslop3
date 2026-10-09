class_name Pal
extends RefCounted
## Palette + material/mesh helpers. Everything visual in Windbags is built from
## primitives and these hand-tuned colours: no imported art.

const INK := Color("2b1d2a")
const CREAM := Color("fff4dc")
const PAPER := Color("f6e7c8")
const WICKER := Color("c48a4a")
const WICKER_DARK := Color("8d5a2b")
const ROCK := Color("c9a27a")
const ROCK_DARK := Color("9a7458")
const MOSS := Color("8dbb5a")
const MOSS_DARK := Color("6a9a45")
const ROOF_A := Color("d9603b")
const ROOF_B := Color("3f8f8a")
const WALL := Color("fbf1df")
const BRASS := Color("e2b04a")
const NAVY := Color("2f3d6b")

const RUBBER: Array[Color] = [Color("e8574a"), Color("f2b33d"), Color("3fb3a6"), Color("8a70d6"),
	Color("ef7fae"), Color("8cc152"), Color("3f7fd9"), Color("f08a3c")]
const RUBBER_NAMES: Array[String] = ["Tomato", "Mustard", "Teal", "Violet", "Bubblegum", "Lime", "Cobalt", "Tangerine"]

const ISLAND_COLORS: Array[Color] = [Color("e8574a"), Color("3fb3a6"), Color("f2b33d"), Color("8a70d6"),
	Color("ef7fae"), Color("5e9e4a"), Color("3f7fd9"), Color("f08a3c"), Color("b8577e"), Color("4a6a9e")]

static var _toon: Shader = preload("res://shaders/toon.gdshader")
static var _outline: Shader = preload("res://shaders/outline.gdshader")
static var _cache := {}
static var title_font: Font = preload("res://fonts/Grandstander.ttf")
static var body_font: Font = preload("res://fonts/Nunito.ttf")

static func toon(c: Color, gloss := 0.0, outline := 0.0, rim := 0.22, grain := 0.0) -> ShaderMaterial:
	var key := "%s|%.2f|%.3f|%.2f|%.2f" % [c.to_html(), gloss, outline, rim, grain]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = _toon
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("gloss", gloss)
	m.set_shader_parameter("rim_amount", rim)
	m.set_shader_parameter("grain", grain)
	if outline > 0.0:
		var o := ShaderMaterial.new()
		o.shader = _outline
		o.set_shader_parameter("width", outline)
		m.next_pass = o
	_cache[key] = m
	return m

static func unshaded(c: Color) -> StandardMaterial3D:
	var key := "u|" + c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m

static func add(parent: Node3D, m: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

static func sphere(r: float, segs := 16, rings := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = rings
	return s

static func cyl(top: float, bottom: float, h: float, segs := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c

static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c

static func prism(size: Vector3) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = size
	return p

static func label3d(text: String, size := 64, col := INK, outline_col := CREAM) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = title_font
	l.font_size = size
	l.outline_size = int(size * 0.25)
	l.modulate = col
	l.outline_modulate = outline_col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = false
	l.pixel_size = 0.01
	return l
