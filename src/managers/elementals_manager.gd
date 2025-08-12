extends Node

@onready var game = get_node("/root/Game")
@onready var token_manager = get_node("/root/Game/TokenManager")
@onready var domination_manager = get_node("/root/Game/DominationManager")

# Blue Elementals Variables
var sigil_a_disabled_biome: int = -1
var sigil_b_disabled_biome: int = -1
var sigil_c_disabled_biome: int = -1
var point_conversion_disabled_biome: int = -1 # blue elemental id 6
var increased_sigil_cost_biome: int = -1 # blue elemental id 7

# Add a variable to track the biome affected by the half-points rule
var half_points_biome: int = -1 # For Red Elemental 06 effect

# Dictionary to hold the notification text for each elemental card
const ELEMENTAL_NOTIFICATION_TEXT = {
	"BLUE": {
		0: "Elemental Effect Activated:\nCannot use Sigil A pattern.",
		1: "Elemental Effect Activated:\nCannot use Sigil B pattern.",
		2: "Elemental Effect Activated:\nCannot use Sigil C pattern.",
		3: "Elemental Effect Activated:\nCannot place token energy on blighted Sigil column.",
		4: "Elemental Effect Activated:\nCannot place token energy on blighted Sigil column.",
		5: "Elemental Effect Activated:\nCannot place token energy on blighted Sigil column.",
		6: "Elemental Effect Activated:\nMana cannot be converted to points but remains in Mana slot.",
		7: "Elemental Effect Activated:\nConsumes 2 Mana to activate Sigil Magic pattern.",
		8: "Elemental Effect Activated:\nMana amount depends on blighted tokens in Biome."
	},
	"RED": {
		0: "Elemental Effect Activated:\nRequires at least 1 blight token in a Biome, determined by dominance; if tied, from last player in reverse order.",
		1: "Elemental Effect Activated:\nRequires at least 2 blight tokens in a Biome, determined by dominance; if tied, from last player in reverse order.",
		2: "Elemental Effect Activated:\nMaximum 4 tokens in a Biome; excess tokens blighted from dominant player, or if tied, from last player in reverse order.",
		3: "Elemental Effect Activated:\nMaximum 5 tokens in a Biome; excess tokens blighted from dominant player, or if tied, from last player in reverse order.",
		4: "Elemental Effect Activated:\nBlighted tokens dominate the Biome.",
		5: "Elemental Effect Activated:\n1 point counts as ½ point.",
		6: "Elemental Effect Activated:\nDominant player in a Biome gains a card instead of a soil star.",
		7: "Elemental Effect Activated:\nCannot plant tokens in a Biome.",
		8: "Elemental Effect Activated:\nFewer tokens in a Biome dominate it."
	}
}


func execute_elemental_effect(_card_id: int, _type:CardResource.ElementalType, card_node: FaceCard3D):
	# This function must only be executed on the server.
	if not multiplayer.is_server():
		return
	
	var biome_index = _get_biome_from_slice(card_node)
	if biome_index == -1:
		print("ERROR: Could not determine elemental's biome. Aborting elemental effect.")
		return

	if _type == CardResource.ElementalType.RED:
		print('Elemental RED Execute')
		match _card_id:
			0: _elemental_red_01_effect(biome_index)
			1: _elemental_red_02_effect(biome_index)
			2: _elemental_red_03_effect(biome_index)
			3: _elemental_red_04_effect(biome_index)
			4: _elemental_red_05_effect(biome_index)
			5: _elemental_red_06_effect(biome_index)
			6: _elemental_red_07_effect(biome_index)
			7: _elemental_red_08_effect(biome_index)
			8: _elemental_red_09_effect(biome_index)
			
	elif _type == CardResource.ElementalType.BLUE:
		print("Elemental BLUE Execute")
		match _card_id:
			0: _elemental_blue_01_effect(biome_index)
			1: _elemental_blue_02_effect(biome_index)
			2: _elemental_blue_03_effect(biome_index)
			3: _elemental_blue_04_effect(biome_index)
			4: _elemental_blue_05_effect(biome_index)
			5: _elemental_blue_06_effect(biome_index)
			6: _elemental_blue_07_effect(biome_index)
			7: _elemental_blue_08_effect(biome_index)
			8: _elemental_blue_09_effect(biome_index)
		
		# Sync all blue elemental states after any blue elemental is played
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
func _elemental_red_05_effect(biome_index):
	print("Elemental Red 05 Effect: Blighted tokens will now determine domination for biome %d" % biome_index)
	if domination_manager:
		domination_manager.set_blighted_domination_biome(biome_index)

# ElementalRed06 - Point in a biome will be cut in Half
func _elemental_red_06_effect(biome_index):
	print("Elemental Red 06 Effect: Points in biome %d will be halved." % biome_index)
	# Set the state variable
	half_points_biome = biome_index
	# Sync this state with all clients
	rpc("sync_half_points_biome", biome_index)

@rpc("any_peer", "call_local")
func sync_half_points_biome(biome_index: int):
	half_points_biome = biome_index
	print("SYNC: Half points effect is now active for biome: %d" % biome_index)

# ElementalRed07 - Card reward if dominate a biome
func _elemental_red_07_effect(biome_index: int):
	print("Elemental Red 07 Effect: Winners in biome %d get a card instead of a star." % biome_index)
	if domination_manager:
		domination_manager.set_card_reward_biome(biome_index)

# ElementalRed08 - Can’t plant token in a biome
func _elemental_red_08_effect(biome_index: int):
	if biome_index != -1:
		token_manager.rpc("set_biome_planting_lock", biome_index, true)

# ElementalRed09 - Less token in a biome will dominate the biome
func _elemental_red_09_effect(biome_index):
	print("Elemental Red 09 Effect: The player with the least tokens will dominate biome %d" % biome_index)
	if domination_manager:
		domination_manager.set_least_tokens_win_biome(biome_index)

# --- Elemental Blue Effect Implementations ---

# ElementalBlue01 (ID 0) - Disable Sigil A pattern in the elemental's biome.
func _elemental_blue_01_effect(biome_index: int):
	print("Elemental Blue 01: Disable Sigil A in the elemental's biome")
	sigil_a_disabled_biome = biome_index
	print("Sigil A is now disabled in biome index: ", sigil_a_disabled_biome)

# ElementalBlue02 (ID 1) - Disable Sigil B pattern in the elemental's biome.
func _elemental_blue_02_effect(biome_index: int):
	print("Elemental Blue 02: Disable Sigil B in the elemental's biome")
	sigil_b_disabled_biome = biome_index
	print("Sigil B is now disabled in biome index: ", sigil_b_disabled_biome)

# ElementalBlue03 (ID 2) - Disable Sigil C pattern in the elemental's biome.
func _elemental_blue_03_effect(biome_index: int):
	print("Elemental Blue 03: Disable Sigil C in the elemental's biome")
	sigil_c_disabled_biome = biome_index
	print("Sigil C is now disabled in biome index: ", sigil_c_disabled_biome)

# ElementalBlue04 (ID 3) - Cannot place token energy on specified blighted Sigil columns.
func _elemental_blue_04_effect(biome_index: int):
	print("Elemental Blue 04: Remove Energy on specified Sigil columns.")
	_disable_sigil_columns([3, 5], biome_index)

# ElementalBlue05 (ID 4) - Cannot place token energy on specified blighted Sigil columns.
func _elemental_blue_05_effect(biome_index: int):
	print("Elemental Blue 05: Remove Energy on specified Sigil columns.")
	_disable_sigil_columns([1, 4], biome_index)

# ElementalBlue06 (ID 5) - Cannot place token energy on specified blighted Sigil columns.
func _elemental_blue_06_effect(biome_index: int):
	print("Elemental Blue 06: Remove Energy on specified Sigil columns.")
	_disable_sigil_columns([4, 5], biome_index)

# ElementalBlue07 (ID 6) - Mana cannot be converted to points.
func _elemental_blue_07_effect(biome_index: int):
	print("Elemental Blue 07: Disable Mana to Point Conversion")
	point_conversion_disabled_biome = biome_index
	print("Mana to point conversion is now disabled in biome index: ", point_conversion_disabled_biome)

# ElementalBlue08 (ID 7) - Sigil activation costs 2 Mana.
func _elemental_blue_08_effect(biome_index: int):
	print("Elemental Blue 08: Increase Sigil activation cost to 2 Mana")
	increased_sigil_cost_biome = biome_index
	print("Sigil activation cost is now 2 in biome index: ", increased_sigil_cost_biome)

# ElementalBlue09 (ID 8) - Mana amount set by blighted tokens.
func _elemental_blue_09_effect(biome_index: int):
	print("Elemental Blue 09: Set Mana based on Blighted Tokens")
	var tokens_node = get_node("/root/Game/Tokens")
	var blighted_token_count = 0
	
	# Count blighted tokens in the elemental's biome
	for token in tokens_node.get_children():
		if token.is_blighted and token.biome_type == biome_index and not token.is_energy:
			blighted_token_count += 1
	
	print("Found %d blighted tokens in biome %d. Setting mana to this value." % [blighted_token_count, biome_index])

	var point_counter = get_node("/root/Game/PointCounter")
	if point_counter:
		point_counter.server_set_mana_for_biome(biome_index, blighted_token_count)

# --- Helper Functions ---

# Refactored function for blue elementals 4, 5, and 6.
# Removes energy tokens from specified sigil placement IDs and hides those placements.
func _disable_sigil_columns(place_ids_to_hide: Array, biome_index: int):
	var tokens_node = get_node("/root/Game/Tokens")
	var positions_to_remove = {} # Use a dictionary to store unique positions

	# Find energy tokens on specified sigil locations in the matching biome
	for token in tokens_node.get_children():
		if token.is_energy:
			var placement = token_manager.get_token_placement_at_position(token.global_position)
			if placement and placement.place_id in place_ids_to_hide:
				if placement.accepted_biome == biome_index:
					positions_to_remove[token.global_position] = true
	
	print("Positions to remove: ", positions_to_remove)
	# Execute the removal for all unique positions found
	for pos in positions_to_remove.keys():
		token_manager.server_remove_token_at_pos(pos)

	# Hide the specified token placements via RPC, now with biome context
	token_manager.rpc("hide_placements_by_id", place_ids_to_hide, biome_index)


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
	print("SYNC: Disabled sigil states updated -> A: %d, B: %d, C: %d, Point Conversion: %d, Increased Cost: %d" % [sigil_a_disabled_biome, sigil_b_disabled_biome, sigil_c_disabled_biome, point_conversion_disabled_biome, increased_sigil_cost_biome])

# Helper function to determine the biome from a card node on a slice.
func _get_biome_from_slice(card_node: FaceCard3D) -> int:
	if is_instance_valid(card_node) and is_instance_valid(card_node.get_parent()):
		var collection = card_node.get_parent()
		if "card_slot_biome" in collection:
			return collection.card_slot_biome
	return -1
