extends Area2D

## Gravity multiplier inside this zone (0.2 = low floaty gravity, -0.5 = reverse gravity)
@export var gravity_scale: float = 0.25

## Upward float velocity applied to the player (e.g. -180.0 for vertical stream ascension)
@export var upward_thrust: float = -180.0

## If true, continuously lifts the player upward like an anti-gravity energy beam
@export var is_uplift_stream: bool = true

@onready var particles: CPUParticles2D = get_node_or_null("CPUParticles2D")
@onready var enter_sfx: AudioStreamPlayer = get_node_or_null("EnterSFX")

func _ready() -> void:
	collision_mask = 2 # Detect Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_anti_gravity"):
		body.set_anti_gravity(gravity_scale, upward_thrust if is_uplift_stream else 0.0)
		if enter_sfx and not enter_sfx.playing:
			enter_sfx.play()

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("reset_anti_gravity"):
		body.reset_anti_gravity()
