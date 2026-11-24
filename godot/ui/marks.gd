extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const SHAPES: Dictionary = {
	"fire": [[0, -1], [0.35, -0.35], [0.55, 0.1], [0.5, 0.5], [0.2, 0.85], [-0.2, 0.85], [-0.5, 0.5], [-0.55, 0.05], [-0.3, -0.25], [-0.1, 0.05]],
	"lightning": [[0.15, -1], [-0.5, 0.1], [-0.05, 0.1], [-0.2, 1], [0.5, -0.15], [0.05, -0.15], [0.3, -1]],
	"poison": [[0, -1], [0.45, -0.1], [0.6, 0.35], [0.4, 0.8], [0, 0.95], [-0.4, 0.8], [-0.6, 0.35], [-0.45, -0.1]],
	"steel": [[-0.75, -0.8], [0.75, -0.8], [0.7, 0.15], [0, 0.95], [-0.7, 0.15]],
}

var symbol: String
var egg: bool


func _init(id: String = "", draw_egg: bool = false) -> void:
	symbol = id
	egg = draw_egg
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var color: Color = GameTheme.COLOR.get(symbol, GameTheme.PANEL_LINE)
	if not egg:
		draw_circle(center, minf(size.x, size.y) / 2.0, color, true, -1.0, true)
		_mark(center, minf(size.x, size.y) * 0.6)
		return
	draw_style_box(GameTheme.style(GameTheme.WELL, Color("#2c2820"), 1, 10, "flat"), Rect2(Vector2.ZERO, size))
	if symbol.is_empty():
		_ellipse(center, size * Vector2(0.56, 0.72), Color(GameTheme.GOLD_DIM, 0.35), false)
		return
	_ellipse(center + Vector2(0, size.y * 0.36), size * Vector2(0.6, 0.14), Color(0, 0, 0, 0.45))
	_ellipse(center, size * Vector2(0.72, 0.88), Color("#14121a"))
	_ellipse(center, size * Vector2(0.64, 0.8), color.darkened(0.28))
	_ellipse(center - size * Vector2(0.025, 0.035), size * Vector2(0.56, 0.7), color)
	_ellipse(center - size * Vector2(0.1, 0.16), size * Vector2(0.3, 0.38), color.lightened(0.22))
	_ellipse(center - size * Vector2(0.14, 0.22), size * Vector2(0.12, 0.16), Color(1, 1, 1, 0.55))
	_mark(center + Vector2(0, 2), minf(size.x, size.y) * 0.42)


func _ellipse(center: Vector2, diameter: Vector2, color: Color, filled: bool = true) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(33):
		points.append(center + Vector2.from_angle(TAU * i / 32.0) * diameter / 2.0)
	if filled:
		points.resize(32)
		draw_colored_polygon(points, color)
	else:
		draw_polyline(points, color, 2, true)


func _mark(center: Vector2, pixels: float) -> void:
	var radius: float = pixels / 2.0
	var ink: Color = GameTheme.INK
	if SHAPES.has(symbol):
		var points: PackedVector2Array = PackedVector2Array()
		for point: Array in SHAPES[symbol]:
			points.append(center + Vector2(point[0], point[1]) * radius)
		draw_colored_polygon(points, ink)
		if symbol == "poison":
			draw_circle(center + Vector2(0.75, -0.55) * radius, 0.16 * radius, ink)
		return
	match symbol:
		"ice":
			for i in range(3):
				var angle: float = PI * i / 3.0
				var axis: Vector2 = Vector2.from_angle(angle) * radius
				draw_line(center - axis, center + axis, ink, 2, true)
				for sign_value: int in [-1, 1]:
					var branch: Vector2 = center + axis * sign_value * 0.55
					for offset: float in [-2.4, 2.4]:
						draw_line(branch, branch + Vector2.from_angle(angle + offset) * sign_value * 0.32 * radius, ink, 2, true)
		"abyss":
			draw_arc(center, radius * 0.78, 0, TAU, 32, ink, 2, true)
			_ellipse(center, Vector2(0.5, 0.9) * radius, ink)
		"gold":
			_ellipse(center, Vector2(0.62, 0.8) * pixels, Color("#fff3bf"))
			_ellipse(center - Vector2(0.1, 0.16) * pixels, Vector2(0.14, 0.22) * pixels, Color.WHITE)
		"wild":
			draw_circle(center, radius * 0.72, Color("#f3f0ff"))
			draw_circle(center + Vector2(0.15, 0.15) * radius, radius * 0.45, Color("#9775fa8c"))
			draw_circle(center - Vector2(0.28, 0.28) * radius, radius * 0.16, Color.WHITE)
