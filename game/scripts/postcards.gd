class_name Postcards
extends Node
## Your own camera snaps "postcards" at funny moments; the best ones are shown
## as polaroids at the end of the day. Purely local - every player gets their
## own album of the same disaster.

const MAX := 8
var game: Game
var cards: Array = [] # {tex, caption, prio, t}
var _cd := 0.0

func _process(dt: float) -> void:
	_cd = maxf(_cd - dt, 0.0)

func reset() -> void:
	cards.clear()

func snap(caption: String, prio: int, delay := 0.0) -> void:
	if _cd > 0.0 and prio < 5 or game.attract or DisplayServer.get_name() == "headless":
		return
	_cd = 3.0
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var hud: CanvasLayer = game.hud
	hud.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	hud.visible = true
	if img == null or img.is_empty():
		return
	var w := 400
	img.resize(w, int(w * float(img.get_height()) / img.get_width()), Image.INTERPOLATE_BILINEAR)
	cards.append({"tex": ImageTexture.create_from_image(img), "caption": caption, "prio": prio, "t": game.day_t})
	if cards.size() > MAX:
		var worst := 0
		for i in cards.size():
			if cards[i].prio < cards[worst].prio:
				worst = i
		cards.remove_at(worst)

func best(n: int) -> Array:
	var sorted := cards.duplicate()
	sorted.sort_custom(func(a, b): return a.prio > b.prio or (a.prio == b.prio and a.t < b.t))
	var out := sorted.slice(0, n)
	out.sort_custom(func(a, b): return a.t < b.t)
	return out
