# card-editor/src/managers/elementals_manager.gd
extends Node

@onready var game = get_node("/root/Game")
@onready var token_manager = get_node("/root/Game/TokenManager")
@onready var domination_manager = get_node("/root/Game/DominationManager")

var sigil_a_disabled_biome: int = -1
var sigil_b_disabled_biome: int = -1
var sigil_c_disabled_biome: int = -1

# --- MODIFICATION START ---
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
# --- MODIFICATION END ---

func execute_elemental_effect(_card_id: int, _type:CardResource.ElementalType, card_node: FaceCard3D):
	# This function must only be executed on the server.
	if not multiplayer.is_server():
		return

	var biome_index = _get_biome_from_slice(card_node)

	match _type:
		CardResource.ElementalType.RED:
			print("Elemental RED Execute")
			match _card_id:
				0: _elemental_red_01_effect()
				1: _elemental_red_02_effect()
				2: _elemental_red_03_effect()
				3: _elemental_red_04_effect()
				4: _elemental_red_05_effect()
				5: _elemental_red_06_effect()
				6: _elemental_red_07_effect()
				7: _elemental_red_08_effect(biome_index)
				8: _elemental_red_09_effect()


		CardResource.ElementalType.BLUE:
			print("Elemental BLUE Execute")
			match _card_id:
				0:
					sigil_a_disabled_biome = biome_index
				1:
					sigil_b_disabled_biome = biome_index
				2:
					sigil_c_disabled_biome = biome_index
				3: _elemental_blue_04_effect()
				4: _elemental_blue_05_effect()
				5: _elemental_blue_06_effect()
				6: _elemental_blue_07_effect()
				7: _elemental_blue_08_effect()
				8: _elemental_blue_09_effect()
			
			# --- MODIFICATION START ---
			# Add a small delay to ensure this notification is shown last
			await get_tree().create_timer(0.1).timeout
			# Show notification for blue elemental effects
			var notification_text = ELEMENTAL_NOTIFICATION_TEXT["BLUE"][_card_id]
			game.notification.show_instruction_label(notification_text)
			await get_tree().create_timer(3.0).timeout
			game.notification.hide_panel()
			# --- MODIFICATION END ---
			
			sync_disabled_sigils.rpc(sigil_a_disabled_biome, sigil_b_disabled_biome, sigil_c_disabled_biome)


# --- Elemental Red Effect Implementations ---

# ElementalRed01 - Blight at least 1 token in a biome.
func _elemental_red_01_effect():
	var target_biome = _find_target_biome_by_dominance()
	if target_biome == -1:
		print("ElementalRed01: No single dominant biome found. No effect.")
		return

	var dominant_players = domination_manager._get_all_dominant_players_in_biome(target_biome)
	if dominant_players.is_empty():
		print("ElementalRed01: No dominant player in biome %s." % target_biome)
		return
	
	var target_player = dominant_players[0] # In case of a tie, the tie-breaker already picked the biome
	
	var tokens_to_blight = _get_player_tokens_in_biome(target_player, target_biome, false, 1)
	for token in tokens_to_blight:
		token_manager.blight_token_and_move(token.global_position)

# ElementalRed02 - Blight at least 2 tokens in a biome.
func _elemental_red_02_effect():
	var target_biome = _find_target_biome_by_dominance()
	if target_biome == -1:
		print("ElementalRed02: No single dominant biome found. No effect.")
		return

	var dominant_players = domination_manager._get_all_dominant_players_in_biome(target_biome)
	if dominant_players.is_empty():
		return
	
	var target_player = dominant_players[0]
	
	var tokens_to_blight = _get_player_tokens_in_biome(target_player, target_biome, false, 2)
	for token in tokens_to_blight:
		token_manager.blight_token_and_move(token.global_position)

# ElementalRed03 - Maximum 4 tokens in a Biome
func _elemental_red_03_effect():
	for biome_type in domination_manager.Biome.values():
		var all_tokens_in_biome = _get_all_tokens_in_biome(biome_type, false)
		
		if all_tokens_in_biome.size() > 4:
			var dominant_players = domination_manager._get_all_dominant_players_in_biome(biome_type)
			if dominant_players.is_empty():
				continue

			var target_player = dominant_players[0]
			var player_tokens_in_biome = _get_player_tokens_in_biome(target_player, biome_type, false)
			
			var blight_count = all_tokens_in_biome.size() - 4
			for i in range(blight_count):
				if i < player_tokens_in_biome.size():
					token_manager.blight_token_and_move(player_tokens_in_biome[i].global_position)

# ElementalRed04 - Maximum 5 tokens in a Biome
func _elemental_red_04_effect():
	for biome_type in domination_manager.Biome.values():
		var all_tokens_in_biome = _get_all_tokens_in_biome(biome_type, false)
		
		if all_tokens_in_biome.size() > 5:
			var dominant_players = domination_manager._get_all_dominant_players_in_biome(biome_type)
			if dominant_players.is_empty():
				continue

			var target_player = dominant_players[0]
			var player_tokens_in_biome = _get_player_tokens_in_biome(target_player, biome_type, false)
			
			var blight_count = all_tokens_in_biome.size() - 5
			for i in range(blight_count):
				if i < player_tokens_in_biome.size():
					token_manager.blight_token_and_move(player_tokens_in_biome[i].global_position)

# ElementalRed05 - Blighted tokens dominate the Biome
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

# ElementalRed06 - 1 point counts as ½ point.
func _elemental_red_06_effect():
	# Placeholder for future implementation
	pass

# ElementalRed07 - Dominant player in a Biome gains a card instead of a soil star.
func _elemental_red_07_effect():
	# Placeholder for future implementation
	pass

# ElementalRed08 - Cannot plant tokens in a Biome.
func _elemental_red_08_effect(biome_index: int):
	if biome_index != -1:
		# We need a new variable in TokenManager to track this
		token_manager.rpc("set_biome_planting_lock", biome_index, true)

# ElementalRed09 - Fewer tokens in a Biome dominate it.
func _elemental_red_09_effect():
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

# --- Elemental Blue Effect Implementations ---

# ElementalBlue04 - Cannot place token energy on blighted Sigil column.
func _elemental_blue_04_effect():
	# Placeholder for future implementation
	pass

# ElementalBlue05 - Cannot place token energy on blighted Sigil column.
func _elemental_blue_05_effect():
	# Placeholder for future implementation
	pass

# ElementalBlue06 - Cannot place token energy on blighted Sigil column.
func _elemental_blue_06_effect():
	# Placeholder for future implementation
	pass

# ElementalBlue07 - Mana cannot be converted to points but remains in Mana slot.
func _elemental_blue_07_effect():
	# Placeholder for future implementation
	pass

# ElementalBlue08 - Consumes 2 Mana to activate Sigil Magic pattern.
func _elemental_blue_08_effect():
	# Placeholder for future implementation
	pass

# ElementalBlue09 - Mana amount depends on blighted tokens in Biome.
func _elemental_blue_09_effect():
	# Placeholder for future implementation
	pass


# --- Helper Functions ---

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
func sync_disabled_sigils(sigil_a_biome: int, sigil_b_biome: int, sigil_c_biome: int):
	sigil_a_disabled_biome = sigil_a_biome
	sigil_b_disabled_biome = sigil_b_biome
	sigil_c_disabled_biome = sigil_c_biome
	print("SYNC: Disabled sigil states updated -> A: %d, B: %d, C: %d" % [sigil_a_disabled_biome, sigil_b_disabled_biome, sigil_c_disabled_biome])

# Helper function to determine the biome from a card node on a slice.
func _get_biome_from_slice(card_node: FaceCard3D) -> int:
	if is_instance_valid(card_node) and is_instance_valid(card_node.get_parent()):
		var collection = card_node.get_parent()
		if "card_slot_biome" in collection:
			return collection.card_slot_biome
	return -1
