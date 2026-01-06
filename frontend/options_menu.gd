extends CanvasLayer

@onready var panel = $SlidePanel
@onready var edge_handler = $EdgeHandler

const ANIM_DURATION = 0.3
const EDGE_THRESHOLD = 50.0

var panel_width = 250.0

var is_open: bool = false
var touch_start_x = 0.0
var is_dragging = false

const CONFIG_PATH = "user://settings.cfg"

func _ready() -> void:
	# Load config first to set initial state correctly
	load_config()

	# Connect UI Signals
	# Toggles
	if not %ToggleHaptic.toggled.is_connected(_on_haptic_toggled):
		%ToggleHaptic.toggled.connect(_on_haptic_toggled)
	if not %ToggleKeyboard.toggled.is_connected(_on_keyboard_toggled):
		%ToggleKeyboard.toggled.connect(_on_keyboard_toggled)
	if not %ToggleIntegerScaling.toggled.is_connected(_on_integer_scaling_toggled):
		%ToggleIntegerScaling.toggled.connect(_on_integer_scaling_toggled)
		
	# Labels (tap to toggle) - Now using Buttons
	%ButtonHaptic.pressed.connect(_on_label_pressed.bind(%ToggleHaptic))
	%ButtonKeyboard.pressed.connect(_on_label_pressed.bind(%ToggleKeyboard))
	%ButtonIntegerScaling.pressed.connect(_on_label_pressed.bind(%ToggleIntegerScaling))
	%ButtonInputMode.pressed.connect(_on_label_pressed.bind(%ToggleInputMode))
	
	if not %ToggleInputMode.toggled.is_connected(_on_input_mode_toggled):
		%ToggleInputMode.toggled.connect(_on_input_mode_toggled)

	if not %SliderSensitivity.value_changed.is_connected(_on_sensitivity_changed):
		%SliderSensitivity.value_changed.connect(_on_sensitivity_changed)

	# Close Button
	$SlidePanel/VBoxContainer/CloseButton.pressed.connect(close_menu)
	%ButtonSave.pressed.connect(save_config)
	
	# Settings are applied via load_config(), no need to manually set button_pressed here if sync works
	# But we need to ensure the UI reflects the loaded state.
	# load_config handles: PicoVideoStreamer settings update AND UI element update.
	
	var app_version = ProjectSettings.get_setting("application/config/version")
	if app_version:
		%VersionLabel.text = "v" + str(app_version)
	else:
		%VersionLabel.text = "v1.0"
	
	# Subscribe to external changes
	KBMan.subscribe(_on_external_keyboard_change)
	
	# Listen for screen resize to update layout/orientation
	get_tree().root.size_changed.connect(_update_layout)
	
	_update_layout()
	panel.position.x = - panel.size.x

func _update_layout():
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Disable Full Keyboard option in landscape (pocketchip not visible)
	var is_landscape = PicoVideoStreamer.is_system_landscape()
	%ToggleKeyboard.disabled = is_landscape
	%ButtonKeyboard.disabled = is_landscape
	# Visually indicate disabled state if needed, but standard disabled style should suffice
	
	# Calculate dynamic font size (e.g., 1/50th of screen height for smaller text)
	var dynamic_font_size = int(max(12, viewport_size.y / 50))
	
	# Scale Factors
	# Keep icon readable but scaled relative to the new small font
	var scale_factor = float(dynamic_font_size) / 10.0
	scale_factor = clamp(scale_factor, 1.2, 3.0)
	
	# --- Apply Styling & Scaling ---
	
	# 1. Main Options Label
	# 1. Main Options Header
	var header_label = $SlidePanel/VBoxContainer/Header/Label
	header_label.add_theme_font_size_override("font_size", dynamic_font_size)
	
	# Scale Icon
	var icon_size = dynamic_font_size * 1.5
	%Icon.custom_minimum_size = Vector2(icon_size, icon_size)
	
	# 2. Haptic Row
	_style_option_row(%ButtonHaptic, %ToggleHaptic, $SlidePanel/VBoxContainer/HapticRow/WrapperHaptic, dynamic_font_size, scale_factor)
	
	# 3. Keyboard Row
	_style_option_row(%ButtonKeyboard, %ToggleKeyboard, $SlidePanel/VBoxContainer/KeyboardRow/WrapperKeyboard, dynamic_font_size, scale_factor)

	# 4. Integer Scaling Row
	_style_option_row(%ButtonIntegerScaling, %ToggleIntegerScaling, $SlidePanel/VBoxContainer/IntegerScalingRow/WrapperIntegerScaling, dynamic_font_size, scale_factor)

	# 5. Input Mode Row
	_style_option_row(%ButtonInputMode, %ToggleInputMode, $SlidePanel/VBoxContainer/InputModeRow/WrapperInputMode, dynamic_font_size, scale_factor)

	# 5. Sensitivity Row
	%LabelSensitivity.add_theme_font_size_override("font_size", dynamic_font_size)
	%LabelSensitivityValue.add_theme_font_size_override("font_size", dynamic_font_size)
	# Scale slider custom minimum width?
	var slider = %SliderSensitivity
	var slider_width = 100.0 * scale_factor
	slider.custom_minimum_size.x = slider_width
	# Note: HSlider height scales reasonably well automatically or via theme, but we can enforce logic if needed.

	
	# 4. Close and Save Buttons
	$SlidePanel/VBoxContainer/CloseButton.add_theme_font_size_override("font_size", dynamic_font_size)
	%ButtonSave.add_theme_font_size_override("font_size", dynamic_font_size)
	
	# 5. Version Label (slightly smaller)
	%VersionLabel.add_theme_font_size_override("font_size", max(10, int(dynamic_font_size * 0.8)))

	# --- Resize Panel ---
	# Wait for layout to process to get correct width
	await get_tree().process_frame
	
	# Adjust panel width if content is wider (due to scaling)
	var content_min_width = $SlidePanel/VBoxContainer.get_combined_minimum_size().x
	# Add some padding (margin of proper fit)
	var required_width = content_min_width + 50
	
	# Minimum safe width
	var final_width = max(required_width, min(400, viewport_size.x * 0.5))
	
	panel.size.x = final_width
	panel.position.x = - final_width

func _style_option_row(label_btn: Button, toggle: CheckButton, wrapper: Control, font_size: int, scale_factor: float):
	# Style Label Button
	label_btn.add_theme_font_size_override("font_size", font_size)
	
	# Scale Toggle
	toggle.scale = Vector2(scale_factor, scale_factor)
	toggle.text = "" # Ensure no text
	toggle.remove_theme_font_size_override("font_size")
	
	# Calculate toggle natural size
	toggle.custom_minimum_size = Vector2.ZERO
	toggle.size = Vector2.ZERO
	var natural_size = toggle.get_combined_minimum_size()
	toggle.size = natural_size
	
	# Resize Wrapper to fit scaled toggle
	# Use a fixed generous height to ensure centering room, usually 40 is good base
	var wrapper_base_height = max(40.0, natural_size.y)
	
	var reserved_width = 80.0 * scale_factor # generous width
	var reserved_height = wrapper_base_height * scale_factor
	
	wrapper.custom_minimum_size = Vector2(reserved_width, reserved_height)
	
	# Center toggle in wrapper
	var child_scaled_height = natural_size.y * scale_factor
	var y_offset = (reserved_height - child_scaled_height) / 2.0
	toggle.position.y = y_offset

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# Check edge swipe start
			if not is_open and event.position.x < EDGE_THRESHOLD:
				touch_start_x = event.position.x
				is_dragging = true
				get_viewport().set_input_as_handled()
			# Outside tap to close
			elif is_open and event.position.x > panel.size.x:
				close_menu()
				get_viewport().set_input_as_handled()
		else:
			if is_dragging:
				if event.position.x > panel.size.x / 3.0:
					open_menu()
				else:
					close_menu()
				is_dragging = false
				get_viewport().set_input_as_handled()
					
	elif event is InputEventScreenDrag:
		if is_dragging:
			var new_x = clamp(event.position.x - panel.size.x, -panel.size.x, 0)
			panel.position.x = new_x
			get_viewport().set_input_as_handled()

func open_menu():
	is_open = true
	var tween = create_tween()
	tween.tween_property(panel, "position:x", 0.0, ANIM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Disable game input via streamer
	if PicoVideoStreamer.instance:
		PicoVideoStreamer.instance.set_process_input(false)

func close_menu():
	is_open = false
	var tween = create_tween()
	tween.tween_property(panel, "position:x", -panel.size.x, ANIM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Re-enable game input
	if PicoVideoStreamer.instance:
		PicoVideoStreamer.instance.set_process_input(true)

func _on_haptic_toggled(toggled_on: bool):
	PicoVideoStreamer.set_haptic_enabled(toggled_on)

func _on_keyboard_toggled(toggled_on: bool):
	# Toggle between Full and Gaming keyboard logic
	KBMan.set_full_keyboard_enabled(toggled_on)
	
	# Refresh Arranger if needed
	var arranger = get_tree().root.get_node_or_null("Main/Arranger")
	if arranger:
		arranger.dirty = true

func _on_label_pressed(button: CheckButton):
	button.button_pressed = not button.button_pressed

func _on_external_keyboard_change(enabled: bool):
	if %ToggleKeyboard:
		%ToggleKeyboard.set_pressed_no_signal(enabled)

func _on_input_mode_toggled(toggled_on: bool):
	PicoVideoStreamer.set_input_mode(toggled_on)
	_update_input_mode_label(toggled_on)

func _update_input_mode_label(is_trackpad: bool):
	if %ButtonInputMode:
		%ButtonInputMode.text = "Input: Trackpad" if is_trackpad else "Input: Mouse"
	
	if %SliderSensitivity:
		%SliderSensitivity.editable = is_trackpad
		%SliderSensitivity.modulate.a = 1.0 if is_trackpad else 0.5
		
	if %LabelSensitivity:
		%LabelSensitivity.modulate.a = 1.0 if is_trackpad else 0.5
		
	if %LabelSensitivityValue:
		%LabelSensitivityValue.modulate.a = 1.0 if is_trackpad else 0.5

func _on_sensitivity_changed(val: float):
	PicoVideoStreamer.set_trackpad_sensitivity(val)
	%LabelSensitivityValue.text = str(val).left(3) # Limit decimal places

func _on_integer_scaling_toggled(toggled_on: bool):
	PicoVideoStreamer.set_integer_scaling_enabled(toggled_on)
	# Force Arranger update
	var arranger = get_tree().root.get_node_or_null("Main/Arranger")
	if arranger:
		arranger._on_resize()

func save_config():
	var config = ConfigFile.new()
	config.set_value("settings", "haptic_enabled", PicoVideoStreamer.get_haptic_enabled())
	config.set_value("settings", "trackpad_sensitivity", PicoVideoStreamer.get_trackpad_sensitivity())
	config.set_value("settings", "integer_scaling_enabled", PicoVideoStreamer.get_integer_scaling_enabled())
	config.save(CONFIG_PATH)
	
func load_config():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	var haptic = false
	var sensitivity = 0.5
	var integer_scaling = true
	
	if err == OK:
		haptic = config.get_value("settings", "haptic_enabled", false)
		sensitivity = config.get_value("settings", "trackpad_sensitivity", 0.5)
		integer_scaling = config.get_value("settings", "integer_scaling_enabled", true)
	
	# Apply Settings
	PicoVideoStreamer.set_haptic_enabled(haptic)
	PicoVideoStreamer.set_trackpad_sensitivity(sensitivity)
	PicoVideoStreamer.set_integer_scaling_enabled(integer_scaling)
	
	# Update UI
	if %ToggleHaptic: %ToggleHaptic.set_pressed_no_signal(haptic)
	if %ToggleIntegerScaling: %ToggleIntegerScaling.set_pressed_no_signal(integer_scaling)
	if %SliderSensitivity:
		%SliderSensitivity.set_value_no_signal(sensitivity) # avoid double setting
		%LabelSensitivityValue.text = str(sensitivity).left(3)
		
	# Sync other non-saved states usually comes from default checks
	if %ToggleInputMode:
		# Default to whatever PicoVideoStreamer has (usually MOUSE default)
		var is_trackpad = PicoVideoStreamer.get_input_mode() == PicoVideoStreamer.InputMode.TRACKPAD
		%ToggleInputMode.set_pressed_no_signal(is_trackpad)
		_update_input_mode_label(is_trackpad)

	if %ToggleKeyboard:
		%ToggleKeyboard.button_pressed = KBMan.get_current_keyboard_type() == KBMan.KBType.FULL
