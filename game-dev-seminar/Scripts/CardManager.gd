# Prototype drag-and-drop script from the early card-handling experiments (separate from
# the main BaseGame scenes). It lets the player pick up a card sprite with the mouse
# and move it around the screen.
extends Node2D

# The card currently attached to the mouse, or null when nothing is being dragged.
var card_being_dragged
# Size of the viewport, stored in _ready() so dragged cards can be kept on screen.
var screen_size
# Physics layer 1 is the one card Area2Ds are placed on; the click test only looks at this layer.
const COLLISION_MASK_CARD = 1

# Godot calls this for every input event. On left-button press we look for a card under
# the mouse and start dragging it; on release we drop whatever we were holding.
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			#print("Left Click")
			var card = raycast_check_for_card()
			if card:
				card_being_dragged = card
		else:
			card_being_dragged = null

# Asks the physics engine "what is under the mouse right now?" and returns the card that
# was hit, or null. A point query is used (rather than a signal on each card) so one
# script can handle every card.
func raycast_check_for_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(parameters)
	# result[0].collider is the card's collision Area2D; its parent is the actual card node.
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size


# Called every frame. 'delta' is the elapsed time since the previous frame.
# Runs every frame: while a card is being dragged, move it to the mouse position.
# clamp() stops the card from being dragged outside the screen edges.
func _process(delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x), 
		clamp(mouse_pos.y, 0, screen_size.y))
