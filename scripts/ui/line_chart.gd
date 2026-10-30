class_name LineChart
extends Control
## Minimal multi-series line chart drawn with CanvasItem calls. Series: {values: Array, color: Color, name: String}.

var series: Array = []
var y_min := 0.0
var y_max := 100.0
var x_labels: Array = []      # optional [first, last]
var reference := -1.0         # dashed horizontal line (e.g. 50% to win)
var reference_label := ""


func _ready() -> void:
	custom_minimum_size = Vector2(200, 140)
	resized.connect(queue_redraw)


func set_series(s: Array, lo: float = 0.0, hi: float = 100.0) -> void:
	series = s
	y_min = lo
	y_max = hi
	queue_redraw()


func _draw() -> void:
	var font := UITheme.font_body()
	var pad_l := 30.0
	var pad_b := 18.0
	var r := Rect2(pad_l, 6, size.x - pad_l - 6, size.y - pad_b - 10)
	draw_rect(r, Color(0, 0, 0, 0.18))
	for i in 5:
		var y := r.position.y + r.size.y * float(i) / 4.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.06), 1.0)
		var v := y_max - (y_max - y_min) * float(i) / 4.0
		draw_string(font, Vector2(2, y + 4), "%d" % int(v), HORIZONTAL_ALIGNMENT_LEFT, pad_l - 4, 10, UITheme.MUTED)
	if reference >= y_min and reference <= y_max:
		var ry := r.end.y - (reference - y_min) / (y_max - y_min) * r.size.y
		draw_dashed_line(Vector2(r.position.x, ry), Vector2(r.end.x, ry), Color(1, 1, 1, 0.3), 1.0, 4.0)
		if reference_label != "":
			draw_string(font, Vector2(r.end.x - 90, ry - 4), reference_label, HORIZONTAL_ALIGNMENT_RIGHT, 88, 10, UITheme.MUTED)
	var legend_x := r.position.x + 4
	for s in series:
		var vals: Array = s["values"]
		if vals.size() < 2:
			continue
		var pts := PackedVector2Array()
		for i in vals.size():
			var x := r.position.x + r.size.x * float(i) / float(vals.size() - 1)
			var y := r.end.y - (clampf(float(vals[i]), y_min, y_max) - y_min) / (y_max - y_min) * r.size.y
			pts.append(Vector2(x, y))
		var fill := pts.duplicate()
		fill.append(Vector2(r.end.x, r.end.y))
		fill.append(Vector2(r.position.x, r.end.y))
		var c: Color = s["color"]
		if series.size() == 1:
			draw_colored_polygon(fill, Color(c.r, c.g, c.b, 0.12))
		draw_polyline(pts, c, 2.0, true)
		draw_circle(pts[pts.size() - 1], 3.5, c)
		draw_string(font, Vector2(legend_x, r.position.y + 14), String(s.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)
		legend_x += font.get_string_size(String(s.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14
	if x_labels.size() == 2:
		draw_string(font, Vector2(r.position.x, size.y - 2), String(x_labels[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.MUTED)
		var w := font.get_string_size(String(x_labels[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, Vector2(r.end.x - w, size.y - 2), String(x_labels[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.MUTED)
