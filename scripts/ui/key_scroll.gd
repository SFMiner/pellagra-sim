class_name KeyScroll
extends ScrollContainer
## A scroll area a keyboard user can reach and move: it takes focus (with a visible outline) and the
## arrow, Page and Home/End keys scroll it. Mouse wheel and touch work as usual.

# === PUBLIC VARIABLES ===
## Outline colour while focused (the theme's focus colour; high contrast uses its own).
var focus_color: Color = SkTheme.DARK["focus"]


# === LIFECYCLE METHODS ===
func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var page: int = int(maxf(size.y - 40.0, 40.0))
	match (event as InputEventKey).keycode:
		KEY_DOWN:
			scroll_vertical += 40
		KEY_UP:
			scroll_vertical -= 40
		KEY_PAGEDOWN:
			scroll_vertical += page
		KEY_PAGEUP:
			scroll_vertical -= page
		KEY_HOME:
			scroll_vertical = 0
		KEY_END:
			scroll_vertical = 1000000
		_:
			return
	accept_event()


func _draw() -> void:
	if has_focus():
		draw_rect(Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), focus_color, false, 4.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
