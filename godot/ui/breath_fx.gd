extends RefCounted
## 용의 숨결. 원소마다 모양이 다르다: 불 = 부채꼴 화염, 얼음 = 얼음 조각, 번개 = 꺾인 벼락,
## 독 = 포물선으로 날아가는 방울, 강철 = 초승달 칼날, 심연 = 검보라 광선.
## cast가 그림만 그린다. 맞는 순간의 처리는 부르는 쪽이 seconds 뒤에 한다.

const GameTheme = preload("res://godot/ui/theme.gd")
const GLOW_PATH: String = "res://assets/ui/glow.png"

static var _additive: CanvasItemMaterial
static var _glow: Texture2D


## power: 0 보통, 1 치명타, 2 궁극기(굵고 밝다).
static func cast(layer: Control, element: String, from: Vector2, to: Vector2, seconds: float, power: int) -> void:
	if from.distance_to(to) < 4.0:
		return
	var tint: Color = GameTheme.COLOR.get(element, Color.WHITE)
	_spark(layer, from, tint, 0.5 + 0.2 * power, seconds + 0.08)
	match element:
		"fire":
			_stream(layer, from, to, tint, seconds, power)
		"ice":
			_shards(layer, from, to, tint, seconds, power)
		"lightning":
			_bolt(layer, from, to, tint, seconds, power)
		"poison":
			_globs(layer, from, to, tint, seconds, power)
		"steel":
			_blades(layer, from, to, tint, seconds, power)
		_:
			_beam(layer, from, to, tint, seconds, power)


static func _add() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


## 부드러운 빛 덩어리 하나.
static func _dot(layer: Control, at: Vector2, tint: Color, scale: float) -> Sprite2D:
	if _glow == null and ResourceLoader.exists(GLOW_PATH):
		_glow = load(GLOW_PATH) as Texture2D
	var dot: Sprite2D = Sprite2D.new()
	dot.texture = _glow
	dot.material = _add()
	dot.modulate = tint
	dot.position = at
	dot.scale = Vector2(scale, scale) * 64.0 / maxf(1.0, float(_glow.get_width()) if _glow != null else 64.0)
	dot.z_index = 52
	layer.add_child(dot)
	return dot


## 입가에서 번쩍이는 빛.
static func _spark(layer: Control, at: Vector2, tint: Color, scale: float, seconds: float) -> void:
	var dot: Sprite2D = _dot(layer, at, tint.lightened(0.4), scale)
	var fade: Tween = dot.create_tween().set_parallel()
	fade.tween_property(dot, "scale", dot.scale * 1.8, seconds)
	fade.tween_property(dot, "modulate:a", 0.0, seconds)
	fade.chain().tween_callback(dot.queue_free)


static func _line(layer: Control, color: Color, width: float, additive: bool) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = width
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.z_index = 51
	if additive:
		line.material = _add()
	layer.add_child(line)
	return line


## 불: 입에서 좁게 나와 끝에서 넓어지는 화염. 앞으로 뻗었다가 사그라든다.
static func _stream(layer: Control, from: Vector2, to: Vector2, tint: Color, seconds: float, power: int) -> void:
	for pass_index: int in range(2):
		var core: bool = pass_index == 1
		var flame: Line2D = _line(layer, Color.WHITE, (30.0 + 14.0 * power) * (0.45 if core else 1.0), true)
		var shape: Curve = Curve.new()
		shape.add_point(Vector2(0.0, 0.22))
		shape.add_point(Vector2(0.7, 1.0))
		shape.add_point(Vector2(1.0, 0.75))
		flame.width_curve = shape
		var heat: Gradient = Gradient.new()
		heat.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		heat.colors = PackedColorArray([Color(1.0, 0.96, 0.7, 0.95), Color(1.0, 0.85, 0.5, 0.8), Color(1.0, 0.7, 0.3, 0.0)]) if core \
			else PackedColorArray([Color(tint.lightened(0.3), 0.85), Color(tint, 0.75), Color(tint.darkened(0.3), 0.0)])
		flame.gradient = heat
		flame.points = PackedVector2Array([from, from])
		var grow: Tween = flame.create_tween()
		grow.tween_method(func(t: float) -> void: flame.points = PackedVector2Array([from, from.lerp(to, t)]), 0.0, 1.0, seconds)
		grow.tween_property(flame, "modulate:a", 0.0, 0.14)
		grow.tween_callback(flame.queue_free)
	for i: int in range(3 + power * 2):
		var ember: Sprite2D = _dot(layer, from, Color(1.0, 0.8, 0.4), 0.16 + 0.05 * float(i % 3))
		var end: Vector2 = to + Vector2(randf_range(-14.0, 14.0), randf_range(-22.0, 10.0))
		var fly: Tween = ember.create_tween()
		fly.tween_interval(seconds * 0.15 * float(i))
		fly.tween_property(ember, "position", end, seconds)
		fly.parallel().tween_property(ember, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
		fly.tween_callback(ember.queue_free)


## 얼음: 길쭉한 얼음 조각 여러 개가 부채꼴로 꽂힌다.
static func _shards(layer: Control, from: Vector2, to: Vector2, tint: Color, seconds: float, power: int) -> void:
	var count: int = 3 + power
	for i: int in range(count):
		var spread: float = (float(i) - float(count - 1) / 2.0) * 13.0
		var end: Vector2 = to + Vector2(0, spread)
		var long: float = 24.0 + 8.0 * power
		var shard: Polygon2D = Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(long, 0), Vector2(0, 4.5), Vector2(-long * 0.45, 0), Vector2(0, -4.5)])
		shard.color = Color(0.92, 0.98, 1.0, 0.95)
		shard.vertex_colors = PackedColorArray([Color.WHITE, tint.lightened(0.5), Color(tint, 0.2), tint.lightened(0.2)])
		shard.position = from
		shard.rotation = (end - from).angle()
		shard.z_index = 52
		layer.add_child(shard)
		var fly: Tween = shard.create_tween()
		fly.tween_interval(seconds * 0.12 * float(i))
		fly.tween_property(shard, "position", end, seconds * 0.85).set_ease(Tween.EASE_IN)
		fly.tween_property(shard, "modulate:a", 0.0, 0.07)
		fly.tween_callback(shard.queue_free)
	var mist: Sprite2D = _dot(layer, to, tint.lightened(0.3), 0.3)
	mist.modulate.a = 0.0
	var puff: Tween = mist.create_tween()
	puff.tween_interval(seconds)
	puff.tween_property(mist, "modulate:a", 0.8, 0.03)
	puff.tween_property(mist, "scale", mist.scale * (2.2 + 0.6 * power), 0.2)
	puff.parallel().tween_property(mist, "modulate:a", 0.0, 0.2)
	puff.tween_callback(mist.queue_free)


static func _jagged(from: Vector2, to: Vector2, wobble: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array([from])
	var side: Vector2 = (to - from).orthogonal().normalized()
	for i: int in range(1, 6):
		points.append(from.lerp(to, float(i) / 6.0) + side * randf_range(-wobble, wobble))
	points.append(to)
	return points


## 번개: 꺾인 벼락이 한 번에 닿고 두 번 깜빡인다.
static func _bolt(layer: Control, from: Vector2, to: Vector2, tint: Color, seconds: float, power: int) -> void:
	var wobble: float = 13.0 + 5.0 * power
	var halo: Line2D = _line(layer, Color(tint, 0.55), 13.0 + 6.0 * power, true)
	var core: Line2D = _line(layer, Color(1.0, 1.0, 0.92), 3.5 + 1.5 * power, false)
	core.joint_mode = Line2D.LINE_JOINT_SHARP
	core.z_index = 53
	var redraw: Callable = func() -> void:
		var points: PackedVector2Array = _jagged(from, to, wobble)
		halo.points = points
		core.points = points
	redraw.call()
	var flick: Tween = core.create_tween()
	flick.tween_interval(maxf(0.02, seconds * 0.5))
	flick.tween_callback(redraw)
	flick.tween_interval(maxf(0.02, seconds * 0.5))
	flick.tween_callback(redraw)
	flick.tween_property(core, "modulate:a", 0.0, 0.1)
	flick.parallel().tween_property(halo, "modulate:a", 0.0, 0.1)
	flick.tween_callback(halo.queue_free)
	flick.tween_callback(core.queue_free)


## 독: 걸쭉한 방울이 포물선으로 날아가 퍼진다.
static func _globs(layer: Control, from: Vector2, to: Vector2, tint: Color, seconds: float, power: int) -> void:
	for i: int in range(3 + power):
		var glob: Sprite2D = _dot(layer, from, tint.lightened(0.15), 0.3 + 0.07 * float(i % 2) + 0.06 * power)
		glob.material = null
		var end: Vector2 = to + Vector2(randf_range(-12.0, 12.0), randf_range(-10.0, 10.0))
		var arc: float = 26.0 + 12.0 * float(i)
		var fly: Tween = glob.create_tween()
		fly.tween_interval(seconds * 0.1 * float(i))
		fly.tween_method(func(t: float) -> void: glob.position = from.lerp(end, t) + Vector2(0, -sin(t * PI) * arc), 0.0, 1.0, seconds)
		fly.tween_property(glob, "scale", glob.scale * 2.2, 0.16)
		fly.parallel().tween_property(glob, "modulate:a", 0.0, 0.16)
		fly.tween_callback(glob.queue_free)


## 강철: 초승달 칼날이 날아가 벤다.
static func _blades(layer: Control, from: Vector2, to: Vector2, tint: Color, seconds: float, power: int) -> void:
	for i: int in range(1 + power):
		var blade: Polygon2D = Polygon2D.new()
		var outline: PackedVector2Array = PackedVector2Array()
		var reach: float = 20.0 + 7.0 * power
		for step: int in range(9):
			var a: float = lerpf(-1.25, 1.25, float(step) / 8.0)
			outline.append(Vector2(cos(a), sin(a)) * reach)
		for step: int in range(9):
			var a: float = lerpf(1.25, -1.25, float(step) / 8.0)
			outline.append(Vector2(cos(a) * 0.62 - 0.1, sin(a)) * reach)
		blade.polygon = outline
		blade.color = Color(tint.lightened(0.6), 0.95)
		blade.position = from
		blade.rotation = (to - from).angle() + (0.5 if i % 2 == 1 else 0.0)
		blade.z_index = 52
		layer.add_child(blade)
		var fly: Tween = blade.create_tween()
		fly.tween_interval(seconds * 0.3 * float(i))
		fly.tween_property(blade, "position", to, seconds * 0.8).set_ease(Tween.EASE_IN)
		fly.parallel().tween_property(blade, "scale", Vector2(1.5, 1.5), seconds * 0.8)
		fly.tween_property(blade, "modulate:a", 0.0, 0.1)
		fly.parallel().tween_property(blade, "scale", Vector2(2.1, 2.1), 0.1)
		fly.tween_callback(blade.queue_free)


## 심연: 검은 심지를 감싼 보랏빛 광선이 닿았다가 가늘어진다.
static func _beam(layer: Control, from: Vector2, to: Vector2, tint: Color, seconds: float, power: int) -> void:
	var halo: Line2D = _line(layer, Color(tint.lightened(0.15), 0.7), 20.0 + 9.0 * power, true)
	var core: Line2D = _line(layer, Color(0.07, 0.02, 0.16, 0.95), 7.0 + 3.0 * power, false)
	core.z_index = 53
	halo.points = PackedVector2Array([from, from])
	core.points = PackedVector2Array([from, from])
	var grow: Tween = core.create_tween()
	grow.tween_method(func(t: float) -> void:
		var tip: Vector2 = from.lerp(to, t)
		halo.points = PackedVector2Array([from, tip])
		core.points = PackedVector2Array([from, tip]), 0.0, 1.0, seconds * 0.7)
	grow.tween_interval(seconds * 0.3)
	grow.tween_property(core, "width", 0.0, 0.14)
	grow.parallel().tween_property(halo, "width", 0.0, 0.14)
	grow.tween_callback(halo.queue_free)
	grow.tween_callback(core.queue_free)
