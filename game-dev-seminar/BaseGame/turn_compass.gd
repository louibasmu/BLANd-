class_name TurnCompass
extends Control
## Small diagram showing the 4 seats in the same layout as the table
## (You bottom, Bot 1 left, Bot 2 top, Bot 3 right) with curved arrows
## pointing the way play is moving. Gold = playing now, orange ring = next.

const SEAT_ANGLES := [PI / 2, PI, PI * 1.5, 0.0]   # bottom, left, top, right (y points down)

var names: Array = ["You", "Bot 1", "Bot 2", "Bot 3"]
var direction: int = 1
var current: int = -1
var next_player: int = -1
var safe: Array = [false, false, false, false]
var frozen: Array = [false, false, false, false]

var _arrow_color := Color(1, 0.85, 0.3)


func _ready() -> void:
	custom_minimum_size = Vector2(150, 130)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(p_direction: int, p_current: int, p_next: int, p_safe: Array, p_frozen: Array) -> void:
	direction = p_direction
	current = p_current
	next_player = p_next
	safe = p_safe
	frozen = p_frozen
	queue_redraw()


## Quick flash when the direction flips (called by the table on Reverse).
func pulse() -> void:
	pivot_offset = size / 2
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.15)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25)


func _draw() -> void:
	var c := size / 2 + Vector2(0, 8)
	var r := minf(size.x, size.y - 16) * 0.36
	var font := ThemeDB.fallback_font

	# Curved arrows between neighbouring seats, in the direction of play.
	var gap := 0.42
	for i in 4:
		var a0: float = SEAT_ANGLES[i]
		var a1: float = a0 + direction * (PI / 2)
		var start := a0 + direction * gap
		var end := a1 - direction * gap
		var pts := PackedVector2Array()
		for k in 13:
			var a := lerpf(start, end, k / 12.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, _arrow_color, 2.0, true)
		# arrowhead at the end, along the tangent
		var tip := pts[pts.size() - 1]
		var tangent := Vector2(-sin(end), cos(end)) * direction
		var side := tangent.orthogonal()
		draw_colored_polygon(PackedVector2Array([
			tip + tangent * 7, tip - tangent * 2 + side * 5, tip - tangent * 2 - side * 5]), _arrow_color)

	# Seats
	for i in 4:
		var pos := c + Vector2(cos(SEAT_ANGLES[i]), sin(SEAT_ANGLES[i])) * r
		var fill := Color(0.15, 0.2, 0.17)
		if safe[i]:
			fill = Color(0.3, 0.45, 0.3)
		elif frozen[i]:
			fill = Color(0.25, 0.5, 0.7)
		if i == current:
			fill = Color(1, 0.8, 0.2)
		draw_circle(pos, 15, fill)
		if i == next_player and i != current:
			draw_arc(pos, 17, 0, TAU, 32, Color(1, 0.55, 0.15), 3.0, true)
		else:
			draw_arc(pos, 15, 0, TAU, 32, Color(0, 0, 0, 0.6), 1.5, true)
		var label: String = "You" if i == 0 else "B%d" % i
		var fs := 12
		var tsize := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tcol := Color(0.1, 0.1, 0.1) if i == current else Color.WHITE
		draw_string(font, pos + Vector2(-tsize.x / 2, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)

	# Caption
	var caption := "clockwise" if direction == 1 else "counter-clockwise"
	var csize := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	draw_string(font, Vector2((size.x - csize.x) / 2, 11), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _arrow_color)
