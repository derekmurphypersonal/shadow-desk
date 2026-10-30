class_name CabinetPanel
extends ScrollContainer
## The seven advisors, their trust, and intelligence accuracy.

var _box: VBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)
	Game.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	UITheme.clear(_box)
	if not Game.has_game():
		return
	var s := Game.state
	_box.add_child(UITheme.label("Advisors resign below 20 trust. Four resignations in a year ends your presidency.", 12, UITheme.MUTED))
	(_box.get_child(0) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for a in s.advisors:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL_2, UITheme.LINE, 8, 10))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var vacant := int(a["vacant_months"]) > 0
		var pr := UITheme.portrait_rect(String(a["name"]), 64)
		if vacant:
			pr.texture = UITheme.tex("res://assets/ui/emblem.png")
			pr.modulate = Color(1, 1, 1, 0.35)
		row.add_child(pr)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UITheme.label(a["title"], 11, UITheme.MUTED))
		v.add_child(UITheme.bold(("Vacant · nominee in %d mo" % int(a["vacant_months"])) if vacant else String(a["name"]), 16, UITheme.WARN if vacant else UITheme.TEXT))
		var tr := HBoxContainer.new()
		tr.add_child(UITheme.label("Trust", 11, UITheme.MUTED))
		var tval := float(a["trust"])
		var col := UITheme.GOOD if tval >= 50.0 else (UITheme.WARN if tval >= 30.0 else UITheme.BAD)
		tr.add_child(UITheme.bar(tval, 100.0, col, 8))
		tr.add_child(UITheme.bold("%d" % int(tval), 12, col))
		v.add_child(tr)
		if tval < 30.0 and not vacant:
			v.add_child(UITheme.label("Considering resignation", 11, UITheme.BAD))
		row.add_child(v)
		pc.add_child(row)
		_box.add_child(pc)
	_box.add_child(HSeparator.new())
	_box.add_child(UITheme.label("Intelligence accuracy: %d%%" % int(Advisors.intel_accuracy(s)), 14, UITheme.ACCENT))
	var note := UITheme.label("Lower accuracy adds noise to every foreign statistic you see. Raise the intelligence budget or keep the CIA Director on side.", 12, UITheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(note)
