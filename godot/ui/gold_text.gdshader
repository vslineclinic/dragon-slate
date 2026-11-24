shader_type canvas_item;
// 글자를 금박처럼: 위는 밝은 금, 가운데 아래는 짙은 금, 맨 아래에 반사광. 그림자·테두리(어두운 색)는 그대로 둔다.
uniform float top_y = 0.0;
uniform float bottom_y = 100.0;
uniform vec4 light : source_color = vec4(1.0, 0.97, 0.82, 1.0);
uniform vec4 mid : source_color = vec4(0.96, 0.78, 0.38, 1.0);
uniform vec4 dark : source_color = vec4(0.66, 0.43, 0.13, 1.0);
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float t = clamp((local_y - top_y) / (bottom_y - top_y), 0.0, 1.0);
	vec3 gold = mix(light.rgb, mid.rgb, smoothstep(0.0, 0.5, t));
	gold = mix(gold, dark.rgb, smoothstep(0.5, 0.82, t));
	gold = mix(gold, mid.rgb, smoothstep(0.86, 1.0, t) * 0.7);
	COLOR.rgb *= gold;
}
