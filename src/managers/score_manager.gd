# score_manager.gd
extends Node

# References to other managers
@onready var game = get_parent()
@onready var token_manager = $"../TokenManager"
@onready var point_counter = $"../PointCounter"
@onready var game_state_manager = $"../GameStateManager"
@onready var elementals_manager = $"../ElementalsManager"

enum BiomeType {
	FOREST,
	WATER,
	MOUNTAIN,
	DESERT
}

# Score multipliers
const CLAIMED_POINT_SCORE = 2
const BIOME_POINT_SCORE = 2
const SIGIL_COMBINATION_SCORE = 1

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
	print('total score after count own tokens : ', total_score)
	# 2. Claimed Points Score
	total_score += _calculate_claimed_points_score(player_id)
	print('total score after claimed point score : ', total_score)
	# 3. Biome Points Score
	total_score += _calculate_biome_points_score(player_id)
	print('total score after biome points score : ', total_score)
	# 4. Sigil Combination Score
	total_score += _calculate_sigil_combination_score(player_id)
	print('total score after sigil combination : ', total_score)
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
			if token_placement:
				token_count += 1
	return token_count

# Calculate score from claimed points in PlayerHUD
func _calculate_claimed_points_score(player_id: int) -> int:
	var player_hud = game.get_node_or_null("PlayerUIs/Player_" + str(player_id) + "_UI")
	if player_hud and player_hud.has_node("Points"):
		var points_node = player_hud.get_node("Points")
		if "current_point" in points_node:
			print("current point : ", points_node.current_point)
			return points_node.current_point * CLAIMED_POINT_SCORE
	return 0

# Calculate score from biome points (converted from mana)
func _calculate_biome_points_score(player_id: int) -> int:
	var total_biome_score = 0
	
	var domination_manager = game.get_node_or_null("DominationManager")
	if not domination_manager:
		printerr("ScoreManager Error: DominationManager not found!")
		return 0

	var biome_data_map = {
		point_counter.Biome.FOREST: {
			"points": point_counter.forest_points,
			"mana": point_counter.forest_magic_points
		},
		point_counter.Biome.WATER: {
			"points": point_counter.water_points,
			"mana": point_counter.water_magic_points
		},
		point_counter.Biome.MOUNTAIN: {
			"points": point_counter.mountain_points,
			"mana": point_counter.mountain_magic_points
		},
		point_counter.Biome.DESERT: {
			"points": point_counter.desert_points,
			"mana": point_counter.desert_magic_points
		}
	}
	
	for biome_type in biome_data_map:
		# Check if the half-points elemental effect is active for this biome
		var current_biome_point_score = BIOME_POINT_SCORE # Default score is 2
		if elementals_manager and elementals_manager.half_points_biome == biome_type:
			current_biome_point_score = 1 # Apply the effect, making the score 1
			print("Applying half points effect for biome %d. Score per point is now %d." % [biome_type, current_biome_point_score])
		
		var dominant_players = domination_manager._get_all_dominant_players_in_biome(biome_type)
		
		# --- NEW TIE-BREAKING LOGIC ---
		match dominant_players.size():
			1: # Case 1: A single player dominates.
				if player_id in dominant_players:
					var biome_data = biome_data_map[biome_type]
					# --- MODIFICATION: Use the variable score multiplier ---
					var points_score = biome_data["points"] * current_biome_point_score
					print("points score : ", points_score)
					var mana_score = floor(biome_data["mana"] / 2.0)
					print('mana score : ', mana_score)
					total_biome_score += points_score + mana_score
			
			2: # Case 2: Exactly two players are tied.
				if player_id in dominant_players:
					var biome_data = biome_data_map[biome_type]
					
					# Distribute points: each player gets half, odd points are discarded.
					var points_per_player = floor(biome_data["points"] / 2.0)
					print('points per player : ', points_per_player)
					# --- MODIFICATION: Use the variable score multiplier ---
					var points_score = points_per_player * current_biome_point_score
					
					# Distribute mana: each player gets half, odd mana is discarded.
					var mana_per_player = floor(biome_data["mana"] / 2.0)
					print('mana per player : ', mana_per_player)
					var mana_score = floor(mana_per_player / 2.0)
					
					total_biome_score += points_score + mana_score

			_: # Default Case: More than two players are tied, or no one dominates.
				# No points are awarded in this case.
				pass
				
	return total_biome_score

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
