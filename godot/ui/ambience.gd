extends RefCounted
## 화면에 떠다니는 작은 빛(불티 · 눈 · 꽃가루 · 심연의 먼지)과 가장자리 어둠.

const GLOW_PATH: String = "res://assets/ui/glow.png"
const VIGNETTE_PATH: String = "res://assets/ui/vignette.png"
const PRESETS: Dictionary = {
	"embers": {"from": "bottom", "amount": 70, "life": 9.0, "dir": Vector2(0.15, -1), "spread": 28.0, "speed": [18.0, 64.0], "gravity": Vector2(0, -10), "scale": [0.05, 0.17], "color": Color("#ffb060")},
	"snow": {"from": "top", "amount": 90, "life": 11.0, "dir": Vector2(0.25, 1), "spread": 18.0, "speed": [22.0, 60.0], "gravity": Vector2(4, 6), "scale": [0.04, 0.11], "color": Color("#eaf7ff")},
	"pollen": {"from": "all", "amount": 46, "life": 10.0, "dir": Vector2(1, -0.25), "spread": 60.0, "speed": [4.0, 16.0], "gravity": Vector2(0, -1), "scale": [0.04, 0.1], "color": Color("#fff2b8")},
	"motes": {"from": "all", "amount": 64, "life": 9.0, "dir": Vector2(0, -1), "spread": 180.0, "speed": [3.0, 14.0], "gravity": Vector2(0, -2), "scale": [0.05, 0.15], "color": Color("#c9b3ff")},
}


## rect 안에 preset 입자를 뿌린다. 돌려주는 노드를 지우면 함께 사라진다.
static func particles(parent: Control, rect: Rect2, preset: String) -> Control:
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	holder.position = rect.position
	holder.size = rect.size
	parent.add_child(holder)
	var cfg: Dictionary = PRESETS[preset]
	var dust: CPUParticles2D = CPUParticles2D.new()
	dust.texture = load(GLOW_PATH) as Texture2D
	dust.amount = int(cfg["amount"])
	dust.lifetime = float(cfg["life"])
	dust.preprocess = float(cfg["life"])
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	match cfg["from"]:
		"bottom":
			dust.position = Vector2(rect.size.x / 2.0, rect.size.y + 12.0)
			dust.emission_rect_extents = Vector2(rect.size.x / 2.0, 8.0)
		"top":
			dust.position = Vector2(rect.size.x / 2.0, -12.0)
			dust.emission_rect_extents = Vector2(rect.size.x / 2.0 + 80.0, 8.0)
		_:
			dust.position = rect.size / 2.0
			dust.emission_rect_extents = rect.size / 2.0
	dust.direction = (cfg["dir"] as Vector2).normalized()
	dust.spread = float(cfg["spread"])
	dust.gravity = cfg["gravity"]
	dust.initial_velocity_min = float(cfg["speed"][0])
	dust.initial_velocity_max = float(cfg["speed"][1])
	dust.scale_amount_min = float(cfg["scale"][0])
	dust.scale_amount_max = float(cfg["scale"][1])
	var tint: Color = cfg["color"]
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.18, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(tint, 0.0), Color(tint, 0.9), Color(tint, 0.6), Color(tint, 0.0)])
	dust.color_ramp = fade
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	dust.material = additive
	holder.add_child(dust)
	return holder


## 가장자리를 어둡게 눌러 가운데로 눈이 가게 한다.
static func vignette(parent: Control, rect: Rect2, strength: float = 0.7) -> TextureRect:
	var shade: TextureRect = TextureRect.new()
	shade.texture = load(VIGNETTE_PATH) as Texture2D
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.modulate = Color(0, 0, 0, strength)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.position = rect.position
	shade.size = rect.size
	parent.add_child(shade)
	return shade
