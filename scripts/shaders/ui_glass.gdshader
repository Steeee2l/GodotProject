shader_type canvas_item;
render_mode blend_mix;

// 모달 뒤 화면 유리(glass) 배경 — 가방·시설 모달 공용.
//  · 뒤 화면 블러(13탭 1패스, 폰 기준) + 어두운 틴트 + 가장자리 비네트
//  · CRT 스캔라인(3px 주기) + 저해상도 노이즈 텍스처 스크롤 그레인
//  · 열릴 때 한 번 훑는 연녹색 스캔 스윕(sweep_y, 코드에서 트윈)
// 렌더러는 gl_compatibility(웹/모바일) — SCREEN_TEXTURE 밉맵 없이 수동 탭으로만 흐린다.
// 셰이더 TIME은 일시정지와 무관하므로 트리를 멈추는 모달에서도 그대로 쓴다.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform float blur_px : hint_range(0.0, 12.0) = 5.0;
uniform vec4 tint : source_color = vec4(0.006, 0.009, 0.012, 0.72);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float scanline_alpha : hint_range(0.0, 1.0) = 0.18;
uniform float scanline_period_px = 3.0;
uniform float grain_alpha : hint_range(0.0, 1.0) = 0.05;
uniform float noise_tex_size = 128.0;
uniform float sweep_y = -1.0;
uniform vec4 sweep_color : source_color = vec4(0.667, 0.886, 0.745, 0.16);
uniform float sweep_half_height = 0.045;

// 13탭 디스크(중심 1 + 안쪽 링 4 + 바깥 링 8). 1패스로 끝낸다.
const vec2 TAPS[13] = {
	vec2(0.0, 0.0),
	vec2(0.5, 0.0), vec2(-0.5, 0.0), vec2(0.0, 0.5), vec2(0.0, -0.5),
	vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.707, 0.707), vec2(-0.707, 0.707), vec2(0.707, -0.707), vec2(-0.707, -0.707)
};
const float TAP_WEIGHTS[13] = {
	0.16,
	0.10, 0.10, 0.10, 0.10,
	0.055, 0.055, 0.055, 0.055,
	0.055, 0.055, 0.055, 0.055
};

float hash1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 step_uv = SCREEN_PIXEL_SIZE * blur_px;
	vec3 blurred = vec3(0.0);
	for (int i = 0; i < 13; i++) {
		blurred += texture(screen_tex, SCREEN_UV + TAPS[i] * step_uv).rgb * TAP_WEIGHTS[i];
	}
	// 어두운 틴트: 흐린 화면 위에 잉크를 덮는다.
	vec3 col = mix(blurred, tint.rgb, tint.a);

	// 비네트: 중앙은 그대로, 가장자리로 갈수록 더 어둡게.
	float d = distance(UV, vec2(0.5));
	col *= 1.0 - smoothstep(0.34, 0.92, d) * vignette_strength;

	// 스캔라인: 화면 픽셀 기준 3px 주기, 그중 한 줄을 살짝 죽인다.
	float line_pos = fract(SCREEN_UV.y / (SCREEN_PIXEL_SIZE.y * scanline_period_px));
	col *= 1.0 - scanline_alpha * step(line_pos, 1.0 / scanline_period_px);

	// 그레인: 128x128 노이즈 텍스처를 화면 픽셀에 1:1로 깔고 24Hz로 튄다.
	float t = floor(TIME * 24.0);
	vec2 jitter = vec2(hash1(t + 1.0), hash1(t + 7.0));
	vec2 noise_uv = SCREEN_UV / (SCREEN_PIXEL_SIZE * noise_tex_size) + jitter;
	float grain = texture(noise_tex, noise_uv).r - 0.5;
	col += grain * grain_alpha * 2.0;

	// 스캔 스윕: 연녹색 띠가 위→아래로 한 번 지나간다(sweep_y는 코드가 움직인다).
	float band = 1.0 - smoothstep(0.0, sweep_half_height, abs(UV.y - sweep_y));
	col += sweep_color.rgb * sweep_color.a * band;

	COLOR = vec4(col, 1.0);
}
