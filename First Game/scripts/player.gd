extends CharacterBody2D


const SPEED = 130.0
const JUMP_VELOCITY = -300.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Anti-gravity mechanics support
var anti_gravity_modifier: float = 1.0
var anti_gravity_uplift: float = 0.0

@onready var animated_sprite = $AnimatedSprite2D

func _physics_process(delta):
	# Add the gravity (affected by anti-gravity mechanics).
	if not is_on_floor():
		velocity.y += (gravity * anti_gravity_modifier) * delta

	# Apply active vertical uplift if inside an anti-gravity stream
	if anti_gravity_uplift != 0.0:
		velocity.y = move_toward(velocity.y, anti_gravity_uplift, 800.0 * delta)

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction: -1, 0, 1
	var direction = Input.get_axis("move_left", "move_right")
	
	# Flip the Sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
	
	# Play animations
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump")
	
	# Apply movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

## External API for anti-gravity puzzle fields / streams
func set_anti_gravity(modifier: float = 0.25, uplift: float = 0.0) -> void:
	anti_gravity_modifier = modifier
	anti_gravity_uplift = uplift

func reset_anti_gravity() -> void:
	anti_gravity_modifier = 1.0
	anti_gravity_uplift = 0.0
