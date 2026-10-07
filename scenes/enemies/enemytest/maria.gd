extends CharacterBody3D

var player = null
var state_machine
var health = 10 
const SPEED = 4.0
const ATTACK_RANGE = 2.5


@export var player_path := "/root/Game/Player"

#@export var player_path : NodePath
@onready var nav_agent = $NavigationAgent3D
@onready var anim_tree = $AnimationTree

func _ready():
	player = get_tree().get_first_node_in_group("player")
	call_deferred("_find_player")
	state_machine = anim_tree.get("parameters/playback")

func _find_player():
	player = get_node(player_path)

func _process(delta):
	velocity = Vector3.ZERO
	
	match state_machine.get_current_node():
		"run":
			#nav
			nav_agent.set_target_position(player.global_transform.origin)
			var next_nav_point = nav_agent.get_next_path_position()
			velocity = (next_nav_point - global_transform.origin).normalized() * SPEED
			look_at(Vector3(global_position.x + velocity.x, global_position.y, player.global_position.z + velocity.z), Vector3.UP, true)
		"punch":
			#look towards target y is not player to not make it look up
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP, true)
	
	
	#look towards target y is not player to not make it look up
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP, true)
	
	#attack condition
	anim_tree.set("parameters/conditions/attack", _target_in_range())
	#attack to run condition
	anim_tree.set("parameters/conditions/run", !_target_in_range())
	
	move_and_slide()

func _target_in_range():
	return global_position.distance_to(player.global_position) < ATTACK_RANGE
	
func _hit_finished():
	if global_position.distance_to(player.global_position) < ATTACK_RANGE + 1:
		var dir = global_position.direction_to(player.global_position)
		player.hit(dir)


func _on_head_collider_body_part_hit(dam: Variant) -> void:
	health -= dam
	if health <= 0:
		queue_free()
