# domination.gd
extends Node

# --- Manager and node references ---
@onready var game = get_node("/root/Game")


## Checks all biomes to find which player has the most non-blighted tokens.
# This function should only be called on the server.
func check_domination_biomes() -> void:
	if not multiplayer.is_server():
		return # Domination logic is handled by the server to ensure consistency.

	print("--- Checking Biome Domination ---")

	# This dictionary will store the total stars to be awarded this turn.
	# We calculate all awards first, then send them.
	# Format: { player_id: stars_to_add, player_id_2: stars_to_add, ... }
	var stars_awarded_this_turn = {}
	for player_id in game.players:
		stars_awarded_this_turn[player_id] = 0

	# --- Loop through each of the four biomes ---
	for biome_value in TokenManager.BiomeType.values():
		var biome_name = TokenManager.BiomeType.keys()[biome_value]
		var player_token_counts = {}

		# Initialize counts for this biome
		for player_id in game.players:
			player_token_counts[player_id] = 0

		# Count non-blighted tokens for each player in the current biome
		for token in game.tokens.get_children():
			if token.biome_type == biome_value and not token.is_blighted:
				if player_token_counts.has(token.owner_id):
					player_token_counts[token.owner_id] += 1

		# --- Determine the winner(s) for this biome ---
		var winners = []
		var max_count = 0

		# First, find the highest token count in this biome
		for player_id in player_token_counts:
			if player_token_counts[player_id] > max_count:
				max_count = player_token_counts[player_id]

		# Second, find all players who achieved that high score.
		# This correctly handles both single winners and ties.
		if max_count > 0:
			for player_id in player_token_counts:
				if player_token_counts[player_id] == max_count:
					winners.append(player_id)

		# --- Log the results and tally the stars to be awarded ---
		if winners.size() > 0:
			if winners.size() == 1:
				print("Player %d dominates the %s biome." % [winners[0], biome_name])
			else:
				print("Domination is TIED in the %s biome between players: %s" % [biome_name, str(winners)])
			
			# Add one star to the tally for each winner
			for winner_id in winners:
				stars_awarded_this_turn[winner_id] += 1
		else:
			print("No non-blighted tokens in %s biome to determine domination." % biome_name)

	# --- Sync the results with all clients ---
	# After checking all biomes, send the total stars awarded to each player.
	for player_id in stars_awarded_this_turn:
		if stars_awarded_this_turn[player_id] > 0:
			# This RPC tells all clients to update the UI for the specific player.
			rpc("award_stars_to_player", player_id, stars_awarded_this_turn[player_id])


## This function is called on all clients (and the server) to update the UI.
@rpc("any_peer", "call_local")
func award_stars_to_player(player_id: int, count: int):
	print("Awarding %d soil star(s) to player %d" % [count, player_id])
	
	# This is the recommended way to find player-specific UI.
	# It assumes you have a central node (e.g., "PlayerUIs") that holds an
	# instance of each player's HUD, named uniquely with their ID.
	# See the explanation below for how to set this up.
	var soil_star_node_path = "/root/Game/PlayerUIs/Player_%d_UI/SoilStar" % player_id
	var soil_star_node = get_node_or_null(soil_star_node_path)

	if soil_star_node:
		# We found the node, so call its function to increase the star count.
		soil_star_node.increase_soil_star(count)
	else:
		# If the node isn't found, this warning will help you debug the path.
		print("WARNING: Could not find SoilStar node for player %d. Please check your scene structure and the path in domination.gd: %s" % [player_id, soil_star_node_path])
