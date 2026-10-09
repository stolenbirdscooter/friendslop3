class_name Hats
extends RefCounted
## Unlockable headwear, earned with lifetime stamps. All built from primitives.
## The courier's balloon knot always pokes through the top.

const NAMES: Array[String] = ["Postal Cap", "Bobble Beanie", "Top Hat", "Propeller Cap", "Flower Crown", "Traffic Cone", "Viking Helm", "Teapot"]
const COSTS: Array[int] = [0, 0, 120, 300, 500, 750, 1000, 1500]

static func build(capn: Node3D, idx: int, rubber: Material) -> void:
	var knot := true
	match idx:
		1:
			var c := Color("e8574a")
			Pal.add(capn, Pal.sphere(0.29, 16, 8), Pal.toon(c, 0.0, 0.022, 0.2, 0.15), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1, 0.62, 1))
			Pal.add(capn, Pal.cyl(0.3, 0.3, 0.08, 16), Pal.toon(Pal.CREAM, 0.0, 0.02, 0.2, 0.2), Vector3(0, -0.02, 0))
			Pal.add(capn, Pal.sphere(0.1, 10, 6), Pal.toon(Pal.CREAM, 0.0, 0.02), Vector3(0, 0.21, 0))
			knot = false
		2:
			var blk := Pal.toon(Color("2b2733"), 0.6, 0.022)
			Pal.add(capn, Pal.cyl(0.36, 0.36, 0.03, 18), blk, Vector3(0, 0.0, 0))
			Pal.add(capn, Pal.cyl(0.22, 0.2, 0.42, 16), blk, Vector3(0, 0.22, 0))
			Pal.add(capn, Pal.cyl(0.205, 0.205, 0.07, 16), Pal.toon(Color("c0453a"), 0.2, 0.0), Vector3(0, 0.07, 0))
			knot = false
		3:
			var segs := [Color("e8574a"), Color("f2b33d"), Color("3fb3a6"), Color("3f7fd9")]
			Pal.add(capn, Pal.sphere(0.28, 16, 8), Pal.toon(segs[1], 0.2, 0.022), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
			Pal.add(capn, Pal.cyl(0.3, 0.3, 0.035, 16), Pal.toon(segs[0], 0.2, 0.015), Vector3(0, -0.02, -0.12), Vector3.ZERO, Vector3(0.9, 1, 0.9))
			Pal.add(capn, Pal.cyl(0.02, 0.02, 0.18, 6), Pal.toon(Pal.INK, 0.5, 0.0), Vector3(0, 0.22, 0))
			var spin := Node3D.new()
			spin.name = "Spin"
			spin.position = Vector3(0, 0.31, 0)
			capn.add_child(spin)
			for i in 2:
				Pal.add(spin, Pal.box(Vector3(0.5, 0.015, 0.08)), Pal.toon(segs[2 + i], 0.3, 0.01), Vector3.ZERO, Vector3(0, i * PI / 2, 0.15))
			knot = false
		4:
			var leaf := Pal.toon(Color("6a9a45"), 0.0, 0.015)
			Pal.add(capn, Pal.cyl(0.28, 0.28, 0.05, 14), leaf, Vector3(0, -0.02, 0))
			var cols := [Color("ef7fae"), Color("fbf3e4"), Color("f2b33d"), Color("8a70d6")]
			for i in 9:
				var a := i * TAU / 9.0
				var f := Pal.add(capn, Pal.sphere(0.06, 8, 5), Pal.toon(cols[i % 4], 0.0, 0.012), Vector3(cos(a) * 0.28, 0.02, sin(a) * 0.28))
				Pal.add(f, Pal.sphere(0.025, 6, 4), Pal.toon(Color("f2b33d"), 0.0, 0.0), Vector3(0, 0.04, 0))
		5:
			Pal.add(capn, Pal.box(Vector3(0.5, 0.04, 0.5)), Pal.toon(Color("f08a3c"), 0.3, 0.02), Vector3(0, -0.02, 0))
			Pal.add(capn, Pal.cyl(0.03, 0.2, 0.62, 14), Pal.toon(Color("f08a3c"), 0.3, 0.022), Vector3(0, 0.3, 0))
			Pal.add(capn, Pal.cyl(0.12, 0.155, 0.1, 14), Pal.toon(Color.WHITE, 0.4, 0.0), Vector3(0, 0.3, 0))
			knot = false
		6:
			var steel := Pal.toon(Color("9aa3b5"), 0.7, 0.022)
			Pal.add(capn, Pal.sphere(0.29, 16, 8), steel, Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
			Pal.add(capn, Pal.cyl(0.3, 0.3, 0.05, 16), Pal.toon(Pal.BRASS, 0.7, 0.015), Vector3(0, -0.04, 0))
			for s in [-1.0, 1.0]:
				var horn := Pal.add(capn, Pal.cyl(0.0, 0.07, 0.36, 8), Pal.toon(Pal.CREAM, 0.3, 0.018), Vector3(s * 0.32, 0.12, 0))
				horn.rotation.z = -s * 0.9
		7:
			var china := Pal.toon(Color("eef3f7"), 0.8, 0.022)
			var blue := Pal.toon(Color("3f6fb9"), 0.3, 0.0)
			Pal.add(capn, Pal.sphere(0.26, 16, 8), china, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1, 0.75, 1))
			Pal.add(capn, Pal.cyl(0.265, 0.265, 0.05, 16), blue, Vector3(0, 0.06, 0))
			Pal.add(capn, Pal.cyl(0.06, 0.04, 0.28, 8), china, Vector3(0.3, 0.12, 0), Vector3(0, 0, -0.9))
			Pal.add(capn, _ring(0.1, 0.025), china, Vector3(-0.27, 0.1, 0), Vector3(PI / 2, 0, 0))
			Pal.add(capn, Pal.sphere(0.05, 8, 5), blue, Vector3(0, 0.29, 0))
			knot = false
		_:
			Pal.add(capn, Pal.cyl(0.27, 0.29, 0.17, 16), Pal.toon(Pal.NAVY, 0.2, 0.022), Vector3(0, 0.05, 0))
			Pal.add(capn, Pal.cyl(0.3, 0.3, 0.035, 16), Pal.toon(Pal.NAVY.darkened(0.2), 0.2, 0.015), Vector3(0, 0.0, -0.13), Vector3.ZERO, Vector3(0.95, 1, 0.9))
			Pal.add(capn, Pal.box(Vector3(0.1, 0.07, 0.03)), Pal.toon(Pal.BRASS, 0.9, 0.0), Vector3(0, 0.07, -0.27))
	if knot:
		Pal.add(capn, Pal.cyl(0.0, 0.06, 0.12, 8), rubber, Vector3(0, 0.19, 0))
		Pal.add(capn, Pal.sphere(0.045, 8, 6), rubber, Vector3(0, 0.25, 0))

static func _ring(r: float, t: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = r - t
	m.outer_radius = r + t
	m.rings = 12
	m.ring_segments = 6
	return m
