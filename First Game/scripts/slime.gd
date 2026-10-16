extends CharacterBody2D

## Dynamic Multi-State Slime Enemy
## Implements rhythmic hopping patrol, player detection with attack telegraphing & lunge,
## post-attack recovery, squash & stretch juice, hit flash, and optional split-on-death.

enum State {
	IDLE,
	HOP,
	AGGRO_WINDUP,
	LUNGE,
	RECOVERY,
	DEAD
}

@export_group("Stats & Combat")
@export var max_health: int = 1
@export var can_split: bool = false
@export var detection_radius: float = 95.0

@export_group("Movement Tuning")
@export var patrol_speed: float = 45.0
@export var jump_force: float = 125.0
@export var lunge_speed: float = 140.0
@export var recovery_time: float = 0.65
@export var hop_interval_min: float = 0.5
@export var hop_interval_max: float = 1.0

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var killzone: Area2D = $Killzone
@onready var killzone_shape: CollisionShape2D = $Killzone/CollisionShape2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox")
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")
@onready var detection_shape: CollisionShape2D = get_node_or_null("DetectionArea/CollisionShape2D")
@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft
@onready var ray_cast_ledge_right: RayCast2D = get_node_or_null("RayCastLedgeRight")
@onready var ray_cast_ledge_left: RayCast2D = get_node_or_null("RayCastLedgeLeft")
@onready var splatter_particles: CPUParticles2D = get_node_or_null("SplatterParticles")
@onready var hop_sfx: AudioStreamPlayer2D = get_node_or_null("HopSound")
@onready var hurt_sfx: AudioStreamPlayer2D = get_node_or_null("HurtSound")

# Runtime state
var current_state: State = State.IDLE
var current_health: int = 1
var direction: int = 1
var target_player: CharacterBody2D = null
var state_timer: float = 0.0
var is_dead: bool = false
var _is_jumping: bool = false
var _original_sprite_scale: Vector2 = Vector2.ONE
var _active_tween: Tween = null

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	current_health = max_health
	if animated_sprite:
		_original_sprite_scale = animated_sprite.scale
	
	# Configure detection radius dynamically from exported property
	if detection_shape and detection_shape.shape is CircleShape2D:
		detection_shape.shape = detection_shape.shape.duplicate()
		detection_shape.shape.radius = detection_radius
	
	# Initial random pause before first patrol hop
	state_timer = randf_range(hop_interval_min, hop_interval_max)
	_play_anim("idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.HOP:
			_process_hop_state(delta)
		State.AGGRO_WINDUP:
			_process_aggro_windup_state(delta)
		State.LUNGE:
			_process_lunge_state(delta)
		State.RECOVERY:
			_process_recovery_state(delta)

	move_and_slide()

# ==============================================================================
# STATE MACHINE LOGIC
# ==============================================================================

func _process_idle_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 350.0 * delta)
	
	# Check for player aggro
	if _can_detect_player():
		_enter_aggro_windup()
		return
	
	state_timer -= delta
	if state_timer <= 0.0 and is_on_floor():
		_start_hop()

func _start_hop() -> void:
	_check_patrol_turnaround()
	current_state = State.HOP
	_is_jumping = true
	
	# Visual squash before leaping
	_kill_active_tween()
	_active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(animated_sprite, "scale", _original_sprite_scale * Vector2(1.25, 0.75), 0.08)
	_active_tween.tween_callback(func():
		velocity.y = -jump_force
		velocity.x = direction * patrol_speed
		_play_anim("default")
		if hop_sfx:
			hop_sfx.pitch_scale = randf_range(0.95, 1.05)
			hop_sfx.play()
		
		# Vertical stretch during ascent
		var stretch_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stretch_tween.tween_property(animated_sprite, "scale", _original_sprite_scale * Vector2(0.8, 1.25), 0.12)
		stretch_tween.tween_property(animated_sprite, "scale", _original_sprite_scale, 0.15)
	)

func _process_hop_state(_delta: float) -> void:
	# Reverse if bumping into walls during hop
	if is_on_wall():
		direction = -direction
		_update_sprite_flip()
		velocity.x = direction * patrol_speed
	
	# Landing check
	if _is_jumping and velocity.y >= 0.0 and is_on_floor():
		_is_jumping = false
		velocity.x = 0.0
		_landing_squash()
		
		# Check if player was spotted during the hop
		if _can_detect_player():
			_enter_aggro_windup()
		else:
			current_state = State.IDLE
			state_timer = randf_range(hop_interval_min, hop_interval_max)
			_play_anim("idle")

func _enter_aggro_windup() -> void:
	current_state = State.AGGRO_WINDUP
	velocity.x = 0.0
	state_timer = 0.45
	
	# Face the player
	if is_instance_valid(target_player):
		direction = 1 if target_player.global_position.x > global_position.x else -1
		_update_sprite_flip()
	
	# Squash down and pulse reddish/golden to telegraph attack clearly
	_kill_active_tween()
	_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(animated_sprite, "scale", _original_sprite_scale * Vector2(1.35, 0.65), 0.2)
	_active_tween.tween_property(animated_sprite, "modulate", Color(1.3, 0.6, 0.6, 1.0), 0.2)
	_play_anim("idle")

func _process_aggro_windup_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	
	# Keep facing target player during windup
	if is_instance_valid(target_player):
		var desired_dir = 1 if target_player.global_position.x > global_position.x else -1
		if desired_dir != direction:
			direction = desired_dir
			_update_sprite_flip()
	
	state_timer -= delta
	if state_timer <= 0.0 and is_on_floor():
		_execute_lunge()

func _execute_lunge() -> void:
	current_state = State.LUNGE
	_is_jumping = true
	
	# Recalculate lunge vector toward player's position
	if is_instance_valid(target_player):
		direction = 1 if target_player.global_position.x > global_position.x else -1
		_update_sprite_flip()
	
	velocity.x = direction * lunge_speed
	velocity.y = -jump_force * 1.35
	
	# Audio feedback
	if hop_sfx:
		hop_sfx.pitch_scale = 1.25
		hop_sfx.play()
	
	# Dynamic stretch in flight and reset telegraph modulate
	_kill_active_tween()
	_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(animated_sprite, "scale", _original_sprite_scale * Vector2(0.7, 1.35), 0.12)
	_active_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
	
	_play_anim("default")

func _process_lunge_state(_delta: float) -> void:
	# Landing from lunge
	if _is_jumping and velocity.y >= 0.0 and is_on_floor():
		_is_jumping = false
		velocity.x = 0.0
		_landing_squash()
		_enter_recovery()

func _enter_recovery() -> void:
	current_state = State.RECOVERY
	state_timer = recovery_time
	_play_anim("idle")

func _process_recovery_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 350.0 * delta)
	
	state_timer -= delta
	if state_timer <= 0.0 and is_on_floor():
		if _can_detect_player():
			_enter_aggro_windup()
		else:
			current_state = State.IDLE
			state_timer = randf_range(hop_interval_min, hop_interval_max)

# ==============================================================================
# SENSORS & NAVIGATION
# ==============================================================================

func _can_detect_player() -> bool:
	if not is_instance_valid(target_player):
		return false
	var dist = global_position.distance_to(target_player.global_position)
	return dist <= detection_radius

func _check_patrol_turnaround() -> void:
	# Check horizontal wall collisions
	if direction == 1 and ray_cast_right and ray_cast_right.is_colliding():
		direction = -1
	elif direction == -1 and ray_cast_left and ray_cast_left.is_colliding():
		direction = 1
	
	# Check platform edge / cliff sensors
	elif is_on_floor():
		if direction == 1 and ray_cast_ledge_right and not ray_cast_ledge_right.is_colliding():
			direction = -1
		elif direction == -1 and ray_cast_ledge_left and not ray_cast_ledge_left.is_colliding():
			direction = 1
	
	_update_sprite_flip()

func _update_sprite_flip() -> void:
	if animated_sprite:
		animated_sprite.flip_h = (direction < 0)

# ==============================================================================
# JUICE: SQUASH, STRETCH, & FLASH
# ==============================================================================

func _landing_squash() -> void:
	_kill_active_tween()
	_active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(animated_sprite, "scale", _original_sprite_scale * Vector2(1.25, 0.75), 0.08)
	_active_tween.tween_property(animated_sprite, "scale", _original_sprite_scale, 0.12)

func _kill_active_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

func _play_anim(anim_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)
		elif animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")

# ==============================================================================
# DAMAGE, COMBAT, & SPLIT ON DEATH
# ==============================================================================

## External API hook: allows player or hazards to damage the slime
func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	
	current_health -= amount
	
	# Audio feedback
	if hurt_sfx:
		hurt_sfx.pitch_scale = randf_range(1.1, 1.3)
		hurt_sfx.play()
	
	# Damage flash (White -> Red -> Normal)
	_kill_active_tween()
	var flash_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(animated_sprite, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.06)
	flash_tween.tween_property(animated_sprite, "modulate", Color(1.5, 0.2, 0.2, 1.0), 0.06)
	flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()

## Called when the slime is defeated
func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_state = State.DEAD
	velocity = Vector2.ZERO
	
	# Disable all hostile collision shapes immediately
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	if killzone:
		killzone.set_deferred("monitoring", false)
		killzone.set_deferred("monitorable", false)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	
	# Particle splatter burst
	if splatter_particles:
		splatter_particles.emitting = true
	
	_play_anim("hurt")
	
	# Split into 2 mini-slimes if configured
	if can_split:
		_spawn_splits()
	
	# Death flatten & fade-out tween
	_kill_active_tween()
	var death_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death_tween.tween_property(animated_sprite, "scale", _original_sprite_scale * Vector2(1.5, 0.15), 0.16)
	death_tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.18)
	await death_tween.finished
	queue_free()

## Instantiates two smaller, agile mini-slimes upon defeat
func _spawn_splits() -> void:
	var slime_scene = load("res://scenes/slime.tscn")
	if not slime_scene:
		return
	
	for offset_dir in [-1, 1]:
		var mini_slime = slime_scene.instantiate()
		mini_slime.scale = scale * 0.6
		mini_slime.can_split = false # Prevent infinite recursive splitting
		mini_slime.max_health = 1
		mini_slime.patrol_speed = patrol_speed * 1.25
		mini_slime.jump_force = jump_force * 0.85
		mini_slime.lunge_speed = lunge_speed * 1.15
		mini_slime.detection_radius = detection_radius * 0.75
		mini_slime.global_position = global_position + Vector2(offset_dir * 8.0, -4.0)
		mini_slime.direction = offset_dir
		
		get_parent().call_deferred("add_child", mini_slime)
		mini_slime.set_deferred("velocity", Vector2(offset_dir * 70.0, -90.0))

# ==============================================================================
# SIGNAL CALLBACKS
# ==============================================================================

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		target_player = body
		if current_state == State.IDLE and is_on_floor():
			_enter_aggro_windup()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null

## Stomp detection from above (Mario-style weakpoint)
func _on_hurtbox_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		# Verify player is falling downward onto the slime's head
		if body.velocity.y > 0.0 and body.global_position.y < global_position.y - 4.0:
			# Temporarily disable killzone so player isn't killed on the same frame
			if killzone:
				killzone.set_deferred("monitoring", false)
				killzone.set_deferred("monitorable", false)
			
			# Bounce player upward
			body.velocity.y = -230.0
			take_damage(1)
