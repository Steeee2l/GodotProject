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
    var game_over_canvas := main_scene.get("game_over_canvas") as CanvasLayer
    var game_over_panel := main_scene.get("game_over_panel") as PanelContainer
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
    var label := main_scene.get("game_over_label") as Label
    assert(label != null and label.text == "작전 실패")
    var survival_value := main_scene.get("game_over_survival_value") as Label
    var kills_value := main_scene.get("game_over_kills_value") as Label
    var damage_value := main_scene.get("game_over_damage_value") as Label
    assert(survival_value != null and not survival_value.text.is_empty())
    assert(kills_value != null and kills_value.text == "3")
    assert(damage_value != null and damage_value.text == "420")
    assert(main_scene.find_child("GameOverStats", true, false) != null)
    assert(main_scene.find_child("GameOverRecoveryBanner", true, false) != null)
    var loss_label := main_scene.get("game_over_loss_label") as Label
    assert(loss_label != null and loss_label.text.contains("사망 지점"))
    var loss_grid := main_scene.get("game_over_loss_grid") as HFlowContainer
    assert(loss_grid != null and loss_grid.get_child_count() > 0)
    assert(loss_grid.get_child(0) is PanelContainer)
    var loss_count_label := main_scene.get("game_over_loss_count_label") as Label
    assert(loss_count_label != null and loss_count_label.text.ends_with("종"))
    var continue_label := main_scene.get("game_over_continue_label") as Label
    assert(continue_label != null and continue_label.text.contains("쉘터로 복귀"))
    assert(game_over_panel.custom_minimum_size.y <= 500.0)
    var corpse := game_state.get("pending_corpse_recovery") as Dictionary
    var corpse_loot := corpse.get("loot", {}) as Dictionary
    assert(int((corpse_loot.get("weapon_inventory", {}) as Dictionary).get("ak47", 0)) == 1)
    assert(int(corpse_loot.get("canned_food", 0)) == 2)
    assert(
        int((corpse_loot.get("mod_component_inventory", {}) as Dictionary).get("magazine_spring", 0)) == 3,
        "All carried springs must remain in the corpse recovery bag."
    )
    main_scene.call("_clear_carried_inventory_after_death")
    assert(not bool(game_state.get("has_ak")))
    assert(int(game_state.call("get_weapon_count", "ak47")) == 0)
    assert(str(game_state.get("equipped_weapon_id")).is_empty())
    assert(int(game_state.get("canned_food")) == 5)
    assert(int(game_state.call("get_stored_storage_count", "food", "canned_food")) == 5)
    assert(int(game_state.call("get_mod_component_count", "magazine_spring")) == 0)
    assert((game_state.get("secure_dog_items") as Array).is_empty())
    Engine.time_scale = 1.0
    main_scene.queue_free()
    print("PLAYER_DEATH_SEQUENCE_OK")
    quit(0)
