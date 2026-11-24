extends StyleBox
## 흑요석 판: StyleBoxFlat 위에 위쪽 광택, 아래쪽 그늘, 안쪽 빛줄을 덧그린다.
## kind: "auto"(크기를 보고 정함) · "button" · "frame"(금박 속줄과 모서리 장식) · "flat"

var base: StyleBoxFlat = StyleBoxFlat.new()
var kind: String = "auto"
var gloss: float = 1.0


func _draw(item: RID, rect: Rect2) -> void:
	base.draw(item, rect)
	var small: float = minf(rect.size.x, rect.size.y)
	if kind == "flat" or small < 22.0 or base.bg_color.a < 0.5:
		return
	var border: float = float(base.border_width_top)
	var inner: Rect2 = rect.grow(-border)
	var radius: float = maxf(0.0, float(base.corner_radius_top_left) - border)
	var points: PackedVector2Array = _rounded(inner, radius)
	var strength: float = gloss * (1.35 if kind == "button" else 1.0)
	## 아래로 갈수록 어두워지는 그늘(세로로 고르게 변하므로 어떤 삼각형 나눔에서도 정확하다).
	var shade: PackedColorArray = PackedColorArray()
	for point: Vector2 in points:
		shade.append(Color(0, 0, 0, 0.22 * strength * (point.y - inner.position.y) / inner.size.y))
	RenderingServer.canvas_item_add_polygon(item, points, shade)
	## 위쪽 절반의 광택.
	var half: float = inner.position.y + inner.size.y * 0.5
	var top: PackedVector2Array = PackedVector2Array()
	var light: PackedColorArray = PackedColorArray()
	for point: Vector2 in points:
		if point.y <= half:
			top.append(point)
	if top.size() >= 3:
		top.append(Vector2(inner.end.x, half))
		top.append(Vector2(inner.position.x, half))
		top = _sorted_ring(top, Vector2(inner.get_center().x, half))
		for point: Vector2 in top:
			light.append(Color(1, 1, 1, 0.085 * strength * (half - point.y) / (inner.size.y * 0.5)))
		RenderingServer.canvas_item_add_polygon(item, top, light)
	## 안쪽 위 빛줄 · 아래 그늘줄.
	var edge: Rect2 = inner.grow(-0.5)
	var arc: PackedVector2Array = _rounded(edge, maxf(0.0, radius - 0.5))
	var line_colors: PackedColorArray = PackedColorArray()
	for point: Vector2 in arc:
		var depth: float = (point.y - edge.position.y) / edge.size.y
		line_colors.append(Color(1, 1, 1, 0.16 * strength * (1.0 - depth)) if depth < 0.5 else Color(0, 0, 0, 0.3 * (depth - 0.5) * 2.0))
	arc.append(arc[0])
	line_colors.append(line_colors[0])
	RenderingServer.canvas_item_add_polyline(item, arc, line_colors, 1.0, true)
	if kind == "frame" and small >= 80.0:
		_frame(item, rect, border, radius)


## 금박 속줄과 네 모서리의 마름모 장식.
func _frame(item: RID, rect: Rect2, border: float, radius: float) -> void:
	var gold: Color = base.border_color
	var inset: Rect2 = rect.grow(-(border + 5.0))
	var ring: PackedVector2Array = _rounded(inset, maxf(0.0, radius - 5.0))
	ring.append(ring[0])
	RenderingServer.canvas_item_add_polyline(item, ring, PackedColorArray([Color(gold, 0.32)]), 1.0, true)
	for corner: Vector2 in [inset.position, Vector2(inset.end.x, inset.position.y), inset.end, Vector2(inset.position.x, inset.end.y)]:
		var center: Vector2 = corner + (rect.get_center() - corner).sign() * 1.0
		_diamond(item, center, 5.0, Color(gold.lightened(0.25), 0.95))
		_diamond(item, center, 2.0, Color(0.05, 0.04, 0.03, 0.9))


static func _diamond(item: RID, center: Vector2, reach: float, color: Color) -> void:
	var shape: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -reach), center + Vector2(reach, 0), center + Vector2(0, reach), center + Vector2(-reach, 0),
	])
	RenderingServer.canvas_item_add_polygon(item, shape, PackedColorArray([color]))


## 둥근 사각형의 테두리 점(시계 방향).
static func _rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	var out: PackedVector2Array = PackedVector2Array()
	if r < 1.0:
		out.append(rect.position)
		out.append(Vector2(rect.end.x, rect.position.y))
		out.append(rect.end)
		out.append(Vector2(rect.position.x, rect.end.y))
		return out
	var centers: Array[Vector2] = [
		Vector2(rect.end.x - r, rect.position.y + r), Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r), Vector2(rect.position.x + r, rect.position.y + r),
	]
	var steps: int = 6
	for c: int in range(4):
		for i: int in range(steps + 1):
			var angle: float = -PI / 2.0 + PI / 2.0 * c + PI / 2.0 * i / steps
			out.append(centers[c] + Vector2.from_angle(angle) * r)
	return out


static func _sorted_ring(points: PackedVector2Array, center: Vector2) -> PackedVector2Array:
	var list: Array = Array(points)
	list.sort_custom(func(a: Vector2, b: Vector2) -> bool: return (a - center).angle() < (b - center).angle())
	return PackedVector2Array(list)
