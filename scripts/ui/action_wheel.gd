class_name ActionWheel
extends Control
## Act on the map: a ring of the four option types around the selected country. Click a type to
## list what you can do there now; click an option to do it. The dossier stays for the detail.

const CATS := ["Diplomacy", "Economic", "Military", "Covert"]
const OFFSETS := [Vector2(0, -58), Vector2(58, 0), Vector2(0, 58), Vector2(-58, 0)]

var map: WorldMap
var iso := ""
var _open_cat := ""
var _ring: Control
var _list: PanelContainer


func setup(m: WorldMap) -> ActionWheel:
	map = m
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_list = PanelContainer.new()
	_list.add_theme_stylebox_override("panel", UITheme.shadow_box(Color(0.03, 0.05, 0.09, 0.97), UITheme.LINE, 8, 8))
	_list.visible = false
	add_child(_list)
	visible = false
	Game.state_changed.connect(_rebuild)
	Game.selection_changed.connect(func(sel):
		if sel != iso:
			close())


func open(country: String) -> void:
	var s := Game.state
	if country == "" or not s.is_active(country) or s.c(country).get("player", false):
		close()
		return
	iso = country
	_open_cat = ""
	visible = true
	_rebuild()


func close() -> void:
	iso = ""
	visible = false


func _process(_delta: float) -> void:
	if not visible or iso == "" or map == null:
		return
	var c := map.centroid_of(iso)
	_ring.position = c
	if _list.visible:
		var ls := _list.get_combined_minimum_size()
		var pos := c + Vector2(92, -ls.y * 0.5)
		if pos.x + ls.x > size.x - 8.0:
			pos.x = c.x - 92.0 - ls.x
		pos.y = clampf(pos.y, 8.0, maxf(8.0, size.y - ls.y - 8.0))
		_list.position = pos


func _by_cat(s: GameState) -> Dictionary:
	var out := {}
	for id in Actions.ORDER:
		var def: Dictionary = Actions.DEFS[id]
		if def.has("system") and not s.has_system(def["system"]):
			continue
		if Actions.available(s, iso, id)["ok"]:
			if not out.has(def["cat"]):
				out[def["cat"]] = []
			out[def["cat"]].append(id)
	return out


func _rebuild() -> void:
	if not visible or iso == "" or not Game.has_game():
		return
	var s := Game.state
	if not s.is_active(iso):
		close()
		return
	UITheme.clear(_ring)
	var by := _by_cat(s)
	# The type your cabinet would reach for first gets a ring.
	var rec_cat := ""
	var rec_id := ""
	var votes := {}
	for a in Advisors.advise(s, iso, Game.map_data):
		var act := String(a["action"])
		if act != "" and Actions.DEFS.has(act) and Actions.available(s, iso, act)["ok"]:
			votes[act] = int(votes.get(act, 0)) + 1
			if rec_id == "" or int(votes[act]) > int(votes[rec_id]):
				rec_id = act
	if Game.highlight.get("iso", "") == iso and Actions.DEFS.has(Game.highlight.get("action", "")):
		rec_id = Game.highlight["action"]
	if rec_id != "":
		rec_cat = Actions.DEFS[rec_id]["cat"]
	for i in CATS.size():
		var cat: String = CATS[i]
		var col: Color = CountryPanel.CAT_COLORS[cat]
		var ids: Array = by.get(cat, [])
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(40, 40)
		b.size = Vector2(40, 40)
		b.position = OFFSETS[i] - Vector2(20, 20)
		b.icon = UITheme.icon(CountryPanel.CAT_ICONS[cat])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 18)
		b.add_theme_color_override("icon_normal_color", col)
		b.add_theme_color_override("icon_hover_color", col.lightened(0.3))
		b.add_theme_color_override("icon_pressed_color", col.lightened(0.3))
		b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.18))
		var ring := UITheme.ACCENT if cat == rec_cat else col
		var bw := 3 if cat == rec_cat or cat == _open_cat else 2
		for st in ["normal", "hover", "pressed", "disabled"]:
			var sb := UITheme.box(Color(0.03, 0.05, 0.09, 0.95) if st != "hover" else Color(0.03, 0.05, 0.09).lerp(col, 0.3), ring if st != "disabled" else Color(1, 1, 1, 0.12), 20, 0)
			sb.set_border_width_all(bw if st != "disabled" else 1)
			b.add_theme_stylebox_override(st, sb)
		b.disabled = ids.is_empty()
		b.tooltip_text = "%s: %s" % [cat, ("%d option%s now" % [ids.size(), "" if ids.size() == 1 else "s"]) if not ids.is_empty() else "nothing possible now"]
		if cat == rec_cat and rec_id != "":
			b.tooltip_text += "\nYour cabinet suggests: %s" % Actions.DEFS[rec_id]["label"]
		b.pressed.connect(func():
			Audio.sfx("click", -6.0)
			_open_cat = "" if _open_cat == cat else cat
			_rebuild())
		_ring.add_child(b)
	_list.visible = _open_cat != "" and by.has(_open_cat)
	if not _list.visible:
		return
	UITheme.clear(_list)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_list.add_child(v)
	var col2: Color = CountryPanel.CAT_COLORS[_open_cat]
	v.add_child(UITheme.caps("%s · %s" % [String(s.c(iso)["name"]), _open_cat], col2, 10))
	for id in by[_open_cat]:
		var def: Dictionary = Actions.DEFS[id]
		var check := Actions.available(s, iso, id)
		var cost: Array = []
		if Actions.pc_of(s, id) > 0:
			cost.append("%d PC" % Actions.pc_of(s, id))
		if def["pool"] != "":
			cost.append("$%.1fbn" % Actions.cost_of(s, id))
		if float(check["chance"]) >= 0.0:
			cost.append("%d%%" % int(check["chance"]))
		var ob := UITheme.button("%s%s    %s" % ["★ " if id == rec_id else "", def["label"], " · ".join(cost)])
		ob.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ob.tooltip_text = String(def["desc"])
		ob.custom_minimum_size.x = 230
		ob.pressed.connect(func():
			Audio.sfx("click")
			_open_cat = ""
			Game.do_action(id))
		v.add_child(ob)
	_list.reset_size()
