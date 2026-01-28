class_name DebugGraph
extends Control

@export var max_samples: int = 128
@export var min_value: float = 0.0
@export var max_value: float = 16.0
@export var graph_color: Color = Color.GREEN
@export var line_width: float = 2.0
@export var label_text: String = "Metric"

var history: Array[float] = []
var _label_node: Label

func _ready():
	# Transparent background
	# self.color = Color(0, 0, 0, 0.5) 
	_label_node = Label.new()
	_label_node.add_theme_color_override("font_color", graph_color)
	_label_node.add_theme_font_size_override("font_size", 24)
	add_child(_label_node)
	_label_node.position = Vector2(10, 0)
	
	# Initial fill
	for i in range(max_samples):
		history.append(min_value)

func add_value(val: float):
	history.append(val)
	if history.size() > max_samples:
		history.pop_front()
	
	_label_node.text = "%s: %.2f" % [label_text, val]
	queue_redraw()

func _draw():
	var w = size.x
	var h = size.y
	
	# Draw background box
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.5))
	
	var step_x = w / float(max_samples)
	var range_val = max_value - min_value
	if range_val <= 0.001: range_val = 1.0 # Avoid div by zero
	
	var points = PackedVector2Array()
	
	for i in range(history.size()):
		var val = history[i]
		# Normalize 0..1
		var norm = (val - min_value) / range_val
		norm = clamp(norm, 0.0, 1.0)
		
		# Invert Y (0 is top, h is bottom)
		var py = h - (norm * h)
		var px = i * step_x
		
		points.append(Vector2(px, py))
	
	if points.size() > 1:
		draw_polyline(points, graph_color, line_width)
