class_name Station
extends Node3D
## Something on the balloon a courier can operate.

enum Kind { PUMP, VENT, HELM }
var kind: Kind
var balloon: Node
var reach := 1.5

func prompt(_p: Node) -> String:
	match kind:
		Kind.PUMP: return "Pump the burner"
		Kind.VENT: return "Hold to vent hot air"
		Kind.HELM:
			if balloon.helm_peer != 0 and balloon.helm_peer != _p.peer:
				return ""
			return "Take the helm" if balloon.helm_peer == 0 else "Leave the helm"
	return ""

func use(p: Node, pressed: bool) -> void:
	match kind:
		Kind.PUMP:
			if pressed:
				balloon.request_pump()
		Kind.VENT:
			balloon.request_vent(pressed)
		Kind.HELM:
			if pressed:
				p.toggle_helm()
