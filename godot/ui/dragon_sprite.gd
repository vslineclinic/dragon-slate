extends Control
## 전장의 용 한 마리 그림. 한 장짜리 그림을 셰이더(dragon_pose)로 움직여 숨 쉬고, 걷고, 머리를 내밀고, 날개를 편다.

const POSE: Shader = preload("res://godot/ui/dragon_pose.gdshader")
const PAD: float = 1.3
## 원본 그림(왼쪽을 봄)에서 입이 있는 자리(0~1).
const MOUTH: Vector2 = Vector2(0.2, 0.37)

var _material: ShaderMaterial
var _image: TextureRect
var _home: Vector2
var _mirror: bool = false
var _act: Tween
var _walk: Tween
var _launch_at: int = 0
var _busy_until: int = 0


## rect 자리에 용 그림을 놓는다. 그림이 없으면 null.
static func make(parent: Control, rect: Rect2, id: String, mirror: bool) -> Control:
	var path: String = "res://assets/dragons/%s.png" % id
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var sprite: Control = new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.position = rect.position
	sprite.size = rect.size
	parent.add_child(sprite)
	sprite._build(load(path) as Texture2D, mirror, float(id.hash() % 628) / 100.0)
	return sprite


func _build(texture: Texture2D, mirror: bool, phase: float) -> void:
	_mirror = mirror
	_material = ShaderMaterial.new()
	_material.shader = POSE
	_material.set_shader_parameter("pad", PAD)
	_material.set_shader_parameter("mirror", 1.0 if mirror else 0.0)
	_material.set_shader_parameter("phase", phase)
	## 트윈이 시작값을 읽을 수 있게 처음 값을 넣어 둔다.
	for parameter: String in ["thrust", "rear", "wings", "lean", "stride"]:
		_material.set_shader_parameter(parameter, 0.0)
	var image: TextureRect = TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.material = _material
	image.size = size * PAD
	image.position = -size * (PAD - 1.0) / 2.0
	image.pivot_offset = Vector2(image.size.x / 2.0, image.size.y * 0.82)
	add_child(image)
	_image = image
	_home = image.position


## 입의 위치(이 그림의 한가운데에서 잰 값). 머리를 내민 만큼 앞으로 나간다.
func mouth() -> Vector2:
	var x: float = (MOUTH.x - 0.5 - 0.1) * size.x
	return Vector2(-x if _mirror else x, (MOUTH.y - 0.5) * size.y)


## 걷는 동안(seconds) 발을 구르고 날개를 친다.
func walk(seconds: float) -> void:
	if _walk != null:
		_walk.kill()
	_walk = create_tween()
	_walk.tween_property(_material, "shader_parameter/stride", 1.0, 0.08)
	_walk.tween_interval(maxf(0.01, seconds))
	_walk.tween_property(_material, "shader_parameter/stride", 0.0, 0.2)


## 공격 동작. 고개를 젖혔다가 머리를 내민다. heavy(치명타·궁극기)면 날개를 활짝 펴고 몸을 키운다.
## 숨결이 입을 떠나기까지 남은 시간(초)을 돌려준다. 이미 치는 중이면 다시 시작하지 않는다.
func strike(speed: float, heavy: bool) -> float:
	var now: int = Time.get_ticks_msec()
	if now < _busy_until:
		return maxf(0.0, float(_launch_at - now) / 1000.0)
	var windup: float = (0.15 if heavy else 0.07) / speed
	var snap: float = 0.05 / speed
	var hold: float = (0.14 if heavy else 0.05) / speed
	var back: float = (0.28 if heavy else 0.18) / speed
	_launch_at = now + int((windup + snap) * 1000.0)
	_busy_until = now + int((windup + snap + hold) * 1000.0)
	if _act != null:
		_act.kill()
	var forward: float = 1.0 if _mirror else -1.0
	_act = create_tween()
	_act.set_parallel()
	## 준비: 고개를 젖히고 몸을 뒤로.
	_tween("rear", 1.0, windup)
	_tween("lean", -0.45 if heavy else -0.3, windup)
	_tween("wings", 1.0 if heavy else 0.25, windup)
	_act.tween_property(_image, "scale", Vector2(1.16, 1.16) if heavy else Vector2(1.03, 1.03), windup)
	_act.tween_property(_image, "position:x", _home.x - 5.0 * forward, windup)
	_act.chain()
	## 내지르기: 머리가 앞으로.
	_tween("thrust", 1.0, snap)
	_tween("rear", 0.0, snap)
	_tween("lean", 0.9 if heavy else 0.65, snap)
	_act.tween_property(_image, "position:x", _home.x + (12.0 if heavy else 7.0) * forward, snap)
	_act.chain().tween_interval(hold)
	_act.chain()
	## 돌아오기.
	_tween("thrust", 0.0, back)
	_tween("lean", 0.0, back)
	_tween("wings", 0.0, back)
	_act.tween_property(_image, "scale", Vector2.ONE, back)
	_act.tween_property(_image, "position:x", _home.x, back)
	return windup + snap


func _tween(parameter: String, value: float, seconds: float) -> void:
	_act.tween_property(_material, "shader_parameter/" + parameter, value, seconds)
