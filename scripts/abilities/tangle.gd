# Tangle — pull vortex. The pull itself is applied in each victim's own
# rollback tick (FPSController._apply_tangle_pull) reading this field's world
# position, so it is deterministic and prediction-friendly. This node carries
# HP / wither (PlacedField) and a block body on the tangle layer that stops
# direct weapon rays (grenades and Null pass through — different masks).
class_name Tangle
extends PlacedField


func _ready() -> void:
	super()
	var block: StaticBody3D = $Block
	block.add_to_group("tangle_block")
	var col: CollisionShape3D = $Block/CollisionShape3D
	var sphere: SphereShape3D = col.shape.duplicate()
	sphere.radius = MatchConfig.get_value("ability.tangle_radius_m")
	col.shape = sphere


func _field_groups() -> Array[String]:
	return ["tangle_fields"]
