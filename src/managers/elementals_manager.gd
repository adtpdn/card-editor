extends Node

var sigil_a_disabled_biome: int = -1 
var sigil_b_disabled_biome: int = -1 
var sigil_c_disabled_biome: int = -1 

func execute_elemental_effect(_card_id: int, _type:CardResource.ElementalType, card_node: FaceCard3D):
	print("execute elemental")
	
	if _type == CardResource.ElementalType.RED:
		print('Elemental RED Execute')
	elif  _type == CardResource.ElementalType.BLUE:
		print("Elemental BLUE Execute")
		var biome_index = _get_biome_from_slice(card_node)
		
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
				print("Elemental Blue 04")
				
			3: 
				print("Elemental Blue 04")
			4: 
				print("Elemental Blue 05")
			5: 
				print("Elemental Blue 06")
			6: 
				print("Elemental Blue 07")
			7: 
				print("Elemental Blue 08")
			8: 
				print("Elemental Blue 09")
		if multiplayer.is_server():
			sync_disabled_sigils.rpc(sigil_a_disabled_biome, sigil_b_disabled_biome, sigil_c_disabled_biome)

@rpc("any_peer", "call_local")
func sync_disabled_sigils(sigil_a_biome: int, sigil_b_biome: int, sigil_c_biome: int):
	sigil_a_disabled_biome = sigil_a_biome
	sigil_b_disabled_biome = sigil_b_biome
	sigil_c_disabled_biome = sigil_c_biome
	print("SYNC: Disabled sigil states updated -> A: %d, B: %d, C: %d" % [sigil_a_disabled_biome, sigil_b_disabled_biome, sigil_c_disabled_biome])

# Helper function to determine the biome from a card node on a slice.
# This avoids repeating the same logic for each elemental effect.
func _get_biome_from_slice(card_node: FaceCard3D) -> int:
	if is_instance_valid(card_node) and is_instance_valid(card_node.get_parent()):
		var collection = card_node.get_parent()
		if "card_slot_biome" in collection:
			var card_slot_biome = collection.card_slot_biome
			# Determine the biome based on the slice index (1-8)
			if card_slot_biome == 0:
				return 0 # Biome.FOREST
			elif card_slot_biome == 1:
				return 1 # Biome.WATER
			elif card_slot_biome == 2:
				return 2 # Biome.MOUNTAIN
			elif card_slot_biome == 3:
				return 3 # Biome.DESERT
	return -1 # Return -1 if the biome can't be determined
