class_name BriefingsPanel
extends VBoxContainer
## Wars in progress, agenda progress, and the running news log (newest first).

var _wars: VBoxContainer
var _log: RichTextLabel

const KIND_COLORS := {"headline": "e0a43a", "war": "e85c54", "scandal": "e85c54", "cabinet": "eab34c", "action": "8fb3e0", "info": "a9b1bf"}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_wars = VBoxContainer.new()
	add_child(_wars)
	add_child(HSeparator.new())
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_active = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.selection_enabled = true
	add_child(_log)
	Game.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	UITheme.clear(_wars)
	if not Game.has_game():
		return
	var s := Game.state
	_wars.add_child(UITheme.caps("Wars in progress"))
	if s.wars.is_empty():
		_wars.add_child(UITheme.label("No wars between states.", 13, UITheme.MUTED))
	for w in s.wars:
		var b := UITheme.button("%s vs %s · month %d" % [s.c(w["a"])["name"], s.c(w["b"])["name"], int(w["months"])], "war")
		b.add_theme_color_override("icon_normal_color", UITheme.BAD)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(Game.select.bind(String(w["b"])))
		_wars.add_child(b)
	_wars.add_child(UITheme.caps("News wire"))
	var lines: Array = []
	for i in range(s.messages.size() - 1, -1, -1):
		var m: Dictionary = s.messages[i]
		var col: String = KIND_COLORS.get(m["kind"], "a9b1bf")
		var txt := String(m["text"]).replace("[", "(")
		if m["kind"] in ["headline", "war", "scandal"]:
			txt = "[b]%s[/b]" % txt
		lines.append("[color=#6b7385]%s[/color]  [color=#%s]%s[/color]" % [m["date"], col, txt])
	_log.text = "\n".join(lines)
