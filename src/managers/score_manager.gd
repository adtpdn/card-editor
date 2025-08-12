# score_manager.gd
extends Node

# References to other managers
@onready var game = get_parent()
@onready var token_manager = $"../TokenManager"
@onready var point_counter = $"../PointCounter"
@onready var game_state_manager = $"../GameStateManager"

# Score multipliers
const CLAIMED_POINT_SCORE = 2
const BIOME_POINT_SCORE = 2
const SIGIL_COMBINATION_SCORE = 2

# Sigil Patterns from the image provided by the user
const SIGIL_PATTERNS = [
	# Sigil A Patterns
	[[1, 2, 7], [2, 3, 7], [4, 5, 7], [5, 6, 7]],
	# Sigil B Patterns
	[[1, 2, 3], [2, 5, 7], [4, 5, 6]],
	# Sigil C Patterns
	[[1, 6, 7], [3, 4, 7]]
]

# --- Public API ---

# Function to calculate the total score for a single player
func calculate_player_score(player_id: int) -> int:
	var total_score = 0
	
	# 1. Unblighted Tokens Score (Points per biome occupied)
	total_score += _calculate_unblighted_token_score(player_id)
	
	# 2. Claimed Points Score
	total_score += _calculate_claimed_points_score(player_id)
	
	# 3. Biome Points Score
	total_score += _calculate_biome_points_score(player_id)
	
	# 4. Sigil Combination Score
	total_score += _calculate_sigil_combination_score(player_id)
	
	return total_score

# --- Score Calculation Logic ---

# NEW LOGIC: Calculate score based on the total number of unblighted tokens on biome placements.
func _calculate_unblighted_token_score(player_id: int) -> int:
	# This rule now applies to all rounds, including round 0.
	# The score is the total count of unblighted tokens on biome placements (place_id = -1).
	var token_count = 0
	for token in game.get_node("Tokens").get_children():
		if token.owner_id == player_id and not token.is_blighted:
			var token_placement = token_manager.get_token_placement_at_position(token.global_position)
			if token_placement and token_placement.place_id == -1:
				token_count += 1
	return token_count

# Calculate score from claimed points in PlayerHUD
func _calculate_claimed_points_score(player_id: int) -> int:
	var player_hud = game.get_node_or_null("PlayerUIs/Player_" + str(player_id) + "_UI")
	if player_hud and player_hud.has_node("Points"):
		var points_node = player_hud.get_node("Points")
		if "current_point" in points_node:
			return points_node.current_point * CLAIMED_POINT_SCORE
	return 0

# Calculate score from biome points (converted from mana)
func _calculate_biome_points_score(player_id: int) -> int:
	# This logic assumes that mana is converted to points at the end of the game
	# or at specific scoring moments, and that each player gets points from the global mana pool
	# based on some criteria (e.g., divided equally, or based on contribution - for now, we'll assume it's global)
	
	# This part of the logic might need adjustment based on how you want to attribute the global mana pool to players.
	# For now, this will return 0 until player-specific mana tracking is implemented.
	return 0

# Calculate score from sigil pattern combinations
func _calculate_sigil_combination_score(player_id: int) -> int:
	var combination_score = 0
	var player_tokens_by_biome = {}

	for token in game.get_node("Tokens").get_children():
		if token.owner_id == player_id:
			var placement = token_manager.get_token_placement_at_position(token.global_position)
			if placement and placement.place_id > 0:
				if not player_tokens_by_biome.has(token.biome_type):
					player_tokens_by_biome[token.biome_type] = []
				player_tokens_by_biome[token.biome_type].append(placement.place_id)

	for biome in player_tokens_by_biome:
		var token_place_ids = player_tokens_by_biome[biome]
		for pattern_group in SIGIL_PATTERNS:
			for pattern in pattern_group:
				var pattern_found = true
				for place_id in pattern:
					if not place_id in token_place_ids:
						pattern_found = false
						break
				if pattern_found:
					combination_score += SIGIL_COMBINATION_SCORE
					
	return combination_score

# --- Networking ---

func update_and_sync_all_scores():
	if not multiplayer.is_server():
		return
		
	for player_id in game.players:
		var score = calculate_player_score(player_id)
		sync_score_for_player.rpc(player_id, score)

@rpc("any_peer", "call_local")
func sync_score_for_player(player_id: int, score: int):
	var player_hud = game.get_node_or_null("PlayerUIs/Player_" + str(player_id) + "_UI")
	if player_hud and player_hud.has_node("ScoreDisplay"):
		var score_display = player_hud.get_node("ScoreDisplay")
		score_display.update_score(score)
