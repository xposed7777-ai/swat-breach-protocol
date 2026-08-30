extends Node3D

const WEAPONS := [
    {"name":"sidearm 9", "class":"handgun", "mag":15, "reserve":90, "damage":34.0, "rpm":430.0, "reload":1.5, "recoil":0.030, "spread":0.012},
    {"name":"sidearm .45", "class":"handgun", "mag":12, "reserve":72, "damage":45.0, "rpm":330.0, "reload":1.6, "recoil":0.038, "spread":0.014},
    {"name":"compact 9", "class":"smg", "mag":32, "reserve":128, "damage":23.0, "rpm":850.0, "reload":1.7, "recoil":0.020, "spread":0.020},
    {"name":"pdw", "class":"smg", "mag":30, "reserve":150, "damage":25.0, "rpm":780.0, "reload":1.8, "recoil":0.022, "spread":0.018},
    {"name":"carbine 5.56", "class":"rifle", "mag":30, "reserve":150, "damage":42.0, "rpm":700.0, "reload":1.9, "recoil":0.026, "spread":0.010},
    {"name":"patrol rifle", "class":"rifle", "mag":30, "reserve":180, "damage":46.0, "rpm":650.0, "reload":2.0, "recoil":0.030, "spread":0.009},
    {"name":"battle rifle", "class":"rifle", "mag":20, "reserve":100, "damage":62.0, "rpm":470.0, "reload":2.1, "recoil":0.040, "spread":0.012},
    {"name":"patrol smg", "class":"smg", "mag":40, "reserve":160, "damage":21.0, "rpm":900.0, "reload":1.8, "recoil":0.018, "spread":0.022},
    {"name":"pump 12g", "class":"shotgun", "mag":8, "reserve":48, "damage":24.0, "pellets":8, "rpm":80.0, "reload":2.6, "recoil":0.070, "spread":0.090},
    {"name":"breach 12g", "class":"shotgun", "mag":6, "reserve":42, "damage":28.0, "pellets":10, "rpm":95.0, "reload":2.8, "recoil":0.080, "spread":0.110},
    {"name":"service carbine", "class":"rifle", "mag":25, "reserve":125, "damage":39.0, "rpm":720.0, "reload":1.9, "recoil":0.028, "spread":0.012},
    {"name":"micro smg", "class":"smg", "mag":25, "reserve":150, "damage":19.0, "rpm":980.0, "reload":1.6, "recoil":0.024, "spread":0.026},
]

var player: CharacterBody3D
var camera: Camera3D
var weapon_holder: Node3D
var npc_root: Node3D
var ammo_label: Label
var status_label: Label
var weapon_label: Label
var objective_label: Label
var crosshair: Label
var bodycam: ColorRect
var fire_button: Button
var reload_button: Button
var aim_button: Button
var restrain_button: Button
var weapon_button: Button

var weapon_index := 4
var ammo := 30
var reserve := 150
var aiming := false
var reloading := false
var restraining := false
var recoil := 0.0
var fire_cooldown := 0.0
var score := 0
var suspects_remaining := 6
var restrained := 0
var mission_complete := false
var npcs: Array[Dictionary] = []

func _ready() -> void:
    player = $Player
    camera = $Player/Camera
    weapon_holder = $Player/Camera/WeaponHolder
    npc_root = $NPCs
    ammo_label = $HUD/Ammo
    status_label = $HUD/Status
    weapon_label = $HUD/Weapon
    objective_label = $HUD/Objective
    crosshair = $HUD/Crosshair
    bodycam = $HUD/Bodycam
    fire_button = $HUD/Controls/Fire
    reload_button = $HUD/Controls/Reload
    aim_button = $HUD/Controls/Aim
    restrain_button = $HUD/Controls/Restrain
    weapon_button = $HUD/Controls/Weapon
    _build_room()
    _spawn_npcs()
    _connect_controls()
    _equip_weapon()
    _update_hud()

func _physics_process(delta: float) -> void:
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    recoil = lerpf(recoil, 0.0, minf(1.0, delta * 10.0))
    _move_player(delta)
    _update_npcs(delta)
    if Input.is_action_pressed("fire") and fire_cooldown <= 0.0:
        fire_weapon()
    if Input.is_action_just_pressed("reload"):
        reload_weapon()
    if Input.is_action_just_pressed("interact"):
        restrain_nearest()
    camera.rotation.x = clampf(camera.rotation.x - recoil, -1.35, 1.35)
    weapon_holder.position.y = lerpf(weapon_holder.position.y, -0.03 - recoil * 0.4, delta * 12.0)

func _move_player(delta: float) -> void:
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := Vector3(input_vec.x, 0.0, input_vec.y)
    direction = player.global_transform.basis * direction
    direction.y = 0.0
    if direction.length_squared() > 0.0:
        direction = direction.normalized()
    var speed := 7.5 if Input.is_action_pressed("sprint") else 4.5
    player.velocity.x = direction.x * speed
    player.velocity.z = direction.z * speed
    if not player.is_on_floor():
        player.velocity.y -= 18.0 * delta
    else:
        player.velocity.y = 0.0
    player.move_and_slide()

func _build_room() -> void:
    _make_box(Vector3(0, -0.25, 0), Vector3(24, 0.5, 24))
    _make_box(Vector3(0, 2.5, -12), Vector3(24, 5, 0.5))
    _make_box(Vector3(0, 2.5, 12), Vector3(24, 5, 0.5))
    _make_box(Vector3(-12, 2.5, 0), Vector3(0.5, 5, 24))
    _make_box(Vector3(12, 2.5, 0), Vector3(0.5, 5, 24))
    _make_box(Vector3(-4, 1.0, -4), Vector3(3.0, 2.0, 0.5))
    _make_box(Vector3(4, 1.0, 2), Vector3(2.0, 2.0, 0.5))
    _make_box(Vector3(-5, 1.0, 5), Vector3(0.5, 2.0, 3.0))
    var light := OmniLight3D.new()
    light.position = Vector3(0, 5, 0)
    light.light_energy = 7.0
    light.omni_range = 20.0
    add_child(light)

func _make_box(position: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = position
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.16, 0.18, 0.19)
    material.roughness = 0.82
    mesh.material_override = material
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)

func _spawn_npcs() -> void:
    var points := [Vector3(-7, 1.0, -7), Vector3(6, 1.0, -7), Vector3(-7, 1.0, 0), Vector3(7, 1.0, 6), Vector3(-2, 1.0, 8), Vector3(7, 1.0, -1)]
    for i in range(points.size()):
        var body := CharacterBody3D.new()
        body.position = points[i]
        body.name = "Suspect_%02d" % (i + 1)
        var mesh := MeshInstance3D.new()
        var capsule := CapsuleMesh.new()
        capsule.height = 1.7
        capsule.radius = 0.35
        mesh.mesh = capsule
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.22, 0.25, 0.28)
        material.roughness = 0.95
        mesh.material_override = material
        body.add_child(mesh)
        var collider := CollisionShape3D.new()
        var shape := CapsuleShape3D.new()
        shape.height = 1.7
        shape.radius = 0.35
        collider.shape = shape
        body.add_child(collider)
        npc_root.add_child(body)
        npcs.append({"body": body, "health": 100.0, "alert": false, "restrained": false})

func _update_npcs(_delta: float) -> void:
    for npc in npcs:
        var body: CharacterBody3D = npc["body"]
        if not is_instance_valid(body) or npc["restrained"]:
            continue
        var to_player: Vector3 = player.global_position - body.global_position
        var distance := to_player.length()
        npc["alert"] = distance < 11.0
        if npc["alert"] and distance > 3.5:
            var direction := to_player.normalized()
            body.velocity = Vector3(direction.x * 0.8, body.velocity.y, direction.z * 0.8)
            body.move_and_slide()
        else:
            body.velocity.x = 0.0
            body.velocity.z = 0.0

func _connect_controls() -> void:
    fire_button.pressed.connect(fire_weapon)
    reload_button.pressed.connect(reload_weapon)
    aim_button.pressed.connect(toggle_aim)
    restrain_button.pressed.connect(restrain_nearest)
    weapon_button.pressed.connect(next_weapon)

func _equip_weapon() -> void:
    var weapon: Dictionary = WEAPONS[weapon_index]
    ammo = int(weapon["mag"])
    reserve = int(weapon["reserve"])
    for child in weapon_holder.get_children():
        child.queue_free()
    var model := Node3D.new()
    weapon_holder.add_child(model)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.045, 0.05, 0.055)
    material.metallic = 0.7
    material.roughness = 0.35
    var receiver := MeshInstance3D.new()
    var receiver_mesh := BoxMesh.new()
    receiver_mesh.size = Vector3(0.32, 0.20, 0.85)
    receiver.mesh = receiver_mesh
    receiver.position = Vector3(0.28, -0.18, -0.45)
    receiver.material_override = material
    model.add_child(receiver)
    var barrel := MeshInstance3D.new()
    var barrel_mesh := CylinderMesh.new()
    barrel_mesh.height = 0.72
    barrel_mesh.top_radius = 0.035
    barrel_mesh.bottom_radius = 0.035
    barrel.mesh = barrel_mesh
    barrel.rotation_degrees = Vector3(90, 0, 0)
    barrel.position = Vector3(0.28, -0.18, -0.98)
    barrel.material_override = material
    model.add_child(barrel)
    var grip := MeshInstance3D.new()
    var grip_mesh := BoxMesh.new()
    grip_mesh.size = Vector3(0.18, 0.42, 0.20)
    grip.mesh = grip_mesh
    grip.position = Vector3(0.28, -0.46, -0.18)
    grip.material_override = material
    model.add_child(grip)

func fire_weapon() -> void:
    if reloading or fire_cooldown > 0.0:
        return
    var weapon: Dictionary = WEAPONS[weapon_index]
    if ammo <= 0:
        status_label.text = "empty — reload"
        return
    ammo -= 1
    fire_cooldown = 60.0 / float(weapon["rpm"])
    recoil = float(weapon["recoil"])
    _muzzle_flash()
    if _raycast_shot(float(weapon["damage"]), int(weapon.get("pellets", 1)), float(weapon["spread"])):
        score += 100
    _update_hud()

func _raycast_shot(damage: float, pellets: int, spread: float) -> bool:
    var hit_any := false
    for _pellet in range(pellets):
        var origin := camera.global_position
        var forward := -camera.global_transform.basis.z
        forward = forward.rotated(camera.global_transform.basis.x, randf_range(-spread, spread))
        forward = forward.rotated(camera.global_transform.basis.y, randf_range(-spread, spread))
        var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * 80.0)
        query.exclude = [player]
        var result := get_world_3d().direct_space_state.intersect_ray(query)
        if result.is_empty():
            continue
        var collider: Object = result["collider"]
        for npc in npcs:
            if collider == npc["body"] and not npc["restrained"]:
                npc["health"] = float(npc["health"]) - damage
                hit_any = true
                if float(npc["health"]) <= 0.0:
                    _neutralize_npc(npc, 250)
                break
    _check_mission()
    return hit_any

func _neutralize_npc(npc: Dictionary, points: int) -> void:
    npc["restrained"] = true
    var body: CharacterBody3D = npc["body"]
    body.visible = false
    suspects_remaining -= 1
    score += points

func reload_weapon() -> void:
    if reloading:
        return
    var weapon: Dictionary = WEAPONS[weapon_index]
    var mag_size := int(weapon["mag"])
    if ammo >= mag_size or reserve <= 0:
        return
    reloading = true
    status_label.text = "reloading..."
    await get_tree().create_timer(float(weapon["reload"])).timeout
    var needed := mag_size - ammo
    var amount := mini(needed, reserve)
    ammo += amount
    reserve -= amount
    reloading = false
    _update_hud()

func toggle_aim() -> void:
    aiming = not aiming
    camera.fov = 52.0 if aiming else 76.0
    _update_hud()

func next_weapon() -> void:
    if reloading:
        return
    weapon_index = (weapon_index + 1) % WEAPONS.size()
    _equip_weapon()
    _update_hud()

func restrain_nearest() -> void:
    if restraining or mission_complete:
        return
    for npc in npcs:
        if npc["restrained"]:
            continue
        var body: CharacterBody3D = npc["body"]
        if player.global_position.distance_to(body.global_position) <= 2.5:
            restraining = true
            status_label.text = "restraining..."
            await get_tree().create_timer(1.0).timeout
            _neutralize_npc(npc, 400)
            restrained += 1
            restraining = false
            _check_mission()
            _update_hud()
            return
    status_label.text = "no suspect in restraint range"

func _check_mission() -> void:
    if suspects_remaining <= 0:
        mission_complete = true
        objective_label.text = "mission complete — scene secured"

func _muzzle_flash() -> void:
    var flash := OmniLight3D.new()
    flash.light_color = Color(1.0, 0.65, 0.25)
    flash.light_energy = 5.0
    flash.omni_range = 2.5
    flash.position = camera.global_position - camera.global_transform.basis.z * 1.2
    add_child(flash)
    get_tree().create_timer(0.05).timeout.connect(flash.queue_free)

func _update_hud() -> void:
    var weapon: Dictionary = WEAPONS[weapon_index]
    ammo_label.text = "%02d / %03d" % [ammo, reserve]
    weapon_label.text = "%s  |  %s" % [weapon["name"], weapon["class"]]
    if not reloading:
        status_label.text = "bodycam  •  %s" % ("aiming" if aiming else "ready")
    objective_label.text = "objective: clear suspects  •  remaining %d  •  restrained %d  •  score %04d" % [suspects_remaining, restrained, score]
    crosshair.text = "◉" if aiming else "+"
    bodycam.modulate.a = 0.13 if aiming else 0.08
