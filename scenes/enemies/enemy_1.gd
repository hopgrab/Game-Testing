extends CharacterBody3D

var player = null
const SPEED = 4.0

@export var player_path : NodePath
@onready var nav_agent = $NavigationAgent3D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	call_deferred("_find_player")

func _find_player():
	player = get_node(player_path)

func _process(delta):
	velocity = Vector3.ZERO
	nav_agent.set_target_position(player.global_transform.origin)
	var next_nav_point = nav_agent.get_next_path_position()
	velocity = (next_nav_point - global_transform.origin).normalized() * SPEED
	move_and_slide()
