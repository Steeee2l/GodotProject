shader_type canvas_item;
render_mode unshaded, blend_mix;

// 돌파 성공 글리치 펄스 — 카드 위에 얹는 ColorRect(FULL_RECT)의 머티리얼로 쓴다.
// 바로 아래에 그려진 카드(뒤 화면)를 SCREEN_UV로 읽어 가로 슬라이스마다 좌우로 잠깐 찢어
// 그대로 다시 그린다. ui_glitch_out과 달리 알파 컷·페이드가 없다 — 카드는 사라지지 않고
// progress가 1이 되면 제자리로 돌아온다(오버레이는 호출자가 떼어 낸다).
// 세기 곡선: 시작에 가장 세고(1−progress)² 로 빠르게 잦아든다.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float slice_px = 5.0;
uniform float max_shift_px = 18.0;
uniform vec4 tear_tint : source_color = vec4(0.941, 0.843, 0.49, 0.3);

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float slice = floor(FRAGCOORD.y / slice_px);
	// 10단계로 양자화된 시간 — 찢김이 '툭툭' 바뀌어야 글리치답다.
	float frame = floor(progress * 10.0);
	float strength = (1.0 - progress) * (1.0 - progress);
	float n = hash2(vec2(slice, frame));
	// 슬라이스의 절반만 찢는다(n 문턱) — 전부 밀리면 글리치가 아니라 흔들림으로 읽힌다.
	float active = step(0.45, hash2(vec2(slice, frame + 37.0)));
	float shift_px = (n - 0.5) * 2.0 * max_shift_px * strength * active;
	vec2 suv = SCREEN_UV - vec2(shift_px * SCREEN_PIXEL_SIZE.x, 0.0);
	vec4 c = textureLod(screen_texture, suv, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	// 찢긴 줄은 살짝 금빛으로 물든다(돌파의 색).
	c.rgb = mix(c.rgb, tear_tint.rgb, tear_tint.a * abs(n - 0.5) * 2.0 * strength * active);
	COLOR = vec4(c.rgb, c.a) * COLOR;
}
