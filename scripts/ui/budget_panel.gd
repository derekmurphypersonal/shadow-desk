class_name BudgetPanel
extends ScrollContainer
## Discretionary budget sliders and their political consequences.

const LINES := [["defense", "Defense"], ["intel", "Intelligence"], ["aid", "Foreign aid"], ["domestic", "Domestic programmes"]]

var _box: VBoxContainer
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _summary: Label
var _building := false


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)
	Game.state_changed.connect(_update)
	_build()


func _build() -> void:
	_building = true
	UITheme.clear(_box)
	_sliders.clear()
	_values.clear()
	var intro := UITheme.label("Annual discretionary spending, $bn. Each line feeds a monthly fund: aid, covert, defense operations, domestic.", 12, UITheme.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(intro)
	for ln in LINES:
		var key: String = ln[0]
		var head := HBoxContainer.new()
		var l := UITheme.label(ln[1], 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(l)
		var val := UITheme.label("", 14, UITheme.ACCENT)
		head.add_child(val)
		_values[key] = val
		_box.add_child(head)
		var sl := HSlider.new()
		sl.step = 1.0
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.value_changed.connect(_on_slider.bind(key))
		_box.add_child(sl)
		_sliders[key] = sl
	_box.add_child(HSeparator.new())
	_summary = UITheme.label("", 13)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_summary)
	_building = false
	_update()


func _update() -> void:
	if not Game.has_game() or _sliders.is_empty():
		return
	var s := Game.state
	_building = true
	for ln in LINES:
		var key: String = ln[0]
		var base := float(s.us["budget_baseline"][key])
		var sl: HSlider = _sliders[key]
		sl.min_value = round(base * 0.5)
		sl.max_value = round(base * 1.6)
		sl.value = float(s.us["budget"][key])
		(_values[key] as Label).text = "$%d bn (%+d%%)" % [int(sl.value), int((sl.value / base - 1.0) * 100.0)]
	_building = false
	var f: Dictionary = s.us["funds"]
	_summary.text = "Deficit: %.1f%% of GDP\nApproval is heading toward %d%%\n\nFunds on hand ($bn)\nAid %.1f · Covert %.1f · Defense ops %.1f · Domestic %.1f" % [
		Simulation.budget_deficit_pct(s), int(Simulation.approval_target(s)),
		float(f["aid"]), float(f["covert"]), float(f["defense"]), float(f["domestic"])]


func _on_slider(value: float, key: String) -> void:
	if _building:
		return
	Game.set_budget(key, value)
