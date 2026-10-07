class_name ContentDefinition
extends Resource

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var kind: String = ""
@export var icon: String = ""
@export var max_rank: int = 5
@export var min_level: int = 1
@export var prerequisite: String = ""
@export var values: Dictionary = {}
