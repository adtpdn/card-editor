# domination.gd
extends Node

# --- Manager and node references ---
@onready var game = get_node("/root/Game")
var stars_awarded_this_turn = {}

## Checks all biomes to find which player has the most non-blighted tokens.
func check_domination_biomes() -> void:
	if not multiplayer.is_server():
		return # Domination logic is handled by the server to ensure consistency.

	print("--- Checking Biome Domination ---")

	# This dictionary will store the total stars to be awarded this turn.
	# We calculate all awards first, then send them.
	# Format: { player_id: stars_to_add, player_id_2: stars_to_add, ... }
	stars_awarded_this_turn = {}
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
			if token.biome_type == biome_value and not token.is_blighted and !token.is_energy:
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
	# Check if any stars were awarded before proceeding.
	var has_awards = false
	for star_count in stars_awarded_this_turn.values():
		if star_count > 0:
			has_awards = true
			break
	
	if has_awards:
		# Send a single RPC to all peers (including the host via "call_local").
		# This function will handle all UI updates and trigger local notifications.
		rpc("update_all_stars_and_notify", stars_awarded_this_turn)
		
		# --- FIX ---
		# Wait on the server for a moment to let the notification be seen by players
		# before the next turn's UI changes can happen. This prevents the "start turn"
		# notification from immediately overriding the star award notification.
		await get_tree().create_timer(3.5).timeout


## This function is called on all peers (host and clients) via RPC.
# It updates the UI and then calls a separate local function for notifications.
# This avoids having `await` inside an RPC function, which is more robust.
@rpc("any_peer", "call_local")
func update_all_stars_and_notify(all_awards: Dictionary):
	# This print will appear on the server and all clients' consoles for debugging.
	print("RPC received on peer %d: Updating stars with data: %s" % [multiplayer.get_unique_id(), str(all_awards)])

	# --- Step 1: Update the SoilStar UI for ALL players who earned stars ---
	for player_id in all_awards:
		var count = all_awards[player_id]
		if count > 0:
			var soil_star_node_path = "/root/Game/PlayerUIs/Player_%d_UI/SoilStar" % player_id
			var soil_star_node = get_node_or_null(soil_star_node_path)

			if soil_star_node:
				# We found the node, so call its function to increase the star count.
				soil_star_node.increase_soil_star(count)
			else:
				# If the node isn't found, this warning will help you debug the path.
				print("WARNING: Could not find SoilStar node for player %d. Path: %s" % [player_id, soil_star_node_path])

	# --- Step 2: Trigger a local notification if this player earned stars ---
	var local_player_id = multiplayer.get_unique_id()
	if all_awards.has(local_player_id):
		var stars_earned = all_awards[local_player_id]
		# Call the new, purely local function to handle the notification.
		_show_local_notification(stars_earned)


## This is a purely local function to show the notification with a timer.
# It contains the `await` call, keeping it separate from the RPC logic.
func _show_local_notification(stars_earned: int):
	var text = "You got %d soil star(s)!" % stars_earned
	
	# This shows the notification panel with the personalized text.
	game.notification.show_instruction_label(text)

	# We create a timer to automatically hide the notification after a few seconds.
	await get_tree().create_timer(3.0).timeout # It's relate to game_state_manager 
	game.notification.hide_panel()
