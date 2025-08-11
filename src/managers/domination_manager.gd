# domination_manager.gd
extends Node

# --- References ---
@onready var game = get_node("/root/Game")
@onready var token_manager = get_node("/root/Game/TokenManager")
@onready var drag_controller = get_node("/root/Game/Deck/Table/DragController")
@onready var elementals_manager = get_node("/root/Game/ElementalsManager")

# Enum to make biome mapping clearer
enum Biome { FOREST, WATER, MOUNTAIN, DESERT }

# This dictionary maps each biome to its corresponding elemental slice pairs.
# The order is important: the second element is checked first for flipping.
const BIOME_TO_SLICES = {
	Biome.FOREST: ["elemental_slice_1", "elemental_slice_2"],
	Biome.WATER: ["elemental_slice_3", "elemental_slice_4"],
	Biome.MOUNTAIN: ["elemental_slice_5", "elemental_slice_6"],
	Biome.DESERT: ["elemental_slice_7", "elemental_slice_8"],
}

var stars_awarded_this_turn = {}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# --- Public API - Called from GameStateManager ---
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# This function should be called FIRST at the end of a round.
# It finds the biome with the most total tokens and triggers a card flip there.
func check_domination_for_elemental_flips():
	# This logic should only ever be run by the server.
	if not multiplayer.is_server():
		return

	print("--- Checking Biome with most tokens for Elemental Flips ---")

	var biome_token_counts = _get_biome_token_counts()
	
	var winning_biomes = []
	var max_count = 0

	# First, find the highest token count.
	for count in biome_token_counts.values():
		if count > max_count:
			max_count = count

	# Second, find all biomes that achieved that high score.
	if max_count > 0:
		for biome_type in biome_token_counts:
			if biome_token_counts[biome_type] == max_count:
				winning_biomes.append(biome_type)

	var winning_biome = -1

	if winning_biomes.size() == 1:
		# A single biome has the most tokens.
		winning_biome = winning_biomes[0]
		var biome_key = Biome.keys()[winning_biome]
		print("The %s biome has the most tokens. Checking for elemental flip." % biome_key)
	elif winning_biomes.size() > 1:
		# Tie-breaker logic.
		print("Tie for most tokens between biomes: ", winning_biomes)
		winning_biome = _resolve_domination_tie(winning_biomes)
	
	if winning_biome != -1:
		_flip_elemental_for_biome(winning_biome)
	else:
		print("No single biome has the most tokens (tie could not be resolved or no tokens). No elemental flip.")

# This function should be called SECOND at the end of a round, after flips.
# It checks for PLAYER domination in each biome and awards stars.
func check_domination_for_soil_stars():
	if not multiplayer.is_server():
		return

	print("--- Checking Biome Domination for Soil Stars ---")

	stars_awarded_this_turn = {}
	for player_id in game.players:
		stars_awarded_this_turn[player_id] = 0

	# Loop through each biome
	for biome_value in Biome.values():
		var biome_name = Biome.keys()[biome_value]
		var winners = _get_all_dominant_players_in_biome(biome_value)

		# Log the results and tally the stars to be awarded
		if winners.size() > 0:
			if winners.size() == 1:
				print("Player %d dominates the %s biome for a soil star." % [winners[0], biome_name])
			else:
				print("Domination is TIED in the %s biome between players: %s" % [biome_name, str(winners)])
			
			# Add one star to the tally for each winner
			for winner_id in winners:
				stars_awarded_this_turn[winner_id] += 1
		else:
			print("No non-blighted tokens in %s biome to determine domination." % biome_name)

	# Sync the results with all clients
	var has_awards = false
	for star_count in stars_awarded_this_turn.values():
		if star_count > 0:
			has_awards = true
			break
	
	if has_awards:
		rpc("update_all_stars_and_notify", stars_awarded_this_turn)
		# Wait on the server to let the notification be seen by players
		await get_tree().create_timer(3.5).timeout

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# --- Private Helper and Logic Functions ---
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Tie-breaker logic based on last player's placement.
func _resolve_domination_tie(tied_biomes: Array) -> int:
	# Get the player turn order for this round.
	var player_order = game.players.duplicate()
	player_order.reverse() # Start checking from the last player of the round.

	print("Resolving tie. Player check order: ", player_order)
	print("Last biome placements: ", game.player_last_biome_placements)

	for player_id in player_order:
		if game.player_last_biome_placements.has(player_id):
			var last_biome = game.player_last_biome_placements[player_id]
			print("Checking player %d, last placed in biome %s" % [player_id, Biome.keys()[last_biome]])
			# If their last placed biome is one of the tied ones, that biome wins.
			if tied_biomes.has(last_biome):
				print("Tie resolved! Player %d's last placement in %s wins." % [player_id, Biome.keys()[last_biome]])
				return last_biome
	
	print("Tie could not be resolved by player placement history.")
	return -1 # Tie could not be resolved.

# NEW FUNCTION: Finds which biome has the most tokens in total, regardless of player.
# Returns the Biome enum value if there's a clear winner, otherwise returns -1 for a tie.
func _get_biome_token_counts() -> Dictionary:
	var biome_token_counts = {
		Biome.FOREST: 0,
		Biome.WATER: 0,
		Biome.MOUNTAIN: 0,
		Biome.DESERT: 0
	}

	# Count all non-energy tokens in each biome
	for token in game.tokens.get_children():
		if not token.is_energy:
			if biome_token_counts.has(token.biome_type):
				biome_token_counts[token.biome_type] += 1
	
	print("Total tokens per biome: ", biome_token_counts)
	return biome_token_counts

# Counts non-blighted, non-energy tokens to find the player with the most.
# Returns a single winner ID, or -1 for a tie/no winner. (Used for Soil Stars)
func _get_dominant_player_in_biome(biome_type: Biome) -> int:
	var winners = _get_all_dominant_players_in_biome(biome_type)
	if winners.size() == 1:
		return winners[0]
	else:
		return -1

# --- NEW FUNCTION for ElementalRed08 ---
# Finds the player(s) with the FEWEST tokens in a biome.
func _get_least_dominant_players_in_biome(biome_type: Biome) -> Array:
	var player_token_counts = {}
	for player_id in game.players:
		player_token_counts[player_id] = 0

	# First, get a list of all players who have at least one token in the biome
	var players_in_biome = []
	for token in game.tokens.get_children():
		if token.biome_type == biome_type and not token.is_blighted and not token.is_energy:
			if not players_in_biome.has(token.owner_id):
				players_in_biome.append(token.owner_id)
			if player_token_counts.has(token.owner_id):
				player_token_counts[token.owner_id] += 1
	
	# If no one has tokens, no one can be the least dominant
	if players_in_biome.is_empty():
		return []

	var winners = []
	# Start with a high number to find the minimum
	var min_count = INF 
	for player_id in players_in_biome:
		if player_token_counts[player_id] < min_count:
			min_count = player_token_counts[player_id]
	
	# Find all players who are tied for the minimum count
	if min_count != INF:
		for player_id in players_in_biome:
			if player_token_counts[player_id] == min_count:
				winners.append(player_id)
	
	return winners

# A more general helper that returns an array of ALL players who are tied for domination. (Used for Soil Stars)
func _get_all_dominant_players_in_biome(biome_type: Biome) -> Array:
	var player_token_counts = {}
	for player_id in game.players:
		player_token_counts[player_id] = 0

	for token in game.tokens.get_children():
		if token.biome_type == biome_type and not token.is_blighted and not token.is_energy:
			if player_token_counts.has(token.owner_id):
				player_token_counts[token.owner_id] += 1

	var winners = []
	var max_count = 0
	for count in player_token_counts.values():
		if count > max_count:
			max_count = count
	
	if max_count > 0:
		for player_id in player_token_counts:
			if player_token_counts[player_id] == max_count:
				winners.append(player_id)
	
	return winners

# Handles the logic for flipping the correct elemental card for a dominated biome.
func _flip_elemental_for_biome(biome_type: Biome):
	if not BIOME_TO_SLICES.has(biome_type):
		return

	var slice_names = BIOME_TO_SLICES[biome_type]
	var slice_to_check_first = drag_controller.get_node_or_null(slice_names[1])
	var slice_to_check_second = drag_controller.get_node_or_null(slice_names[0])

	if _try_flip_card_in_slice(slice_to_check_first):
		return
	if _try_flip_card_in_slice(slice_to_check_second):
		return

# Helper that checks a slice and triggers the RPC if a face-down card is found.
func _try_flip_card_in_slice(slice_node: CardCollection3D) -> bool:
	if not is_instance_valid(slice_node) or slice_node.cards.is_empty():
		return false

	var card = slice_node.cards[-1]
	if is_instance_valid(card) and card is FaceCard3D and card.face_down:
		rpc("flip_and_activate_elemental_card", slice_node.get_path())
		return true
	return false

# This is a purely local function to show the notification with a timer.
func _show_local_notification(stars_earned: int):
	if stars_earned > 0:
		var text = "You got %d soil star(s)!" % stars_earned
		game.notification.show_instruction_label(text)
		await get_tree().create_timer(3.0).timeout
		game.notification.hide_panel()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# --- RPC Functions ---
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "call_local")
func flip_and_activate_elemental_card(slice_path: NodePath):
	var slice_node = get_node_or_null(slice_path)
	
	if not is_instance_valid(slice_node) or slice_node.cards.is_empty():
		print("RPC Error: Could not find slice or card at path: %s" % slice_path)
		return

	var card = slice_node.cards[-1]
	if is_instance_valid(card) and card is FaceCard3D and card.face_down:
		print("Flipping card '%s' in slice '%s'" % [card.card_name, slice_node.name])
		card.face_down = false
		
		# Excute elemental
		if slice_node.has_method("execute_elemental_effect"):
			elementals_manager.execute_elemental_effect(card.card_id, card.elemental_type, card)
		else:
			print("ERROR: CardCollection3D script on slice is missing 'execute_elemental_effect' function.")

@rpc("any_peer", "call_local")
func update_all_stars_and_notify(all_awards: Dictionary):
	print("RPC received on peer %d: Updating stars with data: %s" % [multiplayer.get_unique_id(), str(all_awards)])

	for player_id in all_awards:
		var count = all_awards[player_id]
		if count > 0:
			var soil_star_node_path = "/root/Game/PlayerUIs/Player_%d_UI/SoilStar" % player_id
			var soil_star_node = get_node_or_null(soil_star_node_path)
			if soil_star_node:
				soil_star_node.increase_soil_star(count)
			else:
				print("WARNING: Could not find SoilStar node for player %d. Path: %s" % [player_id, soil_star_node_path])

	var local_player_id = multiplayer.get_unique_id()
	if all_awards.has(local_player_id):
		var stars_earned = all_awards[local_player_id]
		_show_local_notification(stars_earned)
