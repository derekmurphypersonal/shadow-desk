class_name ElectionNight
extends CenterContainer
## Animated election-night returns. Emits closed when the player continues.

signal closed

var vote := 50.0
var won := true
var _you: ProgressBar
var _them: ProgressBar
var _you_l: Label
var _them_l: Label
var _status: Label
var _btn: Button
var _shown := 0.0


func setup(result: Dictionary) -> ElectionNight:
	vote = float(result.get("vote", 50.0))
	won = bool(result.get("won", vote >= 50.0))
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(640, 0)
	p.add_theme_stylebox_override("panel", UITheme.shadow_box(UITheme.PANEL, UITheme.ACCENT, 10, 30))
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(UITheme.caps("Live · %s" % Game.state.date_string(), UITheme.BAD, 12))
	v.add_child(UITheme.heading("ELECTION NIGHT", 44, UITheme.TEXT))
	var r1 := _row("You", UITheme.ACCENT)
	_you = r1[0]
	_you_l = r1[1]
	v.add_child(r1[2])
	var r2 := _row("Challenger", Color(0.45, 0.55, 0.75))
	_them = r2[0]
	_them_l = r2[1]
	v.add_child(r2[2])
	_status = UITheme.bold("Polls are closing on the East Coast...", 16, UITheme.MUTED)
	v.add_child(_status)
	_btn = UITheme.button("Continue", "", true)
	_btn.visible = false
	_btn.pressed.connect(func(): closed.emit())
	v.add_child(_btn)
	Audio.music("tension")
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 0.55, 2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _status.text = "Too close to call. All eyes on the swing states...")
	tw.tween_method(_set_progress, 0.55, 1.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_reveal)


func _row(name: String, color: Color) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var n := UITheme.bold(name, 18)
	n.custom_minimum_size.x = 120
	h.add_child(n)
	var b := UITheme.bar(0.0, 100.0, color, 26)
	h.add_child(b)
	var l := UITheme.heading("0.0%", 24)
	l.custom_minimum_size.x = 90
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(l)
	return [b, l, h]


func _set_progress(t: float) -> void:
	# Early returns wobble around the final result, then converge.
	var wobble := sin(t * 23.0) * 3.0 * (1.0 - t)
	var you := clampf(vote + wobble, 0.0, 100.0) * t
	var them := clampf(100.0 - vote - wobble, 0.0, 100.0) * t
	_you.value = you
	_them.value = them
	_you_l.text = "%.1f%%" % you
	_them_l.text = "%.1f%%" % them
	if int(t * 40.0) != int(_shown * 40.0):
		Audio.sfx("key", -12.0)
	_shown = t


func _reveal() -> void:
	if won:
		_status.text = "The networks call it: you have been re-elected."
		_status.add_theme_color_override("font_color", UITheme.GOOD)
		Audio.sfx("sting_win")
	else:
		_status.text = "The networks call it for the challenger. You have lost."
		_status.add_theme_color_override("font_color", UITheme.BAD)
		Audio.sfx("sting_loss")
	_btn.visible = true
