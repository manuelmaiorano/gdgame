extends CharacterBody3D

const BULLET_VELOCITY = 20

var time_alive = 5
var hit = false

@onready var collision_shape = $CollisionShape3D

func _ready():
	if not multiplayer.is_server():
		set_physics_process(false)
		collision_shape.disabled = true


func _physics_process(delta):
	if hit:
		destroy()
		return
	time_alive -= delta
	if time_alive < 0:
		hit = true
		explode.rpc()
	var col = move_and_collide(-delta * BULLET_VELOCITY * transform.basis.z)
	if col:
		var collider = col.get_collider()
		if collider and collider.has_method("hit"):
			collider.hit.rpc()
		collision_shape.disabled = true
		explode.rpc()
		hit = true


@rpc("call_local")
func explode():
	# Only enable shadows for the explosion, as the moving light
	# is very small and doesn't noticeably benefit from shadow mapping.
	pass


func destroy():
	if not multiplayer.is_server():
		return
	queue_free()
