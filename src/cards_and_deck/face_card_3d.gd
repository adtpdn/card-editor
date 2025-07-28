class_name FaceCard3D
extends Card3D

# REMOVED the local enum definition to avoid type conflicts.
# enum CardType {ACTION, ELEMENTAL}

var card_id : int = -1
var card_on_biome = -1
var card_name : String = ""
# The card_type variable now explicitly uses the enum from CardResource.
var card_type : CardResource.CardType = CardResource.CardType.ACTION
var card_parent : String = ""

func _ready():
	prep_card_mesh()

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
				$CardMesh/ElementalFrontMesh.set_surface_override_material(0, material)

@export var elemental_back_material_path: String:
	set(path):
		if path:
			var material = load(path)
			
			if material:
				$CardMesh/ElementalBackMesh.set_surface_override_material(0, material)
