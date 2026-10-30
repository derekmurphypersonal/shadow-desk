class_name WorldMap
extends Control
## Zoomable, pannable world map drawn from data/map/world.json.
## Mouse wheel / pinch to zoom, drag / two-finger scroll to pan, click to select.

signal country_clicked(iso: String)
signal country_hovered(iso: String)

const MODES := ["relation", "stability", "hunger", "freedom", "military", "bloc"]
const MODE_LABELS := {"relation": "Relations with US", "stability": "Stability", "hunger": "Hunger",
	"freedom": "Freedom", "military": "Military strength", "bloc": "Blocs"}
const MODE_ENDS := {"relation": ["Hostile", "Friendly"], "stability": ["Collapsing", "Stable"], "hunger": ["Fed", "Starving"],
	"freedom": ["Repressive", "Free"], "military": ["Weak", "Powerful"]}
const BLOC_COLORS := {
	"west": Color(0.27, 0.53, 0.86), "warsaw": Color(0.8, 0.28, 0.28), "russia": Color(0.8, 0.28, 0.28),
	"china": Color(0.88, 0.5, 0.2), "nonaligned": Color(0.42, 0.56, 0.48),
}
const BORDER := Color(0.03, 0.05, 0.09, 0.95)
const PLAYER := Color(0.88, 0.64, 0.23)
const DORMANT := Color(0.16, 0.18, 0.23)

var mode := "relation"
var zoom := 1.0
var zoom_target := 1.0
var pan := Vector2.ZERO
var hovered := ""
var attract := false          # main-menu backdrop: slow drift, no input
var show_legend := true
var _shapes: Dictionary = {}
var _map_size := Vector2(2048, 808)
var _dragging := false
var _drag_moved := 0.0
var _mouse := Vector2.ZERO
var _zoom_anchor := Vector2.ZERO
var _time := 0.0
var _redraw_acc := 0.0
var _centroids: Dictionary = {}
var _fx: Array = []
var _ocean: Texture2D

const FX_COLORS := {"hostile": Color(1.0, 0.45, 0.3), "friendly": Color(0.45, 0.75, 1.0), "aid": Color(0.45, 0.9, 0.55),
	"covert": Color(0.75, 0.6, 1.0), "gold": Color(1.0, 0.8, 0.35), "grey": Color(0.7, 0.72, 0.78)}


func _ready() -> void:
	clip_contents = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE if attract else Control.MOUSE_FILTER_STOP
	_build_shapes()
	Game.state_changed.connect(_on_state)
	Game.selection_changed.connect(func(_iso): queue_redraw())
	Settings.changed.connect(queue_redraw)
	resized.connect(queue_redraw)


func _on_state() -> void:
	_centroids.clear()
	if Game.has_game() and not attract:
		for f in Game.state.fx:
			if Settings.get_value("fx"):
				_fx.append({"iso": f["iso"], "kind": f["kind"], "text": f.get("text", ""), "t0": _time + 0.12 * float(_fx.size() % 4)})
		Game.state.fx.clear()
	queue_redraw()


static func fx_style(kind: String) -> String:
	match kind:
		"strike", "op_air", "air", "op_invade", "invade":
			return "hostile"
		"aid", "op_aid":
			return "aid"
		"fund_opposition", "coup", "cyber", "covert", "op_covert":
			return "covert"
		"sanction":
			return "sanction"
		"victory":
			return "victory"
		"halt":
			return "halt"
	return "friendly"


func _build_shapes() -> void:
	var md: Dictionary = Game.map_data
	_map_size = Vector2(float(md.get("width", 2048)), float(md.get("height", 808)))
	for iso in md.get("countries", {}):
		var polys: Array = []
		var tris: Array = []
		var shades: Array = []
		var rect := Rect2()
		var first := true
		for ring in md["countries"][iso]["rings"]:
			var pts := PackedVector2Array()
			for i in range(0, ring.size(), 2):
				pts.append(Vector2(float(ring[i]), float(ring[i + 1])))
			polys.append(pts)
			tris.append(Geometry2D.triangulate_polygon(pts))
			var rr := Rect2(pts[0], Vector2.ZERO)
			for p in pts:
				rr = rr.expand(p)
			var sh := PackedFloat32Array()
			for p in pts:
				sh.append(clampf((p.y - rr.position.y) / maxf(rr.size.y, 1.0), 0.0, 1.0))
			shades.append(sh)
			var r := Rect2(pts[0], Vector2.ZERO)
			for p in pts:
				r = r.expand(p)
			rect = r if first else rect.merge(r)
			first = false
		_shapes[iso] = {"polys": polys, "tris": tris, "rect": rect, "shades": shades}


func _process(delta: float) -> void:
	_time += delta
	if attract:
		pan.x = sin(_time * 0.05) * size.x * 0.12
		pan.y = cos(_time * 0.04) * 30.0
		zoom = 1.35 + sin(_time * 0.03) * 0.15
		_redraw_acc += delta
		if _redraw_acc > 0.033:
			_redraw_acc = 0.0
			queue_redraw()
		return
	if absf(zoom - zoom_target) > 0.001:
		var before := to_map(_zoom_anchor)
		zoom = lerpf(zoom, zoom_target, minf(1.0, delta * 14.0))
		pan += _zoom_anchor - to_screen(before)
		_clamp_pan()
		queue_redraw()
	elif Game.has_game() and (not Game.state.wars.is_empty() or Game.selected != "" or not _fx.is_empty() or not Game.state.us.get("ops", []).is_empty()):
		_redraw_acc += delta
		if _redraw_acc > (0.016 if not _fx.is_empty() else 0.05):
			_redraw_acc = 0.0
			queue_redraw()


# ---- Transform ----

func _base_scale() -> float:
	return minf(size.x / _map_size.x, size.y / _map_size.y) * 1.02


func _scale() -> float:
	return _base_scale() * zoom


func _origin() -> Vector2:
	return (size - _map_size * _scale()) * 0.5 + pan


func to_map(p: Vector2) -> Vector2:
	return (p - _origin()) / _scale()


func to_screen(p: Vector2) -> Vector2:
	return p * _scale() + _origin()


func zoom_at(screen_pos: Vector2, factor: float) -> void:
	_zoom_anchor = screen_pos
	zoom_target = clampf(zoom_target * factor, 1.0, 14.0)


func _clamp_pan() -> void:
	var extra := (_map_size * _scale() - size) * 0.5
	extra.x = maxf(extra.x, 0.0) + 60.0
	extra.y = maxf(extra.y, 0.0) + 60.0
	pan.x = clampf(pan.x, -extra.x, extra.x)
	pan.y = clampf(pan.y, -extra.y, extra.y)


func reset_view() -> void:
	zoom = 1.0
	zoom_target = 1.0
	pan = Vector2.ZERO
	queue_redraw()


func focus(iso: String) -> void:
	## Centre the view on a country.
	if not Game.has_game():
		return
	var c := _centroid_map(iso)
	if c == Vector2.ZERO:
		return
	zoom_target = maxf(zoom_target, 2.2)
	zoom = zoom_target
	pan = Vector2.ZERO
	pan = size * 0.5 - to_screen(c)
	_clamp_pan()
	queue_redraw()


# ---- Input ----

func _gui_input(event: InputEvent) -> void:
	if attract:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_at(mb.position, 1.18)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_at(mb.position, 1.0 / 1.18)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_moved = 0.0
				if mb.double_click:
					zoom_at(mb.position, 1.8)
			else:
				_dragging = false
				if _drag_moved < 6.0:
					var iso := pick(mb.position)
					if iso != "":
						Audio.sfx("click", -4.0)
					country_clicked.emit(iso)
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mouse = mm.position
		if _dragging:
			pan += mm.relative
			_drag_moved += mm.relative.length()
			_clamp_pan()
			queue_redraw()
		else:
			var iso := pick(mm.position)
			if iso != hovered:
				hovered = iso
				country_hovered.emit(iso)
			queue_redraw()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_at(mg.position, mg.factor)
		accept_event()
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		pan -= pg.delta * 14.0
		_clamp_pan()
		queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hovered != "":
		hovered = ""
		country_hovered.emit("")
		queue_redraw()


func pick(screen_pos: Vector2) -> String:
	if not Game.has_game():
		return ""
	var p := to_map(screen_pos)
	for map_iso in _shapes:
		var sh: Dictionary = _shapes[map_iso]
		if not (sh["rect"] as Rect2).grow(1.0).has_point(p):
			continue
		for poly in sh["polys"]:
			if Geometry2D.is_point_in_polygon(p, poly):
				return Game.state.map_owner.get(map_iso, "")
	return ""


# ---- Colours ----

static func ramp(t: float, a: Color, b: Color, c: Color) -> Color:
	t = clampf(t, 0.0, 1.0)
	if t < 0.5:
		return a.lerp(b, t * 2.0)
	return b.lerp(c, (t - 0.5) * 2.0)


func _ramp_colors(good_high: bool) -> Array:
	var bad := Color(0.8, 0.26, 0.24)
	var mid := Color(0.34, 0.37, 0.43)
	var good := Color(0.25, 0.6, 0.86)
	if Settings.get_value("colorblind"):
		bad = Color(0.86, 0.45, 0.1)
		mid = Color(0.4, 0.4, 0.42)
		good = Color(0.2, 0.45, 0.85)
	return [bad, mid, good] if good_high else [good, mid, bad]


func value_t(iso: String) -> float:
	var d := Game.state.c(iso)
	match mode:
		"relation":
			return (float(d["relation"]) + 100.0) / 200.0
		"bloc":
			return 0.0
	return float(d[mode]) / 100.0


func color_for(iso: String) -> Color:
	var s := Game.state
	var d := s.c(iso)
	if d.is_empty():
		return DORMANT
	if d.get("player", false):
		return PLAYER
	if not s.is_active(iso):
		return DORMANT
	if mode == "bloc":
		return BLOC_COLORS.get(d["bloc"], Color(0.4, 0.4, 0.4))
	if mode == "military":
		return ramp(value_t(iso), Color(0.28, 0.31, 0.36), Color(0.6, 0.5, 0.36), Color(0.92, 0.5, 0.18))
	var rc := _ramp_colors(mode != "hunger")
	return ramp(value_t(iso), rc[0], rc[1], rc[2])


# ---- Drawing ----

func _draw() -> void:
	# Ocean: vertical gradient.
	var top := Color(0.055, 0.09, 0.15)
	var bottom := Color(0.03, 0.045, 0.08)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	if _ocean == null:
		_ocean = UITheme.tex("res://assets/ui/ocean.png")
	if _ocean:
		draw_texture_rect(_ocean, Rect2(Vector2.ZERO, size), true, Color(1, 1, 1, 0.5))
	if not Game.has_game():
		return
	var s := Game.state
	var sc := _scale()
	var origin := _origin()
	draw_set_transform(origin, 0.0, Vector2(sc, sc))
	# Coastal glow under the land.
	for map_iso in _shapes:
		for pts in _shapes[map_iso]["polys"]:
			var closed: PackedVector2Array = pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, Color(0.35, 0.55, 0.8, 0.10), 7.0 / sc)
			draw_polyline(closed, Color(0.45, 0.65, 0.9, 0.14), 3.0 / sc)
	# Graticule every 30 degrees.
	var lat_top := float(Game.map_data.get("lat_top", 84.0))
	var lat_bot := float(Game.map_data.get("lat_bottom", -58.0))
	var grid := Color(1, 1, 1, 0.045)
	for lon in range(-150, 181, 30):
		var x := (float(lon) + 180.0) / 360.0 * _map_size.x
		draw_line(Vector2(x, 0), Vector2(x, _map_size.y), grid, -1.0)
	for lat in [-30, 0, 30, 60]:
		var y := (lat_top - float(lat)) / (lat_top - lat_bot) * _map_size.y
		draw_line(Vector2(0, y), Vector2(_map_size.x, y), grid if lat != 0 else Color(1, 1, 1, 0.08), -1.0)
	var ci := get_canvas_item()
	for map_iso in _shapes:
		var owner: String = s.map_owner.get(map_iso, map_iso)
		var col := color_for(owner)
		if owner == hovered and owner != "" and not attract:
			col = col.lightened(0.2)
		var sh: Dictionary = _shapes[map_iso]
		for i in sh["polys"].size():
			var pts: PackedVector2Array = sh["polys"][i]
			var idx: PackedInt32Array = sh["tris"][i]
			if idx.size() >= 3:
				var cols := PackedColorArray()
				cols.resize(pts.size())
				var shade: PackedFloat32Array = sh["shades"][i]
				var hi := col.lightened(0.10)
				var lo := col.darkened(0.16)
				for k in pts.size():
					cols[k] = hi.lerp(lo, shade[k])
				# draw_set_transform also applies to direct RenderingServer commands on this item.
				RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)
	for map_iso in _shapes:
		for pts in _shapes[map_iso]["polys"]:
			var closed: PackedVector2Array = pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, BORDER, -1.0)
	var sel := Game.selected
	if sel != "" and not attract:
		var pulse := 0.6 + 0.4 * sin(_time * 4.0)
		for map_iso in _shapes:
			if s.map_owner.get(map_iso, "") != sel:
				continue
			for pts in _shapes[map_iso]["polys"]:
				var closed: PackedVector2Array = pts.duplicate()
				closed.append(pts[0])
				draw_polyline(closed, Color(1, 0.85, 0.5, 0.25 * pulse), 6.0 / sc, true)
				draw_polyline(closed, Color(1, 1, 1, 0.95), 1.8 / sc, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_overlays(s)
	if not attract:
		_draw_op_badges(s)
		_draw_fx()
	# Vignette edges.
	var v := Color(0, 0, 0, 0.35)
	var clear := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, 40), Vector2(0, 40)]), PackedColorArray([v, v, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, size.y - 40), Vector2(size.x, size.y - 40), size, Vector2(0, size.y)]), PackedColorArray([clear, clear, v, v]))
	if not attract:
		if show_legend:
			_draw_legend()
		if hovered != "" and not _dragging:
			_draw_tooltip(s)


func _centroid_map(iso: String) -> Vector2:
	if _centroids.has(iso):
		return _centroids[iso]
	var s := Game.state
	var best_area := -1.0
	var best := Vector2.ZERO
	for map_iso in Game.map_data["countries"]:
		if s.map_owner.get(map_iso, "") != iso:
			continue
		var area := float(Game.map_data["countries"][map_iso].get("area", 0.0))
		if area > best_area:
			best_area = area
			var cc: Array = Game.map_data["countries"][map_iso]["centroid"]
			best = Vector2(float(cc[0]), float(cc[1]))
	_centroids[iso] = best
	return best


func centroid_of(iso: String) -> Vector2:
	return to_screen(_centroid_map(iso))


func _draw_overlays(s: GameState) -> void:
	var font := UITheme.font_bold()
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	for w in s.wars:
		var a := centroid_of(w["a"])
		var b := centroid_of(w["b"])
		draw_dashed_line(a, b, Color(1, 0.35, 0.3, 0.9), 2.0, 7.0)
		var mid := b.lerp(a, 0.35)
		draw_circle(mid, 10.0 + 5.0 * pulse, Color(0.95, 0.2, 0.15, 0.25 * (1.0 - pulse)))
		draw_circle(mid, 8.0, Color(0.72, 0.1, 0.08))
		draw_arc(mid, 8.0, 0, TAU, 20, Color(1, 0.6, 0.55), 1.2, true)
		draw_line(mid + Vector2(-4, -4), mid + Vector2(4, 4), Color.WHITE, 1.6, true)
		draw_line(mid + Vector2(-4, 4), mid + Vector2(4, -4), Color.WHITE, 1.6, true)
	for iso in s.active_isos():
		var d: Dictionary = s.countries[iso]
		if d.get("civil_war", false):
			var p := centroid_of(iso)
			draw_arc(p, 6.0 + 2.0 * pulse, 0, TAU, 18, Color(1, 0.4, 0.3, 0.9), 1.6, true)
		if float(d.get("rival_pull", 0.0)) >= 20.0 and not attract:
			var p2 := centroid_of(iso) + Vector2(-9, -9)
			var rc: Color = BLOC_COLORS.get(d.get("rival_bloc", ""), Color.RED)
			draw_circle(p2, 3.5, rc)
			draw_arc(p2, 5.5 + 2.0 * pulse, 0, TAU, 14, Color(rc, 0.6), 1.0, true)
	for iso in s.us["troops"]:
		var p := centroid_of(iso) + Vector2(10, -10)
		var r := Rect2(p - Vector2(5, 5), Vector2(10, 10))
		draw_rect(r.grow(1.5), Color(0, 0, 0, 0.8))
		draw_rect(r, PLAYER)
		draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), Color(0.2, 0.15, 0.05), 1.5)
	# Labels, more as you zoom.
	var min_area := 110.0 / (zoom * zoom)
	for map_iso in Game.map_data["countries"]:
		var mc: Dictionary = Game.map_data["countries"][map_iso]
		var owner: String = s.map_owner.get(map_iso, "")
		if owner == "" or not (s.is_active(owner) or owner == Game.selected) or float(mc.get("area", 0)) < min_area:
			continue
		if owner != map_iso:
			if not s.groups.has(owner) or map_iso != _largest_member(owner):
				continue
		var label: String = s.c(owner).get("name", "")
		var pos := to_screen(Vector2(float(mc["centroid"][0]), float(mc["centroid"][1])))
		var fs := 11 if zoom < 2.5 else 13
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var a := 0.55 if attract else 0.9
		draw_string_outline(font, pos + Vector2(-w * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.55 * a))
		draw_string(font, pos + Vector2(-w * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))


func _largest_member(group: String) -> String:
	var best := ""
	var best_area := -1.0
	for m in Game.state.groups.get(group, []):
		var a := float(Game.map_data["countries"].get(m, {}).get("area", 0.0))
		if a > best_area:
			best_area = a
			best = m
	return best


func _draw_legend() -> void:
	var font := UITheme.font_body()
	var r := Rect2(16, size.y - 58, 290, 42)
	draw_style_box(UITheme.box(Color(0.03, 0.05, 0.09, 0.85), UITheme.LINE, 6, 0), r)
	draw_string(UITheme.font_bold(), r.position + Vector2(10, 15), MODE_LABELS[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.TEXT)
	if mode == "bloc":
		var x := r.position.x + 10
		for b in Game.state.scenario["blocs"]:
			var c: Color = BLOC_COLORS.get(b, Color.GRAY)
			draw_rect(Rect2(x, r.position.y + 24, 9, 9), c)
			var short := {"west": "West", "china": "China", "russia": "Russia", "warsaw": "Soviet", "nonaligned": "Neutral"}
			var name: String = short.get(b, b)
			if b == "warsaw" and String(Game.state.scenario["blocs"][b].get("leader", "")) != "SUN":
				name = "Russia"
			draw_string(font, Vector2(x + 12, r.position.y + 33), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.MUTED)
			x += 14 + font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10
		return
	var bar := Rect2(r.position.x + 10, r.position.y + 23, 140, 8)
	var steps := 28
	for i in steps:
		var t := float(i) / float(steps - 1)
		var c: Color
		if mode == "military":
			c = ramp(t, Color(0.28, 0.31, 0.36), Color(0.6, 0.5, 0.36), Color(0.92, 0.5, 0.18))
		else:
			var rc := _ramp_colors(mode != "hunger")
			c = ramp(t, rc[0], rc[1], rc[2])
		draw_rect(Rect2(bar.position.x + bar.size.x * t, bar.position.y, bar.size.x / steps + 1, bar.size.y), c)
	var ends: Array = MODE_ENDS.get(mode, ["Low", "High"])
	draw_string(font, Vector2(bar.end.x + 8, bar.position.y + 8), "%s → %s" % [ends[0], ends[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.MUTED)


func _draw_tooltip(s: GameState) -> void:
	var d := s.c(hovered)
	if d.is_empty():
		return
	var lines: Array = [String(d["name"])]
	if s.is_active(hovered):
		if mode == "bloc":
			lines.append(String(s.scenario["blocs"].get(d["bloc"], {}).get("name", d["bloc"])))
		else:
			var v := float(d[mode]) + CountryPanel.fog(s, hovered, mode)
			lines.append("%s: %d" % [MODE_LABELS[mode], int(v)])
		var tags: Array = []
		if s.at_war(hovered):
			tags.append("At war with %s" % s.c(s.enemy_of(hovered))["name"])
		if d.get("civil_war", false):
			tags.append("Civil war")
		if s.us["troops"].has(hovered):
			tags.append("US troops")
		if float(d.get("rival_pull", 0.0)) >= 20.0:
			tags.append("Courted by %s" % String(s.scenario["blocs"].get(d.get("rival_bloc", ""), {}).get("name", "a rival")))
		lines.append_array(tags)
	elif d.get("player", false):
		lines.append("Home")
	var font := UITheme.font_body()
	var bold := UITheme.font_bold()
	var w := 0.0
	for i in lines.size():
		w = maxf(w, (bold if i == 0 else font).get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13 if i == 0 else 11).x)
	var h := 22.0 + 15.0 * float(lines.size() - 1)
	var pos := _mouse + Vector2(16, 16)
	if pos.x + w + 20 > size.x:
		pos.x = _mouse.x - w - 30
	if pos.y + h > size.y:
		pos.y = _mouse.y - h - 10
	draw_style_box(UITheme.box(Color(0.02, 0.03, 0.06, 0.94), UITheme.ACCENT.darkened(0.35), 5, 0), Rect2(pos, Vector2(w + 20, h + 6)))
	draw_string(bold, pos + Vector2(10, 18), lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT)
	for i in range(1, lines.size()):
		draw_string(font, pos + Vector2(10, 18 + 15 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.MUTED if i > 1 else UITheme.ACCENT)


func _draw_op_badges(s: GameState) -> void:
	var counts := {}
	for op in s.us.get("ops", []):
		var iso: String = op["iso"]
		var n := int(counts.get(iso, 0))
		counts[iso] = n + 1
		var type: String = op["type"]
		var col: Color = FX_COLORS["hostile"] if type in ["air", "invade"] else (FX_COLORS["aid"] if type == "aid" else (FX_COLORS["covert"] if type == "covert" else FX_COLORS["friendly"]))
		var p := centroid_of(iso) + Vector2(-14 + 15 * n, 13)
		var pulse := 0.5 + 0.5 * sin(_time * 5.0 + n)
		draw_circle(p, 9.5 + 2.0 * pulse, Color(col, 0.18))
		draw_circle(p, 8.0, Color(0.03, 0.05, 0.09, 0.95))
		draw_arc(p, 8.0, 0, TAU, 20, col, 1.4, true)
		var ic := UITheme.icon(CountryPanel.OP_ICONS.get(type, "score"))
		if ic:
			draw_texture_rect(ic, Rect2(p - Vector2(5.5, 5.5), Vector2(11, 11)), false, col)
		if type == "invade":
			var w := 30.0
			draw_rect(Rect2(p + Vector2(-w * 0.5, 11), Vector2(w, 3)), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(p + Vector2(-w * 0.5, 11), Vector2(w * float(op["progress"]) / 100.0, 3)), FX_COLORS["gold"])


func _bezier(a: Vector2, b: Vector2, t: float) -> Vector2:
	var mid := (a + b) * 0.5 + Vector2(0, -clampf(a.distance_to(b) * 0.35, 30.0, 220.0))
	return a.lerp(mid, t).lerp(mid.lerp(b, t), t)


func _draw_fx() -> void:
	if _fx.is_empty():
		return
	var font := UITheme.font_bold()
	var home := centroid_of("USA")
	var keep: Array = []
	for f in _fx:
		var age: float = _time - float(f["t0"])
		if age < 0.0:
			keep.append(f)
			continue
		if age > 2.2:
			continue
		keep.append(f)
		var target := centroid_of(f["iso"])
		var style := fx_style(f["kind"])
		var col: Color = FX_COLORS.get(style, FX_COLORS["friendly"])
		if style == "sanction":
			col = Color(1, 0.35, 0.3)
		elif style == "victory":
			col = FX_COLORS["gold"]
		elif style == "halt":
			col = FX_COLORS["grey"]
		var travel := 0.65
		if style in ["hostile", "friendly", "aid"] and home != Vector2.ZERO:
			var tt := clampf(age / travel, 0.0, 1.0)
			var pts := PackedVector2Array()
			var steps := 24
			for i in steps + 1:
				var u := float(i) / float(steps) * tt
				pts.append(_bezier(home, target, u))
			var fade := 1.0 - clampf((age - travel) / 0.8, 0.0, 1.0)
			if pts.size() > 1:
				draw_polyline(pts, Color(col, 0.55 * fade), 2.0, true)
			if tt < 1.0:
				var head := _bezier(home, target, tt)
				draw_circle(head, 6.0, Color(col, 0.35))
				draw_circle(head, 3.0, Color.WHITE)
		var arrive := age - (travel if style in ["hostile", "friendly", "aid"] else 0.0)
		if arrive >= 0.0:
			var k := clampf(arrive / 0.9, 0.0, 1.0)
			match style:
				"hostile":
					draw_circle(target, 6.0 + 26.0 * k, Color(1.0, 0.6, 0.25, 0.45 * (1.0 - k)))
					draw_circle(target, 4.0 + 10.0 * (1.0 - k), Color(1.0, 0.92, 0.6, 0.9 * (1.0 - k)))
					draw_arc(target, 10.0 + 34.0 * k, 0, TAU, 32, Color(1.0, 0.5, 0.3, 0.8 * (1.0 - k)), 2.0, true)
				"aid":
					for j in 5:
						var off := Vector2(-16 + 8 * j, -k * 34.0 - float(j % 2) * 8.0)
						var pc := target + off
						var a := 1.0 - k
						draw_line(pc + Vector2(-4, 0), pc + Vector2(4, 0), Color(col, a), 2.0)
						draw_line(pc + Vector2(0, -4), pc + Vector2(0, 4), Color(col, a), 2.0)
				"victory":
					for j in 12:
						var ang := TAU * float(j) / 12.0
						var d := Vector2(cos(ang), sin(ang))
						draw_line(target + d * (8.0 + 30.0 * k), target + d * (16.0 + 46.0 * k), Color(col, 1.0 - k), 2.5, true)
				_:
					for j in 2:
						var kk := clampf(k - 0.25 * j, 0.0, 1.0)
						draw_arc(target, 6.0 + 30.0 * kk, 0, TAU, 32, Color(col, 0.8 * (1.0 - kk)), 2.0, true)
			var label: String = f.get("text", "")
			if label != "":
				var ty := -18.0 - 26.0 * clampf(arrive / 1.4, 0.0, 1.0)
				var a2 := 1.0 - clampf((arrive - 0.8) / 0.7, 0.0, 1.0)
				var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				draw_string_outline(font, target + Vector2(-w * 0.5, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 5, Color(0, 0, 0, 0.75 * a2))
				draw_string(font, target + Vector2(-w * 0.5, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(col.lightened(0.3), a2))
	_fx = keep
