class_name FaceCard3D
extends Card3D

enum CardType {Card, Elemental}

var card_id : int = -1
var card_on_biome = -1
var card_name : String = ""
var card_type : CardType = CardType.Card
var card_parent : String = ""

func _ready():
	prep_card_mesh()

func prep_card_mesh():
	match card_type:
		"Card":
			$CardMesh/CardBackMesh.show()
			$CardMesh/CardFrontMesh.show()
			$CardMesh/ElementalsMesh.hide()
		"Elemental":
			$CardMesh/ElementalsMesh.show()
			$CardMesh/CardBackMesh.hide()
			$CardMesh/CardFrontMesh.hide()

@export var front_material_path: String:
	set(path):
		if path:
			var material = load(path)
			
			if material:
				$CardMesh/CardFrontMesh.set_surface_override_material(0, material)
		
@export var back_material_path: String:
	set(path):
		if path:
			var material = load(path)
			
			if material:
				$CardMesh/CardBackMesh.set_surface_override_material(0, material)
				
@export var elemental_material_path: String:
	set(path):
		if path:
			var material = load(path)
			
			if material:
				$CardMesh/ElementalsMesh.set_surface_override_material(0, material)
