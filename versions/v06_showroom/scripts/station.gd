class_name Station
extends Node3D
## Something on the balloon a courier can operate.

enum Kind { PUMP, VENT, HELM, PATCH, BELL }
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
		Kind.BELL:
			return "Ring the departure bell" if balloon.game.phase == "dock" else ""
		Kind.PATCH:
			if balloon.leaks <= 0:
				return ""
			return "Hold to patch the envelope (%d leak%s)" % [balloon.leaks, "s" if balloon.leaks > 1 else ""]
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
		Kind.BELL:
			if pressed:
				balloon.game.request_depart()
