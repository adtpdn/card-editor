class_name FaceCard3D
extends Card3D

enum CardType {Card, Elemental}

var card_id : int = -1
var card_on_biome = -1
var card_name : String = ""
var card_type : CardType = CardType.Card
var card_parent : String = ""

@onready var card_back_mesh = $CardMesh/CardBackMesh
@onready var card_front_mesh = $CardMesh/CardFrontMesh

func update_material_front_mesh(material):
	if material != null:
		card_front_mesh.set_surface_override_material(0,material)

func update_material_back_mesh(material):
	if material != null:
		card_back_mesh.set_surface_override_material(0,material)
