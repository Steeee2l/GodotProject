extends Node

const SHELTER_SCENE := preload("res://scenes/shelter_interior.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var tree_root := get_tree().root
	var game_state := tree_root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("unlock_all_shelter_facilities")
	game_state.call("register_shelter_return")
	assert(bool(game_state.call("roll_merchant_visit", 1.0)), "A forced merchant visit must enter the waiting state.")
	assert(str(game_state.get("merchant_status")) == "waiting")
	var rolled_serial := int(game_state.get("merchant_last_roll_serial"))
	game_state.call("roll_merchant_visit", 0.0)
	assert(int(game_state.get("merchant_last_roll_serial")) == rolled_serial, "The same shelter return must not roll twice.")

	var shelter := SHELTER_SCENE.instantiate() as Node3D
	tree_root.add_child(shelter)
	await get_tree().process_frame
	await get_tree().physics_frame
	var waiting_marker := shelter.get_node_or_null("MerchantWaitingBubble") as Node3D
	assert(waiting_marker != null, "A waiting merchant needs a sewer dialogue marker.")
	var workbench := shelter.get_node("StageOneModules/WeaponWorkbench") as Node3D
	assert(workbench.position.x <= 1.5, "The workbench must stay clear of the merchant area on the left side of the upper wall.")
	var arrival_notice := tree_root.find_child("MerchantArrivalNotice", true, false) as PanelContainer
	assert(arrival_notice != null and arrival_notice.visible, "A waiting merchant needs a clean HUD arrival notice.")
	assert(waiting_marker.get_node_or_null("MerchantFace") == null, "The sewer marker must not use a floating merchant portrait.")
	var arrow := waiting_marker.get_node("MerchantArrow") as Label3D
	assert(arrow.text == "▼")
	assert(arrow.position.y <= 3.55 and arrow.position.y >= 2.3)
	assert((waiting_marker.get_node("MerchantKnockLine") as Label3D).text.contains("기다리는 중"))
	var shelter_player := shelter.get_node("ShelterPlayer") as CharacterBody3D
	var pipe_position := shelter.call("_pipe_position") as Vector3
	shelter_player.position = Vector3(pipe_position.x, 0.78, pipe_position.z)
	shelter.call("_update_nearby_station")
	assert(str(shelter.get("current_station")) == "merchant_waiting", "Merchant dialogue must replace sewer exploration while the visitor waits.")
	assert((shelter.get("prompt_label") as Label).text.contains("누군가와 대화"))
	assert((shelter.get("interact_button") as Button).text == "대화")

	shelter.call("_open_merchant_arrival_dialog")
	var arrival_layer := tree_root.find_child("MerchantArrivalLayer", true, false)
	assert(arrival_layer != null)
	var arrival_card := arrival_layer.find_child("MerchantArrivalCard", true, false) as PanelContainer
	assert(arrival_card != null and arrival_card.custom_minimum_size == Vector2(580, 286))
	shelter.call("_accept_merchant")
	await get_tree().process_frame
	assert(str(game_state.get("merchant_status")) == "inside")
	assert(not arrival_notice.visible, "The arrival notice must clear after a decision.")
	shelter.call("_update_nearby_station")
	assert(str(shelter.get("current_station")) == "pipe_exit", "The sewer must become an exploration exit again after the decision.")
	assert(get_tree().get_nodes_in_group("shelter_merchant").size() == 1)
	var merchant := get_tree().get_nodes_in_group("shelter_merchant")[0] as Node3D
	var sprite := merchant.get_node("MerchantSprite") as AnimatedSprite3D
	assert(sprite.sprite_frames.get_frame_count("idle_down_left") == 4)
	var residents_before := int(game_state.get("rescued_workers"))
	assert(bool(shelter.call("_add_debug_resident")), "Debug key 8 must be able to add a resident while capacity remains.")
	await get_tree().process_frame
	assert(int(game_state.get("rescued_workers")) == residents_before + 1)
	assert((shelter.get("shelter_residents") as Array).size() == residents_before + 1)

	game_state.set("scrap", 1000)
	var ammo_before := int(game_state.call("get_ammo_count", "762_fmj"))
	shelter.call("_open_merchant_shop")
	await get_tree().process_frame
	var shop_layer := tree_root.find_child("MerchantShopLayer", true, false) as CanvasLayer
	var shop_close := shop_layer.find_child("CloseButton", true, false) as Button
	assert(shop_close != null and shop_close.text.is_empty(), "Merchant shop close must be icon-only.")
	assert(shop_close.custom_minimum_size.x <= 44.0 and shop_close.custom_minimum_size.y <= 44.0, "Merchant shop close must stay compact.")
	assert(tree_root.find_child("고철Icon", true, false) is TextureRect, "Merchant currency must use a rendered scrap icon instead of an emoji glyph.")
	# 통조림은 더 이상 상인 화폐가 아니다(플레이어 소모품) — 화폐 칩은 고철 하나뿐이다.
	assert(tree_root.find_child("통조림Icon", true, false) == null, "Merchant header must not show a canned food currency chip any more.")
	var shop_list := shelter.get("merchant_shop_list") as VBoxContainer
	assert(shop_list.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Merchant rows must fill the available modal width.")
	var buy_tab := shelter.get("merchant_buy_tab") as Button
	var sell_tab := shelter.get("merchant_sell_tab") as Button
	assert(buy_tab.button_pressed and not sell_tab.button_pressed, "The active buy tab must be visually selected.")
	assert((buy_tab.get_node("SelectedIndicator") as ColorRect).visible)
	var ammo_buy_button := shop_list.get_node("MerchantGood_762_fmj") as Button
	assert(ammo_buy_button != null and not ammo_buy_button.disabled)
	assert(ammo_buy_button.find_child("PriceChipIcon", true, false) is TextureRect, "Every price must use a currency icon.")
	ammo_buy_button.pressed.emit()
	await get_tree().process_frame
	assert(int(game_state.call("get_ammo_count", "762_fmj")) == ammo_before + 30)
	assert(int(game_state.get("scrap")) == 350)

	shelter.call("_set_merchant_shop_mode", "sell")
	await get_tree().process_frame
	shop_list = shelter.get("merchant_shop_list") as VBoxContainer
	assert(not buy_tab.button_pressed and sell_tab.button_pressed, "The active sell tab must be visually selected.")
	assert(not (buy_tab.get_node("SelectedIndicator") as ColorRect).visible)
	assert((sell_tab.get_node("SelectedIndicator") as ColorRect).visible)
	assert(shop_list.get_node_or_null("MerchantGood_rubber_gasket") == null, "The sell tab must hide goods the player does not own.")
	assert(shop_list.get_node_or_null("MerchantGood_magazine_spring") == null, "The sell tab must hide goods the player does not own.")
	var ammo_sell_button := shop_list.get_node("MerchantGood_762_fmj") as Button
	var canned_food_before := int(game_state.get("canned_food"))
	ammo_sell_button.pressed.emit()
	await get_tree().process_frame
	assert(int(game_state.call("get_ammo_count", "762_fmj")) == ammo_before)
	# 매입 대가는 고철이다(7.62mm 30발 → 고철 200, 구매가 650의 약 30%). 통조림은
	# 매입 목록에서 아예 빠졌으므로(훈련 재화) 판매로 늘지도 줄지도 않는다.
	assert(int(game_state.get("scrap")) == 350 + 200, "Merchant sales must pay scrap (sell_scrap), not canned food.")
	assert(int(game_state.get("canned_food")) == canned_food_before)

	print("SHELTER_MERCHANT_OK waiting=true accepted=true idle_frames=4 trade=true")
	get_tree().quit(0)
