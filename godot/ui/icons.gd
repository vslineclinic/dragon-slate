extends Control
## 메달 안에 그리는 작은 그림(유물 · 보상 · 갈림길 · HUD). 좌표는 가운데 기준 -1~1.

const GameTheme = preload("res://godot/ui/theme.gd")

var glyph: String
var tint: Color
var medal: bool


func _init(id: String = "", color: Color = Color("#d9b25f"), with_medal: bool = true) -> void:
	glyph = id
	tint = color
	medal = with_medal
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - 3.0
	if medal:
		draw_circle(center + Vector2(0, 3), radius + 1.0, Color(0, 0, 0, 0.45), true, -1.0, true)
		draw_circle(center, radius, Color("#100f17"), true, -1.0, true)
		draw_circle(center, radius - 1.0, Color(tint, 0.22), true, -1.0, true)
		draw_arc(center, radius * 0.7, PI * 1.1, PI * 1.9, 20, Color(1, 1, 1, 0.06), radius * 0.4, true)
		draw_arc(center, radius, 0, TAU, 56, tint.darkened(0.5), 5.0, true)
		draw_arc(center, radius, 0, TAU, 56, tint, 2.5, true)
		radius *= 0.6
	_glyph(center, radius)


func _p(center: Vector2, radius: float, points: Array, color: Color) -> void:
	var shape: PackedVector2Array = PackedVector2Array()
	for point: Array in points:
		shape.append(center + Vector2(point[0], point[1]) * radius)
	draw_colored_polygon(shape, color)


func _l(center: Vector2, radius: float, from: Array, to: Array, color: Color, width: float = 0.12) -> void:
	draw_line(center + Vector2(from[0], from[1]) * radius, center + Vector2(to[0], to[1]) * radius, color, maxf(1.5, width * radius), true)


func _c(center: Vector2, radius: float, at: Array, reach: float, color: Color) -> void:
	draw_circle(center + Vector2(at[0], at[1]) * radius, reach * radius, color, true, -1.0, true)


func _glyph(c: Vector2, r: float) -> void:
	var hi: Color = tint.lightened(0.55)
	var mid: Color = tint.lightened(0.15)
	var low: Color = tint.darkened(0.35)
	var ink: Color = Color("#14121a")
	match glyph:
		"sword":
			_p(c, r, [[0, -1], [0.16, -0.75], [0.16, 0.3], [-0.16, 0.3], [-0.16, -0.75]], hi)
			_p(c, r, [[0, -1], [0.16, -0.75], [0.16, 0.3], [0, 0.3]], mid)
			_p(c, r, [[-0.5, 0.3], [0.5, 0.3], [0.5, 0.46], [-0.5, 0.46]], tint)
			_p(c, r, [[-0.1, 0.46], [0.1, 0.46], [0.1, 0.85], [-0.1, 0.85]], low)
			_c(c, r, [0, 0.92], 0.14, tint)
		"shell":
			_p(c, r, [[0, -0.85], [0.75, -0.4], [0.85, 0.3], [0.45, 0.8], [-0.45, 0.8], [-0.85, 0.3], [-0.75, -0.4]], mid)
			_p(c, r, [[0, -0.4], [0.38, -0.18], [0.38, 0.28], [0, 0.5], [-0.38, 0.28], [-0.38, -0.18]], hi)
			for edge: Array in [[[0, -0.4], [0, -0.85]], [[0.38, -0.18], [0.75, -0.4]], [[0.38, 0.28], [0.85, 0.3]], [[0, 0.5], [0, 0.8]], [[-0.38, 0.28], [-0.85, 0.3]], [[-0.38, -0.18], [-0.75, -0.4]]]:
				_l(c, r, edge[0], edge[1], low, 0.08)
		"feather", "phoenix":
			var plume: Color = hi if glyph == "feather" else Color("#ffb347")
			_p(c, r, [[0.55, -0.95], [0.75, -0.3], [0.35, 0.35], [-0.2, 0.6], [-0.45, 0.2], [-0.2, -0.45]], plume)
			_p(c, r, [[0.55, -0.95], [0.75, -0.3], [0.35, 0.35], [-0.2, 0.6]], mid if glyph == "feather" else Color("#ff6a2a"))
			_l(c, r, [0.55, -0.95], [-0.65, 0.95], low, 0.1)
			if glyph == "phoenix":
				_c(c, r, [0.3, -0.25], 0.16, Color("#fff3bf"))
		"fang":
			_p(c, r, [[-0.75, -0.7], [-0.1, -0.7], [-0.3, 0.2], [-0.5, 0.9]], hi)
			_p(c, r, [[0.75, -0.7], [0.1, -0.7], [0.3, 0.2], [0.5, 0.9]], hi)
			_p(c, r, [[-0.9, -0.9], [0.9, -0.9], [0.9, -0.6], [-0.9, -0.6]], Color("#d6336c"))
		"horn":
			_p(c, r, [[-0.9, 0.25], [-0.7, 0.05], [0.4, -0.5], [0.4, 0.7], [-0.7, 0.45]], mid)
			_p(c, r, [[0.4, -0.75], [0.8, -0.9], [0.8, 0.95], [0.4, 0.85]], hi)
			_l(c, r, [-0.3, -0.15], [-0.3, 0.52], low, 0.1)
			_l(c, r, [0.05, -0.33], [0.05, 0.6], low, 0.1)
		"banner":
			_l(c, r, [-0.6, -0.95], [-0.6, 0.95], hi, 0.14)
			_p(c, r, [[-0.5, -0.85], [0.8, -0.65], [0.5, -0.2], [0.8, 0.25], [-0.5, 0.1]], mid)
			_c(c, r, [0.05, -0.33], 0.2, hi)
		"tome":
			_p(c, r, [[-0.8, -0.75], [0.8, -0.75], [0.8, 0.8], [-0.8, 0.8]], low)
			_p(c, r, [[-0.62, -0.75], [0.8, -0.75], [0.8, 0.66], [-0.62, 0.66]], mid)
			_p(c, r, [[-0.2, -0.3], [0.38, -0.3], [0.09, 0.3]], hi)
			_l(c, r, [-0.62, -0.75], [-0.62, 0.66], hi, 0.07)
		"scale":
			_l(c, r, [0, -0.85], [0, 0.8], hi, 0.12)
			_l(c, r, [-0.8, -0.55], [0.8, -0.55], hi, 0.12)
			_p(c, r, [[-1.0, 0.05], [-0.4, 0.05], [-0.55, 0.4], [-0.85, 0.4]], mid)
			_p(c, r, [[1.0, 0.05], [0.4, 0.05], [0.55, 0.4], [0.85, 0.4]], mid)
			_l(c, r, [-0.7, -0.55], [-0.7, 0.05], low, 0.06)
			_l(c, r, [0.7, -0.55], [0.7, 0.05], low, 0.06)
			_p(c, r, [[-0.45, 0.8], [0.45, 0.8], [0.3, 0.95], [-0.3, 0.95]], tint)
		"dice", "nudge_dice":
			_p(c, r, [[-0.75, -0.75], [0.75, -0.75], [0.75, 0.75], [-0.75, 0.75]], hi)
			for pip: Array in [[-0.4, -0.4], [0.4, 0.4], [0, 0], [0.4, -0.4], [-0.4, 0.4]]:
				_c(c, r, pip, 0.13, ink)
		"seal":
			draw_arc(c, r * 0.85, 0, TAU, 40, hi, maxf(2.0, r * 0.12), true)
			for i: int in range(3):
				var spot: Vector2 = Vector2.from_angle(TAU * i / 3.0 - PI / 2.0) * 0.45
				draw_circle(c + spot * r, r * 0.2, [Color("#f0622a"), Color("#58b8f5"), Color("#f7b928")][i], true, -1.0, true)
		"kiln":
			_p(c, r, [[-0.75, -0.2], [0.75, -0.2], [0.55, 0.7], [-0.55, 0.7]], mid)
			_p(c, r, [[-0.9, -0.38], [0.9, -0.38], [0.9, -0.2], [-0.9, -0.2]], hi)
			_p(c, r, [[0, -1], [0.28, -0.6], [0, -0.42], [-0.28, -0.6]], Color("#ff8a2a"))
			_p(c, r, [[-0.25, 0.7], [-0.4, 0.95], [-0.2, 0.95]], low)
			_p(c, r, [[0.25, 0.7], [0.4, 0.95], [0.2, 0.95]], low)
		"mana":
			_p(c, r, [[0, -1], [0.62, -0.25], [0, 1], [-0.62, -0.25]], mid)
			_p(c, r, [[0, -1], [0.62, -0.25], [0, -0.05]], hi)
			_p(c, r, [[0, -0.05], [0.62, -0.25], [0, 1]], low)
		"egg", "t2egg":
			_ellipse(c + Vector2(0, 0.05) * r, Vector2(1.25, 1.7) * r, low)
			_ellipse(c, Vector2(1.2, 1.62) * r, mid)
			_ellipse(c - Vector2(0.22, 0.38) * r, Vector2(0.34, 0.5) * r, Color(1, 1, 1, 0.35))
			if glyph == "t2egg":
				_spark(c + Vector2(0.05, 0.12) * r, r * 0.42, Color.WHITE)
		"trait":
			_p(c, r, [[0, -1], [0.55, -0.1], [0.62, 0.4], [0.35, 0.85], [0, 1], [-0.35, 0.85], [-0.62, 0.4], [-0.55, -0.1]], Color("#e64980"))
			_ellipse(c + Vector2(-0.2, 0.3) * r, Vector2(0.24, 0.4) * r, Color(1, 1, 1, 0.35))
		"nudge":
			_p(c, r, [[0, -1], [0.6, -0.3], [0.22, -0.3], [0.22, 0.3], [0.6, 0.3], [0, 1], [-0.6, 0.3], [-0.22, 0.3], [-0.22, -0.3], [-0.6, -0.3]], hi)
		"freeSpin":
			draw_arc(c, r * 0.68, PI * 0.25, PI * 1.85, 28, hi, maxf(2.0, r * 0.2), true)
			_p(c, r, [[0.9, -0.62], [0.28, -0.82], [0.62, -0.12]], hi)
		"transmute":
			## 룬석 하나와 그 둘레를 도는 두 화살표.
			_p(c, r, [[0, -0.62], [0.42, 0], [0, 0.62], [-0.42, 0]], hi)
			_p(c, r, [[0, -0.62], [0.42, 0], [0, 0.62]], mid)
			_l(c, r, [0, -0.3], [0, 0.3], ink, 0.07)
			_l(c, r, [-0.14, -0.08], [0.14, -0.2], ink, 0.07)
			draw_arc(c, r * 0.92, PI * 1.08, PI * 1.82, 20, mid, maxf(2.0, r * 0.14), true)
			draw_arc(c, r * 0.92, PI * 0.08, PI * 0.82, 20, mid, maxf(2.0, r * 0.14), true)
			_p(c, r, [[0.98, -0.6], [0.5, -0.86], [0.66, -0.34]], mid)
			_p(c, r, [[-0.98, 0.6], [-0.5, 0.86], [-0.66, 0.34]], mid)
		"life", "heart":
			_c(c, r, [-0.36, -0.28], 0.44, Color("#ff6b81"))
			_c(c, r, [0.36, -0.28], 0.44, Color("#ff6b81"))
			_p(c, r, [[-0.78, -0.08], [0.78, -0.08], [0, 0.95]], Color("#ff6b81"))
			_c(c, r, [-0.4, -0.38], 0.14, Color(1, 1, 1, 0.5))
		"elite":
			_l(c, r, [-0.75, -0.85], [0.6, 0.6], hi, 0.16)
			_l(c, r, [0.75, -0.85], [-0.6, 0.6], hi, 0.16)
			_l(c, r, [0.3, 0.6], [0.8, 0.1], mid, 0.12)
			_l(c, r, [-0.3, 0.6], [-0.8, 0.1], mid, 0.12)
			_c(c, r, [0.72, 0.78], 0.14, mid)
			_c(c, r, [-0.72, 0.78], 0.14, mid)
		"rest":
			_p(c, r, [[0, -0.95], [0.5, -0.1], [0.3, 0.4], [-0.3, 0.4], [-0.5, -0.1]], Color("#ff8a2a"))
			_p(c, r, [[0, -0.4], [0.24, 0.05], [0, 0.35], [-0.24, 0.05]], Color("#ffe066"))
			_l(c, r, [-0.8, 0.5], [0.8, 0.85], Color("#a8774a"), 0.16)
			_l(c, r, [0.8, 0.5], [-0.8, 0.85], Color("#8a5a35"), 0.16)
		"merchant":
			_p(c, r, [[-0.3, -0.6], [0.3, -0.6], [0.75, 0.3], [0.5, 0.9], [-0.5, 0.9], [-0.75, 0.3]], mid)
			_p(c, r, [[-0.4, -0.95], [0.4, -0.95], [0.25, -0.6], [-0.25, -0.6]], hi)
			_l(c, r, [-0.36, -0.58], [0.36, -0.58], low, 0.12)
			_spark(c + Vector2(0, 0.2) * r, r * 0.34, hi)
		_:
			_spark(c, r * 0.8, hi)


func _ellipse(center: Vector2, diameter: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		points.append(center + Vector2.from_angle(TAU * i / 32.0) * diameter / 2.0)
	draw_colored_polygon(points, color)


func _spark(center: Vector2, reach: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(8):
		points.append(center + Vector2.from_angle(TAU * i / 8.0 - PI / 2.0) * (reach if i % 2 == 0 else reach * 0.28))
	draw_colored_polygon(points, color)
