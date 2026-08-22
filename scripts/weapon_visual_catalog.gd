class_name WeaponVisualCatalog
extends RefCounted


const CATALOG := {
	"m1911": {
		"display_name": "M1911",
		"texture_path": "res://assets/weapons/catalog/generated/m1911.png",
		"world_pixel_size": 0.00068,
	},
	"ak47": {
		"display_name": "AK-47",
		"texture_path": "res://assets/weapons/catalog/generated/ak47.png",
		"world_pixel_size": 0.001,
	},
	"mp5": {
		"display_name": "MP5",
		"texture_path": "res://assets/weapons/catalog/generated/mp5.png",
		"world_pixel_size": 0.0009,
	},
	"double_barrel": {
		"display_name": "더블배럴 산탄총",
		"texture_path": "res://assets/weapons/catalog/generated/double_barrel.png",
		"world_pixel_size": 0.0009,
	},
	# ── 무기 사다리 신규 3종 ──
	# AKM은 정식 아트가 아직 없다 — AK-47 스프라이트를 코드에서 틴트(어두운
	# 폴리머 톤, tint = 덮어 얹는 색·알파)해 임시로 쓴다(_build_tinted_texture).
	# 정식 스프라이트가 들어오면 texture_path만 바꾸고 tint를 지우면 된다.
	"akm": {
		"display_name": "AKM",
		"texture_path": "res://assets/weapons/catalog/generated/ak47.png",
		"world_pixel_size": 0.001,
		"tint": Color(0.16, 0.2, 0.26, 0.48),
	},
	# K2·펌프 산탄총은 assets/weapons/catalog에 이미 있던(미사용) 같은 화풍의
	# 1254² 스프라이트를 쓴다 — 틴트보다 식별이 훨씬 낫다. 여백이 커서
	# pixel_size를 AK(1651px·0.001)와 비슷한 실물 폭이 되도록 잡는다.
	"k2": {
		"display_name": "K2",
		"texture_path": "res://assets/weapons/catalog/rifle_ar_platform.png",
		"world_pixel_size": 0.00125,
	},
	"pump_shotgun": {
		"display_name": "펌프 산탄총",
		"texture_path": "res://assets/weapons/catalog/shotgun_pump.png",
		"world_pixel_size": 0.00125,
	},
	"baseball_bat": {
		"display_name": "야구 방망이",
		"texture_path": "res://assets/weapons/catalog/generated/baseball_bat.png",
		"world_pixel_size": 0.00058,
	},
	"rocket_launcher": {
		"display_name": "로켓런처",
		"texture_path": "res://assets/weapons/catalog/generated/rocket_launcher.png",
		"world_pixel_size": 0.001,
	},
}

# 틴트 텍스처 캐시 — 같은 프로세스 안에서 한 번만 만든다(손 스프라이트·HUD·
# 드랍·적 손·가방 아이콘이 전부 같은 인스턴스를 공유).
static var tinted_texture_cache: Dictionary = {}


static func has_weapon_texture(weapon_id: String) -> bool:
	return CATALOG.has(weapon_id)


static func get_weapon_texture(weapon_id: String) -> Texture2D:
	var entry: Dictionary = CATALOG.get(weapon_id, {})
	var texture_path := str(entry.get("texture_path", ""))
	if texture_path.is_empty():
		return null
	if entry.has("tint"):
		return _build_tinted_texture(weapon_id, texture_path, entry["tint"] as Color)
	return load(texture_path) as Texture2D


static func _build_tinted_texture(weapon_id: String, texture_path: String, tint: Color) -> Texture2D:
	# 임시 틴트 변형: 원본 위에 tint 색을 알파 블렌드로 한 겹 얹되(blend_rect),
	# 원본 알파를 마스크로 써서 투명 여백은 그대로 둔다(blit_rect_mask). 전부
	# 네이티브 Image 연산이라 1651×953도 수십 ms. modulate가 아니라 텍스처를
	# 바꾸는 이유 — 플레이어 손 스프라이트는 실루엣/피격 연출이 modulate를
	# 매 프레임 덮어써서 색을 얹어도 곧 지워진다.
	if tinted_texture_cache.has(weapon_id):
		return tinted_texture_cache[weapon_id]
	var source := load(texture_path) as Texture2D
	if source == null:
		return null
	var original := source.get_image()
	if original == null:
		return source
	original = original.duplicate() as Image
	if original.is_compressed():
		original.decompress()
	original.convert(Image.FORMAT_RGBA8)
	var size := original.get_size()
	var overlay := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	overlay.fill(tint)
	var blended := original.duplicate() as Image
	blended.blend_rect(overlay, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	var result := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	result.blit_rect_mask(blended, original, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	var texture := ImageTexture.create_from_image(result)
	tinted_texture_cache[weapon_id] = texture
	return texture


static func get_world_pixel_size(weapon_id: String, fallback: float = 0.0042) -> float:
	var entry: Dictionary = CATALOG.get(weapon_id, {})
	return float(entry.get("world_pixel_size", fallback))


static func get_inventory_textures() -> Dictionary:
	var textures := {}
	for weapon_id in CATALOG:
		textures[weapon_id] = get_weapon_texture(weapon_id)
	return textures
