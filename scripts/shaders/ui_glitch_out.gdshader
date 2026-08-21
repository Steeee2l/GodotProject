shader_type canvas_item;
render_mode unshaded, blend_mix;

// 버리기 글리치 디졸브 — 사라질 타일을 CanvasGroup으로 감싸고 그 그룹의 머티리얼로 쓴다.
// CanvasGroup은 자식들을 백버퍼(화면 텍스처)의 자기 영역에 먼저 그리고, 그룹 사각형을 그리는
// 순간 이 셰이더가 SCREEN_UV로 그 결과를 읽어 온다(기본 CanvasGroup 셰이더와 같은 구조).
// 가로 슬라이스마다 좌우로 찢고(progress↑) 슬라이스를 무작위 순서로 잘라 낸다(알파 컷).
// fit_margin/clear_margin(26px) 안에서만 읽으므로 찢긴 조각이 타일 밖으로 나가도 안전하다.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float slice_px = 5.0;
uniform float max_shift_px = 22.0;
uniform vec4 tear_tint : source_color = vec4(0.667, 0.886, 0.745, 0.35);

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// 화면 픽셀 행 기준 슬라이스 — 스타일박스·아이콘·글자가 같은 좌표계로 찢긴다.
	float slice = floor(FRAGCOORD.y / slice_px);
	// 12단계로 양자화된 시간 — 찢김이 '툭툭' 바뀌어야 글리치답다.
	float frame = floor(progress * 12.0);
	float n = hash2(vec2(slice, frame));
	float shift_px = (n - 0.5) * 2.0 * max_shift_px * progress;
	vec2 suv = SCREEN_UV - vec2(shift_px * SCREEN_PIXEL_SIZE.x, 0.0);
	vec4 c = textureLod(screen_texture, suv, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	// 슬라이스마다 고유 문턱 — progress가 문턱을 넘으면 그 줄은 사라진다.
	float cut_threshold = hash2(vec2(slice, 99.0)) * 0.8 + 0.12;
	float keep = step(progress, cut_threshold);
	// 찢긴 줄은 살짝 연녹색으로 물든다(단말기 잔상).
	c.rgb = mix(c.rgb, tear_tint.rgb, tear_tint.a * abs(n - 0.5) * 2.0 * progress);
	// 마지막 15%는 남은 줄도 전체 페이드.
	float fade = 1.0 - smoothstep(0.85, 1.0, progress);
	COLOR *= vec4(c.rgb, c.a * keep * fade);
}
