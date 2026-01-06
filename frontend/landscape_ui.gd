extends Control

var tex_x_normal = preload("res://assets/btn_x_normal.png")
var tex_x_pressed = preload("res://assets/btn_x_pressed.png")
var tex_o_normal = preload("res://assets/btn_o_normal.png")
var tex_o_pressed = preload("res://assets/btn_o_pressed.png")

var tex_mouse_l_normal = preload("res://assets/btn_mouse_left_normal.png")
var tex_mouse_l_pressed = preload("res://assets/btn_mouse_left_pressed.png")
var tex_mouse_r_normal = preload("res://assets/btn_mouse_right_normal.png")
var tex_mouse_r_pressed = preload("res://assets/btn_mouse_right_pressed.png")

func _ready() -> void:
	# LandscapeUI is a child of Main (where PicoVideoStreamer script is attached)
	var streamer = get_parent()
	if streamer.has_signal("input_mode_changed"):
		streamer.input_mode_changed.connect(_update_buttons_for_mode)
		# Initialize buttons with current state
		_update_buttons_for_mode(streamer.get_input_mode() == streamer.InputMode.TRACKPAD)

func _process(delta: float) -> void:
	var arranger = get_node_or_null("../Arranger")
	if arranger:
		# Force uniform scaling to prevent distortion (use X scale for both axes)
		var s = arranger.scale.x
		scale = Vector2(s, s)
		# Compensate size so anchors cover the full viewport in local coordinates
		size = get_viewport_rect().size / s
		
		# Inverse scale the high-res D-Pad so it stays physical size
		var dpad = get_node_or_null("Control/LeftPad/Omnipad")
		if dpad:
			var target_scale = 8.5 / s
			dpad.scale = Vector2(target_scale, target_scale)
	else:
		size = get_viewport_rect().size
	
	var is_landscape = PicoVideoStreamer.is_system_landscape()
	
	# Only show if in landscape mode AND controls are needed (no physical controller)
	var is_controller_connected = ControllerUtils.is_real_controller_connected()
	var should_be_visible = is_landscape and not is_controller_connected
	
	# print("LandscapeUI: landscape=", is_landscape, " controller=", is_controller_connected, " visible=", should_be_visible)
	
	visible = should_be_visible

func _update_buttons_for_mode(is_trackpad: bool):
	var x_btn = get_node_or_null("Control/RightPad/X")
	var z_btn = get_node_or_null("Control/RightPad/Z")
	
	if is_trackpad:
		if x_btn:
			x_btn.set_textures(tex_mouse_l_normal, tex_mouse_l_pressed)
		if z_btn:
			z_btn.set_textures(tex_mouse_r_normal, tex_mouse_r_pressed)
	else:
		if x_btn:
			x_btn.set_textures(tex_x_normal, tex_x_pressed)
		if z_btn:
			z_btn.set_textures(tex_o_normal, tex_o_pressed)
