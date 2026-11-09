class_name VideoFeed
extends Control
## A secure video link to an advisor: slow camera drift, scanlines, live audio waveform,
## a ticking call timer and a glow that follows the voice.

var person := ""
var seat_title := ""
var _tex: Texture2D
var _t := 0.0
var _call := 0.0
var _levels: PackedFloat32Array = PackedFloat32Array()
var _smooth := 0.0
const BARS := 28


func setup(p: String, title: String) -> VideoFeed:
	person = p
	seat_title = title
	return self


func _ready() -> void:
	_tex = UITheme.portrait(person)
	_levels.resize(BARS)
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	_call += delta
	var lv := Audio.voice_level()
	_smooth = lerpf(_smooth, lv, clampf(delta * 14.0, 0.0, 1.0))
	for i in BARS - 1:
		_levels[i] = _levels[i + 1]
	_levels[BARS - 1] = _smooth
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.04, 0.05, 0.07))
	if _tex:
		# Cover-fit with a slow drift and a breath of zoom, like a handheld webcam on a desk.
		var speak := _smooth
		var zoom := 1.06 + 0.015 * sin(_t * 0.35) + 0.01 * speak
		var ts := Vector2(_tex.get_size())
		var scale := maxf(size.x / ts.x, size.y / ts.y) * zoom
		var ds := ts * scale
		var off := (size - ds) * 0.5 + Vector2(sin(_t * 0.23) * 4.0, cos(_t * 0.31) * 3.0 - ds.y * 0.03)
		var tint := Color(1, 1, 1).lerp(Color(1.04, 1.03, 1.0), speak)
		draw_texture_rect(_tex, Rect2(off, ds), false, tint)
	# Scanlines and vignette.
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.07), 1.0)
		y += 3.0
	for i in 10:
		var a := 0.05 * (1.0 - float(i) / 10.0)
		draw_rect(Rect2(i * 2, i * 2, size.x - i * 4, size.y - i * 4), Color(0, 0, 0, a), false, 2.0)
	# Lower third with waveform.
	var band := 34.0
	var bottom := Rect2(0, size.y - band, size.x, band)
	draw_rect(bottom, Color(0.02, 0.03, 0.05, 0.78))
	var bw := (size.x - 20.0) / float(BARS)
	for i in BARS:
		var h := 3.0 + _levels[i] * (band - 12.0) * (0.75 + 0.25 * sin(float(i) * 1.7 + _t * 9.0))
		var x := 10.0 + i * bw
		var c := Color(0.45, 0.85, 0.65, 0.45 + 0.55 * _levels[i])
		draw_rect(Rect2(x, size.y - band * 0.5 - h * 0.5, maxf(bw - 2.0, 1.0), h), c)
	# Top bar: LIVE dot, encryption tag, timer.
	var f := UITheme.font_bold()
	draw_rect(Rect2(0, 0, size.x, 20), Color(0.02, 0.03, 0.05, 0.6))
	var blink := 0.55 + 0.45 * (1.0 if fmod(_t, 1.2) < 0.8 else 0.0)
	draw_circle(Vector2(10, 10), 4.0, Color(0.95, 0.2, 0.2, blink))
	draw_string(f, Vector2(19, 14.5), "SECURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.92, 0.94, 0.97, 0.9))
	var tc := "%02d:%02d" % [int(_call) / 60, int(_call) % 60]
	draw_string(f, Vector2(size.x - 40, 14.5), tc, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.92, 0.94, 0.97, 0.75))
	# Speaking glow.
	var glow := Color(0.45, 0.85, 0.65, 0.25 + 0.75 * _smooth) if Audio.is_speaking() else Color(0.5, 0.55, 0.62, 0.5)
	draw_rect(r.grow(-1.0), glow, false, 2.0)
