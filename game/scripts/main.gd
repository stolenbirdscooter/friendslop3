extends Node
## Title menu + session lifecycle.

var game: Game
var menu: Control
var menu_layer: CanvasLayer
var name_edit: LineEdit
var ip_edit: LineEdit
var status: Label
var swatches: Array[Button] = []
var _pending_join := false

func _ready() -> void:
	_setup_input()
	Net.joined_session.connect(_on_joined)
	Net.left_session.connect(back_to_menu)
	var args := OS.get_cmdline_user_args()
	_load_prefs()
	_make_world(randi(), true)
	_build_menu()
	# headless/automation helpers: --solo, --host, --join=IP, --shot=path
	for a in args:
		if a.begins_with("--name="):
			Net.my_name = a.substr(7)
		elif a.begins_with("--color="):
			Net.my_color = int(a.substr(8))
	for a in args:
		if a == "--solo":
			_solo()
		elif a == "--host":
			_host()
		elif a.begins_with("--join="):
			ip_edit.text = a.substr(7)
			_join()
		elif a.begins_with("--test="):
			var t: Node = load("res://tests/%s.gd" % a.substr(7)).new()
			t.set("main", self)
			add_child(t)
		elif a.begins_with("--shot="):
			_shots(a.substr(7))

## Automation: --shot=prefix:t1,t2,... saves screenshots at those times then quits.
func _shots(spec: String) -> void:
	var parts := spec.split(":")
	var times := parts[1].split(",") if parts.size() > 1 else PackedStringArray(["3"])
	var elapsed := 0.0
	for i in times.size():
		var t := float(times[i])
		await get_tree().create_timer(t - elapsed).timeout
		elapsed = t
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [parts[0], i])
	get_tree().quit()

func _setup_input() -> void:
	var keys := {
		"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "interact": [KEY_E, KEY_F], "squeak": [KEY_Q],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("action"):
		InputMap.add_action("action")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("action", mb)
	# gamepad
	var pad := {"jump": JOY_BUTTON_A, "interact": JOY_BUTTON_X, "squeak": JOY_BUTTON_Y, "action": JOY_BUTTON_RIGHT_SHOULDER}
	for action in pad:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pad[action]
		InputMap.action_add_event(action, jb)

func _make_world(seed_: int, attract: bool) -> void:
	if game:
		game.name = "OldGame"
		game.queue_free()
	game = Game.new()
	game.name = "Game"
	game.main = self
	add_child(game)
	game.setup(seed_, attract)

# ------------------------------------------------------------------ menu
func _build_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(menu)
	var hud := preload("res://scripts/hud.gd")
	# title, top-left, each letter a different rubber colour
	var title := HBoxContainer.new()
	title.position = Vector2(70, 50)
	title.add_theme_constant_override("separation", -4)
	menu.add_child(title)
	var word := "WINDBAGS"
	for i in word.length():
		var l := Label.new()
		l.text = word[i]
		l.add_theme_font_override("font", Pal.title_font)
		l.add_theme_font_size_override("font_size", 128)
		l.add_theme_color_override("font_color", Pal.RUBBER[i % Pal.RUBBER.size()])
		l.add_theme_color_override("font_outline_color", Pal.INK)
		l.add_theme_constant_override("outline_size", 26)
		l.rotation = sin(i * 1.7) * 0.06
		l.pivot_offset = Vector2(40, 70)
		title.add_child(l)
		var tw := l.create_tween().set_loops()
		tw.tween_property(l, "position:y", -8.0, 0.9 + i * 0.07).set_trans(Tween.TRANS_SINE)
		tw.tween_property(l, "position:y", 0.0, 0.9 + i * 0.07).set_trans(Tween.TRANS_SINE)
	var sub := hud.label("a co-op airmail disaster for 1–6 inflatable couriers", 28, Pal.CREAM, true)
	sub.add_theme_color_override("font_outline_color", Pal.INK)
	sub.add_theme_constant_override("outline_size", 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub.position = Vector2(80, 210)
	menu.add_child(sub)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", hud.stamp_style(Pal.CREAM, Pal.INK, 18))
	panel.position = Vector2(80, 280)
	panel.custom_minimum_size = Vector2(470, 0)
	menu.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var nl := hud.label("Courier name", 20, Pal.INK, true)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(nl)
	name_edit = LineEdit.new()
	name_edit.text = Net.my_name
	name_edit.max_length = 16
	name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.add_theme_stylebox_override("normal", hud.stamp_style(Color.WHITE, Pal.INK, 10))
	name_edit.add_theme_color_override("font_color", Pal.INK)
	name_edit.text_changed.connect(func(t): Net.my_name = t)
	v.add_child(name_edit)
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 8)
	v.add_child(sw)
	for i in Pal.RUBBER.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(44, 44)
		b.tooltip_text = Pal.RUBBER_NAMES[i]
		var st := hud.stamp_style(Pal.RUBBER[i], Pal.INK, 22)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var idx := i
		b.pressed.connect(func():
			Net.my_color = idx
			Sfx.play("squeak", 0.8 + idx * 0.12, -4.0)
			_refresh_swatches())
		sw.add_child(b)
		swatches.append(b)
	_refresh_swatches()
	var solo := hud.button("Fly solo", Color("3fb3a6"))
	solo.pressed.connect(_solo)
	v.add_child(solo)
	var host := hud.button("Host a crew", Color("e8574a"))
	host.pressed.connect(_host)
	v.add_child(host)
	var jr := HBoxContainer.new()
	jr.add_theme_constant_override("separation", 8)
	v.add_child(jr)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "host address (127.0.0.1)"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.add_theme_font_size_override("font_size", 20)
	ip_edit.add_theme_stylebox_override("normal", hud.stamp_style(Color.WHITE, Pal.INK, 10))
	ip_edit.add_theme_color_override("font_color", Pal.INK)
	jr.add_child(ip_edit)
	var join := hud.button("Join", Color("8a70d6"))
	join.pressed.connect(_join)
	jr.add_child(join)
	status = hud.label("", 18, Color("8d5a2b"))
	v.add_child(status)
	var quit := hud.button("Quit", Color("8d5a2b"))
	quit.pressed.connect(func(): get_tree().quit())
	v.add_child(quit)

	var help := PanelContainer.new()
	help.add_theme_stylebox_override("panel", hud.stamp_style(Pal.CREAM, Pal.INK, 18))
	help.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	help.position = Vector2(-470, -330)
	help.custom_minimum_size = Vector2(420, 0)
	menu.add_child(help)
	var hv := VBoxContainer.new()
	help.add_child(hv)
	hv.add_child(hud.label("How to fly a windbag", 26, Pal.INK, true))
	var lines := "WASD walk · Space jump · Mouse look\nHold Space while falling: puff up & glide\nE pick up / put down / use · Hold LMB: throw\nLMB empty-handed: shove a crewmate\nQ squeak (look up for a higher note)\n\nPump the burner to rise, vent to sink.\nEvery altitude blows a different way:\nread the wind arrows, pick a layer, ride it.\nThrow parcels into the matching chute."
	var hl := hud.label(lines, 18)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hv.add_child(hl)
	var credit := hud.label("Fonts: Grandstander & Nunito (SIL OFL). Everything else made from code.", 14, Pal.CREAM)
	credit.add_theme_color_override("font_outline_color", Pal.INK)
	credit.add_theme_constant_override("outline_size", 6)
	credit.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	credit.position = Vector2(20, -34)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu.add_child(credit)

func _refresh_swatches() -> void:
	for i in swatches.size():
		swatches[i].scale = Vector2.ONE * (1.2 if i == Net.my_color else 0.9)
		swatches[i].pivot_offset = Vector2(22, 22)

func _save_prefs() -> void:
	var cf := ConfigFile.new()
	cf.set_value("courier", "name", Net.my_name)
	cf.set_value("courier", "color", Net.my_color)
	cf.set_value("net", "ip", ip_edit.text if ip_edit else "")
	cf.save("user://prefs.cfg")

func _load_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://prefs.cfg") == OK:
		Net.my_name = cf.get_value("courier", "name", Net.my_name)
		Net.my_color = cf.get_value("courier", "color", 0)

func _hide_menu() -> void:
	menu_layer.visible = false

func _solo() -> void:
	_save_prefs()
	Net.start_solo()
	_hide_menu()
	game.begin_host()

func _host() -> void:
	_save_prefs()
	var err := Net.start_host()
	if err != OK:
		status.text = "Couldn't open port %d (error %d)." % [Net.PORT, err]
		return
	_hide_menu()
	game.begin_host()
	game.toast("Crew open on port %d. Friends join with your address." % Net.PORT)

func _join() -> void:
	_save_prefs()
	var err := Net.start_join(ip_edit.text.strip_edges())
	if err != OK:
		status.text = "Couldn't start connecting (error %d)." % err
		return
	status.text = "Ringing the post office..."
	_pending_join = true

func _on_joined(seed_: int, state: Dictionary) -> void:
	_pending_join = false
	_make_world(seed_, false)
	_hide_menu()
	game.begin_client(state)

func back_to_menu(reason: String) -> void:
	if Net.online or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		Net.leave()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_make_world(randi(), true)
	menu_layer.visible = true
	status.text = reason
