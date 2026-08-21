shader_type canvas_item;
render_mode blend_mix;

// 선택된 칸의 림라이트 펄스 — 타일 위에 얹는 풀렉트 ColorRect용.
// 둥근 사각형 SDF로 가장자리 거리(px)를 재고, 가장자리로 갈수록 밝아지는 골드 테두리가
// sin(TIME*4.2)로 숨 쉰다. rect_size는 코드에서 넣는다(canvas_item에 크기 내장값이 없다).

uniform vec2 rect_size = vec2(82.0, 74.0);
uniform float corner_radius = 7.0;
uniform float rim_width_px = 9.0;
uniform vec4 rim_color : source_color = vec4(0.941, 0.843, 0.49, 1.0);
uniform float pulse_speed = 4.2;
uniform float max_alpha : hint_range(0.0, 1.0) = 0.85;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.06;

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	vec2 b = rect_size * 0.5 - vec2(corner_radius);
	vec2 q = abs(p) - b;
	float sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	// sdf는 바깥이 +, 안쪽이 - . 안쪽 거리 0~rim_width 구간을 림으로 쓴다.
	float inside = 1.0 - smoothstep(-1.0, 0.5, sdf);
	float edge_t = clamp(1.0 + sdf / rim_width_px, 0.0, 1.0);
	// 목업의 smoothstep(.82,1,dist_to_edge)와 같은 감각 — 가장자리 2~3px가 가장 밝다.
	float rim = pow(edge_t, 2.2);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float a = (rim * (0.45 + 0.55 * pulse) * max_alpha + fill_alpha * pulse) * inside;
	COLOR = vec4(rim_color.rgb, a * rim_color.a);
}
