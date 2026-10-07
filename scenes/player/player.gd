extends CharacterBody3D
var speed
const SPRINT_SPEED = 10.0
const WALK_SPEED = 5.0
const CROUCH_SPEED = 1.5
const JUMP_VELOCITY = 5.5
const WALL_JUMP_VELOCITY = 5.0
const SENSITIVITY = 0.003

#health
signal health_changed(new_health)
var health = 100.0
var max_health = 100.0
var health_regen_cd = 0.0
var health_regen_rate = 5.0
var health_regen_flag = false
var can_regen = false

#stamina
signal stamina_changed(new_stamina)
var stamina = 100.0
var max_stamina = 100.0
const SPRINT_COST = 15.0
const stam_regen_rate = 30.0
var stam_regen_cd = 0.0
var can_use_stam = true
var stam_regen_flag = false

#dash
const DASH_SPEED = 17.5
const DASH_TIME = 0.2
var is_dashing = false
var can_dash = true
var dash_timer = 0.0
var dash_direction = Vector3.ZERO
const DASH_COST = 33
var dash_cooldown = 0

#head movement
const BOB_FREQ = 2.0
const BOB_AMP = 0.025
var t_bob = 0.0

#fov
const BASE_FOV = 75
const FOV_CHANGE = 1.5

#environment interactions
const HIT_STAGGER = 8.0
signal player_hit

var bullet = load("res://scenes/player/Bullet.tscn")
var instance

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var gun_anim = $Head/Camera3D/gun/AnimationPlayer
@onready var gun_barrel = $Head/Camera3D/gun/RayCast3D

func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	call_deferred("_connect_hud_bars")

func _connect_hud_bars():
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	var health_bar = get_tree().get_first_node_in_group("health_bar")
	if stamina_bar:
		stamina_bar.init_stamina(max_stamina)
		stamina_changed.connect(func(s): stamina_bar.stamina = s)
	if health_bar:
		health_bar.init_health(max_health)
		health_changed.connect(func(h): health_bar.health = h)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor() and !is_dashing:
		velocity += get_gravity() * delta

	if dash_cooldown > 0:
		dash_cooldown -= delta
	else:
		can_dash = true

	#stamina regen
	if stamina < max_stamina and stam_regen_cd <= 0:
		stamina += stam_regen_rate * delta
		stamina = min(stamina, max_stamina)

	if stamina <= 15 and !stam_regen_flag:
		can_use_stam = false
		stam_regen_flag = true

	if stam_regen_flag and stamina >= 40:
		can_use_stam = true
		stam_regen_flag = false

	if stam_regen_cd > 0.0:
		stam_regen_cd -= delta

	stamina = clamp(stamina, 0.0, max_stamina)
	stamina_changed.emit(stamina)

	#sprint
	if Input.is_action_pressed("sprint") and is_on_floor() and stamina >= SPRINT_COST and can_use_stam:
		speed = SPRINT_SPEED
		stam_regen_cd = 3.0
		stamina -= SPRINT_COST * delta
	elif Input.is_action_pressed("crouch") and is_on_floor():
		speed = CROUCH_SPEED
	else:
		speed = WALK_SPEED

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	#wall jump
	if Input.is_action_just_pressed("jump") and is_on_wall() and !is_on_floor():
		var wall_normal = get_wall_normal()
		velocity = wall_normal * WALL_JUMP_VELOCITY
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if is_dashing:
		velocity.x = dash_direction.x * DASH_SPEED
		velocity.z = dash_direction.z * DASH_SPEED
	else:
		if is_on_floor():
			if direction:
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed
			else:
				velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
				velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)

	# Head Bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	#FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	#dash
	if is_dashing:
		can_dash = false
		dash_cooldown = 999
		dash_timer -= delta
		velocity.x = dash_direction.x * DASH_SPEED
		velocity.z = dash_direction.z * DASH_SPEED
		if dash_timer <= 0:
			is_dashing = false
			dash_cooldown = 2

	if Input.is_action_just_pressed("dash") and can_dash and stamina >= DASH_COST and can_use_stam:
		start_dash()

	#shoot
	if Input.is_action_just_pressed("shoot"):
		if !gun_anim.is_playing():
			gun_anim.play("shoot")
			instance = bullet.instantiate()
			instance.position = gun_barrel.global_position
			instance.transform.basis = gun_barrel.global_transform.basis
			get_parent().add_child(instance)

	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time + BOB_FREQ) * BOB_AMP
	pos.x = sin(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func start_dash():
	stamina -= DASH_COST
	stam_regen_cd = 3.0
	stamina_changed.emit(stamina)

	var input_dir = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	if input_dir != Vector2.ZERO:
		dash_direction = head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	else:
		dash_direction = -head.global_transform.basis.z

	dash_direction.y = 0
	dash_direction = dash_direction.normalized()
	dash_timer = DASH_TIME
	is_dashing = true

func hit(dir):
	emit_signal("player_hit")
	velocity += dir * HIT_STAGGER

func take_damage(amount: float):
	health -= amount
	health = clamp(health, 0.0, max_health)
	health_changed.emit(health)
