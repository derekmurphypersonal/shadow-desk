class_name UITheme
extends RefCounted
## Situation-room dark theme, fonts, icons and portraits. Built in code: no binary theme assets.

const BG := Color(0.043, 0.063, 0.106)
const PANEL := Color(0.075, 0.102, 0.161)
const PANEL_2 := Color(0.102, 0.137, 0.212)
const LINE := Color(0.19, 0.235, 0.32)
const TEXT := Color(0.91, 0.925, 0.95)
const MUTED := Color(0.58, 0.63, 0.71)
const ACCENT := Color(0.88, 0.64, 0.23)
const GOOD := Color(0.36, 0.76, 0.5)
const BAD := Color(0.92, 0.38, 0.34)
const WARN := Color(0.93, 0.72, 0.32)
const PAPER := Color(0.95, 0.92, 0.85)
const INK := Color(0.13, 0.12, 0.11)
const STAMP := Color(0.72, 0.12, 0.12)

static var _fonts: Dictionary = {}
static var _tex: Dictionary = {}


static func _variation(path: String, weight: int) -> Font:
	var key := "%s@%d" % [path, weight]
	if _fonts.has(key):
		return _fonts[key]
	var base: FontFile = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	_fonts[key] = fv
	return fv


static func font_body() -> Font:
	return _variation("res://assets/fonts/Inter.ttf", 420)


static func font_bold() -> Font:
	return _variation("res://assets/fonts/Inter.ttf", 640)


static func font_head() -> Font:
	return _variation("res://assets/fonts/Oswald.ttf", 560)


static func font_type() -> Font:
	if not _fonts.has("type"):
		_fonts["type"] = load("res://assets/fonts/CourierPrime-Regular.ttf")
	return _fonts["type"]


static func font_type_bold() -> Font:
	if not _fonts.has("typeb"):
		_fonts["typeb"] = load("res://assets/fonts/CourierPrime-Bold.ttf")
	return _fonts["typeb"]


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func icon(name: String) -> Texture2D:
	return tex("res://assets/icons/%s.png" % name)


static func portrait_path(person: String) -> String:
	var slug := person.to_lower()
	var re := RegEx.new()
	re.compile("[^a-z0-9]+")
	slug = re.sub(slug, "_", true).strip_edges().trim_prefix("_").trim_suffix("_")
	return "res://assets/portraits/%s.png" % slug


static func portrait(person: String) -> Texture2D:
	return tex(portrait_path(person))


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 6, pad: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	if border.a > 0.0:
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	return sb


static func line_box(color: Color, thickness: int = 1) -> StyleBoxLine:
	var sl := StyleBoxLine.new()
	sl.color = color
	sl.thickness = thickness
	return sl


static func shadow_box(bg: Color, border: Color, radius: int = 10, pad: int = 16) -> StyleBoxFlat:
	var sb := box(bg, border, radius, pad)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 6)
	return sb


static func build(scale: float = 1.0) -> Theme:
	var t := Theme.new()
	t.default_font = font_body()
	t.default_font_size = int(14 * scale)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.48, 0.55))
	t.set_color("icon_normal_color", "Button", TEXT)
	t.set_color("icon_disabled_color", "Button", Color(0.45, 0.48, 0.55))
	t.set_constant("h_separation", "Button", 8)
	t.set_stylebox("normal", "Button", box(PANEL_2, LINE, 6, 7))
	t.set_stylebox("hover", "Button", box(PANEL_2.lightened(0.1), ACCENT, 6, 7))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.5), ACCENT, 6, 7))
	t.set_stylebox("disabled", "Button", box(PANEL.darkened(0.1), LINE.darkened(0.35), 6, 7))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT.darkened(0.2), 6, 7))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 0, 10))
	t.set_stylebox("panel", "Panel", box(PANEL, LINE, 0, 0))
	t.set_stylebox("panel", "TabContainer", box(PANEL, LINE, 0, 12))
	t.set_stylebox("tab_selected", "TabContainer", box(PANEL_2, ACCENT, 5, 8))
	t.set_stylebox("tab_unselected", "TabContainer", box(PANEL, LINE, 5, 8))
	t.set_stylebox("tab_hovered", "TabContainer", box(PANEL_2, LINE, 5, 8))
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_font("font", "TabContainer", font_bold())
	t.set_stylebox("background", "ProgressBar", box(Color(0.04, 0.055, 0.09), Color(0, 0, 0, 0), 4, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, Color(0, 0, 0, 0), 4, 0))
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("bold_font", "RichTextLabel", font_bold())
	t.set_stylebox("normal", "LineEdit", box(Color(0.05, 0.07, 0.11), LINE, 5, 7))
	t.set_stylebox("normal", "OptionButton", box(PANEL_2, LINE, 6, 7))
	t.set_stylebox("hover", "OptionButton", box(PANEL_2.lightened(0.1), ACCENT, 6, 7))
	t.set_stylebox("pressed", "OptionButton", box(PANEL_2, ACCENT, 6, 7))
	t.set_stylebox("focus", "OptionButton", box(Color(0, 0, 0, 0), ACCENT.darkened(0.2), 6, 7))
	t.set_stylebox("panel", "PopupMenu", box(PANEL_2, LINE, 6, 6))
	t.set_stylebox("hover", "PopupMenu", box(ACCENT.darkened(0.45), Color(0, 0, 0, 0), 4, 4))
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.02, 0.03, 0.06, 0.97), ACCENT.darkened(0.3), 6, 10))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("slider", "HSlider", box(Color(0.04, 0.055, 0.09), LINE, 4, 3))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT.darkened(0.2), Color(0, 0, 0, 0), 4, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, Color(0, 0, 0, 0), 4, 3))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_stylebox("normal", "CheckButton", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 4))
	t.set_stylebox("hover", "CheckButton", box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 4, 4))
	t.set_stylebox("pressed", "CheckButton", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 4))
	t.set_stylebox("focus", "CheckButton", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 4))
	t.set_stylebox("separator", "HSeparator", line_box(LINE))
	t.set_constant("separation", "HSeparator", 10)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 2))
	t.set_stylebox("grabber", "VScrollBar", box(LINE, Color(0, 0, 0, 0), 4, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(ACCENT.darkened(0.3), Color(0, 0, 0, 0), 4, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, Color(0, 0, 0, 0), 4, 2))
	return t


static func label(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func heading(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font_head())
	return l


static func bold(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font_bold())
	return l


static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func caps(text: String, color: Color = ACCENT, size: int = 11) -> Label:
	var l := bold(text.to_upper(), size, color)
	return l


static func bar(value: float, max_value: float = 100.0, color: Color = ACCENT, height: int = 8) -> ProgressBar:
	var p := ProgressBar.new()
	p.max_value = max_value
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, height)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("fill", box(color, Color(0, 0, 0, 0), 4, 0))
	return p


static func icon_rect(name: String, size: int = 16, color: Color = TEXT) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(name)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = color
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


static func portrait_rect(person: String, size: int = 64) -> TextureRect:
	var r := TextureRect.new()
	r.texture = portrait(person)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return r


static func button(text: String, icon_name: String = "", primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = icon(icon_name)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 18)
	if primary:
		b.add_theme_stylebox_override("normal", box(ACCENT.darkened(0.1), ACCENT.lightened(0.2), 6, 9))
		b.add_theme_stylebox_override("hover", box(ACCENT.lightened(0.1), Color.WHITE, 6, 9))
		b.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.3), ACCENT, 6, 9))
		b.add_theme_color_override("font_color", Color(0.06, 0.06, 0.08))
		b.add_theme_color_override("font_hover_color", Color(0.02, 0.02, 0.04))
		b.add_theme_color_override("font_pressed_color", Color(0.02, 0.02, 0.04))
		b.add_theme_font_override("font", font_bold())
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_entered.connect(func(): Audio.sfx("hover", -14.0))
	b.pressed.connect(func(): Audio.sfx("click"))
	return b


static func clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()
