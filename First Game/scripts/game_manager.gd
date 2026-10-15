extends Node

var score = 0
@onready var pause_menu = $pausemenu
@onready var score_label = $ScoreLabel

func _ready() -> void:
	if Engine.has_singleton("SaveManager") or get_node_or_null("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		var saved_score = sm.get_score()
		if saved_score > 0 and score == 0:
			score = saved_score
			if score_label:
				score_label.text = "You collected " + str(score) + " coins."

func add_point():
	score += 1
	if score_label:
		score_label.text = "You collected " + str(score) + " coins."
	if Engine.has_singleton("SaveManager") or get_node_or_null("/root/SaveManager"):
		get_node("/root/SaveManager").set_score(score)

func pause_game():
	if pause_menu and pause_menu.has_method("pause"):
		pause_menu.pause()
