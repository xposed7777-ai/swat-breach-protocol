extends SceneTree

func _init() -> void:
    var scene := load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        push_error("smoke: main scene could not be loaded")
        quit(1)
        return

    var game := scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    _require(game.player != null, "player exists")
    _require(game.camera != null, "camera exists")
    _require(game.npc_root != null, "npc root exists")
    _require(game.npcs.size() >= 6, "npc population exists")
    _require(game.fire_button != null, "fire gui exists")
    _require(game.reload_button != null, "reload gui exists")
    _require(game.aim_button != null, "aim gui exists")
    _require(game.restrain_button != null, "restrain gui exists")
    _require(game.weapon_button != null, "weapon gui exists")

    var initial_ammo: int = game.ammo
    game.fire_weapon()
    _require(game.ammo == initial_ammo - 1, "fire consumes ammunition")

    game.reload_weapon()
    await create_timer(0.15).timeout
    _require(game.reloading or game.ammo > initial_ammo - 1, "reload starts")
    await create_timer(2.2).timeout
    _require(not game.reloading, "reload completes")
    _require(game.ammo == initial_ammo, "reload restores magazine")

    var original_fov: float = game.camera.fov
    game.toggle_aim()
    _require(game.aiming, "aim toggles on")
    _require(game.camera.fov != original_fov, "aim changes camera fov")
    game.toggle_aim()
    _require(not game.aiming, "aim toggles off")

    var original_weapon: int = game.weapon_index
    game.next_weapon()
    _require(game.weapon_index != original_weapon, "weapon switching works")
    _require(game.weapon_holder.get_child_count() > 0, "weapon model is equipped")

    game.queue_free()
    await process_frame
    print("gameplay smoke test: PASS — npc, hud/gui, fire, reload, aim, weapon switch")
    quit(0)

func _require(condition: bool, message: String) -> void:
    if not condition:
        push_error("smoke: FAIL — " + message)
        quit(1)
        await process_frame
