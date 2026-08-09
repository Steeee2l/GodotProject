extends SceneTree


const TEST_MAP_SEED := 47291
const FIRST_RAID_SERIAL := 31
const MINIMUM_CHANGED_DISTANCE := 8.0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var game_state: Node = root.get_node("GameState")
    game_state.set("persistence_enabled", false)
    game_state.call("reset_run")

    var first_positions: Array[Vector3] = await _capture_mission_positions(
        game_state,
        FIRST_RAID_SERIAL
    )
    var second_positions: Array[Vector3] = await _capture_mission_positions(
        game_state,
        FIRST_RAID_SERIAL + 1
    )

    assert(first_positions.size() == 6)
    assert(second_positions.size() == first_positions.size())
    var changed_count: int = 0
    for index in first_positions.size():
        if first_positions[index].distance_to(second_positions[index]) >= MINIMUM_CHANGED_DISTANCE:
            changed_count += 1
    assert(
        changed_count >= 4,
        "Mission anchors must reroll for every sortie, even when the map seed is reused."
    )

    print("MISSION_POSITION_RANDOMIZATION_OK changed=%d total=%d" % [
        changed_count,
        first_positions.size(),
    ])
    quit(0)


func _capture_mission_positions(game_state: Node, raid_serial: int) -> Array[Vector3]:
    game_state.set("map_seed", TEST_MAP_SEED)
    game_state.set("raid_serial", raid_serial)
    game_state.set("returning_from_shelter", false)
    var packed_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    var main_scene: Node = packed_scene.instantiate()
    root.add_child(main_scene)
    await process_frame
    await physics_frame
    main_scene.process_mode = Node.PROCESS_MODE_DISABLED

    var positions: Array[Vector3] = []
    for site_value in main_scene.get("field_missions").field_mission_sites:
        var site := site_value as Node3D
        positions.append(site.global_position)

    main_scene.queue_free()
    await process_frame
    await process_frame
    return positions
