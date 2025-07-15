class_name FaceCard3D
extends Card3D

enum CardType {Card, Elemental}

var card_id : int = -1
var card_on_biome = -1
var card_name : String = ""
var card_type : CardType = CardType.Card
var card_parent : String = ""


func update_material_front_mesh(material):
	if material != null:
		$CardMesh/CardFrontMesh.set_surface_override_material(0,material)

func update_material_back_mesh(material):
	if material != null:
		$CardMesh/CardBackMesh.set_surface_override_material(0,material)
		
