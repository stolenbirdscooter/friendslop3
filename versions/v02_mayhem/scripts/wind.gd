class_name Wind
extends RefCounted
## The sky is layered: every altitude blows a different way. Balloons can't
## steer much on their own - you pick a layer and ride it.

static var seed_angle := 0.0

static func at(y: float, t: float) -> Vector3:
	var a := seed_angle + y * 0.047 + sin(t * 0.011 + y * 0.021) * 0.5
	var s := 3.4 + 1.6 * sin(y * 0.093 + 1.3) + 0.6 * sin(t * 0.043 + y * 0.031)
	return Vector3(cos(a), 0.0, sin(a)) * s

static func gust(t: float) -> float:
	return clampf(sin(t * 0.37) * sin(t * 0.13 + 2.0) * 1.6 - 0.6, 0.0, 1.0)
