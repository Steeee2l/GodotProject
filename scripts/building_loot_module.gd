extends Node3D

const SALVAGE_TEXTURE := preload("res://assets/interiors/office_dungeon/modules/office_salvage_loot_v1.png")
const AMMO_TEXTURE := preload("res://assets/items/ammo_762.png")
const COMPONENT_TEXTURES := {
	"rubber_gasket": preload("res://assets/items/mod_components/rubber_gasket.png"),
	"scope_lens": preload("res://assets/items/mod_components/scope_lens.png"),
	"magazine_spring": preload("res://assets/items/mod_components/magazine_spring.png"),
}
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const SFX := preload("res://scripts/sfx_bank.gd")
const SHELTER_REQUISITION := preload("res://scripts/shelter/requisition.gd")
const FLOOR_DROP_MAX_WIDTH := 0.9
const FLOOR_DROP_MAX_HEIGHT := 0.72

signal collected(loot_key: String, description: String)

var loot_key := ""
var loot_type := "container"
var amount := 1
var floor_number := 1
var container_type := ""
var stage_tier := 1
var roll_seed := 1
var fixed_definition: Dictionary = {}

@onready var BuildingRunState: Node = get_node("/root/BuildingRunState")
@onready var GameState: Node = get_node("/root/GameState")


func configure(key_value: String, type_value: String, amount_value: int, floor_value: int) -> void:
	loot_key = key_value
	loot_type = type_value
	amount = maxi(1, amount_value)
	floor_number = floor_value
	var data := {
		"amount": amount,
		"display_name": _legacy_display_name(type_value),
		"base_value": 0,
		"slot_size": 1,
		"total_value": 0,
	}
	match type_value:
		"ammo":
			data["ammo_id"] = "762_fmj"
		"component":
			loot_type = "mod_component"
			data["component_id"] = _resolved_component_id()
		"weapon":
			data["weapon_id"] = _resolved_weapon_id()
		"equipment":
			loot_type = "armor"
			data["equipment_id"] = _resolved_equipment_id()
	fixed_definition = {"type": loot_type, "data": data}
	_apply_metadata()


func configure_item(key_value: String, definition: Dictionary, floor_value: int) -> void:
	loot_key = key_value
	floor_number = floor_value
	fixed_definition = definition.duplicate(true)
	loot_type = str(fixed_definition.get("type", "canned_food"))
	amount = int((fixed_definition.get("data", {}) as Dictionary).get("amount", 1))
	_apply_metadata()


func configure_container(
	key_value: String,
	container_value: String,
	stage_value: int,
	floor_value: int,
	seed_value: int
) -> void:
	loot_key = key_value
	container_type = container_value
	stage_tier = clampi(stage_value, 1, 4)
	floor_number = floor_value
	roll_seed = seed_value
	loot_type = "container"
	fixed_definition.clear()
	_apply_metadata()


func _apply_metadata() -> void:
	set_meta("loot_key", loot_key)
	set_meta("loot_type", loot_type)
	set_meta("container_type", container_type)
	set_meta("stage_tier", stage_tier)


func _ready() -> void:
	add_to_group("building_interactable")
	add_to_group("building_loot_module")
	_build_visual()


func get_interaction_radius() -> float:
	return 1.65


func get_interaction_prompt() -> String:
	if not container_type.is_empty():
		return "수색 · %s" % LOOT_ECONOMY.get_container_display_name(container_type)
	return "획득 · %s" % _definition_display_name(fixed_definition)


func interact() -> String:
	if BuildingRunState.is_loot_collected(floor_number, loot_key):
		return "이미 비어 있습니다."
	var definitions: Array[Dictionary] = []
	if fixed_definition.is_empty():
		var random := RandomNumberGenerator.new()
		random.seed = roll_seed
		definitions = LOOT_ECONOMY.roll_container(
			container_type,
			stage_tier,
			"business_corner",
			random
		)
	else:
		definitions.append(fixed_definition)
	var pending_items: Array[Dictionary] = []
	for definition in definitions:
		var pending_item: Dictionary = _raid_item_from_definition(definition)
		if not pending_item.is_empty():
			pending_items.append(pending_item)
	if not GameState.can_add_raid_items(pending_items):
		return "가방이 꽉 찼습니다. 가방에서 물품을 버린 뒤 다시 시도하세요."
	var acquired_names: Array[String] = []
	var goal_note := ""
	for definition in definitions:
		if (
			fixed_definition.is_empty()
			and not LOOT_ECONOMY.try_register_loot(
				GameState,
				definition,
				"field",
				stage_tier
			)
		):
			continue
		var granted := _grant_definition(definition)
		if not granted.is_empty():
			acquired_names.append(granted)
			# 쉘터 다음 목표 품목(츄르)이면 진행도 한 줄 — 필드 토스트와 같은 문구.
			if str(_raid_item_from_definition(definition).get("type", "")) == "churu":
				goal_note = SHELTER_REQUISITION.describe_progress_after_pickup("churu")
	BuildingRunState.mark_loot_collected(floor_number, loot_key)
	GameState.save_persistent_state()
	# 컨테이너 수색은 열기 소리, 바닥 픽업은 주머니 소리.
	SFX.play("container_open" if not container_type.is_empty() else "pickup")
	var description := "비어 있습니다."
	if not acquired_names.is_empty():
		description = "획득 · %s" % " / ".join(acquired_names)
		if not goal_note.is_empty():
			description += "   ·   %s" % goal_note
	collected.emit(loot_key, description)
	queue_free()
	return description


func _grant_definition(definition: Dictionary) -> String:
	var data: Dictionary = definition.get("data", {}) as Dictionary
	var item_amount: int = maxi(1, int(data.get("amount", 1)))
	var display_name: String = str(data.get("display_name", "전리품"))
	var raid_item: Dictionary = _raid_item_from_definition(definition)
	if raid_item.is_empty():
		return ""
	if not GameState.try_add_raid_item(
		str(raid_item.get("type", "")),
		str(raid_item.get("id", "")),
		int(raid_item.get("amount", 1))
	):
		return ""
	return "%s x%d" % [display_name, item_amount]


func _raid_item_from_definition(definition: Dictionary) -> Dictionary:
	var type_name: String = str(definition.get("type", "canned_food"))
	var data: Dictionary = definition.get("data", {}) as Dictionary
	var item_amount: int = maxi(1, int(data.get("amount", 1)))
	match type_name:
		"ammo":
			return {"type": "ammo", "id": str(data.get("ammo_id", "762_fmj")), "amount": item_amount}
		"canned_food":
			return {"type": "food", "id": "canned_food", "amount": item_amount}
		"medkit":
			return {"type": "medkit", "id": "medkit", "amount": item_amount}
		"churu":
			return {"type": "churu", "id": "churu", "amount": item_amount}
		"mod_component":
			return {"type": "component", "id": str(data.get("component_id", "rubber_gasket")), "amount": item_amount}
		"weapon_mod":
			return {"type": "mod", "id": str(data.get("weapon_mod_id", "scope_2x")), "amount": item_amount}
		"progression_item":
			return {"type": "progression", "id": str(data.get("progression_item_id", "rifle_blueprint")), "amount": item_amount}
		"weapon":
			return {"type": "weapon", "id": str(data.get("weapon_id", "m1911")), "amount": item_amount}
		"armor":
			return {"type": "equipment", "id": str(data.get("equipment_id", "scav_vest")), "amount": item_amount}
	return {}


func _build_visual() -> void:
	var texture: Texture2D = SALVAGE_TEXTURE
	# 월드 폭 기준(1.41m) — 텍스처 해상도(size_limit)가 바뀌어도 같은 크기.
	var pixel_size := 1.4143 / float(maxi(1, SALVAGE_TEXTURE.get_width()))
	var icon_name := "backpack"
	var tint := Color("#8ea097")
	if not container_type.is_empty():
		match container_type:
			"ammo_case":
				icon_name = "ammo"
				tint = Color("#c8ab62")
			"toolbox":
				icon_name = "parts"
				tint = Color("#a77a5c")
			"clothing_cache":
				icon_name = "armor"
				tint = Color("#8d9ca4")
			"weapon_case":
				icon_name = "weapon"
				tint = Color("#d3a252")
			"secure_cache":
				icon_name = "secure"
				tint = Color("#76b7a5")
	else:
		var data := fixed_definition.get("data", {}) as Dictionary
		match loot_type:
			"ammo":
				texture = AMMO_TEXTURE
				pixel_size = 0.0032
				icon_name = "ammo"
			"canned_food":
				texture = UI_ICONS.get_icon("food", 96, Color("#d9b85f"))
				pixel_size = 0.007
				icon_name = "food"
			"mod_component":
				var component_id := str(data.get("component_id", "rubber_gasket"))
				texture = COMPONENT_TEXTURES.get(component_id, COMPONENT_TEXTURES["rubber_gasket"])
				pixel_size = 0.9405 / float(maxi(1, texture.get_width()))
				icon_name = "parts"
			"progression_item":
				var progression_item_id := str(data.get("progression_item_id", "rifle_blueprint"))
				icon_name = "secure" if progression_item_id == "sealed_zone_keycard" else "craft"
				texture = UI_ICONS.get_icon(icon_name, 96, Color("#e7c96f"))
				pixel_size = 0.007
			"weapon":
				texture = UI_ICONS.get_icon("weapon", 96, Color("#c4d0ca"))
				pixel_size = 0.007
				icon_name = "weapon"
			"armor":
				texture = UI_ICONS.get_icon("armor", 96, Color("#a9c8b8"))
				pixel_size = 0.007
				icon_name = "armor"
	if container_type.is_empty():
		pixel_size = _fit_floor_drop_pixel_size(texture, pixel_size)
	var visual_height: float = float(texture.get_height()) * pixel_size
	var sprite := Sprite3D.new()
	sprite.name = "GeneratedLootVisual"
	sprite.texture = texture
	sprite.pixel_size = pixel_size
	sprite.position = Vector3(0, visual_height * 0.5, 0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.modulate = tint if not container_type.is_empty() else Color.WHITE
	add_child(sprite)
	var marker := Sprite3D.new()
	marker.name = "LootMarker"
	marker.texture = UI_ICONS.get_icon(icon_name, 64, Color("#e0ba55"))
	marker.pixel_size = 0.006
	marker.position = Vector3(0, maxf(0.82, visual_height + 0.28), 0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.shaded = false
	marker.transparent = true
	add_child(marker)


func _fit_floor_drop_pixel_size(texture: Texture2D, preferred_pixel_size: float) -> float:
	var texture_width: float = float(maxi(1, texture.get_width()))
	var texture_height: float = float(maxi(1, texture.get_height()))
	var width_limit: float = FLOOR_DROP_MAX_WIDTH / texture_width
	var height_limit: float = FLOOR_DROP_MAX_HEIGHT / texture_height
	return minf(preferred_pixel_size, minf(width_limit, height_limit))


func _definition_display_name(definition: Dictionary) -> String:
	return str((definition.get("data", {}) as Dictionary).get("display_name", "전리품"))


func _legacy_display_name(type_name: String) -> String:
	match type_name:
		"ammo":
			return "탄약"
		"canned_food":
			return "통조림"
		"component":
			return "총기 부품"
		"weapon":
			return "버려진 총기"
		"equipment":
			return "방어 장비"
	return "보급품"


func _resolved_component_id() -> String:
	var component_ids: Array[String] = ["rubber_gasket", "scope_lens", "magazine_spring"]
	return component_ids[absi(loot_key.hash()) % component_ids.size()]


func _resolved_weapon_id() -> String:
	var weapon_ids: Array[String] = ["m1911", "mp5", "double_barrel"]
	return weapon_ids[absi(loot_key.hash()) % weapon_ids.size()]


func _resolved_equipment_id() -> String:
	# 계열은 도시 티어가 정하고, 레벨은 loot_key에서 결정적으로 굴린다 —
	# 같은 컨테이너는 항상 같은 개체.
	var zone: Dictionary = GameState.RAID_ZONES.get(GameState.selected_raid_zone, {})
	var tier := int(zone.get("stage_tier", 1))
	var pool: Array = GameState.LOOT_ECONOMY.armor_pool_for_stage(tier)
	var base_id := str(pool[absi(loot_key.hash()) % pool.size()])
	var unit_roll := float(absi((loot_key + ":equip_level").hash()) % 1000) / 1000.0
	return GameState.make_equipment_id(
		base_id, GameState.LOOT_ECONOMY.roll_equipment_level(unit_roll)
	)
