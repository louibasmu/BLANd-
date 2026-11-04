class_name TurnCompass
extends Control
# Small diagram showing the 4 seats in the same layout as the table
#
# It is purely a display widget: the table calls set_state() whenever something changes
# and the widget redraws itself in _draw(). It never makes game decisions.
# (You bottom, Bot 1 left, Bot 2 top, Bot 3 right) with curved arrows
# pointing the way play is moving. Gold = playing now, orange ring = next.

# Where each seat sits on the circle, as an angle in radians. Seat 0 (You) is at the
# bottom, then going round: left, top, right. Godot's y axis points DOWN, so PI/2 is "down".
const SEAT_ANGLES := [PI / 2, PI, PI * 1.5, 0.0]   # bottom, left, top, right (y points down)

# Display names per seat (index = seat number).
var names: Array = ["You", "Bot 1", "Bot 2", "Bot 3"]




# Colour of the arrows and caption (gold, to match the "current player" highlight).
var _arrow_color := Color(1, 0.85, 0.3)


# Godot calls this once when the node joins the scene.
	# @param
	# @return
func _ready() -> void:
	# Reserve space so the container doesn't squash the widget.
	custom_minimum_size = Vector2(150, 130)
	# Let clicks pass through, so this decoration never blocks the buttons underneath it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

var direction: int = 1 # +1 = clockwise, -1 = counter-clockwise. Flipped by the Reverse card.
var current: int = -1 # Seat that is playing right now (-1 = nobody).
var next_player: int = -1 # The seat that will play after them.
# Safe and frozen only change the seat's colour here.
var safe: Array = [false, false, false, false] # Per-seat flags: `safe` = has emptied their hand this round. 
var frozen: Array = [false, false, false, false] #`frozen` = is missing turns.

# The table pushes new information in here. We only store it and ask Godot to redraw
# (queue_redraw) rather than drawing immediately; _draw() then uses the stored values.
	# @param p_direction -> int, p_current -> int, p_next -> int, p_safe -> Array, p_frozen -> Array
	# @return void
func set_state(p_direction: int, p_current: int, p_next: int, p_safe: Array, p_frozen: Array) -> void:
	direction = p_direction
	current = p_current
	next_player = p_next
	safe = p_safe
	frozen = p_frozen
	queue_redraw()

# Quick flash when the direction flips (called by the table on Reverse).
	# @param none
	# @return void
func pulse() -> void:
	# Briefly scales the widget up and back down to catch the player's eye.
	# pivot_offset makes it grow from the centre instead of the top-left corner.
	pivot_offset = size / 2 # from Vector2 class
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.15)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25)


# Godot calls _draw() whenever a redraw is requested. Everything below is drawn in three parts:
# the arrows, the seat circles, then the caption.
	# @param none
	# @return void
func _draw() -> void:
	# c = centre of the circle (nudged down 8px to leave room for the caption); r = radius,
	# sized from the smaller of width/height so the diagram always fits.
	var c := size / 2 + Vector2(0, 8)
	var r := minf(size.x, size.y - 16) * 0.36
	var font := ThemeDB.fallback_font

	# Curved arrows between neighbouring seats, in the direction of play.
	# For seat i the arrow runs from its angle to the next seat's angle (a quarter turn,
	# direction decides which way). `gap` pulls both ends in so the arrow doesn't touch the circles.
	var gap := 0.42
	for i in 4:
		var a0: float = SEAT_ANGLES[i]
		var a1: float = a0 + direction * (PI / 2)
		var start := a0 + direction * gap
		var end := a1 - direction * gap
		var pts := PackedVector2Array()
		# Approximate the curve with 13 points along the arc; lerpf gives the angle at each step.
		for k in 13:
			var a := lerpf(start, end, k / 12.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, _arrow_color, 2.0, true)
		# The arrowhead is a small triangle at the tip. `tangent` is the direction of travel at
		# the end of the arc; `side` is perpendicular to it, which gives the triangle its width.
		# arrowhead at the end, along the tangent
		var tip := pts[pts.size() - 1]
		var tangent := Vector2(-sin(end), cos(end)) * direction
		var side := tangent.orthogonal()
		draw_colored_polygon(PackedVector2Array([
			tip + tangent * 7, tip - tangent * 2 + side * 5, tip - tangent * 2 - side * 5]), _arrow_color)

	# Seat circle colours, from lowest to highest priority:
	for i in 4:
		var pos := c + Vector2(cos(SEAT_ANGLES[i]), sin(SEAT_ANGLES[i])) * r
		var fill := Color(0.15, 0.2, 0.17) # dark green = normal
		if safe[i]:
			fill = Color(0.3, 0.45, 0.3) # lighter green = safe
		elif frozen[i]:
			fill = Color(0.25, 0.5, 0.7) # blue = frozen
		if i == current:
			fill = Color(1, 0.8, 0.2) # gold = playing now.
		draw_circle(pos, 15, fill)
		if i == next_player and i != current:
			draw_arc(pos, 17, 0, TAU, 32, Color(1, 0.55, 0.15), 3.0, true) # Orange ring marks who plays next.
			draw_arc(pos, 15, 0, TAU, 32, Color(0, 0, 0, 0.6), 1.5, true)  # Those who aren't playing get a thin dark outline.

		var label: String = "You" if i == 0 else "B%d" % i 		# "You" for seat 0, otherwise "B1".."B3". centered label by subtracting half its width.
		var fs := 12
		var tsize := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tcol := Color(0.1, 0.1, 0.1) if i == current else Color.WHITE
		draw_string(font, pos + Vector2(-tsize.x / 2, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)

	var caption := "clockwise" if direction == 1 else "counter-clockwise" 	# Caption that tells the player which way play is going.
	var csize := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	draw_string(font, Vector2((size.x - csize.x) / 2, 11), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _arrow_color)
