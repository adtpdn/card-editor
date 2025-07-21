class_name FaceCards
extends Resource

enum card_id {
	Zero = 0,
	One = 1,
	Two = 2,
	Three = 3,
	Four = 4
}

enum card_on_biome {
	Hand = -1 ,
	Forest = 1, 
	Mountain = 2, 
	Water = 3, 
	Desert = 4
}


#var data: Dictionary = _generate_all_face_cards()

## Change Data on the cards
#func get_card_data(rank: Rank, suit: Suit):
	#var card_id = get_card_id(rank, suit)
	#
	#if data.has(card_id):
		#return data[card_id]
	#
	#return null
#
#func _generate_all_face_cards() -> Dictionary:
	#var _data = {}
	#
	#for suit in Suit:
		#for rank in Rank:
			#var front_material = "res://example/materials/" + str(suit).to_lower() + "-" + str(Rank[rank]) + ".tres"
			#var back_material = "res://example/materials/card-back.tres"
			#var card_data = {
			#"rank": Rank[rank],
			#"suit": Suit[suit],
			#"front_material_path": front_material,
			#"back_material_path": back_material
			#}
			#var card_id = get_card_id(Rank[rank], Suit[suit])
			#_data[card_id] = card_data
			#
	#return _data
