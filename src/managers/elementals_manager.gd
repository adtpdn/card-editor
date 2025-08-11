# card-editor/src/managers/elementals_manager.gd
extends Node

@onready var game = get_node("/root/Game")
@onready var token_manager = get_node("/root/Game/TokenManager")
@onready var domination_manager = get_node("/root/Game/DominationManager")


# Blue Elementals Variables
var sigil_a_disabled_biome: int = -1
var sigil_b_disabled_biome: int = -1
var sigil_c_disabled_biome: int = -1
var point_conversion_disabled_biome: int = -1 # blue elemental 6
var increased_sigil_cost_biome: int = -1 # blue elemental 7

func execute_elemental_effect(_card_id: int, _type:CardResource.ElementalType, card_node: FaceCard3D):
	print("execute elemental")
	# This function must only be executed on the server.
	if not multiplayer.is_server():
		return
	
	var biome_index = _get_biome_from_slice(card_node)
	if _type == CardResource.ElementalType.RED:
		print('Elemental RED Execute')
		match _card_id:
			0: _elemental_red_01_effect(biome_index)
			1: _elemental_red_02_effect(biome_index)
			2: _elemental_red_03_effect(biome_index)
			3: _elemental_red_04_effect(biome_index)
			4: _elemental_red_05_effect()
			# Card 06 (ElementalRed06) is deferred
			6: _elemental_red_07_effect(biome_index)
			7: _elemental_red_08_effect()
	elif  _type == CardResource.ElementalType.BLUE:
		print("Elemental BLUE Execute")
		match _card_id:
			0: 
				print("Elemental Blue 01: Disable Sigil A in the elemental's biome")
				sigil_a_disabled_biome = biome_index
				print("Sigil A is now disabled in biome index: ", sigil_a_disabled_biome)
			1: 
				print("Elemental Blue 02: Disable Sigil B in the elemental's biome")
				sigil_b_disabled_biome = biome_index
				print("Sigil B is now disabled in biome index: ", sigil_b_disabled_biome)
			2: 
				print("Elemental Blue 03: Disable Sigil C in the elemental's biome")
				sigil_c_disabled_biome = biome_index
				print("Sigil C is now disabled in biome index: ", sigil_c_disabled_biome)
			3:
				print("Elemental Blue 04: Remove Energy on Sigils")
				var card_biome = _get_biome_from_slice(card_node)
				if card_biome == -1:
					print("ERROR: Could not determine elemental's biome for card_id 3.")
					return

				var token_manager = get_node("/root/Game/TokenManager")
				var tokens_node = get_node("/root/Game/Tokens")
				var positions_to_remove = {} # Use a dictionary to store unique positionse

				# Find energy tokens on regular sigil locations (0-7) in the matching biome
				for token in tokens_node.get_children():
					if token.is_energy:
						var placement = token_manager.get_token_placement_at_position(token.global_position)
						if placement and (placement.place_id == 3 or placement.place_id == 5):
							if placement.accepted_biome == card_biome:
								positions_to_remove[token.global_position] = true
				
				print("position to remove : ", positions_to_remove)
				# Execute the removal for all unique positions found
				for pos in positions_to_remove.keys():
					token_manager.server_remove_token_at_pos(pos)

				# Hide the specified token placements via RPC, now with biome context
				token_manager.rpc("hide_placements_by_id", [3, 5], card_biome)
			
			4: 
				print("Elemental Blue 05: Remove Energy on Sigils")
				var card_biome = _get_biome_from_slice(card_node)
				if card_biome == -1:
					print("ERROR: Could not determine elemental's biome for card_id 4.")
					return

				var token_manager = get_node("/root/Game/TokenManager")
				var tokens_node = get_node("/root/Game/Tokens")
				var positions_to_remove = {} # Use a dictionary to store unique positionse

				# Find energy tokens on regular sigil locations (0-7) in the matching biome
				for token in tokens_node.get_children():
					if token.is_energy:
						var placement = token_manager.get_token_placement_at_position(token.global_position)
						if placement and (placement.place_id == 1 or placement.place_id == 4):
							if placement.accepted_biome == card_biome:
								positions_to_remove[token.global_position] = true
				
				print("position to remove : ", positions_to_remove)
				# Execute the removal for all unique positions found
				for pos in positions_to_remove.keys():
					token_manager.server_remove_token_at_pos(pos)

				# Hide the specified token placements via RPC, now with biome context
				token_manager.rpc("hide_placements_by_id", [1, 4], card_biome)
			5: 
				print("Elemental Blue 06: Remove Energy on Sigils")
				var card_biome = _get_biome_from_slice(card_node)
				if card_biome == -1:
					print("ERROR: Could not determine elemental's biome for card_id 4.")
					return

				var token_manager = get_node("/root/Game/TokenManager")
				var tokens_node = get_node("/root/Game/Tokens")
				var positions_to_remove = {} # Use a dictionary to store unique positionse

				# Find energy tokens on regular sigil locations (0-7) in the matching biome
				for token in tokens_node.get_children():
					if token.is_energy:
						var placement = token_manager.get_token_placement_at_position(token.global_position)
						if placement and (placement.place_id == 4 or placement.place_id == 5):
							if placement.accepted_biome == card_biome:
								positions_to_remove[token.global_position] = true
				
				print("position to remove : ", positions_to_remove)
				# Execute the removal for all unique positions found
				for pos in positions_to_remove.keys():
					token_manager.server_remove_token_at_pos(pos)

				# Hide the specified token placements via RPC, now with biome context
				token_manager.rpc("hide_placements_by_id", [4, 5], card_biome)
			6: 
				print("Elemental Blue 07: Disable Mana to Point Conversion")
				point_conversion_disabled_biome = biome_index
				print("Mana to point conversion is now disabled in biome index: ", point_conversion_disabled_biome)
			7: 
				print("Elemental Blue 08: Increase Sigil activation cost to 2 Mana")
				increased_sigil_cost_biome = biome_index
				print("Sigil activation cost is now 2 in biome index: ", increased_sigil_cost_biome)
			8: 
				print("Elemental Blue 09: Set Mana based on Blighted Tokens")
				var card_biome = _get_biome_from_slice(card_node)
				if card_biome == -1:
					print("ERROR: Could not determine elemental's biome for card_id 8.")
					return
				
				var tokens_node = get_node("/root/Game/Tokens")
				var blighted_token_count = 0
				
				# Count blighted tokens in the elemental's biome
				for token in tokens_node.get_children():
					if token.is_blighted and token.biome_type == card_biome and !token.is_energy:
						blighted_token_count += 1
				
				print("Found %d blighted tokens in biome %d. Setting mana to this value." % [blighted_token_count, card_biome])

				var point_counter = get_node("/root/Game/PointCounter")
				print("point counter : ", point_counter)
				if point_counter:
					point_counter.server_set_mana_for_biome(card_biome, blighted_token_count)
		
		# Sync variable
		if multiplayer.is_server():
			sync_disabled_states.rpc(sigil_a_disabled_biome, sigil_b_disabled_biome, sigil_c_disabled_biome, point_conversion_disabled_biome, increased_sigil_cost_biome)

# --- Elemental Red Effect Implementations ---

# ElementalRed01 - Blight at least 1 token in a biome.
func _elemental_red_01_effect(biome_type):
	print("elemental red 01 activated")
	for count in _get_all_tokens_in_biome(biome_type, false).size():
		var blight_token_on_biome = _get_blight_token_in_biome(biome_type)
		if blight_token_on_biome.size() < 1:
			var dominant_players = domination_manager._get_all_dominant_players_in_biome(biome_type)
			var target_player
			if dominant_players.size() > 1:
				var last_player = dominant_players.size() - 1
				target_player = dominant_players[last_player]
			else:
				target_player = dominant_players[0]
			var player_tokens_in_biome = _get_player_tokens_in_biome(target_player, biome_type, false)
			token_manager.blight_token_and_move(player_tokens_in_biome[0].global_position)

# ElementalRed02 - Blight at least 2 tokens in a biome.
func _elemental_red_02_effect(biome_type):
	print("elemental red 02 activated")
	for count in _get_all_tokens_in_biome(biome_type, false).size():
		var blight_token_on_biome = _get_blight_token_in_biome(biome_type)
		if blight_token_on_biome.size() < 2:
			var dominant_players = domination_manager._get_all_dominant_players_in_biome(biome_type)
			var target_player
			if dominant_players.size() > 1:
				var last_player = dominant_players.size() - 1
				target_player = dominant_players[last_player]
			else:
				target_player = dominant_players[0]
			var player_tokens_in_biome = _get_player_tokens_in_biome(target_player, biome_type, false)
			token_manager.blight_token_and_move(player_tokens_in_biome[0].global_position)

# ElementalRed03 - Blight tokens in a biome if there are more than 4.
func _elemental_red_03_effect(biome_type):
	print("elemental red 03 activated")
	for count in _get_all_tokens_in_biome(biome_type, false).size():
		var all_tokens_in_biome = _get_all_tokens_in_biome(biome_type, false)
		
		if all_tokens_in_biome.size() > 4:
			var dominant_players = domination_manager._get_all_dominant_players_in_biome(biome_type)
			var target_player
			
			if dominant_players.size() > 1:
				var last_player = dominant_players.size() - 1
				target_player = dominant_players[last_player]
			else:
				target_player = dominant_players[0]
			
			var player_tokens_in_biome = _get_player_tokens_in_biome(target_player, biome_type, false)
			token_manager.blight_token_and_move(player_tokens_in_biome[0].global_position)

# ElementalRed04 - Maximum 5 tokens in a biome
func _elemental_red_04_effect(biome_type):
	print("elemental red 04 activated")
	for count in _get_all_tokens_in_biome(biome_type, false).size():
		var all_tokens_in_biome = _get_all_tokens_in_biome(biome_type, false)
		
		if all_tokens_in_biome.size() > 5:
			var dominant_players = domination_manager._get_all_dominant_players_in_biome(biome_type)
			var target_player
			
			if dominant_players.size() > 1:
				var last_player = dominant_players.size() - 1
				target_player = dominant_players[last_player]
			else:
				target_player = dominant_players[0]
			var player_tokens_in_biome = _get_player_tokens_in_biome(target_player, biome_type, false)
			token_manager.blight_token_and_move(player_tokens_in_biome[0].global_position)

# ElementalRed05 - Blighted tokens will dominate the Biome
func _elemental_red_05_effect():
	var target_biome = _find_target_biome_by_dominance()
	if target_biome == -1:
		return

	var player_blight_counts = {}
	for player_id in game.players:
		player_blight_counts[player_id] = _get_player_tokens_in_biome(player_id, target_biome, true).size()

	var dominant_blight_player = -1
	var max_blighted = 0
	for player_id in player_blight_counts:
		if player_blight_counts[player_id] > max_blighted:
			max_blighted = player_blight_counts[player_id]
			dominant_blight_player = player_id
	
	if dominant_blight_player != -1:
		# Award a soil star to the player with the most blighted tokens
		var player_ui = game.soil_star_actions._get_active_player_ui()
		if player_ui:
			var soil_star_node = player_ui.get_node_or_null("SoilStar")
			if soil_star_node:
				soil_star_node.increase_soil_star(1)


# ElementalRed07 - Can’t plant token in a biome
func _elemental_red_07_effect(biome_index: int):
	if biome_index != -1:
		# We need a new variable in TokenManager to track this
		token_manager.rpc("set_biome_planting_lock", biome_index, true)

# ElementalRed08 - Less token in a biome will dominate the biome
func _elemental_red_08_effect():
	var target_biome = _find_target_biome_by_dominance()
	if target_biome == -1:
		return
	
	# Use the new function from DominationManager
	var least_dominant_players = domination_manager._get_least_dominant_players_in_biome(target_biome)
	
	if least_dominant_players.is_empty():
		return
		
	# Award a soil star to the player(s) with the fewest tokens
	for player_id in least_dominant_players:
		var player_ui = game.soil_star_actions._get_active_player_ui()
		if player_ui:
			var soil_star_node = player_ui.get_node_or_null("SoilStar")
			if soil_star_node:
				soil_star_node.increase_soil_star(1)


# --- Helper Functions ---
func _get_blight_token_in_biome(biome_type):
	var all_tokens_in_biome = _get_all_tokens_in_biome(biome_type, true)
	var blight_token_arr = []
	for token in all_tokens_in_biome:
		if token.is_blighted and not token.is_energy:
			blight_token_arr.append(token)
	
	return blight_token_arr


# Finds the target biome based on token dominance and tie-breaker rules.
func _find_target_biome_by_dominance() -> int:
	var biome_token_counts = domination_manager._get_biome_token_counts()
	
	var winning_biomes = []
	var max_count = 0

	for count in biome_token_counts.values():
		if count > max_count:
			max_count = count

	if max_count > 0:
		for biome_type in biome_token_counts:
			if biome_token_counts[biome_type] == max_count:
				winning_biomes.append(biome_type)

	if winning_biomes.size() == 1:
		return winning_biomes[0]
	elif winning_biomes.size() > 1:
		return domination_manager._resolve_domination_tie(winning_biomes)
	
	return -1

# Gets a list of a specific player's tokens in a given biome.
func _get_player_tokens_in_biome(player_id: int, biome_type: int, include_blighted: bool = true, limit: int = -1) -> Array:
	var player_tokens = []
	for token in game.tokens.get_children():
		if token.owner_id == player_id and token.biome_type == biome_type and not token.is_energy:
			if include_blighted or not token.is_blighted:
				player_tokens.append(token)
	
	if limit > 0 and player_tokens.size() > limit:
		return player_tokens.slice(0, limit)
		
	return player_tokens

# Gets all non-energy tokens in a biome.
func _get_all_tokens_in_biome(biome_type: int, include_blighted: bool = true) -> Array:
	var all_tokens = []
	for token in game.tokens.get_children():
		if token.biome_type == biome_type and not token.is_energy:
			if include_blighted or not token.is_blighted:
				all_tokens.append(token)
	return all_tokens

@rpc("any_peer", "call_local")
func sync_disabled_states(sigil_a_biome: int, sigil_b_biome: int, sigil_c_biome: int, point_conversion_biome: int, increased_cost_biome: int):
	sigil_a_disabled_biome = sigil_a_biome
	sigil_b_disabled_biome = sigil_b_biome
	sigil_c_disabled_biome = sigil_c_biome
	point_conversion_disabled_biome = point_conversion_biome
	increased_sigil_cost_biome = increased_cost_biome
	print("SYNC: Disabled sigil states updated -> A: %d, B: %d, C: %d" % [sigil_a_disabled_biome, sigil_b_disabled_biome, sigil_c_disabled_biome])

# Helper function to determine the biome from a card node on a slice.
func _get_biome_from_slice(card_node: FaceCard3D) -> int:
	if is_instance_valid(card_node) and is_instance_valid(card_node.get_parent()):
		var collection = card_node.get_parent()
		if "card_slot_biome" in collection:
			return collection.card_slot_biome
	return -1
