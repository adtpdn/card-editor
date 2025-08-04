class_name FaceCard3D
extends Card3D

var card_id : int = -1
var card_on_biome = -1 # Special for action card
var card_name : String = ""
var card_type : CardResource.CardType = CardResource.CardType.ACTION
var elemental_type : CardResource.ElementalType = CardResource.ElementalType.NONE
var card_parent : String = ""
var owner_id: int = -1


func _ready():
	prep_card_mesh()
	
	set_scale_elemental()

func set_scale_elemental():
	# Set Default Instantiate ELemental Card Type
	if card_type == CardResource.CardType.ELEMENTAL:
		scale = Vector3(0.7, 0.7, 1)

func prep_card_mesh():
	match card_type:
		# Use the full, unambiguous path to the enum values.
		CardResource.CardType.ACTION:
			$CardMesh/CardBackMesh.show()
			$CardMesh/CardFrontMesh.show()
			$CardMesh/ElementalsBackMesh.hide()
			$CardMesh/ElementalsFrontMesh.hide()
		CardResource.CardType.ELEMENTAL:
			$CardMesh/ElementalsBackMesh.show()
			$CardMesh/ElementalsFrontMesh.show()
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
				
@export var elemental_front_material_path: String:
	set(path):
		if path:
			var material = load(path)
			
			if material:
				$CardMesh/ElementalsFrontMesh.set_surface_override_material(0, material)

@export var elemental_back_material_path: String:
	set(path):
		if path:
			var material = load(path)
			
			if material:
				$CardMesh/ElementalsBackMesh.set_surface_override_material(0, material)
