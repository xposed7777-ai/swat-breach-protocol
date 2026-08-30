extends Node3D

var player: CharacterBody3D
var camera: Camera3D
var speed := 4.5
var sprint_speed := 7.0
var gravity := 18.0
var ammo := 15
var magazine := 15
var reserve := 90
var aiming := false
var firing := false

func _ready() -> void:
    player = $Player
    camera = $Player/Camera
    _build_room()
    _connect_mobile_buttons()

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := Vector3(input_vec.x, 0.0, input_vec.y)
    var basis_dir := player.global_transform.basis * direction
    basis_dir.y = 0.0
    basis_dir = basis_dir.normalized()
    var current_speed := sprint_speed if Input.is_action_pressed("sprint") else speed
    player.velocity.x = basis_dir.x * current_speed
    player.velocity.z = basis_dir.z * current_speed
    if not player.is_on_floor():
        player.velocity.y -= gravity * delta
    else:
        player.velocity.y = 0.0
    player.move_and_slide()
    if Input.is_action_just_pressed("reload"):
        reload_weapon()
    if Input.is_action_just_pressed("fire"):
        fire_weapon()

func fire_weapon() -> void:
    if ammo <= 0:
        return
    ammo -= 1
    _update_hud()

func reload_weapon() -> void:
    var needed := magazine - ammo
    var amount := mini(needed, reserve)
    ammo += amount
    reserve -= amount
    _update_hud()

func _build_room() -> void:
    _make_box(Vector3(0, -0.25, 0), Vector3(20, 0.5, 20))
    _make_box(Vector3(0, 2.0, -10), Vector3(20, 4, 0.5))
    _make_box(Vector3(0, 2.0, 10), Vector3(20, 4, 0.5))
    _make_box(Vector3(-10, 2.0, 0), Vector3(0.5, 4, 20))
    _make_box(Vector3(10, 2.0, 0), Vector3(0.5, 4, 20))
    for z in [-5.0, 0.0, 5.0]:
        _make_box(Vector3(-3, 1.0, z), Vector3(0.4, 2, 2.0))
        _make_box(Vector3(4, 1.0, z), Vector3(0.4, 2, 2.0))

func _make_box(position: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = position
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)

func _connect_mobile_buttons() -> void:
    var fire_button := get_node_or_null("HUD/MobileControls/Fire")
    var reload_button := get_node_or_null("HUD/MobileControls/Reload")
    var aim_button := get_node_or_null("HUD/MobileControls/Aim")
    if fire_button:
        fire_button.pressed.connect(fire_weapon)
    if reload_button:
        reload_button.pressed.connect(reload_weapon)
    if aim_button:
        aim_button.pressed.connect(_toggle_aim)
    _update_hud()

func _toggle_aim() -> void:
    aiming = not aiming
    camera.fov = 55.0 if aiming else 75.0

func _update_hud() -> void:
    var status := get_node_or_null("HUD/Status")
    if status:
        status.text = "BREACH PROTOCOL  |  AMMO %02d / %02d  |  %s" % [ammo, reserve, "AIM" if aiming else "READY"]
