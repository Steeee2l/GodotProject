shader_type canvas_item;
render_mode blend_mix;

// 타이틀 색수차 깜빡임 — Label에 직접 붙인다. shift_px가 0이면 원본과 같고,
// 코드가 7~9초마다 60ms 동안 1로 올리면 R/B 채널이 ±1px 갈라진다.
// 글리프 아틀라스(TEXTURE) 좌표계에서 1px만 움직이므로 이웃 글리프 침범은 없다.

uniform float shift_px = 0.0;

void fragment() {
	vec2 off = vec2(TEXTURE_PIXEL_SIZE.x * shift_px, 0.0);
	vec4 c = texture(TEXTURE, UV);
	if (shift_px <= 0.0) {
		COLOR = c * COLOR;
	} else {
		float a_r = texture(TEXTURE, UV + off).a;
		float a_b = texture(TEXTURE, UV - off).a;
		float a = max(max(a_r, c.a), a_b);
		// 채널별 알파를 색으로 흉내 낸다(혼합은 한 알파만 받으므로).
		vec3 rgb = COLOR.rgb * vec3(a_r, c.a, a_b) / max(a, 0.001);
		COLOR = vec4(rgb, a * COLOR.a);
	}
}
