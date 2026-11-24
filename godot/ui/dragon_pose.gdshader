shader_type canvas_item;
// 한 장짜리 용 그림을 살아 있게 만든다: 머리 내밀기(thrust) · 고개 젖히기(rear) · 날개 펴기(wings) · 몸 기울이기(lean) · 숨쉬기(idle) · 걸음(stride).
// 원본 그림은 왼쪽을 본다(머리는 왼쪽 위, 날개는 위쪽). mirror가 1이면 좌우를 뒤집어 오른쪽을 보게 한다.
// 그림 밖으로 머리·날개가 나갈 자리를 두려고, 노드는 그림보다 pad배 크게 놓는다.
uniform float pad = 1.3;
uniform float mirror = 0.0;
uniform float thrust = 0.0;
uniform float rear = 0.0;
uniform float wings = 0.0;
uniform float lean = 0.0;
uniform float idle = 1.0;
uniform float stride = 0.0;
uniform float phase = 0.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = (UV - 0.5) * pad + 0.5;
	if (mirror > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	float breath = sin(TIME * 2.2 + phase) * idle;
	float step_wave = sin(TIME * 12.0 + phase) * stride;

	// 몸: 발을 축으로 위쪽이 앞(왼쪽)으로 기울고, 숨 쉴 때와 걸을 때 위아래로 움직인다.
	float up = clamp(0.94 - uv.y, 0.0, 1.0);
	uv.x += (lean * 0.11 + step_wave * 0.012) * up;
	uv.y += (breath * 0.010 + abs(step_wave) * 0.022) * up;

	// 머리: 왼쪽 위 덩어리가 앞으로 뻗거나(thrust) 뒤로 젖혀진다(rear). 목은 부드럽게 늘어난다.
	vec2 move = thrust * vec2(-0.13, 0.035) + rear * vec2(0.055, -0.06) + vec2(0.0, breath * 0.008);
	vec2 head = vec2(0.27, 0.30) + move * 0.5;
	float head_mask = 1.0 - smoothstep(0.10, 0.44, distance(uv, head));
	uv -= move * head_mask;

	// 날개: 머리를 뺀 위쪽이 몸통 가운데에서 바깥으로 벌어진다.
	float wing_mask = (1.0 - smoothstep(0.22, 0.64, uv.y)) * (1.0 - head_mask);
	float spread = (wings * 0.27 + breath * 0.018 + abs(step_wave) * 0.03) * wing_mask;
	vec2 root = vec2(0.55, 0.52);
	uv = root + (uv - root) / (1.0 + spread);

	vec4 color = texture(TEXTURE, uv);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		color.a = 0.0;
	}
	COLOR = color * tint;
}
