class_name WeaponSystem
extends RefCounted

const DEFAULT_WEAPON_ID := "ak47"

const WEAPONS := {
	"m1911": {
		"display_name": "M1911 \"솜방망이\"",
		"category": "권총",
		"ammo_type": "45_acp",
		"magazine_id": "m1911_7rnd",
		"default_ammo_id": "45_fmj",
		"magazine_size": 7,
		"damage": 34,
		"pellet_count": 1,
		"fire_interval": 0.22,
		"automatic": false,
		"base_spread_deg": 1.3,
		"max_spread_deg": 8.0,
		"spread_per_shot_deg": 1.1,
		"spread_recovery_deg": 7.5,
		"moving_spread_multiplier": 1.35,
		"injured_spread_multiplier": 1.3,
		"loaf_spread_multiplier": 0.85,
		"recoil_kick": 0.22,
		"loaf_recoil_multiplier": 0.75,
		"player_knockback": 0.04,
		"penetration_count": 0,
		"durability_loss": 0.045,
		"reload_time": 1.35,
		"sound_radius": 36.0,
		"mouth_carry_fire": true,
	},
	"mp5": {
		"display_name": "MP5 \"하악이\"",
		"category": "기관단총",
		"ammo_type": "9mm",
		"magazine_id": "mp5_30rnd",
		"default_ammo_id": "9mm_fmj",
		"magazine_size": 30,
		"damage": 18,
		"pellet_count": 1,
		"fire_interval": 0.075,
		"automatic": true,
		"base_spread_deg": 1.8,
		"max_spread_deg": 10.0,
		"spread_per_shot_deg": 0.42,
		"spread_recovery_deg": 9.0,
		"moving_spread_multiplier": 1.15,
		"injured_spread_multiplier": 1.3,
		"loaf_spread_multiplier": 0.72,
		"recoil_kick": 0.16,
		"loaf_recoil_multiplier": 0.65,
		"player_knockback": 0.025,
		"penetration_count": 0,
		"durability_loss": 0.038,
		"reload_time": 1.7,
		"sound_radius": 43.0,
		"roll_ready": true,
	},
	"ak47": {
		"display_name": "AK-47 \"캣라시니코프\"",
		"category": "소총",
		"ammo_type": "762x39",
		"magazine_id": "ak_30rnd",
		"default_ammo_id": "762_fmj",
		"magazine_size": 30,
		# 30으로 상향(24였다). MP5가 DPS·반동·명중·재장전 전부에서 앞서 시작 무기가
		# 하위호환이었다. AK는 "적은 발수, 묵직한 한 방 + 사거리/관통" 정체성으로 간다.
		# 존1 중심 명중 기준 4발 → 3발 킬.
		"damage": 30,
		"pellet_count": 1,
		"fire_interval": 0.12,
		"automatic": true,
		"base_spread_deg": 2.4,
		"max_spread_deg": 14.0,
		"spread_per_shot_deg": 1.25,
		"spread_recovery_deg": 5.2,
		"moving_spread_multiplier": 1.8,
		"injured_spread_multiplier": 1.4,
		"loaf_spread_multiplier": 0.45,
		"recoil_kick": 0.72,
		"loaf_recoil_multiplier": 0.28,
		"player_knockback": 0.18,
		"penetration_count": 1,
		"durability_loss": 0.065,
		"reload_time": 2.15,
		"sound_radius": 52.0,
	},
	"double_barrel": {
		"display_name": "Double-Barrel \"참치 헌터\"",
		"category": "산탄총",
		"ammo_type": "12g",
		"magazine_id": "double_barrel_chamber",
		"default_ammo_id": "12g_buckshot",
		"magazine_size": 2,
		"damage": 18,
		"pellet_count": 8,
		"fire_interval": 0.58,
		"automatic": false,
		"base_spread_deg": 7.0,
		"max_spread_deg": 18.0,
		"spread_per_shot_deg": 4.5,
		"spread_recovery_deg": 4.0,
		"moving_spread_multiplier": 1.5,
		"injured_spread_multiplier": 1.45,
		"loaf_spread_multiplier": 0.7,
		"recoil_kick": 1.4,
		"loaf_recoil_multiplier": 0.55,
		"player_knockback": 0.85,
		"penetration_count": 0,
		"durability_loss": 0.12,
		# 2.8 → 3.3. 방아쇠 한 번이 약실 두 발을 한꺼번에 비우게 되면서(FIRE_FEEL
		# shots_per_trigger=2) 옛 "0.58초 텀 + 2.8초 장전" 3.38초 주기가 2.8초로
		# 짧아졌다. 탄창당 화력은 그대로 두고 주기만 되돌린 값이다(3.3s ≒ 3.38s).
		# 이 3.3초가 더블배럴의 대가다 — 쏘고 나면 온전히 무방비다.
		"reload_time": 3.3,
		"sound_radius": 58.0,
	},
	# ── 무기 사다리(2·3단) ─────────────────────────────────────────
	# 시작 무기 AK가 최강 소총이라 "강화해서 쓰다가 다음 총으로 갈아타는" 흐름이
	# 없었다. 같은 구경(7.62x39 / 12g)을 공유하는 상위 기종을 두고, 강화는
	# WEAPON_FAMILY_LADDER를 따라 60% 이관된다(GameState.transfer_weapon_enhancement).
	# 새 구경은 만들지 않는다 — 탄약 수급선이 갈라지면 갈아타는 비용이 벽이 된다.
	"akm": {
		# 2단(을지로·용산). AK보다 묵직하고 조금 더 안정된 개조 소총.
		"display_name": "AKM \"개조형\"",
		"category": "소총",
		"ammo_type": "762x39",
		"magazine_id": "akm_40rnd",
		"default_ammo_id": "762_fmj",
		"magazine_size": 40,
		"damage": 38,
		"pellet_count": 1,
		"fire_interval": 0.115,
		"automatic": true,
		"base_spread_deg": 2.1,
		"max_spread_deg": 13.0,
		"spread_per_shot_deg": 1.15,
		"spread_recovery_deg": 5.6,
		"moving_spread_multiplier": 1.7,
		"injured_spread_multiplier": 1.4,
		"loaf_spread_multiplier": 0.45,
		"recoil_kick": 0.62,
		"loaf_recoil_multiplier": 0.28,
		"player_knockback": 0.17,
		"penetration_count": 1,
		"durability_loss": 0.06,
		"reload_time": 2.3,
		"sound_radius": 54.0,
	},
	"k2": {
		# 3단(남산). 용산 통제 키가 있어야 작업대에서 만든다 — 적 풀·상자에 없다.
		"display_name": "K2 \"전투소총\"",
		"category": "소총",
		"ammo_type": "762x39",
		"magazine_id": "k2_30rnd",
		"default_ammo_id": "762_fmj",
		"magazine_size": 30,
		"damage": 48,
		"pellet_count": 1,
		"fire_interval": 0.11,
		"automatic": true,
		"base_spread_deg": 1.7,
		"max_spread_deg": 12.0,
		"spread_per_shot_deg": 1.05,
		"spread_recovery_deg": 6.0,
		"moving_spread_multiplier": 1.6,
		"injured_spread_multiplier": 1.35,
		"loaf_spread_multiplier": 0.45,
		"recoil_kick": 0.5,
		"loaf_recoil_multiplier": 0.28,
		"player_knockback": 0.15,
		"penetration_count": 2,
		"durability_loss": 0.055,
		"reload_time": 2.0,
		"sound_radius": 54.0,
	},
	"pump_shotgun": {
		# 2단 산탄총. 펠릿당 피해는 더블배럴보다 낮지만(~0.85) 6발 튜브 탄창으로
		# "두 발 쏘고 무방비"가 사라진다. 장전은 탄 하나씩이지만 단순화해 전체 2.6초.
		"display_name": "펌프 산탄총 \"하울러\"",
		"category": "산탄총",
		"ammo_type": "12g",
		"magazine_id": "pump_6rnd",
		"default_ammo_id": "12g_buckshot",
		"magazine_size": 6,
		"damage": 15,
		"pellet_count": 8,
		"fire_interval": 0.55,
		"automatic": false,
		"base_spread_deg": 6.5,
		"max_spread_deg": 17.0,
		"spread_per_shot_deg": 4.0,
		"spread_recovery_deg": 4.2,
		"moving_spread_multiplier": 1.5,
		"injured_spread_multiplier": 1.45,
		"loaf_spread_multiplier": 0.7,
		"recoil_kick": 1.2,
		"loaf_recoil_multiplier": 0.55,
		"player_knockback": 0.7,
		"penetration_count": 0,
		"durability_loss": 0.1,
		"reload_time": 2.6,
		"sound_radius": 58.0,
	},
}

# ══════════════════════════════════════════════════════════════════
# 무기 개성 — 투사체 프로필 · 발사 손맛
# ══════════════════════════════════════════════════════════════════
# 예전에는 일곱 자루가 전부 같은 예광탄을 같은 속도로 뱉고, 같은 셰이크로
# 화면을 흔들었다. 차이가 숫자(피해·연사)뿐이라 "상황에 따라 다른 총을
# 들고 나갈" 이유가 없었다. 여기 두 표가 그 차이를 만든다 —
# 값은 반드시 이 파일 한 곳에만 산다(bullet_projectile / weapon_combat는
# get_projectile_profile / get_fire_feel로 읽기만 한다).

# ── 투사체 프로필 ─────────────────────────────────────────────
# width/length는 '심지'(가장 안쪽 발광층) 치수다. 바깥 두 겹은
# bullet_projectile이 고정 비율로 부풀린다 — 기본값은 옛 예광탄과 완전히
# 같은 모양이라, 프로필을 주지 않는 탄(적·동행·포탑)은 지금 그대로 보인다.
const DEFAULT_PROJECTILE_PROFILE := {
	"speed": 46.0,
	"lifetime": 1.15,
	"width": 0.045,
	"length": 0.54,
	# 심지 → 중간 → 바깥 순서로 밝기가 떨어진다.
	"core_color": "#fff7b0",
	"mid_color": "#ffc52e",
	"outer_color": "#ff9a12",
	"trail_color": "#ffc62e",
	"trail_amount": 22,
	"trail_lifetime": 0.16,
	"trail_scale": 1.0,
	"glow_energy": 1.0,
}

const PROJECTILE_PROFILES := {
	# 권총 — 짧고 선명한 백금색 점. 느리지도 빠르지도 않게, 한 발이 또렷하게 보인다.
	"m1911": {
		"speed": 52.0, "lifetime": 0.72, "width": 0.040, "length": 0.40,
		"core_color": "#ffffff", "mid_color": "#ffe9a8", "outer_color": "#ffb43a",
		"trail_color": "#ffd98a", "trail_amount": 10, "trail_lifetime": 0.10,
		"trail_scale": 0.8, "glow_energy": 1.15,
	},
	# 기관단총 — 작고 잦은 옅은 탄. 하나하나는 가볍지만 초당 열세 개가 흐른다.
	# 트레일을 얇게 깎은 건 연출이자 성능이다(13발/초 × 22입자는 화면을 덮는다).
	"mp5": {
		"speed": 56.0, "lifetime": 0.60, "width": 0.028, "length": 0.34,
		"core_color": "#f4fffb", "mid_color": "#b6ffd8", "outer_color": "#4fe0a0",
		"trail_color": "#8ff0c4", "trail_amount": 7, "trail_lifetime": 0.075,
		"trail_scale": 0.65, "glow_energy": 0.9,
	},
	# AK — 길고 묵직한 호박색 예광. 이 총의 정체성은 "적은 발수, 큰 한 방"이라
	# 탄 자체가 느리고 굵어서 날아가는 게 보여야 한다.
	"ak47": {
		"speed": 44.0, "lifetime": 1.15, "width": 0.062, "length": 0.95,
		"core_color": "#fff3c0", "mid_color": "#ffab20", "outer_color": "#ff7a08",
		"trail_color": "#ffa61e", "trail_amount": 26, "trail_lifetime": 0.19,
		"trail_scale": 1.25, "glow_energy": 1.2,
	},
	# AKM — 같은 7.62지만 한 뼘 더 길고 더 붉다. 사다리를 오른 게 눈에 보여야 한다.
	"akm": {
		"speed": 44.0, "lifetime": 1.15, "width": 0.068, "length": 1.05,
		"core_color": "#fff0b0", "mid_color": "#ff9412", "outer_color": "#ff5a04",
		"trail_color": "#ff8c14", "trail_amount": 28, "trail_lifetime": 0.20,
		"trail_scale": 1.3, "glow_energy": 1.28,
	},
	# K2 — 가늘고 아주 빠른 백청색. 쏘면 이미 닿아 있다. 소총 사다리 안에서도
	# 색이 완전히 갈려야 "다른 총"으로 읽힌다.
	"k2": {
		"speed": 68.0, "lifetime": 0.85, "width": 0.034, "length": 1.15,
		"core_color": "#ffffff", "mid_color": "#9fe4ff", "outer_color": "#2f9dff",
		"trail_color": "#7fd4ff", "trail_amount": 16, "trail_lifetime": 0.12,
		"trail_scale": 0.85, "glow_energy": 1.45,
	},
	# 더블배럴 — 짧고 굵은 주황 덩어리. 예광이 아니라 '날아가는 쇳덩이'다.
	# 유효 사거리 6.5m / 최대 15m라 수명 0.5초면 충분하다.
	"double_barrel": {
		"speed": 36.0, "lifetime": 0.50, "width": 0.115, "length": 0.30,
		"core_color": "#fff2d0", "mid_color": "#ff8a2a", "outer_color": "#ff3d05",
		"trail_color": "#ff6a1e", "trail_amount": 9, "trail_lifetime": 0.09,
		"trail_scale": 1.1, "glow_energy": 1.3,
	},
	# 펌프 — 같은 12게이지지만 덩어리가 조금 작고 밝다(한 발씩 여섯 번의 리듬).
	"pump_shotgun": {
		"speed": 38.0, "lifetime": 0.50, "width": 0.092, "length": 0.28,
		"core_color": "#fff6de", "mid_color": "#ffa347", "outer_color": "#ff5c14",
		"trail_color": "#ff8330", "trail_amount": 8, "trail_lifetime": 0.085,
		"trail_scale": 1.0, "glow_energy": 1.15,
	},
}

# ── 발사 손맛 ─────────────────────────────────────────────────
# 화면 셰이크(진폭은 월드 단위 — 보간 뒤에 얹는다) · 화면 펀치 · 머즐 플래시 ·
# 연기/탄피 · 한 번의 방아쇠에 나가는 발수 · 무기 무게가 걸음에 주는 계수.
const DEFAULT_FIRE_FEEL := {
	"shots_per_trigger": 1,
	# 방아쇠 한 번에 여러 발이 나갈 때, 총열별로 벌려 주는 각(부채꼴로 읽히게).
	"volley_spread_bias_deg": 0.0,
	"camera_shake": 0.10,
	"camera_shake_time": 0.10,
	"camera_punch": 0.11,
	"muzzle_flash_scale": 1.0,
	"muzzle_flash_color": "#ffb347",
	"muzzle_flash_energy": 3.0,
	"muzzle_spark_count": 6,
	"smoke_puffs": 2,
	"shell_color": "#d9a441",
	# 총의 무게가 걸음을 붙잡는 계수. 굼뜨되 답답하면 안 된다 — 하한 0.9.
	"move_speed_multiplier": 1.0,
	# 사격 뒤 기계 동작 소리(펌프 슬라이드). 초 단위 지연, 0이면 없음.
	"action_sound_delay": 0.0,
	"action_sound_id": "",
}

const FIRE_FEEL := {
	"m1911": {
		"camera_shake": 0.085, "camera_shake_time": 0.08, "camera_punch": 0.10,
		"muzzle_flash_scale": 0.85, "muzzle_flash_color": "#ffd9a0",
		"muzzle_flash_energy": 2.6, "muzzle_spark_count": 5, "smoke_puffs": 1,
		"move_speed_multiplier": 1.06,
	},
	"mp5": {
		"camera_shake": 0.055, "camera_shake_time": 0.06, "camera_punch": 0.06,
		"muzzle_flash_scale": 0.7, "muzzle_flash_color": "#cfffe6",
		"muzzle_flash_energy": 2.2, "muzzle_spark_count": 4, "smoke_puffs": 1,
		"move_speed_multiplier": 1.04,
	},
	"ak47": {
		"camera_shake": 0.115, "camera_shake_time": 0.10, "camera_punch": 0.13,
		"muzzle_flash_scale": 1.05, "muzzle_flash_color": "#ffab35",
		"muzzle_flash_energy": 3.2, "muzzle_spark_count": 7, "smoke_puffs": 2,
		"move_speed_multiplier": 0.96,
	},
	"akm": {
		"camera_shake": 0.125, "camera_shake_time": 0.105, "camera_punch": 0.14,
		"muzzle_flash_scale": 1.12, "muzzle_flash_color": "#ff9328",
		"muzzle_flash_energy": 3.4, "muzzle_spark_count": 7, "smoke_puffs": 2,
		"move_speed_multiplier": 0.94,
	},
	"k2": {
		"camera_shake": 0.095, "camera_shake_time": 0.09, "camera_punch": 0.11,
		"muzzle_flash_scale": 0.92, "muzzle_flash_color": "#a8dcff",
		"muzzle_flash_energy": 3.0, "muzzle_spark_count": 6, "smoke_puffs": 1,
		"move_speed_multiplier": 0.97,
	},
	# ── 더블배럴: 두 총열을 한 번에 비운다 ────────────────────────
	# 방아쇠 한 번 = 약실 2발 = 펠릿 16개가 한 순간에. 그래서 화면이 크게 밀리고
	# 고양이가 뒤로 밀리고, 그 대가로 3.3초 동안 완전히 무방비가 된다.
	"double_barrel": {
		"shots_per_trigger": 2,
		"volley_spread_bias_deg": 3.4,
		"camera_shake": 0.34, "camera_shake_time": 0.17, "camera_punch": 0.30,
		"muzzle_flash_scale": 2.2, "muzzle_flash_color": "#ff8b2e",
		"muzzle_flash_energy": 6.5, "muzzle_spark_count": 18, "smoke_puffs": 3,
		"move_speed_multiplier": 0.90,
	},
	# ── 펌프: 반대 성격 ──────────────────────────────────────────
	# 한 발씩 여섯 번. 매 발 뒤 0.22초에 슬라이드를 당기는 소리가 붙어
	# "쏘고-철컥, 쏘고-철컥" 리듬이 손에 남는다.
	"pump_shotgun": {
		"camera_shake": 0.20, "camera_shake_time": 0.13, "camera_punch": 0.22,
		"muzzle_flash_scale": 1.5, "muzzle_flash_color": "#ffa145",
		"muzzle_flash_energy": 4.4, "muzzle_spark_count": 11, "smoke_puffs": 2,
		"move_speed_multiplier": 0.92,
		"action_sound_delay": 0.22, "action_sound_id": "shotgun_pump",
	},
}


static func get_projectile_profile(weapon_id: String) -> Dictionary:
	# 기본값 위에 무기별 차이만 덮는다 — 프로필이 없는 id는 옛 예광탄 그대로.
	var profile := DEFAULT_PROJECTILE_PROFILE.duplicate(true)
	var overrides: Dictionary = PROJECTILE_PROFILES.get(weapon_id, {})
	for key in overrides:
		profile[key] = overrides[key]
	return profile


static func get_fire_feel(weapon_id: String) -> Dictionary:
	var feel := DEFAULT_FIRE_FEEL.duplicate(true)
	var overrides: Dictionary = FIRE_FEEL.get(weapon_id, {})
	for key in overrides:
		feel[key] = overrides[key]
	return feel


# ── 무기 가족 사다리 ──────────────────────────────────────────
# 같은 가족 안에서 "하위 → 상위" 순서. 상위 무기를 처음 손에 넣는 순간
# 바로 아래 단계(보유 중이면 그 중 가장 높은 레벨)의 강화를 60% 이관한다.
# 하위 무기의 강화는 그대로 남는다 — 갈아타기가 손실이 아니라 승계여야 한다.
const WEAPON_FAMILY_LADDER := {
	"rifle": ["ak47", "akm", "k2"],
	"shotgun": ["double_barrel", "pump_shotgun"],
}
const ENHANCEMENT_TRANSFER_RATIO := 0.6
# 강화 피해 곡선의 두 손잡이. 초반(+25까지)은 존별 킬 타이밍이 튜닝돼 있어
# 옛 곡선을 그대로 두고, 그 뒤부터 복리로 간다. 세기를 바꾸려면 여기만 만진다.
const ENHANCEMENT_TUNED_LEVELS := 25
# 5% → 8%(2026-08-30 2차). 유저 판정: "인크리멘탈이면 피해가 수천은 돼야지".
# 8%면 +70에 K2가 2,500을 때리고 +99엔 24,000을 넘긴다 — 숫자가 자릿수를
# 갈아타는 맛이 이 장르의 본체다. 적 체력도 같은 폭으로 함께 열었다
# (enemy_director.ENEMY_STAGE_POWER_GROWTH).
const WEAPON_DAMAGE_GROWTH_LATE := 1.08

const MAGAZINES := {
	"m1911_7rnd": {"caliber": "45_acp", "capacity": 7, "weapons": ["m1911"]},
	"mp5_30rnd": {"caliber": "9mm", "capacity": 30, "weapons": ["mp5"]},
	"ak_30rnd": {"caliber": "762x39", "capacity": 30, "weapons": ["ak47"]},
	"double_barrel_chamber": {"caliber": "12g", "capacity": 2, "weapons": ["double_barrel"]},
	# 사다리 상위 기종 — 구경은 기존 탄과 공유하고 탄창만 전용이다.
	"akm_40rnd": {"caliber": "762x39", "capacity": 40, "weapons": ["akm"]},
	"k2_30rnd": {"caliber": "762x39", "capacity": 30, "weapons": ["k2"]},
	"pump_6rnd": {"caliber": "12g", "capacity": 6, "weapons": ["pump_shotgun"]},
}

const AMMO_TYPES := {
	"9mm_fmj": {"display_name": "9mm 보통탄", "caliber": "9mm", "damage_multiplier": 1.0, "penetration": 0, "tier": 1},
	"9mm_ap": {"display_name": "9mm AP탄", "caliber": "9mm", "damage_multiplier": 0.92, "penetration": 1, "tier": 3},
	"45_fmj": {"display_name": ".45 ACP 보통탄", "caliber": "45_acp", "damage_multiplier": 1.0, "penetration": 0, "tier": 1},
	"45_ap": {"display_name": ".45 ACP 철갑탄", "caliber": "45_acp", "damage_multiplier": 0.9, "penetration": 1, "tier": 3},
	"762_fmj": {"display_name": "7.62mm 보통탄", "caliber": "762x39", "damage_multiplier": 1.0, "penetration": 1, "tier": 2},
	"762_ap": {"display_name": "7.62mm AP탄", "caliber": "762x39", "damage_multiplier": 0.95, "penetration": 2, "tier": 4},
	"12g_buckshot": {"display_name": "12게이지 벅샷", "caliber": "12g", "damage_multiplier": 1.0, "penetration": 0, "tier": 1},
	"12g_slug": {"display_name": "12게이지 슬러그", "caliber": "12g", "damage_multiplier": 1.7, "penetration": 1, "tier": 3},
}

const MODS := {
	"laser_pointer": {
		"display_name": "레이저 포인터",
		"slot": "sight",
		"multipliers": {"base_spread_deg": 0.65, "spread_recovery_deg": 1.2},
	},
	"scope_2x": {
		"display_name": "폐점포 2x 스코프",
		"slot": "sight",
		"multipliers": {"base_spread_deg": 0.78, "spread_recovery_deg": 1.1},
		"overrides": {"scope_zoom": 2.0, "scope_shift": 5.5},
	},
	"scope_4x": {
		"display_name": "망원경 4x 스코프",
		"slot": "sight",
		"multipliers": {"base_spread_deg": 0.62, "moving_spread_multiplier": 1.18},
		"overrides": {"scope_zoom": 4.0, "scope_shift": 10.0},
	},
	"muffled_sock": {
		"display_name": "소리 방지용 양말",
		"slot": "muzzle",
		"multipliers": {"sound_radius": 0.5, "durability_loss": 1.6},
	},
	"sponge_pad": {
		"display_name": "스펀지 턱받이",
		"slot": "stock",
		"multipliers": {"loaf_spread_multiplier": 0.6, "spread_recovery_deg": 1.15},
	},
	"quick_mag": {
		"display_name": "테이프 듀얼 탄창",
		"slot": "magazine",
		"multipliers": {"reload_time": 0.7, "movement_sound_multiplier": 1.1},
	},
	"bell_bait": {
		"display_name": "딸랑이 방울",
		"slot": "tactical",
		"multipliers": {"sound_radius": 1.2},
		"sound_decoy": true,
	},
	"m1911_last_stand_slide": {
		"display_name": "M1911 최후 저항 슬라이드",
		"slot": "special",
		"compatible_weapons": ["m1911"],
		"multipliers": {"damage": 1.18, "fire_interval": 0.86, "recoil_kick": 1.2},
	},
	"mp5_overdrive_bolt": {
		"display_name": "MP5 과급 노리쇠",
		"slot": "special",
		"compatible_weapons": ["mp5"],
		"multipliers": {"damage": 1.12, "fire_interval": 0.74, "spread_per_shot_deg": 1.3, "durability_loss": 1.65},
	},
	"ak_precision_receiver": {
		"display_name": "AK 정밀 단발 리시버",
		"slot": "special",
		# AKM도 같은 리시버 규격 — 사다리를 오르면서 특수 파츠를 잃지 않게 한다.
		"compatible_weapons": ["ak47", "akm"],
		"multipliers": {"damage": 1.15, "base_spread_deg": 0.42, "recoil_kick": 0.72},
		"overrides": {"automatic": false, "fire_interval": 0.28, "special_mechanic": "precision_semi_auto"},
	},
	"double_barrel_cluster_choke": {
		"display_name": "참치통 확산 초크",
		"slot": "special",
		"compatible_weapons": ["double_barrel"],
		"multipliers": {"damage": 0.82, "base_spread_deg": 0.8},
		"additives": {"pellet_count": 4},
		"overrides": {"special_mechanic": "cluster_blast"},
	},
}


static func get_weapon(weapon_id: String) -> Dictionary:
	var definition: Dictionary = WEAPONS.get(weapon_id, WEAPONS[DEFAULT_WEAPON_ID])
	return definition.duplicate(true)


static func get_mod(mod_id: String) -> Dictionary:
	var definition: Dictionary = MODS.get(mod_id, {})
	return definition.duplicate(true)


static func build_stats(
	weapon_id: String,
	mod_ids: Array[String],
	enhancement_level: int = 0,
	mod_enhancement_levels: Dictionary = {}
) -> Dictionary:
	var stats := get_weapon(weapon_id)
	stats["weapon_id"] = weapon_id
	stats["movement_sound_multiplier"] = 1.0
	stats["scope_zoom"] = 1.0
	stats["scope_shift"] = 0.0
	var magazine := get_magazine(str(stats.get("magazine_id", "")))
	if not magazine.is_empty():
		stats["magazine_size"] = int(magazine.get("capacity", stats.get("magazine_size", 0)))
	var occupied_slots: Dictionary = {}
	for mod_id in mod_ids:
		var mod_definition := get_mod(mod_id)
		if mod_definition.is_empty():
			continue
		var compatible_weapons: Array = mod_definition.get("compatible_weapons", [])
		if not compatible_weapons.is_empty() and not compatible_weapons.has(weapon_id):
			continue
		var slot := str(mod_definition.get("slot", ""))
		if occupied_slots.has(slot):
			continue
		occupied_slots[slot] = mod_id
		var mod_level := clampi(int(mod_enhancement_levels.get(mod_id, 0)), 0, 99)
		# 선형(+1.2%/Lv, +99면 ×2.19) → 수렴(최대 +50%). 강화는 끝이 없어야 하지만
		# 힘은 끝이 있어야 적이 종이가 되지 않는다.
		var mod_power := 1.0 + 0.5 * (1.0 - pow(0.95, float(mod_level)))
		var multipliers: Dictionary = mod_definition.get("multipliers", {})
		for stat_name in multipliers:
			var base_multiplier := float(multipliers[stat_name])
			var enhanced_multiplier := maxf(0.1, 1.0 + (base_multiplier - 1.0) * mod_power)
			stats[stat_name] = float(stats.get(stat_name, 1.0)) * enhanced_multiplier
		var additives: Dictionary = mod_definition.get("additives", {})
		for stat_name in additives:
			stats[stat_name] = float(stats.get(stat_name, 0.0)) + float(additives[stat_name]) * mod_power
		var overrides: Dictionary = mod_definition.get("overrides", {})
		for stat_name in overrides:
			stats[stat_name] = overrides[stat_name]
	var level := clampi(enhancement_level, 0, 99)
	if level > 0:
		# ── 피해 곡선(2026-08-30 천장 철거) ───────────────────────────
		# 예전에는 전 구간이 수렴 곡선이라 아무리 부어도 ×2.1이 천장이었다.
		# MP5를 +55까지 올려도 18 × 1.88 = 33이 나왔고, 유저 판정은 "인크리멘탈
		# 게임에서 있을 수 없는 일". 맞는 말이다 — 강화가 이 게임의 주 성장선인데
		# 55단계를 부어 두 배가 안 되면 올릴 이유가 없다.
		#
		# 초반 +25까지는 존별 킬 타이밍(종로 AK+5·을지로 AKM+15·남산 K2+25가
		# 각각 3발)이 맞춰져 있어 옛 곡선을 그대로 둔다. 천장은 그 뒤부터
		# 걷어내고 복리(+8%/단계)로 간다 — 여기서부터가 '쌓는 재미' 구간이다.
		#   +25 ×1.66(불변) · +40 ×5.3 · +55 ×16.7 · +70 ×53 · +99 ×501
		#   K2 기준 실피해: +40 253 · +55 802 · +70 2,543 · +99 24,065
		# 비용은 3구간 지수라 여전히 비용이 파워보다 가파르다 — "한 단계 더"가
		# 계속 목표로 남는 이유다.
		var tuned_level := mini(level, ENHANCEMENT_TUNED_LEVELS)
		var damage_bonus := 0.03 * float(tuned_level)
		if tuned_level > 10:
			damage_bonus = 0.30 + 0.60 * (1.0 - pow(0.94, float(tuned_level - 10)))
		var damage_multiplier := 1.0 + damage_bonus
		if level > ENHANCEMENT_TUNED_LEVELS:
			damage_multiplier *= pow(
				WEAPON_DAMAGE_GROWTH_LATE, float(level - ENHANCEMENT_TUNED_LEVELS)
			)
		stats["damage"] = float(stats.get("damage", 1.0)) * damage_multiplier
		stats["base_spread_deg"] = float(stats.get("base_spread_deg", 2.0)) * maxf(0.72, 1.0 - float(level) * 0.003)
		stats["recoil"] = float(stats.get("recoil", 1.0)) * maxf(0.76, 1.0 - float(level) * 0.0025)
		stats["durability_loss"] = float(stats.get("durability_loss", 1.0)) * maxf(0.55, 1.0 - float(level) * 0.0045)
	stats["enhancement_level"] = level
	return stats


static func validate_mod_loadout(mod_ids: Array[String], weapon_id: String = "") -> bool:
	var occupied_slots: Dictionary = {}
	for mod_id in mod_ids:
		var definition := get_mod(mod_id)
		if definition.is_empty():
			return false
		var compatible_weapons: Array = definition.get("compatible_weapons", [])
		if not weapon_id.is_empty() and not compatible_weapons.is_empty() and not compatible_weapons.has(weapon_id):
			return false
		var slot := str(definition.get("slot", ""))
		if occupied_slots.has(slot):
			return false
		occupied_slots[slot] = true
	return true


static func get_magazine(magazine_id: String) -> Dictionary:
	var definition: Dictionary = MAGAZINES.get(magazine_id, {})
	return definition.duplicate(true)


static func get_ammo(ammo_id: String) -> Dictionary:
	var definition: Dictionary = AMMO_TYPES.get(ammo_id, {})
	return definition.duplicate(true)


static func is_magazine_compatible(weapon_id: String, magazine_id: String) -> bool:
	var magazine := get_magazine(magazine_id)
	return not magazine.is_empty() and (magazine.get("weapons", []) as Array).has(weapon_id)


static func is_ammo_compatible(magazine_id: String, ammo_id: String) -> bool:
	var magazine := get_magazine(magazine_id)
	var ammo := get_ammo(ammo_id)
	return (
		not magazine.is_empty()
		and not ammo.is_empty()
		and str(magazine.get("caliber", "")) == str(ammo.get("caliber", ""))
	)


static func validate_ammo_loadout(weapon_id: String, magazine_id: String, ammo_id: String) -> bool:
	return is_magazine_compatible(weapon_id, magazine_id) and is_ammo_compatible(magazine_id, ammo_id)


static func get_weapon_family(weapon_id: String) -> String:
	for family_id in WEAPON_FAMILY_LADDER:
		if (WEAPON_FAMILY_LADDER[family_id] as Array).has(weapon_id):
			return str(family_id)
	return ""


static func get_lower_ladder_weapons(weapon_id: String) -> Array[String]:
	# 같은 가족에서 이 무기보다 아래 단계의 id들(낮은 순). 가족이 없거나
	# 맨 아래면 빈 배열.
	var result: Array[String] = []
	var family_id := get_weapon_family(weapon_id)
	if family_id.is_empty():
		return result
	var ladder: Array = WEAPON_FAMILY_LADDER[family_id]
	var index := ladder.find(weapon_id)
	for lower_index in index:
		result.append(str(ladder[lower_index]))
	return result

