extends Control

var original_position: Vector2
var original_scale: Vector2
var drag_offset_start: Vector2
var is_repositionable: bool = true

var active_touches = {}
var initial_pinch_dist = 0.0
var initial_scale_modifier = 1.0

func _ready() -> void:
	original_position = position
	original_scale = scale
	
	if PicoVideoStreamer.instance:
		PicoVideoStreamer.instance.layout_reset.connect(_on_layout_reset)
	
	
	# Attempt to load saved position and scale
	var is_landscape = _is_in_landscape_ui()
	var saved_pos = PicoVideoStreamer.get_control_pos(name, is_landscape)
	if saved_pos != null:
		position = saved_pos
	
	var saved_scale = PicoVideoStreamer.get_control_scale(name, is_landscape)
	scale = original_scale * saved_scale

func _gui_input(event: InputEvent) -> void:
	if PicoVideoStreamer.display_drag_enabled and is_repositionable:
		var event_index = event.index if "index" in event else 0
		if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
			if event.pressed:
				drag_offset_start = event.position
				active_touches[event_index] = event.position
				
				# Centralized Selection: Update the last touched element
				if PicoVideoStreamer.instance:
					PicoVideoStreamer.instance.selected_control = self
					PicoVideoStreamer.instance.control_selected.emit(self)
				
				accept_event()
			else:
				active_touches.erase(event_index)
				# Save position when interaction ends
				_save_layout()
				accept_event()
		elif event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)):
			if active_touches.has(event_index):
				active_touches[event_index] = event.position
			
			if active_touches.size() == 1:
				# Single touch: Drag logic
				position += event.position - drag_offset_start
				
				# Clamp to parent
				var p = get_parent()
				if p is Control:
					var min_pos = Vector2.ZERO
					var max_pos = p.size - (size * scale)
					position = position.clamp(min_pos, max_pos)
				
				accept_event()
			elif active_touches.size() == 2:
				# Multi-touch: CONSUME but don't handle locally (let Arranger handle global pinch)
				accept_event()
		else:
			# Block all other GUI input (like focus, etc.)
			accept_event()
		return # Block normal input (clicks) when in drag mode
	
func _is_in_landscape_ui() -> bool:
	# heuristic: check if we are inside LandscapeUI node path
	var p = get_parent()
	while p:
		if p.name == "LandscapeUI":
			return true
		p = p.get_parent()
	return false

func _save_layout():
	var current_scale_mod = scale.x / original_scale.x
	PicoVideoStreamer.set_control_layout_data(name, position, current_scale_mod, _is_in_landscape_ui())

func _on_layout_reset(target_is_landscape: bool):
	if target_is_landscape == _is_in_landscape_ui():
		position = original_position
		scale = original_scale
