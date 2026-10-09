extends CanvasLayer
## Everything on screen during flight, drawn by hand in a postage-stamp style.

var game: Game
var root: Control
var draw: Control
var toasts: VBoxContainer
var banner_box: VBoxContainer
var results: PanelContainer
var pause_panel: PanelContainer
var _banner_t := 0.0
var _bursts := []

const INK := Color("2b1d2a")
const PAPER := Color("fff4dc")
const PAPER_D := Color("ead9b4")

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	draw = Control.new()
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw_hud)
	root.add_child(draw)
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.position = Vector2(-360, 120)
	toasts.custom_minimum_size = Vector2(720, 0)
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 6)
	root.add_child(toasts)
	banner_box = VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_CENTER)
	banner_box.position = Vector2(-400, -190)
	banner_box.custom_minimum_size = Vector2(800, 0)
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.modulate.a = 0.0
	root.add_child(banner_box)

static func stamp_style(bg := PAPER, border := INK, radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.shadow_color = Color(0.17, 0.11, 0.16, 0.35)
	s.shadow_size = 0
	s.shadow_offset = Vector2(4, 5)
	return s

static func label(text: String, size := 22, col := INK, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Pal.title_font if title else Pal.body_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func button(text: String, col := Color("e8574a")) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", Pal.title_font)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", PAPER_D)
	var n := stamp_style(col, INK, 12)
	n.shadow_size = 1
	var h := stamp_style(col.lightened(0.12), INK, 12)
	h.shadow_size = 1
	h.shadow_offset = Vector2(2, 3)
	var p := stamp_style(col.darkened(0.12), INK, 12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_entered.connect(func(): Sfx.play("ui", 1.2, -6.0))
	b.pressed.connect(func(): Sfx.play("ui", 0.9))
	return b

# ------------------------------------------------------------------ messages
func toast(text: String, col := INK) -> void:
	var p := PanelContainer.new()
	var st := stamp_style(PAPER, col, 10)
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	st.shadow_size = 1
	p.add_theme_stylebox_override("panel", st)
	p.add_child(label(text, 21, INK))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toasts.add_child(p)
	toasts.move_child(p, 0)
	p.scale = Vector2(0.6, 0.6)
	p.pivot_offset = Vector2(200, 20)
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
	while toasts.get_child_count() > 5:
		toasts.get_child(toasts.get_child_count() - 1).queue_free()
		break

func banner(title: String, sub: String) -> void:
	for c in banner_box.get_children():
		c.queue_free()
	var t := label(title, 92, PAPER, true)
	t.add_theme_color_override("font_outline_color", INK)
	t.add_theme_constant_override("outline_size", 22)
	banner_box.add_child(t)
	var s := label(sub, 28, PAPER, true)
	s.add_theme_color_override("font_outline_color", INK)
	s.add_theme_constant_override("outline_size", 12)
	banner_box.add_child(s)
	_banner_t = 4.0

func burst(world_pos: Vector3) -> void:
	_bursts.append([world_pos, 0.0])

# ------------------------------------------------------------------ results
func show_results(ok: bool, day: int, got: int, q: int, total: int, awards: Array) -> void:
	hide_results()
	results = PanelContainer.new()
	results.add_theme_stylebox_override("panel", stamp_style(PAPER, INK, 18))
	results.set_anchors_preset(Control.PRESET_CENTER)
	results.custom_minimum_size = Vector2(700, 0)
	results.position = Vector2(-350, -380)
	root.add_child(results)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	results.add_child(v)
	v.add_child(label("END OF DAY %d" % day, 22, Color("8d5a2b"), true))
	v.add_child(label("Quota met!" if ok else "Quota missed...", 56, Color("5e9e4a") if ok else Color("c0453a"), true))
	v.add_child(label("%d of %d needed parcels delivered  ·  %d stamps earned in total" % [got, q, total], 22))
	if not ok:
		v.add_child(label("The Postmaster has revoked your wings. Back to Day 1.", 20, Color("8a5a5a")))
	v.add_child(HSeparator.new())
	if awards.is_empty():
		v.add_child(label("No awards today. Suspiciously well-behaved.", 20, Color("8d5a2b")))
	for a in awards:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var badge := PanelContainer.new()
		var bs := stamp_style(Net.pcolor(a[3]), INK, 30)
		bs.content_margin_top = 2
		bs.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", bs)
		badge.add_child(label(a[0], 20, PAPER, true))
		row.add_child(badge)
		var l := label("  %s — %s" % [a[1], a[2]], 20)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(l)
		v.add_child(row)
	var cards: Array = game.postcards.best(3)
	if not cards.is_empty():
		v.add_child(HSeparator.new())
		v.add_child(label("From your camera", 18, Color("8d5a2b"), true))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		v.add_child(row)
		for i in cards.size():
			row.add_child(_polaroid(cards[i], (i - 1) * 0.05))
	v.add_child(HSeparator.new())
	if multiplayer.is_server():
		var b := button("Next day" if ok else "Start over", Color("3fb3a6") if ok else Color("e8574a"))
		b.pressed.connect(func():
			game.host_continue(ok)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
		v.add_child(b)
	else:
		v.add_child(label("Waiting for the host to ring the bell...", 20, Color("8d5a2b")))

func _polaroid(card: Dictionary, rot: float) -> Control:
	var frame := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("fffdf7")
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 8
	st.content_margin_bottom = 4
	st.shadow_color = Color(0.17, 0.11, 0.16, 0.35)
	st.shadow_size = 4
	st.shadow_offset = Vector2(3, 4)
	frame.add_theme_stylebox_override("panel", st)
	var vb := VBoxContainer.new()
	frame.add_child(vb)
	var tr := TextureRect.new()
	tr.texture = card.tex
	tr.custom_minimum_size = Vector2(200, 112)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	vb.add_child(tr)
	var l := label(card.caption, 15, INK, true)
	l.custom_minimum_size = Vector2(200, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)
	frame.rotation = rot
	frame.pivot_offset = Vector2(108, 80)
	return frame

func hide_results() -> void:
	if results:
		results.queue_free()
		results = null
	if not game.menu_open and not game.attract:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_pause() -> void:
	if pause_panel:
		pause_panel.queue_free()
		pause_panel = null
		game.menu_open = false
		if game.phase != "results":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	game.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", stamp_style(PAPER, INK, 18))
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(460, 0)
	pause_panel.position = Vector2(-230, -220)
	root.add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pause_panel.add_child(v)
	v.add_child(label("Tea Break", 48, INK, true))
	v.add_child(label("(the balloon keeps flying)", 18, Color("8d5a2b")))
	var sl := HSlider.new()
	sl.min_value = 0.3
	sl.max_value = 2.5
	sl.step = 0.05
	sl.value = game.mouse_sens
	sl.value_changed.connect(func(x): game.mouse_sens = x)
	v.add_child(label("Mouse sensitivity", 18))
	v.add_child(sl)
	var r := button("Back to the basket", Color("3fb3a6"))
	r.pressed.connect(toggle_pause)
	v.add_child(r)
	var q := button("Leave the crew", Color("e8574a"))
	q.pressed.connect(func(): game.main.back_to_menu(""))
	v.add_child(q)

func _unhandled_input(e: InputEvent) -> void:
	if game.attract:
		return
	if e.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and not game.menu_open and game.phase != "results":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ------------------------------------------------------------------ per-frame
func _process(dt: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= dt
		banner_box.modulate.a = clampf(minf(_banner_t, 4.0 - _banner_t) * 2.0, 0.0, 1.0)
	for b in _bursts:
		b[1] += dt
	_bursts = _bursts.filter(func(b): return b[1] < 1.2)
	draw.visible = not game.attract
	toasts.visible = not game.attract
	draw.queue_redraw()

func _font(title := true) -> Font:
	return Pal.title_font if title else Pal.body_font

func _text(pos: Vector2, s: String, size: int, col := INK, align := HORIZONTAL_ALIGNMENT_CENTER, width := -1.0, outline := 0, title := true) -> void:
	var f := _font(title)
	var w := width
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER and width < 0:
		w = 600.0
		p.x -= 300.0
	if outline > 0:
		draw.draw_string_outline(f, p, s, align, w, size, outline, INK)
	draw.draw_string(f, p, s, align, w, size, col)

func _stamp_rect(r: Rect2, bg := PAPER) -> void:
	# perforated postage-stamp edge
	draw.draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0.17, 0.11, 0.16, 0.3))
	draw.draw_rect(r, bg)
	draw.draw_rect(r.grow(-6), INK, false, 2.0)
	var step := 13.0
	var x := r.position.x + step * 0.5
	while x < r.end.x:
		draw.draw_circle(Vector2(x, r.position.y), 3.6, Color(0, 0, 0, 0) if false else Color(0.17, 0.11, 0.16, 0.0))
		x += step

func _draw_hud() -> void:
	if game == null or game.attract:
		return
	var vs := draw.size
	var me: Courier = game.local_courier()
	var bal: Balloon = game.balloon
	var cam := draw.get_viewport().get_camera_3d()
	_draw_day(vs)
	if bal:
		_draw_altimeter(vs, bal, cam)
		_draw_heat(vs, bal)
	if cam:
		_draw_compass(vs, cam, me)
		for b in _bursts:
			var wp: Vector3 = b[0]
			if not cam.is_position_behind(wp):
				var sp := cam.unproject_position(wp)
				var t: float = b[1]
				for i in 10:
					var a := i * TAU / 10.0 + t
					var r := 20.0 + t * 120.0
					draw.draw_circle(sp + Vector2(cos(a), sin(a)) * r, 7.0 * (1.2 - t), Pal.ISLAND_COLORS[i % 6])
	if me:
		_draw_reticle(vs, me)
		_draw_prompt(vs, me)

func _draw_day(vs: Vector2) -> void:
	var w := 420.0
	var r := Rect2(vs.x / 2 - w / 2, 14, w, 74)
	_stamp_rect(r)
	var f: float = game.day_frac()
	# sun arc
	var c := Vector2(r.position.x + 52, r.end.y - 16)
	draw.draw_arc(c, 34, PI, TAU, 24, Color("ead9b4"), 4.0)
	var a := PI + f * PI
	draw.draw_circle(c + Vector2(cos(a), sin(a)) * 34, 8, Color("f2b33d").lerp(Color("e8574a"), smoothstep(0.7, 1.0, f)))
	draw.draw_line(c + Vector2(-42, 0), c + Vector2(42, 0), INK, 2.0)
	_text(Vector2(r.position.x + 105, r.position.y + 34), "DAY %d" % game.day, 26, INK, HORIZONTAL_ALIGNMENT_LEFT, 200)
	var left := maxf(game.day_len - game.day_t, 0.0)
	var sub := "%d:%02d to sunset" % [int(left) / 60, int(left) % 60]
	if game.phase == "dock":
		sub = "moored · ring the bell"
	_text(Vector2(r.position.x + 105, r.position.y + 60), sub, 18, Color("8d5a2b"), HORIZONTAL_ALIGNMENT_LEFT, 200, 0, false)
	# parcels: filled = delivered, ring = quota line
	var px := r.position.x + 245
	for i in game.day_parcels:
		var cx: float = px + (i % 6) * 26
		var cy: float = r.position.y + 26 + (i / 6) * 26
		var box := Rect2(cx, cy - 9, 20, 18)
		var col := Color("ead9b4")
		if i < game.delivered:
			col = Color("8cc152")
		elif i >= game.day_parcels - game.lost_count:
			col = Color("b8a8d8")
		draw.draw_rect(box, col)
		draw.draw_rect(box, INK, false, 2.0)
		if i == game.quota - 1:
			draw.draw_line(Vector2(cx + 23, cy - 13), Vector2(cx + 23, cy + 13), Color("c0453a"), 3.0)
	_text(Vector2(px, r.end.y - 10), "%d / %d delivered" % [game.delivered, game.quota], 16, INK, HORIZONTAL_ALIGNMENT_LEFT, 170, 0, false)

func _draw_altimeter(vs: Vector2, bal: Balloon, cam: Camera3D) -> void:
	var h := minf(vs.y * 0.58, 520.0)
	var r := Rect2(vs.x - 116, vs.y / 2 - h / 2, 92, h)
	_stamp_rect(r)
	var top_alt := 160.0
	var y0 := r.end.y - 18
	var y1 := r.position.y + 18
	var cx := r.position.x + 30
	draw.draw_line(Vector2(cx, y0), Vector2(cx, y1), INK, 2.0)
	var cam_yaw := 0.0
	if cam:
		var f := -cam.global_transform.basis.z
		cam_yaw = atan2(f.x, -f.z)
	var alt := 0
	while alt <= int(top_alt):
		var y := lerpf(y0, y1, alt / top_alt)
		draw.draw_line(Vector2(cx - 5, y), Vector2(cx + 5, y), INK, 2.0)
		if alt % 20 == 0:
			var w := Wind.at(float(alt), game.clock)
			var ang := atan2(w.x, -w.z) - cam_yaw
			var dir := Vector2(sin(ang), -cos(ang))
			var len := 7.0 + w.length() * 2.2
			var ac := Vector2(cx + 34, y)
			var col := Color("3f7fd9")
			draw.draw_line(ac - dir * len * 0.5, ac + dir * len * 0.5, col, 3.0)
			draw.draw_colored_polygon(PackedVector2Array([ac + dir * (len * 0.5 + 6), ac + dir * len * 0.5 + dir.orthogonal() * 5, ac + dir * len * 0.5 - dir.orthogonal() * 5]), col)
		alt += 10
	# destination island heights
	var pending := {}
	for k in game.parcels:
		pending[game.parcels[k].address] = true
	for i in pending:
		var isl: Island = game.islands[i]
		var y := lerpf(y0, y1, clampf(isl.top_center.y / top_alt, 0, 1))
		draw.draw_rect(Rect2(cx - 16, y - 3, 10, 6), isl.color)
		draw.draw_rect(Rect2(cx - 16, y - 3, 10, 6), INK, false, 1.5)
	var home: Island = game.islands[0]
	var hy := lerpf(y0, y1, home.top_center.y / top_alt)
	draw.draw_rect(Rect2(cx - 16, hy - 3, 10, 6), Color("c0453a"))
	# balloon marker
	var by := lerpf(y0, y1, clampf(bal.altitude() / top_alt, 0, 1))
	draw.draw_circle(Vector2(cx, by - 6), 8, Color("e8574a"))
	draw.draw_arc(Vector2(cx, by - 6), 8, 0, TAU, 16, INK, 2.0)
	draw.draw_rect(Rect2(cx - 4, by + 2, 8, 6), Color("c48a4a"))
	var vy := bal.vertical_speed()
	if absf(vy) > 0.3:
		var d := -signf(vy)
		draw.draw_colored_polygon(PackedVector2Array([Vector2(cx + 12, by + d * 2), Vector2(cx + 20, by + d * 2), Vector2(cx + 16, by + d * 10)]), INK)
	_text(Vector2(r.position.x + 46, r.position.y - 8), "%dm" % int(bal.altitude()), 20, PAPER, HORIZONTAL_ALIGNMENT_CENTER, -1, 6)

func _draw_heat(vs: Vector2, bal: Balloon) -> void:
	var c := Vector2(vs.x - 70, vs.y / 2 + minf(vs.y * 0.29, 260) + 70)
	draw.draw_circle(c + Vector2(4, 5), 44, Color(0.17, 0.11, 0.16, 0.3))
	draw.draw_circle(c, 44, PAPER)
	draw.draw_arc(c, 44, 0, TAU, 32, INK, 3.0)
	var a0 := PI * 0.75
	var span := PI * 1.5
	draw.draw_arc(c, 32, a0, a0 + span, 32, Color("ead9b4"), 9.0)
	draw.draw_arc(c, 32, a0, a0 + span * bal.heat, 32, Color("f2b33d").lerp(Color("e8574a"), bal.heat), 9.0)
	var eq := clampf(bal.equilibrium_heat(), 0, 1)
	var ea := a0 + span * eq
	draw.draw_line(c + Vector2(cos(ea), sin(ea)) * 22, c + Vector2(cos(ea), sin(ea)) * 42, INK, 3.0)
	_text(c + Vector2(0, 6), "HEAT", 15, INK)
	var word := "rising" if bal.vertical_speed() > 0.4 else ("sinking" if bal.vertical_speed() < -0.4 else "steady")
	if bal.landed:
		word = "landed"
	_text(c + Vector2(0, 26), word, 13, Color("8d5a2b"), HORIZONTAL_ALIGNMENT_CENTER, -1, 0, false)

func _draw_compass(vs: Vector2, cam: Camera3D, me: Courier) -> void:
	var f := -cam.global_transform.basis.z
	var yaw := atan2(f.x, -f.z)
	var y := 112.0
	var half := 300.0
	var cx := vs.x / 2
	draw.draw_line(Vector2(cx - half, y), Vector2(cx + half, y), Color(1, 0.96, 0.86, 0.7), 2.0)
	var pending := {}
	for k in game.parcels:
		pending[game.parcels[k].address] = pending.get(game.parcels[k].address, 0) + 1
	var from := me.global_position if me else cam.global_position
	var used: Array[float] = []
	for isl in game.islands:
		var d: Vector3 = isl.chute_pos - from
		var ang := wrapf(atan2(d.x, -d.z) - yaw, -PI, PI)
		if absf(ang) > 1.3:
			continue
		var x := cx + ang / 1.3 * half
		var important: bool = pending.has(isl.index) or isl.is_home
		var col: Color = Color("c0453a") if isl.is_home else isl.color
		var rad := 9.0 if important else 5.0
		if not important:
			col.a = 0.55
		draw.draw_circle(Vector2(x, y), rad, col)
		draw.draw_arc(Vector2(x, y), rad, 0, TAU, 16, INK, 2.0)
		if important:
			var dist := Vector2(d.x, d.z).length()
			var dy := d.y
			var arrow := "▲" if dy > 4 else ("▼" if dy < -4 else "")
			var nm: String = isl.iname if not isl.is_home else "Post Office"
			var lbl := "%s  %dm %s" % [nm, int(dist), arrow]
			if pending.has(isl.index):
				lbl += "  ×%d" % pending[isl.index]
			var row := 0
			for ux in used:
				if absf(ux - x) < 190.0:
					row += 1
			used.append(x)
			_text(Vector2(x, y + 28 + row * 20), lbl, 16, PAPER, HORIZONTAL_ALIGNMENT_CENTER, -1, 5)

func _draw_reticle(vs: Vector2, me: Courier) -> void:
	var c := vs / 2
	draw.draw_circle(c, 3.0, PAPER)
	draw.draw_arc(c, 3.5, 0, TAU, 12, INK, 1.5)
	if me.charge >= 0.0:
		draw.draw_arc(c, 20, -PI / 2, -PI / 2 + TAU * me.charge, 32, Color("f2b33d"), 5.0)
		draw.draw_arc(c, 20, 0, TAU, 32, INK, 1.0)
	if me.puffed or me.air < 1.0:
		draw.draw_arc(c + Vector2(0, 40), 14, -PI / 2, -PI / 2 + TAU * me.air, 24, Color("3fb3a6"), 5.0)
		_text(c + Vector2(0, 70), "puff", 14, PAPER, HORIZONTAL_ALIGNMENT_CENTER, -1, 4)
	if me.lost:
		_text(Vector2(vs.x / 2, vs.y / 2 - 40), "Lost in the fluff...", 44, PAPER, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		_text(Vector2(vs.x / 2, vs.y / 2 + 4), "the crew's spare pump will reinflate you in %d" % ceili(me.lost_t), 22, PAPER, HORIZONTAL_ALIGNMENT_CENTER, -1, 6)

func _draw_prompt(vs: Vector2, me: Courier) -> void:
	var s := ""
	if me.at_helm:
		s = "[A/D] steer   [W/S] propeller   [E] let go"
	elif me.carrying != 0:
		s = "hold [LMB] to throw your crewmate   [E] put down"
	elif me.holding != 0:
		var p: Parcel = game.parcels.get(me.holding)
		var dest: String = game.island_name(p.address) if p else ""
		s = "For %s   ·   hold [LMB] to throw   [E] put down" % dest
	elif me.target:
		if me.target is Courier:
			s = "[E] pick up %s%s" % [me.target.pname, " (carry them to the pump!)" if me.target.flat else ""]
		elif me.target is Parcel:
			var fl: String = "" if me.target.flavor == "normal" else me.target.flavor + " "
			s = "[E] pick up %sparcel for %s" % [fl, game.island_name(me.target.address)]
		elif me.target is Station:
			s = "[E] %s" % me.target.prompt(me)
	elif me.flat:
		s = "You're a pancake! A crewmate can carry you [E] to the pump, or wait to reinflate"
	elif me.carried_by != 0:
		s = "Mash [SPACE] to wriggle free"
	elif not me.is_on_floor() and not me.lost and me.air > 0.0 and not me.puffed and me.velocity.y < 0:
		s = "hold [SPACE] to puff up and glide"
	if s != "":
		var f := _font(false)
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 40
		var r := Rect2(vs.x / 2 - w / 2, vs.y - 120, w, 42)
		draw.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0.17, 0.11, 0.16, 0.3))
		draw.draw_rect(r, PAPER)
		draw.draw_rect(r, INK, false, 2.5)
		_text(Vector2(vs.x / 2, r.position.y + 29), s, 22, INK, HORIZONTAL_ALIGNMENT_CENTER, -1, 0, false)
