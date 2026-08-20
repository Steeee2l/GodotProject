extends SceneTree


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var game_state := root.get_node("GameState")
    game_state.set("persistence_enabled", false)
    game_state.call("reset_run")
    var main_scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(main_scene)
    await process_frame
    # 게임오버 UI는 main 변수가 아니라 game_over_screen 모듈로 옮겨졌다.
    var game_over_screen: RefCounted = main_scene.get("game_over_screen")
    var game_over_canvas := game_over_screen.get("canvas") as CanvasLayer
    var game_over_panel := game_over_screen.get("panel") as PanelContainer
    assert(not game_over_canvas.visible, "The inactive game-over layer must not cover normal HUD controls.")
    assert(
        game_over_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "The transparent game-over panel must never intercept inventory clicks."
    )
    game_state.set("canned_food", 7)
    (game_state.get("mod_component_inventory") as Dictionary)["magazine_spring"] = 3
    assert(bool((game_state.call("deposit_storage_item", "food", "canned_food", 5) as Dictionary).get("ok", false)))
    main_scene.set("run_kills", 3)
    main_scene.set("run_damage_dealt", 420)
    main_scene.call("_begin_player_death_sequence")
    assert(bool(main_scene.get("player_death_sequence_active")))
    assert(game_over_canvas.visible)
    assert(Engine.time_scale < 1.0)
    var label := game_over_screen.get("title_label") as Label
    assert(label != null and label.text == "작전 실패")
    var survival_value := game_over_screen.get("survival_value") as Label
    var kills_value := game_over_screen.get("kills_value") as Label
    var damage_value := game_over_screen.get("damage_value") as Label
    assert(survival_value != null and not survival_value.text.is_empty())
    assert(kills_value != null and kills_value.text == "3")
    assert(damage_value != null and damage_value.text == "420")
    assert(main_scene.find_child("GameOverStats", true, false) != null)
    assert(main_scene.find_child("GameOverRecoveryBanner", true, false) != null)
    var loss_label := game_over_screen.get("loss_label") as Label
    assert(loss_label != null and loss_label.text.contains("사망 지점"))
    var loss_grid := game_over_screen.get("loss_grid") as HFlowContainer
    assert(loss_grid != null and loss_grid.get_child_count() > 0)
    assert(loss_grid.get_child(0) is PanelContainer)
    var loss_count_label := game_over_screen.get("loss_count_label") as Label
    assert(loss_count_label != null and loss_count_label.text.ends_with("종"))
    var continue_label := game_over_screen.get("continue_label") as Label
    assert(continue_label != null and continue_label.text.contains("쉘터로 복귀"))
    assert(game_over_panel.custom_minimum_size.y <= 500.0)
    var corpse := game_state.get("pending_corpse_recovery") as Dictionary
    var corpse_loot := corpse.get("loot", {}) as Dictionary
    # 사망 페널티 완화(2026-08): 장착 중이던 무기 1정은 시체로 가지 않고 손에
    # 남는다. 시작 AK는 장착 상태이므로 시체 전리품에 있으면 안 된다(이중 지급 방지).
    assert(int((corpse_loot.get("weapon_inventory", {}) as Dictionary).get("ak47", 0)) == 0)
    assert(str(corpse_loot.get("equipped_weapon_id", "x")).is_empty())
    assert(int(corpse_loot.get("canned_food", 0)) == 2)
    # 시큐어 주머니가 죽음에서 1개를 지킨다(츄르>개조품>부품>구급약 우선순위).
    # 츄르·개조품이 없는 이 시나리오에서는 스프링 1개가 보존되고 2개만 시체에 남는다.
    assert(
        int((corpse_loot.get("mod_component_inventory", {}) as Dictionary).get("magazine_spring", 0)) == 2,
        "Two springs stay on the corpse; the secure pouch keeps one."
    )
    # 페널티는 _begin_player_death_sequence가 사망 순간 원자적으로 이미 적용했다.
    # 예전 이 자리의 중복 _clear_carried_inventory_after_death 호출은 시큐어
    # 주머니가 복원해 준 스프링까지 다시 0으로 밀어 HEAD에서 이 테스트를
    # 깨뜨리고 있었다(실측: 라인 70 어서션 행 걸림) — 중복 호출을 제거한다.
    # 사망 페널티 완화(2026-08): 장착 무기(AK)는 사망 후에도 손에 남는다.
    # 탄약(가방 몫)은 종전대로 전부 잃는다.
    assert(bool(game_state.get("has_ak")))
    assert(int(game_state.call("get_weapon_count", "ak47")) == 1)
    assert(str(game_state.get("equipped_weapon_id")) == "ak47")
    assert(int(game_state.call("get_ammo_count", "762_fmj")) == 0)
    assert(int(game_state.get("canned_food")) == 5)
    assert(int(game_state.call("get_stored_storage_count", "food", "canned_food")) == 5)
    # 시큐어 주머니가 지킨 스프링 1개는 정산 후 인벤토리로 복원된다.
    assert(int(game_state.call("get_mod_component_count", "magazine_spring")) == 1)
    assert((game_state.get("secure_dog_items") as Array).is_empty())
    Engine.time_scale = 1.0
    main_scene.queue_free()
    print("PLAYER_DEATH_SEQUENCE_OK")
    quit(0)
