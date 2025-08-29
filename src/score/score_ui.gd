extends Control

# Player Name Labels (New)
@onready var player_name_p_1 = $PanelScore/Players/Player1
@onready var player_name_p_2 = $PanelScore/Players/Player2
@onready var player_name_p_3 = $PanelScore/Players/Player3
@onready var player_name_p_4 = $PanelScore/Players/Player4

# Player 1
@onready var alive_tokens_p_1 = $PanelScore/PlayerScore/Player1/AliveTokensP1
@onready var claimed_points_p_1 = $PanelScore/PlayerScore/Player1/ClaimedPointsP1
@onready var biome_points_p_1 = $PanelScore/PlayerScore/Player1/BiomePointsP1
@onready var pattern_completion_p_1 = $PanelScore/PlayerScore/Player1/PatternCompletionP1
@onready var total_p_1 = $PanelScore/PlayerScore/Player1/TotalP1

# Player 2
@onready var alive_tokens_p_2 = $PanelScore/PlayerScore/Player2/AliveTokensP2
@onready var claimed_points_p_2 = $PanelScore/PlayerScore/Player2/ClaimedPointsP2
@onready var biome_points_p_2 = $PanelScore/PlayerScore/Player2/BiomePointsP2
@onready var pattern_completion_p_2 = $PanelScore/PlayerScore/Player2/PatternCompletionP2
@onready var total_p_2 = $PanelScore/PlayerScore/Player2/TotalP2

# Player 3
@onready var alive_tokens_p_3 = $PanelScore/PlayerScore/Player3/AliveTokensP3
@onready var claimed_points_p_3 = $PanelScore/PlayerScore/Player3/ClaimedPointsP3
@onready var biome_points_p_3 = $PanelScore/PlayerScore/Player3/BiomePointsP3
@onready var pattern_completion_p_3 = $PanelScore/PlayerScore/Player3/PatternCompletionP3
@onready var total_p_3 = $PanelScore/PlayerScore/Player3/TotalP3

# Player 4
@onready var alive_tokens_p_4 = $PanelScore/PlayerScore/Player4/AliveTokensP4
@onready var claimed_points_p_4 = $PanelScore/PlayerScore/Player4/ClaimedPointsP4
@onready var biome_points_p_4 = $PanelScore/PlayerScore/Player4/BiomePointsP4
@onready var pattern_completion_p_4 = $PanelScore/PlayerScore/Player4/PatternCompletionP4
@onready var total_p_4 = $PanelScore/PlayerScore/Player4/TotalP4


# Helper to get player name labels
func _get_player_name_labels() -> Array[Label]:
	return [
		player_name_p_1,
		player_name_p_2,
		player_name_p_3,
		player_name_p_4
	]

func _get_player_labels(player_index: int) -> Dictionary:
	match player_index:
		0: # Player 1
			return {
				"unblighted": alive_tokens_p_1,
				"claimed": claimed_points_p_1,
				"biome": biome_points_p_1,
				"sigil": pattern_completion_p_1,
				"total" : total_p_1
			}
		1: # Player 2
			return {
				"unblighted": alive_tokens_p_2,
				"claimed": claimed_points_p_2,
				"biome": biome_points_p_2,
				"sigil": pattern_completion_p_2,
				"total" : total_p_2
			}
		2: # Player 3
			return {
				"unblighted": alive_tokens_p_3,
				"claimed": claimed_points_p_3,
				"biome": biome_points_p_3,
				"sigil": pattern_completion_p_3,
				"total" : total_p_3
			}
		3: # Player 4
			return {
				"unblighted": alive_tokens_p_4,
				"claimed": claimed_points_p_4,
				"biome": biome_points_p_4,
				"sigil": pattern_completion_p_4,
				"total" : total_p_4
			}
		_:
			return {}

# Updates the player name labels
func update_player_names():
	var game = get_node_or_null("/root/Game")
	if not game:
		printerr("ScoreUI: Could not find Game node.")
		return

	var name_labels = _get_player_name_labels()
	var initial_order = game.initial_player_order
	var names = game.player_names

	for i in range(name_labels.size()):
		var label = name_labels[i]
		if not is_instance_valid(label): continue

		if i < initial_order.size():
			var player_id = initial_order[i]
			# Fetch the name from the game's dictionary, with a default fallback.
			var player_name = names.get(player_id, "Player %d" % (i + 1))
			label.text = player_name
		else:
			# If no player exists for this slot, revert to default.
			label.text = "Player %d" % (i + 1)

func update_player_scores(player_id: int, scores: Dictionary):
	var game = get_node("/root/Game")
	if not game: return

	# Find the player's index in the permanent initial_player_order array
	var player_index = game.initial_player_order.find(player_id)

	if player_index == -1:
		print("Warning: Player ID %d not found in initial_player_order for score update." % player_id)
		return

	var labels = _get_player_labels(player_index)
	if labels.is_empty(): return
	
	labels.unblighted.text = str(scores.get("unblighted", 0))
	labels.claimed.text = str(scores.get("claimed", 0))
	labels.biome.text = str(scores.get("biome", 0))
	labels.sigil.text = str(scores.get("sigil", 0))
	labels.total.text = str(scores.get("total", 0))

@rpc("any_peer", "call_local")
func show_scores():
	update_player_names()
	self.show()
